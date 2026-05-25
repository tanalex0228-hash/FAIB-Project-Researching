create schema if not exists research;

create or replace view research.monthly_macro_long as
with monthly_last as (
    select
        series_id,
        date_trunc('month', date)::date as month,
        (array_agg(value order by date desc))[1] as value
    from macro_data
    group by series_id, date_trunc('month', date)::date
)
select
    month,
    series_id,
    value
from monthly_last
order by month, series_id;

create or replace view research.monthly_macro_wide as
select
    month,
    max(value) filter (where series_id = 'DGS10') as dgs10,
    max(value) filter (where series_id = 'DGS2') as dgs2,
    max(value) filter (where series_id = 'TB3MS') as tb3ms,
    max(value) filter (where series_id = 'FEDFUNDS') as fedfunds,
    max(value) filter (where series_id = 'CPIAUCSL') as cpiaucsl,
    max(value) filter (where series_id = 'CPILFESL') as cpilfesl,
    max(value) filter (where series_id = 'UNRATE') as unrate,
    max(value) filter (where series_id = 'NROU') as nrou,
    max(value) filter (where series_id = 'INDPRO') as indpro,
    max(value) filter (where series_id = 'USREC') as usrec,
    max(value) filter (where series_id = 'M2SL') as m2sl,
    max(value) filter (where series_id = 'MORTGAGE30US') as mortgage30us,
    max(value) filter (where series_id = 'GDPC1') as gdpc1
from research.monthly_macro_long
group by month
order by month;

grant usage on schema research to public;
grant select on research.monthly_macro_long to public;
grant select on research.monthly_macro_wide to public;
