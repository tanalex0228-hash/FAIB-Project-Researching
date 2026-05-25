from __future__ import annotations

from typing import Any

import pandas as pd
import requests

from app.config import FRED_API_KEY, FRED_BASE_URL, OBSERVATION_END, OBSERVATION_START


class FredClient:
    def __init__(self, api_key: str | None = FRED_API_KEY, base_url: str = FRED_BASE_URL) -> None:
        if not api_key or api_key == "your_fred_api_key_here":
            raise ValueError("FRED_API_KEY is missing or still uses the placeholder value. Set it in .env before running the sync.")
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")

    def _get(self, endpoint: str, params: dict[str, Any]) -> dict[str, Any]:
        request_params = {
            "api_key": self.api_key,
            "file_type": "json",
            **params,
        }
        response = requests.get(f"{self.base_url}/{endpoint}", params=request_params, timeout=30)
        response.raise_for_status()
        return response.json()

    def get_series_metadata(self, series_id: str) -> dict[str, Any]:
        payload = self._get("series", {"series_id": series_id})
        series = payload.get("seriess", [])
        if not series:
            raise ValueError(f"No FRED metadata found for series_id={series_id}")
        item = series[0]
        return {
            "series_id": item["id"],
            "title": item.get("title") or item["id"],
            "frequency": item.get("frequency"),
            "units": item.get("units"),
            "source": "FRED",
        }

    def get_observations(
        self,
        series_id: str,
        observation_start: str = OBSERVATION_START,
        observation_end: str = OBSERVATION_END,
    ) -> pd.DataFrame:
        payload = self._get(
            "series/observations",
            {
                "series_id": series_id,
                "observation_start": observation_start,
                "observation_end": observation_end,
            },
        )
        observations = payload.get("observations", [])
        if not observations:
            return pd.DataFrame(columns=["series_id", "date", "value"])

        df = pd.DataFrame(observations)
        df = df[["date", "value"]].copy()
        df["series_id"] = series_id
        df["date"] = pd.to_datetime(df["date"]).dt.date
        df["value"] = pd.to_numeric(df["value"].replace(".", pd.NA), errors="coerce")
        df["value"] = df["value"].astype(object).where(pd.notna(df["value"]), None)
        return df[["series_id", "date", "value"]]
