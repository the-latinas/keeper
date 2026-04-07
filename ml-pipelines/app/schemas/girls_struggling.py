from pydantic import BaseModel, Field


class GirlsStrugglingFeatures(BaseModel):
    # Numeric features
    present_age_years: float | None = None
    length_stay_years: float | None = None
    age_upon_admission_years: float | None = None
    has_special_needs: int | None = Field(None, ge=0, le=1)
    family_parent_pwd: int | None = Field(None, ge=0, le=1)
    hw_mean_nutrition_score: float | None = None
    hw_mean_energy_level_score: float | None = None
    hw_rate_psychological_checkup_done: float | None = None
    edu_latest_attendance_rate: float | None = None
    n_education_records: float | None = Field(None, ge=0)
    n_intervention_plans: float | None = Field(None, ge=0)
    n_home_visitations: float | None = Field(None, ge=0)
    n_incidents: float | None = Field(None, ge=0)
    n_process_sessions: float | None = Field(None, ge=0)
    incident_high_rate: float | None = None
    incident_unresolved_rate: float | None = None
    safety_concern_rate: float | None = None
    followup_needed_rate: float | None = None
    concerns_flagged_rate: float | None = None
    referral_made_rate: float | None = None
    occupancy_ratio: float | None = None

    # Categorical features
    case_status: str | None = None
    case_category: str | None = None
    initial_risk_level: str | None = None
    current_risk_level: str | None = None
    referral_source: str | None = None
    reintegration_status: str | None = None
    edu_latest_education_level: str | None = None
    edu_latest_enrollment_status: str | None = None
    edu_latest_completion_status: str | None = None
    region: str | None = None
    province: str | None = None


class GirlsStrugglingPrediction(BaseModel):
    predicted_class: int = Field(..., description="1 = struggling, 0 = not struggling")
    label: str
    probability_not_struggling: float
    probability_struggling: float
    features_used: list[str]
