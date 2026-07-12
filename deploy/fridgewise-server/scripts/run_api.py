"""Start FridgeWise API with uvicorn."""

from __future__ import annotations

import sys
from pathlib import Path

import uvicorn

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from api.config import get_settings


def main() -> None:
    s = get_settings()
    uvicorn.run("api.main:app", host=s.api_host, port=s.api_port, reload=False)


if __name__ == "__main__":
    main()
