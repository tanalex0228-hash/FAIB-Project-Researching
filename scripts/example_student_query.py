import pandas as pd
from sqlalchemy import create_engine


DATABASE_URL = "postgresql+psycopg2://student_username:student_password@100.72.157.21:5432/fred_macro"

engine = create_engine(DATABASE_URL)

query = """
select date, series_id, value
from macro_data
where series_id in ('DGS10', 'DGS2', 'FEDFUNDS', 'CPIAUCSL', 'UNRATE', 'GDPC1')
order by date, series_id
"""

df = pd.read_sql(query, engine)
df_wide = df.pivot(index="date", columns="series_id", values="value")

print(df_wide.tail())
