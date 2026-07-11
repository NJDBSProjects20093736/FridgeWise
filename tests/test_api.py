"""API smoke tests."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from fastapi.testclient import TestClient
from api.main import app

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_recommend():
    r = client.post("/recommend", json={"user_id": 5060, "k": 3})
    assert r.status_code == 200
    data = r.json()
    assert data["user_id"] == 5060
    assert len(data["recipes"]) <= 3
    assert "why_recommended" in data["recipes"][0]


def test_recipe_detail():
    rec = client.post("/recommend", json={"user_id": 5060, "k": 1}).json()
    rid = rec["recipes"][0]["recipe_id"]
    r = client.get(f"/recipe/{rid}")
    assert r.status_code == 200


def test_inventory():
    r = client.get("/inventory/5060")
    assert r.status_code == 200
    assert "items" in r.json()
