#!/usr/bin/env python3
"""Generate and validate the offline Finding-code registry from canonical docs."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs/src/findings.md"
CONTRACTS = ROOT / "knowledge/executable.toml"
SCHEMA = ROOT / "schemas/finding-registry.schema.json"
OUTPUT = ROOT / "generated/finding-registry.json"
JULIA_OUTPUT = ROOT / "src/report/finding_registry_generated.jl"
SOURCE_ROOT = ROOT / "src"
SCHEMA_VERSION = "0.1.0"
REGISTRY_ID = "bmopftools-findings-0.1.0"
HEADING = re.compile(r"^## ([A-Z][A-Z0-9_]*) — (.+)$")
ROW = re.compile(
    r"^\| `(?P<code>[EWI]\.[A-Z0-9_]+(?:\.[A-Z0-9_]+)+)` "
    r"\| (?P<severity>[EWI]) \| (?P<meaning>.+) \|$"
)
SEVERITY = {"E": "ERROR", "W": "WARNING", "I": "INFO"}
CODE_LITERAL = re.compile(r'"([EWI]\.[A-Z0-9_]+(?:\.[A-Z0-9_]+)+)"')


def source_finding_codes() -> set[str]:
    """Return Finding codes authored in package source, excluding generated output."""
    codes: set[str] = set()
    for path in SOURCE_ROOT.rglob("*.jl"):
        if path == JULIA_OUTPUT:
            continue
        codes.update(CODE_LITERAL.findall(path.read_text()))
    return codes


def canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contract_links() -> tuple[dict[str, dict], list[str]]:
    errors: list[str] = []
    registry = tomllib.loads(CONTRACTS.read_text())
    links: dict[str, dict] = {}
    for contract in registry.get("contract", []):
        contract_id = contract.get("id")
        knowledge_ids = contract.get("knowledge_ids", [])
        for code in contract.get("finding_codes", []):
            if code in links:
                errors.append(f"{code}: linked to more than one executable contract")
            links[code] = {
                "contract_id": contract_id,
                "knowledge_ids": knowledge_ids,
            }
    return links, errors


def build_registry() -> tuple[dict, list[str]]:
    links, errors = contract_links()
    findings: list[dict] = []
    seen: set[str] = set()
    family: str | None = None
    family_title: str | None = None

    for line_number, line in enumerate(DOCS.read_text().splitlines(), start=1):
        heading = HEADING.fullmatch(line)
        if heading:
            family, family_title = heading.groups()
            continue
        row = ROW.fullmatch(line)
        if not row:
            continue
        if family is None or family_title is None:
            errors.append(f"line {line_number}: Finding row precedes a family heading")
            continue
        code = row.group("code")
        if code in seen:
            errors.append(f"duplicate Finding code: {code}")
            continue
        seen.add(code)
        namespace = code.split(".", 2)[1]
        link = links.get(code, {"contract_id": None, "knowledge_ids": []})
        findings.append({
            "code": code,
            "severity": SEVERITY[row.group("severity")],
            "namespace": namespace,
            "catalogue_section": family,
            "section_title": family_title,
            "meaning": row.group("meaning"),
            "contract_id": link["contract_id"],
            "knowledge_ids": link["knowledge_ids"],
        })

    if not findings:
        errors.append("no Finding rows were parsed from docs/src/findings.md")
    missing_contract_codes = sorted(set(links) - seen)
    if missing_contract_codes:
        errors.append(
            "executable-contract Finding codes absent from canonical docs: "
            + ", ".join(missing_contract_codes)
        )
    missing_source_codes = sorted(source_finding_codes() - seen)
    if missing_source_codes:
        errors.append(
            "BMOPFTools-authored Finding codes absent from canonical docs: "
            + ", ".join(missing_source_codes)
        )
    return {
        "schema_version": SCHEMA_VERSION,
        "registry_id": REGISTRY_ID,
        "source": {
            "path": DOCS.relative_to(ROOT).as_posix(),
            "sha256": sha256_file(DOCS),
        },
        "finding_count": len(findings),
        "findings": findings,
    }, errors


def validate_schema(registry: dict, errors: list[str]) -> None:
    schema = json.loads(SCHEMA.read_text())
    if schema.get("properties", {}).get("schema_version", {}).get("const") != SCHEMA_VERSION:
        errors.append("Finding registry schema version differs from the generator")
    if schema.get("properties", {}).get("registry_id", {}).get("const") != REGISTRY_ID:
        errors.append("Finding registry ID differs from the generator")
    if registry["finding_count"] != len(registry["findings"]):
        errors.append("Finding registry count differs from its records")


def julia_string(value: str) -> str:
    escaped = (value.replace("\\", "\\\\")
                    .replace("\"", "\\\"")
                    .replace("$", "\\$")
                    .replace("\n", "\\n")
                    .replace("\r", "\\r")
                    .replace("\t", "\\t"))
    return f'"{escaped}"'


def render_julia(registry: dict) -> str:
    lines = [
        "# Generated by scripts/generate_finding_registry.py; do not edit by hand.",
        f'const _FINDING_REGISTRY_SCHEMA_VERSION = {julia_string(SCHEMA_VERSION)}',
        f'const _FINDING_REGISTRY_ID = {julia_string(REGISTRY_ID)}',
        f'const _FINDING_REGISTRY_SOURCE_PATH = {julia_string(registry["source"]["path"])}',
        f'const _FINDING_REGISTRY_SOURCE_SHA256 = {julia_string(registry["source"]["sha256"])}',
        "const _FINDING_EXPLANATIONS = Dict{String,NamedTuple}(",
    ]
    for item in registry["findings"]:
        contract_id = (
            "nothing" if item["contract_id"] is None
            else julia_string(item["contract_id"])
        )
        knowledge_ids = "[" + ", ".join(
            julia_string(value) for value in item["knowledge_ids"]
        ) + "]"
        lines.extend([
            f"    {julia_string(item['code'])} => (",
            f"        severity={julia_string(item['severity'])},",
            f"        namespace={julia_string(item['namespace'])},",
            f"        catalogue_section={julia_string(item['catalogue_section'])},",
            f"        section_title={julia_string(item['section_title'])},",
            f"        meaning={julia_string(item['meaning'])},",
            f"        contract_id={contract_id},",
            f"        knowledge_ids=String{knowledge_ids},",
            "    ),",
        ])
    lines.extend([
        ")",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()

    registry, errors = build_registry()
    validate_schema(registry, errors)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    json_text = json.dumps(registry, indent=2, ensure_ascii=False) + "\n"
    julia_text = render_julia(registry)
    if args.write:
        OUTPUT.write_text(json_text)
        JULIA_OUTPUT.write_text(julia_text)
        print(f"wrote {OUTPUT.relative_to(ROOT)} and {JULIA_OUTPUT.relative_to(ROOT)}")
    else:
        stale = []
        if not OUTPUT.is_file() or OUTPUT.read_text() != json_text:
            stale.append(OUTPUT.relative_to(ROOT).as_posix())
        if not JULIA_OUTPUT.is_file() or JULIA_OUTPUT.read_text() != julia_text:
            stale.append(JULIA_OUTPUT.relative_to(ROOT).as_posix())
        if stale:
            print("stale Finding registry outputs: " + ", ".join(stale), file=sys.stderr)
            print("run: python3 scripts/generate_finding_registry.py --write", file=sys.stderr)
            return 1
    print(f"Finding registry: {registry['finding_count']} documented codes pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
