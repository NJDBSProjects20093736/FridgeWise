"""Ranking and rating evaluation metrics."""

from __future__ import annotations

import math
from typing import Iterable


def _as_set(items: Iterable[int]) -> set[int]:
    return {int(x) for x in items}


def precision_at_k(recommended: list[int], relevant: set[int], k: int) -> float:
    if k <= 0:
        return 0.0
    rec_k = recommended[:k]
    if not rec_k:
        return 0.0
    hits = sum(1 for r in rec_k if r in relevant)
    return hits / k


def recall_at_k(recommended: list[int], relevant: set[int], k: int) -> float:
    if not relevant:
        return 0.0
    rec_k = recommended[:k]
    hits = sum(1 for r in rec_k if r in relevant)
    return hits / len(relevant)


def average_precision_at_k(recommended: list[int], relevant: set[int], k: int) -> float:
    if not relevant:
        return 0.0
    rec_k = recommended[:k]
    hits = 0
    precision_sum = 0.0
    for i, item in enumerate(rec_k, start=1):
        if item in relevant:
            hits += 1
            precision_sum += hits / i
    if hits == 0:
        return 0.0
    return precision_sum / min(len(relevant), k)


def dcg_at_k(recommended: list[int], relevant: set[int], k: int) -> float:
    dcg = 0.0
    for i, item in enumerate(recommended[:k], start=1):
        if item in relevant:
            dcg += 1.0 / math.log2(i + 1)
    return dcg


def ndcg_at_k(recommended: list[int], relevant: set[int], k: int) -> float:
    if not relevant:
        return 0.0
    dcg = dcg_at_k(recommended, relevant, k)
    ideal_hits = min(len(relevant), k)
    idcg = sum(1.0 / math.log2(i + 1) for i in range(1, ideal_hits + 1))
    if idcg == 0:
        return 0.0
    return dcg / idcg


def hit_rate_at_k(recommended: list[int], relevant: set[int], k: int) -> float:
    rec_k = _as_set(recommended[:k])
    return 1.0 if rec_k & relevant else 0.0
