from pydantic import BaseModel, Field


class GrowthFeatures(BaseModel):
    """Input features for growth regression (no total_monetary_value — that is what we predict)."""

    recency_days: float | None = Field(None, description="Days since last gift; null uses fallback")
    frequency: float = Field(0, ge=0)
    avg_monetary_value: float | None = None
    social_referral_count: float = Field(0, ge=0)
    is_recurring_donor: int = Field(0, ge=0, le=1)
    top_program_interest: str | None = None


class GrowthPrediction(BaseModel):
    predicted_total_monetary_value: float = Field(
        ..., description="Model estimate of supporter total giving scale"
    )
    features_used: list[str]
