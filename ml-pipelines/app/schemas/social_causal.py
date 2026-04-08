"""Pydantic schemas for the T-Learner causal boost endpoint."""

from pydantic import BaseModel, Field


class SocialCausalFeatures(BaseModel):
    """Pre-treatment covariates for the causal boost T-Learner.

    Matches CAUSAL_FEATURE_COLUMNS in social_media_causal_boost.ipynb Phase 3.
    Do NOT include is_boosted — it is the treatment variable, not an input feature.
    The model estimates the counterfactual effect of boosting for this specific post.
    """

    # Numeric pre-treatment covariates
    caption_length: float = Field(0.0, ge=0, description="Character count of post caption")
    num_hashtags: float = Field(0.0, ge=0, description="Number of hashtags in caption")
    follower_count_at_post: float = Field(0.0, ge=0, description="Page/account followers at time of posting")
    post_hour: int = Field(0, ge=0, le=23, description="Hour of day the post was published (0–23)")
    has_call_to_action: int = Field(0, ge=0, le=1, description="1 if post contains a CTA, else 0")
    boost_budget_php: float = Field(
        0.0,
        ge=0,
        description=(
            "Hypothetical boost budget in PHP. Use 0 for organic-only counterfactual, "
            "or the planned budget to condition the ITE on a specific spend level."
        ),
    )

    # Categorical pre-treatment covariates
    platform: str = Field("Unknown", description="Social media platform (e.g. Facebook, Instagram)")
    post_type: str = Field("Unknown", description="Type of post (e.g. Photo, Video, Story)")
    media_type: str = Field("Unknown", description="Media format (e.g. Image, Reel, Carousel)")
    content_topic: str = Field("Unknown", description="Topic category of the post content")
    sentiment_tone: str = Field("Unknown", description="Tone/sentiment of the post (e.g. Inspirational, Informational)")
    post_dow: str = Field(
        "Unknown",
        description="Day of week the post was published (e.g. Monday). Derive from post timestamp.",
    )
    call_to_action_type: str = Field(
        "None",
        description=(
            "'None' when has_call_to_action=0 (structural — no CTA means no CTA type). "
            "Use 'Unknown' only when a CTA exists but the type is unrecorded."
        ),
    )


class SocialCausalPrediction(BaseModel):
    """Causal inference output from the T-Learner boost model."""

    estimated_ite: float = Field(
        ...,
        description=(
            "Individual treatment effect: E[Y(1)|X] - E[Y(0)|X]. "
            "Positive = boosting is estimated to increase P(has_referred_gift) for this post."
        ),
    )
    p_outcome_if_boosted: float = Field(
        ...,
        description="P(has_referred_gift=1 | X, boost=1) from the treatment response surface.",
    )
    p_outcome_if_not_boosted: float = Field(
        ...,
        description="P(has_referred_gift=1 | X, boost=0) from the control response surface.",
    )
    propensity_score: float = Field(
        ...,
        description=(
            "P(is_boosted=1 | X) — how likely this post would naturally be chosen for boosting. "
            "Scores near 0 or 1 indicate poor overlap and should be interpreted cautiously."
        ),
    )
    ate: float = Field(
        ...,
        description="Population-level average treatment effect estimated from training data.",
    )
    ate_lower: float = Field(
        ...,
        description="Bootstrap 95% confidence interval lower bound for the ATE.",
    )
    ate_upper: float = Field(
        ...,
        description="Bootstrap 95% confidence interval upper bound for the ATE.",
    )
    features_used: list[str]
