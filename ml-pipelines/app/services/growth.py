"""Load growth regression Pipeline and build feature rows (matches donor_growth notebook Phase 3)."""

from __future__ import annotations

from pathlib import Path

import joblib
import pandas as pd

from app.config import growth_pipeline_path, max_recency_fallback

# Must match GROWTH_* columns in donor_growth.ipynb — never include total_monetary_value as input.
GROWTH_NUMERIC_FEATURES = [
    "recency_days",
    "frequency",
    "avg_monetary_value",
    "social_referral_count",
    "is_recurring_donor",
]
GROWTH_CATEGORICAL_FEATURES = ["top_program_interest"]
GROWTH_FEATURE_COLUMNS = GROWTH_NUMERIC_FEATURES + GROWTH_CATEGORICAL_FEATURES


def load_growth_pipeline(path: Path | None = None):
    p = path or growth_pipeline_path()
    if not p.is_file():
        raise FileNotFoundError(
            f"Growth pipeline not found at {p}. "
            "Train donor_growth.ipynb Phase 6 or set GROWTH_PIPELINE_PATH."
        )
    return joblib.load(p)


def clean_growth_row(row: dict, *, recency_fallback: float | None = None) -> pd.DataFrame:
    """Same cleaning rules as the growth notebook for a single API row."""
    fallback = recency_fallback if recency_fallback is not None else max_recency_fallback()

    df = pd.DataFrame([dict(row)])
    out = df.copy()

    if out["recency_days"].isna().any():
        out.loc[out["recency_days"].isna(), "recency_days"] = float(fallback)

    out["frequency"] = out["frequency"].fillna(0.0)
    zero_gift = out["frequency"] == 0
    out.loc[out["avg_monetary_value"].isna() & zero_gift, "avg_monetary_value"] = 0.0
    med_avg = out["avg_monetary_value"].median(skipna=True)
    if pd.isna(med_avg):
        med_avg = 0.0
    out["avg_monetary_value"] = out["avg_monetary_value"].fillna(med_avg)

    out["social_referral_count"] = out["social_referral_count"].fillna(0.0)
    out["is_recurring_donor"] = out["is_recurring_donor"].fillna(0).astype(int)

    out["top_program_interest"] = (
        out["top_program_interest"].fillna("Unknown").astype(str).str.strip()
    )
    out.loc[out["top_program_interest"] == "", "top_program_interest"] = "Unknown"

    return out[GROWTH_FEATURE_COLUMNS]


def predict_growth(pipeline, row: dict) -> float:
    X = clean_growth_row(row)
    return float(pipeline.predict(X)[0])
