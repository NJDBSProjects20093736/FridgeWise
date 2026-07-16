"""Load recommender models once at startup."""

from __future__ import annotations

import logging
from pathlib import Path

from api.config import get_settings
from src.data_loader import ThriftyChefData, load_fridgewise_data
from src.models.collaborative import CollaborativeRecommender
from src.models.content_based import ContentBasedRecommender
from src.models.popularity import PopularityRecommender
from src.recommender import HybridRecommender

logger = logging.getLogger(__name__)


class ModelRegistry:
    def __init__(self) -> None:
        self.data: ThriftyChefData | None = None
        self.popularity: PopularityRecommender | None = None
        self.content: ContentBasedRecommender | None = None
        self.cf: CollaborativeRecommender | None = None
        self.hybrid: HybridRecommender | None = None
        self._loaded = False

    def load(self) -> None:
        if self._loaded:
            return
        settings = get_settings()
        root = settings.project_root
        self.data = load_fridgewise_data(root)

        artifacts = settings.models_dir
        if (artifacts / "hybrid.pkl").exists():
            self.hybrid = HybridRecommender.load(artifacts / "hybrid.pkl")
            self.cf = CollaborativeRecommender.load(artifacts / "svd.pkl")
            self.content = ContentBasedRecommender.load(artifacts / "content_based.pkl")
            self.popularity = PopularityRecommender.load(artifacts / "popularity.pkl")
        else:
            self.popularity = PopularityRecommender().fit(self.data)
            self.content = ContentBasedRecommender().fit(self.data)
            self.cf = CollaborativeRecommender(n_factors=50, n_epochs=20).fit(
                self.data, test_size=0.0
            )
            self.hybrid = HybridRecommender().fit(self.data, self.cf, self.content)
            try:
                artifacts.mkdir(parents=True, exist_ok=True)
                self.popularity.save(artifacts / "popularity.pkl")
                self.content.save(artifacts / "content_based.pkl")
                self.cf.save(artifacts / "svd.pkl")
                self.hybrid.save(artifacts / "hybrid.pkl")
            except OSError as exc:
                logger.warning(
                    "Model artifacts directory is not writable; continuing with in-memory models: %s",
                    exc,
                )

        self._loaded = True


registry = ModelRegistry()
