do $$
begin
    if not exists (select from pg_roles where rolname = 'macro_reader') then
        create role macro_reader login password 'macro_reader_change_me';
    end if;
end
$$;

grant connect on database fred_macro to macro_reader;
grant usage on schema public to macro_reader;
grant select on all tables in schema public to macro_reader;
alter default privileges in schema public grant select on tables to macro_reader;
