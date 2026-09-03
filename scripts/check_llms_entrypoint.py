#!/usr/bin/env python3
"""Check that the canonical llms.txt is discoverable, documented, and published."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LLMS = ROOT / "llms.txt"
README = ROOT / "README.md"
ASSISTANT_GUIDE = ROOT / "docs/src/ai_assistants.md"
DOCS_BUILD = ROOT / "docs/make.jl"

REQUIRED_LLMS_TEXT = (
    "# BMOPFTools.jl",
    "## Primary documentation",
    "## Machine-readable discovery",
    "generated/executable-knowledge-manifest.json",
    "schemas/execution-response.schema.json",
    "bin/bmopf-mcp",
)


def main() -> int:
    errors: list[str] = []
    if not LLMS.is_file():
        errors.append("missing canonical llms.txt")
        llms_text = ""
    else:
        llms_text = LLMS.read_text()
    for required in REQUIRED_LLMS_TEXT:
        if required not in llms_text:
            errors.append(f"llms.txt is missing required discovery text: {required}")

    readme_text = README.read_text()
    if "[llms.txt](llms.txt)" not in readme_text:
        errors.append("README.md does not link the canonical llms.txt")

    assistant_text = ASSISTANT_GUIDE.read_text()
    public_url = "https://frederikgeth.github.io/BMOPFTools.jl/docs/llms.txt"
    if public_url not in assistant_text:
        errors.append("AI-assistant guide does not link the published llms.txt")

    docs_text = DOCS_BUILD.read_text()
    if not all(fragment in docs_text for fragment in (
        "cp(", 'joinpath(REPOSITORY_ROOT, "llms.txt")',
        'joinpath(@__DIR__, "build", "llms.txt")')):
        errors.append("docs/make.jl does not publish the canonical llms.txt")

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("llms.txt: canonical entry point is linked, CI-checked, and published by the docs build")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
