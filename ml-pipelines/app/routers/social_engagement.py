from fastapi import APIRouter, HTTPException, Request

from app.schemas.social_engagement import SocialEngagementFeatures, SocialEngagementPrediction
from app.services.social_engagement import SOCIAL_FEATURE_COLUMNS, predict_social_engagement

router = APIRouter(prefix="/social", tags=["social"])


@router.get("/features")
def social_feature_schema():
    return {"feature_columns": SOCIAL_FEATURE_COLUMNS, "order": SOCIAL_FEATURE_COLUMNS}


@router.post("/predict", response_model=SocialEngagementPrediction)
def social_engagement_predict(request: Request, body: SocialEngagementFeatures):
    pipeline = getattr(request.app.state, "social_engagement_pipeline", None)
    if pipeline is None:
        raise HTTPException(
            status_code=503,
            detail=(
                "Social engagement pipeline not loaded. Run social_media.ipynb Phase 6 "
                "or set SOCIAL_ENGAGEMENT_PIPELINE_PATH."
            ),
        )

    row = body.model_dump()
    try:
        pred = predict_social_engagement(pipeline, row)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    return SocialEngagementPrediction(
        predicted_engagement_rate=pred,
        features_used=SOCIAL_FEATURE_COLUMNS,
    )
