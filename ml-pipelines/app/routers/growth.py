from fastapi import APIRouter, HTTPException, Request

from app.schemas.growth import GrowthFeatures, GrowthPrediction
from app.services.growth import GROWTH_FEATURE_COLUMNS, predict_growth

router = APIRouter(prefix="/growth", tags=["growth"])


@router.get("/features")
def growth_feature_schema():
    return {"feature_columns": GROWTH_FEATURE_COLUMNS, "order": GROWTH_FEATURE_COLUMNS}


@router.post("/predict", response_model=GrowthPrediction)
def growth_predict(request: Request, body: GrowthFeatures):
    pipeline = getattr(request.app.state, "growth_pipeline", None)
    if pipeline is None:
        raise HTTPException(
            status_code=503,
            detail="Growth pipeline not loaded. Run donor_growth.ipynb Phase 6 or set GROWTH_PIPELINE_PATH.",
        )

    row = body.model_dump()
    try:
        pred = predict_growth(pipeline, row)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    return GrowthPrediction(
        predicted_total_monetary_value=pred,
        features_used=GROWTH_FEATURE_COLUMNS,
    )
