"""Shared recommender types."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class Recommendation:
    recipe_id: int
    recipe_name: str
    score: float
    model: str = ""


class Recommender(Protocol):
    name: str

    def recommend(self, user_id: int, k: int = 10) -> list[Recommendation]:
        ...
