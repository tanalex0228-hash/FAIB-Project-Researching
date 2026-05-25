# Team Research Platform

This project can run as a small research data platform for VAR, forecasting, and machine learning work.

## Roles

| Role | Tool | Purpose |
| --- | --- | --- |
| Server owner | PostgreSQL `postgres`, pgAdmin, Metabase admin | Manage data, users, usage, and dashboards |
| Research member | Personal PostgreSQL account | Pull data into Python/R/Notebook for modeling |
| Viewer | Metabase account | Explore charts and export CSV without coding |

## Access Model

Each teammate should have two identities:

```text
1. PostgreSQL account: for Python/R/ML training access
2. Metabase account: for browser-based exploration and dashboards
```

Do not share one database account across the whole team. Personal DB accounts make usage monitoring meaningful.

## Owner URLs

```text
Metabase: http://100.72.157.21:3000
pgAdmin:  http://100.72.157.21:5050
```

Use Tailscale or VPN-only access. Avoid exposing these panels directly to the public internet.

## Bootstrap

Run this on the Ubuntu server:

```bash
cd ~/fred-macro-research-db
chmod +x scripts/bootstrap_team_platform.sh
sudo TEAM_SIZE=5 TEAM_PREFIX=member PGADMIN_EMAIL='your_email@example.com' scripts/bootstrap_team_platform.sh
```

The script writes generated credentials to:

```text
team_credentials.local
```

Keep that file private.

## Usage Monitoring

The monitoring setup creates:

```text
admin.user_usage_summary
admin.user_query_usage
```

Useful owner queries:

```sql
select *
from admin.user_usage_summary;
```

```sql
select username, calls, rows, total_exec_ms, mean_exec_ms, query_sample
from admin.user_query_usage
order by total_exec_ms desc;
```

Important limitation:

```text
pg_stat_statements tracks normalized query patterns and aggregate usage.
It does not store a perfect event-by-event audit trail.
```

For full audit logs later, add PostgreSQL audit logging and ship logs into Loki, ELK, or another log viewer.

## Modeling Workflow

Members connect with their personal connection string:

```python
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine(
    "postgresql+psycopg2://member01:password@100.72.157.21:5432/fred_macro",
    connect_args={"application_name": "member01-var-model"},
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

Ask members to set `application_name` in their connection. It helps the owner see active model jobs in PostgreSQL.

## GitHub Workflow

Use GitHub for project management:

```text
Issues: research tasks, data requests, model experiments
Branches: one branch per task
Pull requests: code review and reproducibility check
GitHub Projects: kanban board for progress tracking
```

Suggested labels:

```text
data
model
var
machine-learning
experiment
bug
documentation
blocked
needs-review
```

Suggested columns:

```text
Backlog
Ready
In Progress
Review
Done
```

Every model experiment should record:

```text
Data range
Series used
Preprocessing
Train/test split
Model configuration
Metrics
Output artifacts
```
