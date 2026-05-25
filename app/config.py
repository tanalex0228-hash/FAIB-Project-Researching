import os
from datetime import date

from dotenv import load_dotenv


load_dotenv()


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@localhost:5432/fred_macro",
)

FRED_API_KEY = os.getenv("FRED_API_KEY")
FRED_BASE_URL = os.getenv("FRED_BASE_URL", "https://api.stlouisfed.org/fred")

OBSERVATION_START = os.getenv("OBSERVATION_START", "1945-01-01")
OBSERVATION_END = os.getenv("OBSERVATION_END", date.today().isoformat())

FRED_SERIES_IDS = [
    "DGS10",
    "DGS2",
    "TB3MS",
    "FEDFUNDS",
    "CPIAUCSL",
    "CPILFESL",
    "UNRATE",
    "NROU",
    "INDPRO",
    "USREC",
    "M2SL",
    "MORTGAGE30US",
    "GDPC1",
]
