"""Load girls-struggling classifier and build feature rows matching girls_struggling.ipynb."""

from __future__ import annotations

from pathlib import Path

import joblib
import numpy as np
import pandas as pd

from app.config import girls_struggling_pipeline_path

STRUGGLE_NUMERIC_FEATURES = [
    "present_age_years",
    "length_stay_years",
    "age_upon_admission_years",
    "has_special_needs",
    "family_parent_pwd",
    "hw_mean_nutrition_score",
    "hw_mean_energy_level_score",
    "hw_rate_psychological_checkup_done",
    "edu_latest_attendance_rate",
    "n_education_records",
    "n_intervention_plans",
    "n_home_visitations",
    "n_incidents",
    "n_process_sessions",
    "incident_high_rate",
    "incident_unresolved_rate",
    "safety_concern_rate",
    "followup_needed_rate",
    "concerns_flagged_rate",
    "referral_made_rate",
    "occupancy_ratio",
]
STRUGGLE_CATEGORICAL_FEATURES = [
    "case_status",
    "case_category",
    "initial_risk_level",
    "current_risk_level",
    "referral_source",
    "reintegration_status",
    "edu_latest_education_level",
    "edu_latest_enrollment_status",
    "edu_latest_completion_status",
    "region",
    "province",
]
STRUGGLE_FEATURE_COLUMNS = STRUGGLE_NUMERIC_FEATURES + STRUGGLE_CATEGORICAL_FEATURES


def load_girls_struggling_pipeline(path: Path | None = None):
    p = path or girls_struggling_pipeline_path()
    if not p.is_file():
        raise FileNotFoundError(
            f"Girls struggling pipeline not found at {p}. "
            "Train girls_struggling.ipynb Phase 6 or set GIRLS_STRUGGLING_PIPELINE_PATH."
        )
    return joblib.load(p)


def clean_girls_struggling_row(row: dict) -> pd.DataFrame:
    """Single-row cleaning aligned with notebook preprocessing assumptions."""
    data = {k: row.get(k, None) for k in STRUGGLE_FEATURE_COLUMNS}
    out = pd.DataFrame([data])

    for c in STRUGGLE_NUMERIC_FEATURES:
        out[c] = pd.to_numeric(out[c], errors="coerce")

    for c in STRUGGLE_CATEGORICAL_FEATURES:
        s = out[c].astype(str).str.strip()
        s = s.replace({"": np.nan, "nan": np.nan, "None": np.nan})
        out[c] = s

    return out[STRUGGLE_FEATURE_COLUMNS]


def predict_girls_struggling(pipeline, row: dict) -> tuple[int, list[float]]:
    X = clean_girls_struggling_row(row)
    pred = int(pipeline.predict(X)[0])
    proba = pipeline.predict_proba(X)[0].tolist()
    return pred, proba
