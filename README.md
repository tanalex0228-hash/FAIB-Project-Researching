# fred-macro-research-db

Python + PostgreSQL macroeconomic research database for collecting FRED time series data.

The project is structured as a small ETL pipeline that fetches FRED metadata and observations, stores them in PostgreSQL, and keeps repeated syncs idempotent with upserts. The schema is intentionally simple and research-friendly for future VAR, forecasting, regime analysis, and time series workflows.

## Project Structure

```text
fred-macro-research-db/
├── app/
│   ├── db.py
│   ├── fred_client.py
│   ├── sync_fred.py
│   ├── models.py
│   └── config.py
├── .env
├── requirements.txt
├── README.md
└── docker-compose.yml
```

## PostgreSQL Setup

Start PostgreSQL with Docker:

```bash
docker compose up -d
```

Default database settings:

```text
host: localhost
port: 5432
database: fred_macro
user: postgres
password: postgres
```

The Python sync script creates the required tables automatically through SQLAlchemy.

## Environment Variables

Edit `.env`:

```env
DATABASE_URL=postgresql+psycopg2://postgres:postgres@localhost:5432/fred_macro
FRED_API_KEY=your_fred_api_key_here
OBSERVATION_START=1945-01-01
```

`OBSERVATION_END` is optional. If omitted, the sync uses today's date.

## Install Dependencies

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run ETL Sync

From the project root:

```bash
python -m app.sync_fred
```

The script fetches data from `1945-01-01` through today for:

```text
DGS10
DGS2
TB3MS
FEDFUNDS
CPIAUCSL
CPILFESL
UNRATE
NROU
INDPRO
USREC
M2SL
MORTGAGE30US
GDPC1
```

Repeated runs are safe. Existing `(series_id, date)` rows are updated through PostgreSQL upsert.

## Ubuntu Server Deployment

Example server:

```text
user: alex
host: 100.72.157.21
project path: ~/fred-macro-research-db
```

Start PostgreSQL on the server with Docker:

```bash
cd ~/fred-macro-research-db
chmod +x scripts/start_postgres_server.sh
sudo scripts/start_postgres_server.sh
```

The container binds PostgreSQL to:

```text
127.0.0.1:5432
100.72.157.21:5432
```

This allows local ETL jobs on the server and Tailscale-only access from your Mac.

Create the Python environment on the server:

```bash
cd ~/fred-macro-research-db
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m app.sync_fred
python scripts/check_db.py
```

From your Mac, connect through Tailscale with:

```text
postgresql://postgres:postgres@100.72.157.21:5432/fred_macro
```

## Team Research Access

Recommended setup:

```text
PostgreSQL
├── postgres: owner/admin account
├── one read-only DB account per teammate
├── pg_stat_statements: query and usage statistics
├── Metabase: charts, exploration, CSV export
└── pgAdmin: admin database panel
```

Create five read-only research users:

```bash
cd ~/fred-macro-research-db
chmod +x scripts/create_research_users.sh

sudo scripts/create_research_users.sh \
  member01='replace_with_password_1' \
  member02='replace_with_password_2' \
  member03='replace_with_password_3' \
  member04='replace_with_password_4' \
  member05='replace_with_password_5'
```

Each research user can only read:

```text
fred_series
macro_data
```

They cannot create databases, create roles, or write to the research tables.

Student connection string:

```text
postgresql+psycopg2://member01:password@100.72.157.21:5432/fred_macro
```

Python example:

```python
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine(
    "postgresql+psycopg2://member01:password@100.72.157.21:5432/fred_macro"
)

df = pd.read_sql(
    """
    select date, series_id, value
    from macro_data
    where series_id in ('DGS10', 'DGS2', 'FEDFUNDS', 'CPIAUCSL', 'UNRATE', 'GDPC1')
    order by date, series_id
    """,
    engine,
)

df_wide = df.pivot(index="date", columns="series_id", values="value")
```

## Usage Monitoring

Enable PostgreSQL query statistics:

```bash
cd ~/fred-macro-research-db
chmod +x scripts/setup_usage_monitoring.sh
sudo scripts/setup_usage_monitoring.sh
```

This creates:

```text
admin.user_query_usage
admin.user_usage_summary
```

Useful admin queries:

```sql
select *
from admin.user_usage_summary;
```

```sql
select username, calls, rows, total_exec_ms, mean_exec_ms, query_sample
from admin.user_query_usage
order by total_exec_ms desc;
```

Notes:

```text
pg_stat_statements stores normalized query patterns and aggregate usage.
It is good for seeing who queried heavily, which query patterns are expensive, row counts, and execution time.
It is not a full forensic audit log of every exact query text with every literal value.
```

For stronger auditing later, add PostgreSQL audit logging or route PostgreSQL logs into Loki/ELK.

## Visual Panels

### Metabase

Metabase is best for teammates:

```text
http://100.72.157.21:3000
```

Use it for filtering, charts, dashboards, and CSV export without writing SQL.

Start it:

```bash
cd ~/fred-macro-research-db
chmod +x scripts/start_metabase_server.sh
sudo scripts/start_metabase_server.sh
```

Metabase database connection:

```text
Database type: PostgreSQL
Host: fred_macro_postgres
Port: 5432
Database name: fred_macro
Username: macro_reader or a read-only member account
Password: the account password
```

### pgAdmin

pgAdmin is best for the server owner/admin:

```text
http://100.72.157.21:5050
```

Start it:

```bash
cd ~/fred-macro-research-db
chmod +x scripts/start_pgadmin_server.sh
sudo PGADMIN_EMAIL='your_email@example.com' PGADMIN_PASSWORD='replace_with_admin_password' scripts/start_pgadmin_server.sh
```

Register the PostgreSQL server inside pgAdmin:

```text
Host: fred_macro_postgres
Port: 5432
Maintenance database: fred_macro
Username: postgres
Password: postgres
```

As the owner, use pgAdmin or Metabase with the `postgres` account to inspect:

```text
admin.user_usage_summary
admin.user_query_usage
```

## Schema

### fred_series

Stores FRED series metadata.

| Column | Type | Notes |
| --- | --- | --- |
| id | integer | Primary key |
| series_id | varchar | Unique FRED series identifier |
| title | varchar | FRED series title |
| frequency | varchar | Series frequency |
| units | varchar | Measurement units |
| source | varchar | Defaults to `FRED` |
| created_at | timestamp with time zone | Insert timestamp |

### macro_data

Stores normalized time series observations.

| Column | Type | Notes |
| --- | --- | --- |
| id | integer | Primary key |
| series_id | varchar | Foreign key to `fred_series.series_id` |
| date | date | Observation date |
| value | float | Numeric value; missing FRED values are stored as null |
| created_at | timestamp with time zone | Insert timestamp |

Constraints:

```text
unique(series_id, date)
```

This keeps the dataset suitable for panel-style joins and wide time series transformations.

## Research Workflow Notes

For VAR and time series research, use `macro_data` as the canonical long-format table:

```sql
select
  date,
  series_id,
  value
from macro_data
where date >= '1945-01-01'
order by date, series_id;
```

Long format is easier to audit and append. In Python, pivot it into wide format when modeling:

```python
df_wide = df.pivot(index="date", columns="series_id", values="value")
```

This keeps ingestion simple while leaving transformations flexible for stationarity checks, lag construction, differencing, resampling, and model-specific preprocessing.
