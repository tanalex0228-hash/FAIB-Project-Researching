import sys
from pathlib import Path

from sqlalchemy import text

sys.path.append(str(Path(__file__).resolve().parents[1]))

from app.db import engine


with engine.connect() as conn:
    print("fred_series", conn.execute(text("select count(*) from fred_series")).scalar())
    print("macro_data", conn.execute(text("select count(*) from macro_data")).scalar())
    rows = conn.execute(
        text(
            """
            select series_id, count(*) as n, min(date), max(date)
            from macro_data
            group by series_id
            order by series_id
            """
        )
    ).fetchall()
    for row in rows:
        print(tuple(row))
