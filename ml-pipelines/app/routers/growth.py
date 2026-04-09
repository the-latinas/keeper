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
    try:
        pred = predict_growth(pipeline, body.model_dump())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    return GrowthPrediction(predicted_total_monetary_value=pred, features_used=GROWTH_FEATURE_COLUMNS)


@router.post("/batch/predict", response_model=list[GrowthPrediction])
def growth_batch_predict(request: Request, batch: list[GrowthFeatures]):
    pipeline = getattr(request.app.state, "growth_pipeline", None)
    if pipeline is None:
        raise HTTPException(status_code=503, detail="Growth pipeline not loaded.")
    try:
        return [
            GrowthPrediction(
                predicted_total_monetary_value=predict_growth(pipeline, row.model_dump()),
                features_used=GROWTH_FEATURE_COLUMNS,
            )
            for row in batch
        ]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
