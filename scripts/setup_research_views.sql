create schema if not exists research;

create table if not exists macro_features (
    month date primary key,
    inflation_yoy numeric,
    core_inflation_yoy numeric,
    spread_10y_2y numeric,
    spread_10y_3m numeric,
    real_10y_rate numeric,
    real_fedfunds_rate numeric,
    industrial_production_yoy numeric,
    recession_regime integer,
    created_at timestamp default now(),
    updated_at timestamp default now()
);

create or replace view research.monthly_macro_long as
with month_bounds as (
    select
        date_trunc('month', min(date))::date as min_month,
        date_trunc('month', max(date))::date as max_month
    from macro_data
),
calendar as (
    select generate_series(min_month, max_month, interval '1 month')::date as month
    from month_bounds
),
series_list as (
    select distinct series_id
    from macro_data
),
monthly_last as (
    select
        series_id,
        date_trunc('month', date)::date as month,
        (array_agg(value order by date desc))[1] as value
    from macro_data
    group by series_id, date_trunc('month', date)::date
),
monthly_aligned as (
    select
        calendar.month,
        series_list.series_id,
        case
            when series_list.series_id = 'GDPC1' then (
                select gdpc1.value
                from monthly_last gdpc1
                where gdpc1.series_id = 'GDPC1'
                  and calendar.month >= gdpc1.month
                  and calendar.month < gdpc1.month + interval '3 months'
                order by gdpc1.month desc
                limit 1
            )
            else monthly_last.value
        end as value
    from calendar
    cross join series_list
    left join monthly_last
      on monthly_last.month = calendar.month
     and monthly_last.series_id = series_list.series_id
)
select
    month,
    series_id,
    value
from monthly_aligned
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
    max(value) filter (where series_id = 'GDPC1') as gdpc1,
    max(value) filter (where series_id = 'VIXCLS') as vixcls,
    max(value) filter (where series_id = 'UMCSENT') as umcsent,
    max(value) filter (where series_id = 'PAYEMS') as payems,
    max(value) filter (where series_id = 'WALCL') as walcl,
    max(value) filter (where series_id = 'T10Y2Y') as t10y2y
from research.monthly_macro_long
group by month
order by month;

create or replace view research.monthly_macro_features as
select
    wide.*,
    features.inflation_yoy,
    features.core_inflation_yoy,
    features.spread_10y_2y,
    features.spread_10y_3m,
    features.real_10y_rate,
    features.real_fedfunds_rate,
    features.industrial_production_yoy,
    features.recession_regime
from research.monthly_macro_wide wide
left join macro_features features
  on features.month = wide.month
order by wide.month;

grant usage on schema research to public;
grant select on macro_features to public;
grant select on research.monthly_macro_long to public;
grant select on research.monthly_macro_wide to public;
grant select on research.monthly_macro_features to public;
