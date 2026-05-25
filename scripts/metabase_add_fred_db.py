import os
import sys
from typing import NoReturn

import requests


METABASE_URL = os.getenv("METABASE_URL", "http://100.72.157.21:3000").rstrip("/")
METABASE_EMAIL = os.getenv("METABASE_EMAIL")
METABASE_PASSWORD = os.getenv("METABASE_PASSWORD")

DB_DISPLAY_NAME = os.getenv("MB_FRED_DB_NAME", "FRED Macro Research DB")
DB_HOST = os.getenv("MB_FRED_DB_HOST", "fred_macro_postgres")
DB_PORT = int(os.getenv("MB_FRED_DB_PORT", "5432"))
DB_NAME = os.getenv("MB_FRED_DB_DATABASE", "fred_macro")
DB_USER = os.getenv("MB_FRED_DB_USER", "postgres")
DB_PASSWORD = os.getenv("MB_FRED_DB_PASSWORD", "postgres")


def require_env(name: str, value: str | None) -> str:
    if not value:
        print(f"Missing environment variable: {name}", file=sys.stderr)
        sys.exit(1)
    return value


def raise_with_body(response: requests.Response) -> NoReturn:
    print(f"Metabase API error: HTTP {response.status_code}", file=sys.stderr)
    print(response.text, file=sys.stderr)
    response.raise_for_status()
    raise RuntimeError("unreachable")


def main() -> None:
    email = require_env("METABASE_EMAIL", METABASE_EMAIL)
    password = require_env("METABASE_PASSWORD", METABASE_PASSWORD)

    session_response = requests.post(
        f"{METABASE_URL}/api/session",
        json={"username": email, "password": password},
        timeout=30,
    )
    session_response.raise_for_status()
    token = session_response.json()["id"]
    headers = {"X-Metabase-Session": token}

    databases_response = requests.get(f"{METABASE_URL}/api/database", headers=headers, timeout=30)
    databases_response.raise_for_status()
    existing = databases_response.json().get("data", [])
    for database in existing:
        if database.get("name") == DB_DISPLAY_NAME:
            print(f"Database already exists in Metabase: {DB_DISPLAY_NAME}")
            print(f"Metabase database id: {database.get('id')}")
            return

    payload = {
        "name": DB_DISPLAY_NAME,
        "engine": "postgres",
        "details": {
            "host": DB_HOST,
            "port": DB_PORT,
            "dbname": DB_NAME,
            "user": DB_USER,
            "password": DB_PASSWORD,
            "ssl": False,
            "tunnel-enabled": False,
        },
        "is_full_sync": True,
        "is_on_demand": False,
        "schedules": {},
        "auto_run_queries": True,
    }

    create_response = requests.post(
        f"{METABASE_URL}/api/database",
        json=payload,
        headers=headers,
        timeout=30,
    )
    if not create_response.ok:
        raise_with_body(create_response)
    database = create_response.json()
    database_id = database["id"]

    requests.post(
        f"{METABASE_URL}/api/database/{database_id}/sync_schema",
        headers=headers,
        timeout=30,
    ).raise_for_status()

    print(f"Added database to Metabase: {DB_DISPLAY_NAME}")
    print(f"Metabase database id: {database_id}")


if __name__ == "__main__":
    main()
