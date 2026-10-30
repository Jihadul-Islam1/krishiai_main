"""Assembles the server folder to deploy at build/server_deploy/.

Copies the Dockerfile, the API code and every crop model that is ready
(ml_backend/models/<crop>/ with labels.txt and model.tflite|keras).
Push that folder to its own GitHub repo and point the host at it.

    python ml_backend/deploy/make_deploy.py

Run it again after adding a crop model, then push again.
"""

import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
MODELS = ROOT / "ml_backend" / "models"
OUT = ROOT / "build" / "server_deploy"


def is_ready(folder: Path) -> bool:
    has_model = (folder / "model.tflite").exists() or (folder / "model.keras").exists()
    return has_model and (folder / "labels.txt").exists()


def main() -> None:
    crops = [d for d in sorted(MODELS.iterdir()) if d.is_dir() and is_ready(d)]
    if not crops:
        sys.exit(f"No crop models in {MODELS}; add one (see ml_backend/SETUP.md) first.")

    # Keep a cloned repo's .git so the folder can be pushed again.
    OUT.mkdir(parents=True, exist_ok=True)
    for p in OUT.iterdir():
        if p.name != ".git":
            shutil.rmtree(p) if p.is_dir() else p.unlink()
    for f in ("Dockerfile", "requirements.txt", "README.md"):
        shutil.copy(HERE / f, OUT / f)
    shutil.copytree(ROOT / "ml_backend" / "api", OUT / "ml_backend" / "api",
                    ignore=shutil.ignore_patterns("__pycache__"))
    for crop in crops:
        shutil.copytree(crop, OUT / "ml_backend" / "models" / crop.name)

    size = sum(p.stat().st_size for p in OUT.rglob("*")
               if p.is_file() and ".git" not in p.parts) / 1e6
    print(f"Server folder: {OUT} ({size:.1f} MB)")
    print("Crops:", ", ".join(c.name for c in crops))


if __name__ == "__main__":
    main()
