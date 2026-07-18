"""Shared offline experiment settings for reproducible evaluation."""

from __future__ import annotations

from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class ExperimentConfig:
    """Fixed settings for a reportable evaluation run."""

    name: str = "thriftychef_v1"
    random_state: int = 1103
    k: int = 10
    max_eval_users: int = 500
    test_fraction: float = 0.2
    relevant_rating_threshold: int = 4
    min_user_interactions: int = 5
    svd_factors: int = 50
    svd_epochs: int = 20

    def to_dict(self) -> dict[str, int | float | str]:
        return asdict(self)


EXPERIMENT_CONFIG = ExperimentConfig()

# Back-compat aliases used by older scripts/notebooks
CAOneExperimentConfig = ExperimentConfig
CA_ONE_CONFIG = EXPERIMENT_CONFIG
