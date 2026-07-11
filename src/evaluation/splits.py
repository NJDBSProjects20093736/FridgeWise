"""Train/test splitting for offline evaluation."""

from __future__ import annotations

import numpy as np
import pandas as pd


def user_holdout_split(
    interactions: pd.DataFrame,
    *,
    test_frac: float = 0.2,
    min_user_interactions: int = 5,
    relevant_rating_threshold: int = 4,
    random_state: int = 42,
) -> tuple[pd.DataFrame, pd.DataFrame, dict[int, set[int]]]:
    """
    Per-user holdout split.

    Returns train_df, test_df, and test_relevant map (user_id -> relevant recipe_ids
    with rating >= threshold in test set).
    """
    train_parts: list[pd.DataFrame] = []
    test_parts: list[pd.DataFrame] = []
    test_relevant: dict[int, set[int]] = {}

    for uid, grp in interactions.groupby("user_id"):
        uid = int(uid)
        if len(grp) < min_user_interactions:
            train_parts.append(grp)
            continue

        n_test = max(1, int(round(len(grp) * test_frac)))
        rng = np.random.default_rng(random_state + uid)
        test_idx = rng.choice(grp.index.to_numpy(), size=n_test, replace=False)
        test = grp.loc[test_idx]
        train = grp.drop(test_idx)

        train_parts.append(train)
        test_parts.append(test)

        rel = test[test["rating"] >= relevant_rating_threshold]["recipe_id"].astype(int).tolist()
        if rel:
            test_relevant[uid] = set(rel)

    train_df = pd.concat(train_parts, ignore_index=True) if train_parts else interactions.iloc[0:0]
    test_df = pd.concat(test_parts, ignore_index=True) if test_parts else interactions.iloc[0:0]
    return train_df, test_df, test_relevant
