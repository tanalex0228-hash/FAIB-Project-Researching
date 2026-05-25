from __future__ import annotations

from sqlalchemy.dialects.postgresql import insert

from app.config import FRED_SERIES_IDS
from app.db import SessionLocal, init_db
from app.fred_client import FredClient
from app.models import FredSeries, MacroData


def upsert_series(session, metadata: dict) -> None:
    stmt = insert(FredSeries).values(**metadata)
    stmt = stmt.on_conflict_do_update(
        index_elements=[FredSeries.series_id],
        set_={
            "title": stmt.excluded.title,
            "frequency": stmt.excluded.frequency,
            "units": stmt.excluded.units,
            "source": stmt.excluded.source,
        },
    )
    session.execute(stmt)


def upsert_observations(session, rows: list[dict]) -> None:
    if not rows:
        return

    stmt = insert(MacroData).values(rows)
    stmt = stmt.on_conflict_do_update(
        constraint="uq_macro_data_series_id_date",
        set_={"value": stmt.excluded.value},
    )
    session.execute(stmt)


def sync_series(client: FredClient, series_id: str) -> int:
    with SessionLocal() as session:
        metadata = client.get_series_metadata(series_id)
        upsert_series(session, metadata)

        observations = client.get_observations(series_id)
        rows = observations.to_dict(orient="records")
        upsert_observations(session, rows)

        session.commit()
        return len(rows)


def main() -> None:
    init_db()
    client = FredClient()

    for series_id in FRED_SERIES_IDS:
        count = sync_series(client, series_id)
        print(f"Synced {series_id}: {count} observations")


if __name__ == "__main__":
    main()
