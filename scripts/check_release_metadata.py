#!/usr/bin/env python3
"""Check the bundled-schema fingerprint and public dependency bounds (Python 3.11+)."""
import hashlib
import json
from pathlib import Path
import tomllib

root = Path(__file__).resolve().parents[1]
project = tomllib.loads((root / "Project.toml").read_text())
snapshot = tomllib.loads((root / "schemas/bundled-schema.toml").read_text())
schema = root / snapshot["path"]
assert hashlib.sha256(schema.read_bytes()).hexdigest() == snapshot["sha256"], (
    "Bundled schema changed: review its provenance and update schemas/bundled-schema.toml"
)
assert json.loads(schema.read_text())["version"] == snapshot["schema_version"]
for name in project.get("deps", {}) | project.get("weakdeps", {}):
    assert name in project["compat"], f"Missing compatibility declaration for {name}"
assert "julia" in project["compat"]
for path in ("test/data/LV", "test/data/MV", "test/data/MVLVmeshed", "test/data/ENWL",
             "test/data/Master.dss", "examples/lv1_14bus.json"):
    assert not (root / path).exists(), f"External dataset was reintroduced: {path}"
print("Release metadata: schema fingerprint, dependency declarations, and external dataset paths pass")
