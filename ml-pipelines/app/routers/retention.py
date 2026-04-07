from fastapi import APIRouter, HTTPException, Request

from app.schemas.retention import RetentionFeatures, RetentionPrediction
from app.services.retention import FEATURE_COLUMNS, predict_retention

router = APIRouter(prefix="/retention", tags=["retention"])


@router.get("/features")
def retention_feature_schema():
    return {"feature_columns": FEATURE_COLUMNS, "order": FEATURE_COLUMNS}


@router.post("/predict", response_model=RetentionPrediction)
def retention_predict(request: Request, body: RetentionFeatures):
    pipeline = getattr(request.app.state, "retention_pipeline", None)
    if pipeline is None:
        raise HTTPException(status_code=503, detail="Pipeline not loaded")

    row = body.model_dump()
    try:
        pred, proba = predict_retention(pipeline, row)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    clf = pipeline.named_steps["clf"]
    classes = list(getattr(clf, "classes_", [0, 1]))
    prob_by_class = {int(c): float(p) for c, p in zip(classes, proba)}
    p_lapsed = prob_by_class.get(0, 0.0)
    p_retained = prob_by_class.get(1, 0.0)

    label = "retained" if pred == 1 else "lapsed"
    return RetentionPrediction(
        predicted_class=pred,
        label=label,
        probability_lapsed=p_lapsed,
        probability_retained=p_retained,
        features_used=FEATURE_COLUMNS,
    )
