from fastapi import APIRouter, HTTPException, Request

from app.schemas.girls_struggling import GirlsStrugglingFeatures, GirlsStrugglingPrediction
from app.services.girls_struggling import STRUGGLE_FEATURE_COLUMNS, predict_girls_struggling

router = APIRouter(prefix="/girls-struggling", tags=["girls-struggling"])


@router.get("/features")
def girls_struggling_feature_schema():
    return {"feature_columns": STRUGGLE_FEATURE_COLUMNS, "order": STRUGGLE_FEATURE_COLUMNS}


@router.post("/predict", response_model=GirlsStrugglingPrediction)
def girls_struggling_predict(request: Request, body: GirlsStrugglingFeatures):
    pipeline = getattr(request.app.state, "girls_struggling_pipeline", None)
    if pipeline is None:
        raise HTTPException(
            status_code=503,
            detail=(
                "Girls struggling pipeline not loaded. Run girls_struggling.ipynb Phase 6 "
                "or set GIRLS_STRUGGLING_PIPELINE_PATH."
            ),
        )

    row = body.model_dump()
    try:
        pred, proba = predict_girls_struggling(pipeline, row)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    clf = pipeline.named_steps.get("clf", None)
    classes = list(getattr(clf, "classes_", [0, 1]))
    prob_by_class = {int(c): float(p) for c, p in zip(classes, proba)}
    p_not = prob_by_class.get(0, 0.0)
    p_struggle = prob_by_class.get(1, 0.0)

    return GirlsStrugglingPrediction(
        predicted_class=pred,
        label="struggling" if pred == 1 else "not_struggling",
        probability_not_struggling=p_not,
        probability_struggling=p_struggle,
        features_used=STRUGGLE_FEATURE_COLUMNS,
    )
