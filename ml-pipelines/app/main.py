"""
Donor ML pipelines — FastAPI entrypoint.

Run from repository root:
  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

Docs: http://127.0.0.1:8000/docs
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from starlette.requests import Request

from app.config import (
    girls_progress_pipeline_path,
    girls_struggling_pipeline_path,
    growth_pipeline_path,
    retention_pipeline_path,
    social_engagement_pipeline_path,
)
from app.routers.girls_progress import router as girls_progress_router
from app.routers.girls_struggling import router as girls_struggling_router
from app.routers.growth import router as growth_router
from app.routers.retention import router as retention_router
from app.routers.social_engagement import router as social_engagement_router
from app.services.girls_progress import load_girls_progress_pipeline
from app.services.girls_struggling import load_girls_struggling_pipeline
from app.services.growth import load_growth_pipeline
from app.services.retention import load_retention_pipeline
from app.services.social_engagement import load_social_engagement_pipeline


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Retention classifier (required for full service — train donor_retention Phase 6)
    app.state.retention_pipeline = load_retention_pipeline(retention_pipeline_path())
    # Growth regressor (optional until donor_growth Phase 6 artifact exists)
    app.state.growth_pipeline = None
    gp = growth_pipeline_path()
    if gp.is_file():
        try:
            app.state.growth_pipeline = load_growth_pipeline(gp)
        except Exception:
            app.state.growth_pipeline = None
    app.state.social_engagement_pipeline = None
    sp = social_engagement_pipeline_path()
    if sp.is_file():
        try:
            app.state.social_engagement_pipeline = load_social_engagement_pipeline(sp)
        except Exception:
            app.state.social_engagement_pipeline = None
    app.state.girls_progress_pipeline = None
    gp_girls = girls_progress_pipeline_path()
    if gp_girls.is_file():
        try:
            app.state.girls_progress_pipeline = load_girls_progress_pipeline(gp_girls)
        except Exception:
            app.state.girls_progress_pipeline = None
    app.state.girls_struggling_pipeline = None
    gs_girls = girls_struggling_pipeline_path()
    if gs_girls.is_file():
        try:
            app.state.girls_struggling_pipeline = load_girls_struggling_pipeline(gs_girls)
        except Exception:
            app.state.girls_struggling_pipeline = None
    yield
    app.state.retention_pipeline = None
    app.state.growth_pipeline = None
    app.state.social_engagement_pipeline = None
    app.state.girls_progress_pipeline = None
    app.state.girls_struggling_pipeline = None


app = FastAPI(
    title="Donor ML API",
    description="Retention, growth, social engagement, girls education progress, and girls struggling pipelines.",
    version="1.0.0",
    lifespan=lifespan,
)

app.include_router(retention_router)
app.include_router(growth_router)
app.include_router(social_engagement_router)
app.include_router(girls_progress_router)
app.include_router(girls_struggling_router)


@app.get("/")
def root():
    """Browsing http://localhost:8000/ hits this; API lives under /health, /docs, and router prefixes."""
    return {
        "service": "Donor ML API",
        "docs": "/docs",
        "health": "/health",
        "retention": {"features": "/retention/features", "predict": "/retention/predict"},
        "growth": {"features": "/growth/features", "predict": "/growth/predict"},
        "social": {"features": "/social/features", "predict": "/social/predict"},
        "girls_progress": {
            "features": "/girls-progress/features",
            "predict": "/girls-progress/predict",
        },
        "girls_struggling": {
            "features": "/girls-struggling/features",
            "predict": "/girls-struggling/predict",
        },
    }


@app.get("/health")
def health_check(request: Request):
    return {
        "status": "ok",
        "retention_pipeline_loaded": getattr(request.app.state, "retention_pipeline", None)
        is not None,
        "growth_pipeline_loaded": getattr(request.app.state, "growth_pipeline", None)
        is not None,
        "social_engagement_pipeline_loaded": getattr(
            request.app.state, "social_engagement_pipeline", None
        )
        is not None,
        "girls_progress_pipeline_loaded": getattr(
            request.app.state, "girls_progress_pipeline", None
        )
        is not None,
        "girls_struggling_pipeline_loaded": getattr(
            request.app.state, "girls_struggling_pipeline", None
        )
        is not None,
    }
