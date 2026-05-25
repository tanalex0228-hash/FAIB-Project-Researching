import os

import numpy as np
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine
from statsmodels.tsa.api import VAR


load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@localhost:5432/fred_macro",
)

SERIES = ["dgs10", "dgs2", "fedfunds", "cpiaucsl", "unrate", "indpro"]


def main() -> None:
    engine = create_engine(
        DATABASE_URL,
        connect_args={"application_name": "var-example"},
    )

    query = f"""
    select month, {", ".join(SERIES)}
    from research.monthly_macro_wide
    where month >= '1985-01-01'
    order by month
    """

    df = pd.read_sql(query, engine, parse_dates=["month"]).set_index("month")

    # VAR needs aligned, stationary-ish data. This example uses common simple transforms:
    # rates and unemployment in differences; CPI and industrial production in log differences.
    transformed = pd.DataFrame(index=df.index)
    transformed["d_dgs10"] = df["dgs10"].diff()
    transformed["d_dgs2"] = df["dgs2"].diff()
    transformed["d_fedfunds"] = df["fedfunds"].diff()
    transformed["inflation"] = 100 * np.log(df["cpiaucsl"]).diff()
    transformed["d_unrate"] = df["unrate"].diff()
    transformed["indpro_growth"] = 100 * np.log(df["indpro"]).diff()

    model_df = transformed.dropna()
    model = VAR(model_df)
    results = model.fit(maxlags=12, ic="aic")

    print(results.summary())
    print("\nSelected lag order:", results.k_ar)
    print("\n5-step forecast:")
    forecast = results.forecast(model_df.values[-results.k_ar :], steps=5)
    print(pd.DataFrame(forecast, columns=model_df.columns))


if __name__ == "__main__":
    main()
