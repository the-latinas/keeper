"""T-Learner causal inference service for is_boosted → has_referred_gift.

Artifact format (dict saved by social_media_causal_boost.ipynb Phase 6):
    {
        "control_pipeline":   sklearn.Pipeline,  # fit on T==0 rows
        "treatment_pipeline": sklearn.Pipeline,  # fit on T==1 rows
        "propensity_pipeline": sklearn.Pipeline, # fit on all rows
        "ate":       float,
        "ate_lower": float,
        "ate_upper": float,
        "n_control": int,
        "n_treated": int,
    }
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import joblib
import pandas as pd

from app.config import social_causal_pipeline_path

# Must match CAUSAL_FEATURE_COLUMNS in social_media_causal_boost.ipynb Phase 3
CAUSAL_NUMERIC_FEATURES: list[str] = [
    "caption_length",
    "num_hashtags",
    "follower_count_at_post",
    "post_hour",
    "has_call_to_action",
    "boost_budget_php",
]
CAUSAL_CATEGORICAL_FEATURES: list[str] = [
    "platform",
    "post_type",
    "media_type",
    "content_topic",
    "sentiment_tone",
    "post_dow",
    "call_to_action_type",
]
CAUSAL_FEATURE_COLUMNS: list[str] = CAUSAL_NUMERIC_FEATURES + CAUSAL_CATEGORICAL_FEATURES

_REQUIRED_ARTIFACT_KEYS = {
    "control_pipeline",
    "treatment_pipeline",
    "propensity_pipeline",
    "ate",
    "ate_lower",
    "ate_upper",
}


def load_social_causal_artifact(path: Path | None = None) -> dict[str, Any]:
    """Load the T-Learner artifact dict from disk."""
    p = path or social_causal_pipeline_path()
    if not p.is_file():
        raise FileNotFoundError(
            f"Social causal artifact not found at {p}. "
            "Run social_media_causal_boost.ipynb Phase 6 or set "
            "SOCIAL_CAUSAL_PIPELINE_PATH."
        )
    raw = joblib.load(p)
    if not isinstance(raw, dict):
        raise ValueError(
            f"Expected a dict artifact; got {type(raw).__name__}. "
            "Re-run social_media_causal_boost.ipynb Phase 6."
        )
    missing = _REQUIRED_ARTIFACT_KEYS - raw.keys()
    if missing:
        raise ValueError(f"Artifact is missing required keys: {missing}")
    return raw


def clean_causal_row(row: dict) -> pd.DataFrame:
    """Align single-row inference with notebook Phase 3 cleaning rules."""
    df = pd.DataFrame([dict(row)])

    for col in CAUSAL_NUMERIC_FEATURES:
        if col not in df.columns:
            df[col] = 0.0
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0.0)

    for col in CAUSAL_CATEGORICAL_FEATURES:
        default = "None" if col == "call_to_action_type" else "Unknown"
        if col not in df.columns:
            df[col] = default
        df[col] = df[col].astype("string").fillna(default).replace("", default)

    df["has_call_to_action"] = df["has_call_to_action"].clip(0, 1).round().astype(int)
    df["boost_budget_php"] = df["boost_budget_php"].clip(lower=0)
    df["post_hour"] = df["post_hour"].clip(0, 23).round().astype(int)

    return df[CAUSAL_FEATURE_COLUMNS]


def predict_causal_boost(
    artifact: dict[str, Any],
    row: dict,
) -> tuple[float, float, float, float]:
    """Return (p_if_boosted, p_if_not_boosted, propensity_score, estimated_ite).

    p_if_boosted     = P(has_referred_gift=1 | X, boost=1)  [treatment pipeline]
    p_if_not_boosted = P(has_referred_gift=1 | X, boost=0)  [control pipeline]
    estimated_ite    = p_if_boosted - p_if_not_boosted
    propensity_score = P(is_boosted=1 | X)                  [propensity pipeline]
    """
    X = clean_causal_row(row)
    p_if_not_boosted = float(artifact["control_pipeline"].predict_proba(X)[0, 1])
    p_if_boosted = float(artifact["treatment_pipeline"].predict_proba(X)[0, 1])
    propensity = float(artifact["propensity_pipeline"].predict_proba(X)[0, 1])
    ite = p_if_boosted - p_if_not_boosted
    return p_if_boosted, p_if_not_boosted, propensity, ite
