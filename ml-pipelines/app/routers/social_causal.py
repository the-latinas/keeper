"""FastAPI router for the T-Learner causal boost endpoint."""

from fastapi import APIRouter, HTTPException, Request

from app.schemas.social_causal import SocialCausalFeatures, SocialCausalPrediction
from app.services.social_causal import CAUSAL_FEATURE_COLUMNS, predict_causal_boost

router = APIRouter(prefix="/social", tags=["social-causal"])


@router.get("/causal/features")
def causal_feature_schema():
    """Return the expected input feature columns for the causal boost model.

    Note: do NOT include is_boosted — it is the treatment variable.
    The model estimates the counterfactual effect of boosting for any post.
    """
    return {
        "feature_columns": CAUSAL_FEATURE_COLUMNS,
        "order": CAUSAL_FEATURE_COLUMNS,
        "treatment_variable": "is_boosted",
        "outcome_variable": "has_referred_gift",
        "note": (
            "Omit is_boosted from the request body. "
            "The model returns estimated_ite = P(gift | boosted) - P(gift | not boosted) "
            "as a counterfactual comparison for the same post characteristics."
        ),
    }


@router.post("/causal/predict", response_model=SocialCausalPrediction)
def social_causal_predict(request: Request, body: SocialCausalFeatures):
    """Estimate the causal effect of boosting this post on donation referral probability.

    Returns the individual treatment effect (ITE), counterfactual probabilities,
    propensity score, and the population-level ATE with 95% bootstrap CI.
    """
    artifact = getattr(request.app.state, "social_causal_artifact", None)
    if artifact is None:
        raise HTTPException(
            status_code=503,
            detail=(
                "Social causal artifact not loaded. "
                "Run social_media_causal_boost.ipynb Phase 6 or set SOCIAL_CAUSAL_PIPELINE_PATH."
            ),
        )

    row = body.model_dump()
    try:
        p_boosted, p_not_boosted, propensity, ite = predict_causal_boost(artifact, row)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    return SocialCausalPrediction(
        estimated_ite=ite,
        p_outcome_if_boosted=p_boosted,
        p_outcome_if_not_boosted=p_not_boosted,
        propensity_score=propensity,
        ate=artifact["ate"],
        ate_lower=artifact["ate_lower"],
        ate_upper=artifact["ate_upper"],
        features_used=CAUSAL_FEATURE_COLUMNS,
    )
