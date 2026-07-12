"""Trained recommender model artifacts."""

from src.models.collaborative import CollaborativeRecommender
from src.models.content_based import ContentBasedRecommender
from src.models.popularity import PopularityRecommender
from src.recommender import HybridRecommender

__all__ = [
    "PopularityRecommender",
    "ContentBasedRecommender",
    "CollaborativeRecommender",
    "HybridRecommender",
]
