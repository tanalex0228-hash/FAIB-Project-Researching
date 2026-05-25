from __future__ import annotations

import argparse
from datetime import date
from decimal import Decimal
from typing import Any

import pandas as pd
from sqlalchemy import text
from sqlalchemy.dialects.postgresql import insert

from app.db import SessionLocal, engine, init_db
from app.models import MacroFeatures


FEATURE_COLUMNS = [
    "inflation_yoy",
    "core_inflation_yoy",
    "spread_10y_2y",
    "spread_10y_3m",
    "real_10y_rate",
    "real_fedfunds_rate",
    "industrial_production_yoy",
    "recession_regime",
]


def latest_feature_month() -> date | None:
    with engine.connect() as conn:
        return conn.execute(text("select max(month) from macro_features")).scalar()


def load_monthly_dataset() -> pd.DataFrame:
    query = """
    select *
    from research.monthly_macro_wide
    order by month
    """
    df = pd.read_sql(query, engine, parse_dates=["month"])
    return df.set_index("month")


def calculate_features(monthly: pd.DataFrame) -> pd.DataFrame:
    features = pd.DataFrame(index=monthly.index)

    features["inflation_yoy"] = monthly["cpiaucsl"].pct_change(12, fill_method=None) * 100
    features["core_inflation_yoy"] = monthly["cpilfesl"].pct_change(12, fill_method=None) * 100

    features["spread_10y_2y"] = monthly["dgs10"] - monthly["dgs2"]
    features["spread_10y_3m"] = monthly["dgs10"] - monthly["tb3ms"]

    features["real_10y_rate"] = monthly["dgs10"] - features["inflation_yoy"]
    features["real_fedfunds_rate"] = monthly["fedfunds"] - features["inflation_yoy"]

    features["industrial_production_yoy"] = monthly["indpro"].pct_change(12, fill_method=None) * 100

    features["recession_regime"] = monthly["usrec"].where(monthly["usrec"].isna(), monthly["usrec"].round().astype("Int64"))
    features["recession_regime"] = features["recession_regime"].where(features["recession_regime"].isin([0, 1]) | features["recession_regime"].isna())

    return features.reset_index().rename(columns={"month": "month"})


def decimal_or_none(value: Any) -> Decimal | int | None:
    if pd.isna(value):
        return None
    if isinstance(value, (int,)):
        return value
    return Decimal(str(float(value)))


def to_rows(features: pd.DataFrame) -> list[dict[str, Any]]:
    rows = []
    for record in features.to_dict(orient="records"):
        row: dict[str, Any] = {"month": record["month"].date()}
        for column in FEATURE_COLUMNS:
            row[column] = decimal_or_none(record[column])
        if row["recession_regime"] is not None:
            row["recession_regime"] = int(row["recession_regime"])
        rows.append(row)
    return rows


def upsert_features(rows: list[dict[str, Any]]) -> None:
    if not rows:
        return

    with SessionLocal() as session:
        stmt = insert(MacroFeatures).values(rows)
        stmt = stmt.on_conflict_do_update(
            index_elements=[MacroFeatures.month],
            set_={
                "inflation_yoy": stmt.excluded.inflation_yoy,
                "core_inflation_yoy": stmt.excluded.core_inflation_yoy,
                "spread_10y_2y": stmt.excluded.spread_10y_2y,
                "spread_10y_3m": stmt.excluded.spread_10y_3m,
                "real_10y_rate": stmt.excluded.real_10y_rate,
                "real_fedfunds_rate": stmt.excluded.real_fedfunds_rate,
                "industrial_production_yoy": stmt.excluded.industrial_production_yoy,
                "recession_regime": stmt.excluded.recession_regime,
                "updated_at": text("now()"),
            },
        )
        session.execute(stmt)
        session.commit()


def filter_incremental(features: pd.DataFrame, full_refresh: bool) -> pd.DataFrame:
    if full_refresh:
        return features

    latest_month = latest_feature_month()
    if latest_month is None:
        return features

    start_month = pd.Timestamp(latest_month) - pd.DateOffset(months=12)
    return features[features["month"] >= start_month]


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate macro feature table from monthly macro dataset.")
    parser.add_argument("--full-refresh", action="store_true", help="Recompute and upsert all months.")
    args = parser.parse_args()

    init_db()
    monthly = load_monthly_dataset()
    features = calculate_features(monthly)
    features = filter_incremental(features, args.full_refresh)
    rows = to_rows(features)
    upsert_features(rows)
    print(f"Upserted macro_features rows: {len(rows)}")


if __name__ == "__main__":
    main()
