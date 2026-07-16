"""Socio-demographic style clustering for ThriftyChef cold-start users."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.metrics import davies_bouldin_score, silhouette_score
from sklearn.preprocessing import MinMaxScaler

from src.data_loader import parse_json_list


@dataclass
class ClusterSelectionResult:
    k: int
    wcss_values: list[float]
    silhouette: float
    davies_bouldin: float


def profiles_for_clustering(profiles: pd.DataFrame) -> pd.DataFrame:
    """Map ThriftyChef profiles to clustering features."""
    rows = []
    for _, row in profiles.iterrows():
        cuisines = parse_json_list(row.get("preferred_cuisines"))
        rows.append(
            {
                "user_id": int(row["user_id"]),
                "primary_cuisine": cuisines[0] if cuisines else "unknown",
                "dietary_type": str(row.get("dietary_type", "none")),
                "region": str(row.get("region", "unknown")),
                "openness_to_new_cuisines": float(row.get("openness_to_new_cuisines", 0.5)),
            }
        )
    return pd.DataFrame(rows)


class ColdStartClusterRecommender:
    """Cluster users by onboarding profile and recommend cluster-popular recipes."""

    def __init__(self, n_clusters: int = 5, random_state: int = 42):
        self.n_clusters = n_clusters
        self.random_state = random_state
        self.scaler = MinMaxScaler()
        self.kmeans = KMeans(
            n_clusters=n_clusters,
            init="k-means++",
            random_state=random_state,
            n_init="auto",
        )
        self.feature_columns_: list[str] = []
        self.user_clusters_: dict[int, int] = {}

    def _encode_profiles(self, users: pd.DataFrame) -> pd.DataFrame:
        encoded = pd.get_dummies(
            users,
            columns=["primary_cuisine", "dietary_type", "region"],
        )
        return encoded

    def fit(self, profiles: pd.DataFrame) -> "ColdStartClusterRecommender":
        users = profiles_for_clustering(profiles)
        encoded = self._encode_profiles(users)
        self.feature_columns_ = encoded.drop(columns=["user_id"]).columns.tolist()
        scaled = self.scaler.fit_transform(encoded.drop(columns=["user_id"]))
        labels = self.kmeans.fit_predict(scaled)
        self.user_clusters_ = {
            int(uid): int(label) for uid, label in zip(users["user_id"], labels)
        }
        return self

    def predict_cluster(self, user_id: int, profiles: pd.DataFrame) -> int | None:
        if user_id in self.user_clusters_:
            return self.user_clusters_[user_id]
        users = profiles_for_clustering(profiles)
        row = users[users["user_id"] == user_id]
        if row.empty:
            return None
        encoded = self._encode_profiles(row)
        encoded = encoded.reindex(columns=["user_id"] + self.feature_columns_, fill_value=0)
        scaled = self.scaler.transform(encoded.drop(columns=["user_id"]))
        return int(self.kmeans.predict(scaled)[0])

    def recommend_for_cluster(
        self,
        cluster_id: int,
        profiles: pd.DataFrame,
        interactions: pd.DataFrame,
        top_n: int = 10,
    ) -> pd.DataFrame:
        users = profiles_for_clustering(profiles)
        users["cluster"] = users["user_id"].map(self.user_clusters_)
        cluster_users = users.loc[users["cluster"] == cluster_id, "user_id"]
        cluster_interactions = interactions[interactions["user_id"].isin(cluster_users)]
        if cluster_interactions.empty:
            return pd.DataFrame(columns=["recipe_id", "avg_rating", "n_ratings"])

        return (
            cluster_interactions.groupby("recipe_id")
            .agg(avg_rating=("rating", "mean"), n_ratings=("rating", "count"))
            .reset_index()
            .sort_values(["avg_rating", "n_ratings"], ascending=False)
            .head(top_n)
        )


def compute_wcss_curve(
    profiles: pd.DataFrame,
    k_min: int = 1,
    k_max: int = 10,
    random_state: int = 42,
) -> pd.DataFrame:
    users = profiles_for_clustering(profiles)
    encoded = pd.get_dummies(
        users,
        columns=["primary_cuisine", "dietary_type", "region"],
    ).drop(columns=["user_id"])
    scaled = MinMaxScaler().fit_transform(encoded)

    rows = []
    for k in range(k_min, k_max + 1):
        model = KMeans(n_clusters=k, init="k-means++", random_state=random_state, n_init="auto")
        model.fit(scaled)
        rows.append({"k": k, "wcss": model.inertia_})
    return pd.DataFrame(rows)


def evaluate_cluster_model(
    profiles: pd.DataFrame,
    n_clusters: int,
    random_state: int = 42,
) -> ClusterSelectionResult:
    model = ColdStartClusterRecommender(n_clusters=n_clusters, random_state=random_state)
    model.fit(profiles)
    users = profiles_for_clustering(profiles)
    encoded = pd.get_dummies(
        users,
        columns=["primary_cuisine", "dietary_type", "region"],
    ).drop(columns=["user_id"])
    scaled = model.scaler.fit_transform(encoded)
    labels = model.kmeans.fit_predict(scaled)
    wcss_curve = compute_wcss_curve(profiles, random_state=random_state)
    return ClusterSelectionResult(
        k=n_clusters,
        wcss_values=wcss_curve["wcss"].tolist(),
        silhouette=float(silhouette_score(scaled, labels)),
        davies_bouldin=float(davies_bouldin_score(scaled, labels)),
    )
