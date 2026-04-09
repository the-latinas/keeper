from fastapi import APIRouter, HTTPException, Request

from app.schemas.retention import RetentionFeatures, RetentionPrediction
from app.services.retention import FEATURE_COLUMNS, predict_retention

router = APIRouter(prefix="/retention", tags=["retention"])


def _make_prediction(pipeline, body: RetentionFeatures) -> RetentionPrediction:
    row = body.model_dump()
    pred, proba = predict_retention(pipeline, row)
    clf = pipeline.named_steps["clf"]
    classes = list(getattr(clf, "classes_", [0, 1]))
    prob_by_class = {int(c): float(p) for c, p in zip(classes, proba)}
    label = "retained" if pred == 1 else "lapsed"
    return RetentionPrediction(
        predicted_class=pred,
        label=label,
        probability_lapsed=prob_by_class.get(0, 0.0),
        probability_retained=prob_by_class.get(1, 0.0),
        features_used=FEATURE_COLUMNS,
    )


@router.get("/features")
def retention_feature_schema():
    return {"feature_columns": FEATURE_COLUMNS, "order": FEATURE_COLUMNS}


@router.post("/predict", response_model=RetentionPrediction)
def retention_predict(request: Request, body: RetentionFeatures):
    pipeline = getattr(request.app.state, "retention_pipeline", None)
    if pipeline is None:
        raise HTTPException(
            status_code=503,
            detail=(
                "Retention pipeline not loaded. Run donor_retention.ipynb Phase 6, "
                "place retention_pipeline_v1.sav under pipelines/, or set RETENTION_PIPELINE_PATH."
            ),
        )
    try:
        return _make_prediction(pipeline, body)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e


@router.post("/batch/predict", response_model=list[RetentionPrediction])
def retention_batch_predict(request: Request, batch: list[RetentionFeatures]):
    pipeline = getattr(request.app.state, "retention_pipeline", None)
    if pipeline is None:
        raise HTTPException(status_code=503, detail="Retention pipeline not loaded.")
    try:
        return [_make_prediction(pipeline, row) for row in batch]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
