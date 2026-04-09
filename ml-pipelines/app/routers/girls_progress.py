from fastapi import APIRouter, HTTPException, Request

from app.schemas.girls_progress import GirlsProgressFeatures, GirlsProgressPrediction
from app.services.girls_progress import GIRLS_FEATURE_COLUMNS, predict_girls_progress

router = APIRouter(prefix="/girls-progress", tags=["girls-progress"])


@router.get("/features")
def girls_progress_feature_schema():
    return {"feature_columns": GIRLS_FEATURE_COLUMNS, "order": GIRLS_FEATURE_COLUMNS}


@router.post("/predict", response_model=GirlsProgressPrediction)
def girls_progress_predict(request: Request, body: GirlsProgressFeatures):
    pipeline = getattr(request.app.state, "girls_progress_pipeline", None)
    if pipeline is None:
        raise HTTPException(
            status_code=503,
            detail="Girls progress pipeline not loaded. Run girls_progressing.ipynb Phase 6 or set GIRLS_PROGRESS_PIPELINE_PATH.",
        )
    try:
        pred = predict_girls_progress(pipeline, body.model_dump())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    return GirlsProgressPrediction(predicted_mean_progress=pred, features_used=GIRLS_FEATURE_COLUMNS)


@router.post("/batch/predict", response_model=list[GirlsProgressPrediction])
def girls_progress_batch_predict(request: Request, batch: list[GirlsProgressFeatures]):
    pipeline = getattr(request.app.state, "girls_progress_pipeline", None)
    if pipeline is None:
        raise HTTPException(status_code=503, detail="Girls progress pipeline not loaded.")
    try:
        return [
            GirlsProgressPrediction(
                predicted_mean_progress=predict_girls_progress(pipeline, row.model_dump()),
                features_used=GIRLS_FEATURE_COLUMNS,
            )
            for row in batch
        ]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
