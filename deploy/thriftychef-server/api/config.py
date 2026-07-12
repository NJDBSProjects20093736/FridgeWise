"""Application configuration from environment."""

from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")


@dataclass(frozen=True)
class Settings:
    project_root: Path
    api_host: str
    api_port: int
    supabase_url: str
    supabase_publishable_key: str
    supabase_secret_key: str
    database_url: str
    demo_legacy_user_id: int
    models_dir: Path
    clean_data_dir: Path

    @property
    def use_postgres(self) -> bool:
        return bool(self.database_url)


@lru_cache
def get_settings() -> Settings:
    return Settings(
        project_root=ROOT,
        api_host=os.getenv("API_HOST", "0.0.0.0"),
        api_port=int(os.getenv("API_PORT", "8000")),
        supabase_url=os.getenv("SUPABASE_URL", ""),
        supabase_publishable_key=os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_PUBLISHABLE_KEY", ""),
        supabase_secret_key=os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SECRET_KEY", ""),
        database_url=os.getenv("DATABASE_URL", ""),
        demo_legacy_user_id=int(os.getenv("DEMO_LEGACY_USER_ID", "5060")),
        models_dir=ROOT / "src" / "models" / "artifacts",
        clean_data_dir=ROOT / "data" / "clean",
    )
