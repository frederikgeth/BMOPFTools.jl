#!/usr/bin/env python3
"""Generate and validate deterministic BMOPFTools executable-knowledge records."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tomllib
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "knowledge/executable.toml"
SCHEMA = ROOT / "schemas/executable-knowledge.schema.json"
PROJECT = ROOT / "Project.toml"
OUTPUT = ROOT / "generated/executable_knowledge.jsonl"
MANIFEST = ROOT / "generated/executable-knowledge-manifest.json"
SCHEMA_VERSION = "0.1.0"
PSK_ID = re.compile(r"^PSK-[0-9]{6}$")
CONTRACT_ID = re.compile(r"^[a-z][a-z0-9_]*$")
FINDING_CODE = re.compile(r"^[EWI]\.[A-Z0-9_]+(?:\.[A-Z0-9_]+)+$")
FIXTURE_ROOT = ROOT / "test/fixtures/negative"


def canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def require_strings(record_id: str, field: str, value: object, errors: list[str]) -> list[str]:
    if not isinstance(value, list) or not value or not all(isinstance(item, str) and item.strip() for item in value):
        errors.append(f"{record_id}: {field} must be a nonempty string array")
        return []
    if len(value) != len(set(value)):
        errors.append(f"{record_id}: {field} contains duplicates")
    return value


def source_block(paths: list[Path]) -> dict:
    entries = [
        {"path": path.relative_to(ROOT).as_posix(), "sha256": sha256_file(path)}
        for path in sorted(set(paths))
    ]
    return {
        "repository": "frederikgeth/BMOPFTools.jl",
        "paths": [entry["path"] for entry in entries],
        "sha256": sha256_bytes(canonical_json(entries).encode()),
    }


def record_base(record_id: str, record_type: str, knowledge_ids: list[str], title: str,
                text: str, package: dict, paths: list[Path]) -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "record_id": record_id,
        "record_type": record_type,
        "knowledge_ids": knowledge_ids,
        "title": title,
        "text": text,
        "package": package,
        "source": source_block(paths),
    }


def fixture_metadata() -> list[tuple[Path, dict]]:
    return [
        (path, tomllib.loads(path.read_text()))
        for path in sorted(FIXTURE_ROOT.glob("*/metadata.toml"))
    ]


def validate_and_build() -> tuple[list[dict], dict, list[str]]:
    errors: list[str] = []
    registry = tomllib.loads(REGISTRY.read_text())
    schema = json.loads(SCHEMA.read_text())
    project = tomllib.loads(PROJECT.read_text())
    package = {"name": project["name"], "version": project["version"]}
    if package["name"] != "BMOPFTools":
        errors.append("Project.toml package name is not BMOPFTools")
    if registry.get("schema_version") != SCHEMA_VERSION:
        errors.append("unexpected executable registry schema version")
    if schema.get("properties", {}).get("schema_version", {}).get("const") != SCHEMA_VERSION:
        errors.append("executable JSON schema version differs from the generator")

    contracts = registry.get("contract", [])
    findings = registry.get("finding", [])
    contract_ids = [item.get("id") for item in contracts]
    duplicates = sorted(item for item, count in Counter(contract_ids).items() if count > 1)
    if duplicates:
        errors.append(f"duplicate contract IDs: {duplicates}")
    finding_codes = [item.get("code") for item in findings]
    duplicates = sorted(item for item, count in Counter(finding_codes).items() if count > 1)
    if duplicates:
        errors.append(f"duplicate finding codes: {duplicates}")
    finding_by_code = {item.get("code"): item for item in findings}
    fixture_by_id = {item.get("fixture_id"): (path, item) for path, item in fixture_metadata()}

    module_text = (ROOT / "src/BMOPFTools.jl").read_text()
    contract_text = (ROOT / "src/knowledge/contracts.jl").read_text()
    finding_docs = (ROOT / "docs/src/findings.md").read_text()
    records: list[dict] = []
    all_sources: set[Path] = {REGISTRY, SCHEMA, PROJECT}

    for item in contracts:
        contract_id = item.get("id", "<missing>")
        if not isinstance(contract_id, str) or not CONTRACT_ID.fullmatch(contract_id):
            errors.append(f"invalid contract ID: {contract_id}")
            continue
        title = item.get("title")
        entrypoint = item.get("entrypoint")
        scope = item.get("scope")
        knowledge_ids = require_strings(contract_id, "knowledge_ids", item.get("knowledge_ids"), errors)
        applicability = require_strings(contract_id, "applicability", item.get("applicability"), errors)
        checked = require_strings(contract_id, "checked_dimensions", item.get("checked_dimensions"), errors)
        unassessed = require_strings(contract_id, "unassessed_dimensions", item.get("unassessed_dimensions"), errors)
        codes = require_strings(contract_id, "finding_codes", item.get("finding_codes"), errors)
        fixture_ids = require_strings(contract_id, "fixture_ids", item.get("fixture_ids"), errors)
        path_strings = require_strings(contract_id, "source_paths", item.get("source_paths"), errors)
        if not isinstance(title, str) or not title.strip():
            errors.append(f"{contract_id}: missing title")
        if not isinstance(scope, str) or not scope.strip():
            errors.append(f"{contract_id}: missing scope")
        if not isinstance(entrypoint, str) or not re.fullmatch(r"[a-z][A-Za-z0-9_!?]*", entrypoint):
            errors.append(f"{contract_id}: invalid entrypoint {entrypoint}")
        elif not re.search(rf"\b{re.escape(entrypoint)}\b", module_text):
            errors.append(f"{contract_id}: entrypoint is not exported by src/BMOPFTools.jl")
        for knowledge_id in knowledge_ids:
            if not PSK_ID.fullmatch(knowledge_id):
                errors.append(f"{contract_id}: invalid knowledge ID {knowledge_id}")
        for code in codes:
            if not FINDING_CODE.fullmatch(code):
                errors.append(f"{contract_id}: invalid Finding code {code}")
            if code not in finding_by_code:
                errors.append(f"{contract_id}: Finding code {code} has no registry definition")
            if code not in contract_text or code not in finding_docs:
                errors.append(f"{contract_id}: Finding code {code} is absent from implementation or docs")
        source_paths = [ROOT / path_string for path_string in path_strings]
        for path in source_paths:
            if not path.is_file():
                errors.append(f"{contract_id}: missing source path {path.relative_to(ROOT)}")
        all_sources.update(path for path in source_paths if path.is_file())

        contract_record = record_base(
            f"contract:{contract_id}", "executable_contract", knowledge_ids, title,
            f"Executable contract {contract_id}. {scope} Applicability: {' '.join(applicability)} "
            f"Checked dimensions: {', '.join(checked)}. Explicitly unassessed: {', '.join(unassessed)}.",
            package, [REGISTRY, *source_paths],
        )
        contract_record.update({
            "contract_id": contract_id,
            "entrypoint": entrypoint,
            "scope": scope,
            "applicability": applicability,
            "checked_dimensions": checked,
            "unassessed_dimensions": unassessed,
            "finding_codes": codes,
            "fixture_ids": fixture_ids,
        })
        records.append(contract_record)

        api_record = record_base(
            f"api:{entrypoint}", "api_operation", knowledge_ids, entrypoint,
            f"BMOPFTools API operation {entrypoint} evaluates {contract_id}. {scope} "
            f"It reports Finding codes {', '.join(codes)} and refuses out-of-domain cases explicitly.",
            package, [REGISTRY, ROOT / "src/BMOPFTools.jl", ROOT / "src/knowledge/contracts.jl"],
        )
        api_record.update({
            "contract_id": contract_id,
            "entrypoint": entrypoint,
            "scope": scope,
            "applicability": applicability,
            "finding_codes": codes,
        })
        records.append(api_record)

        for code in codes:
            definition = finding_by_code.get(code)
            if not definition:
                continue
            severity = definition.get("severity")
            if severity not in {"ERROR", "WARNING", "INFO"}:
                errors.append(f"{code}: invalid severity {severity}")
            meaning = definition.get("meaning")
            if not isinstance(meaning, str) or not meaning.strip():
                errors.append(f"{code}: missing meaning")
                meaning = "Missing finding meaning."
            finding_record = record_base(
                f"finding:{code}", "finding", knowledge_ids, code,
                f"BMOPFTools Finding {code} ({severity}) for {contract_id}: {meaning}",
                package, [REGISTRY, ROOT / "src/knowledge/contracts.jl", ROOT / "docs/src/findings.md"],
            )
            finding_record.update({
                "contract_id": contract_id,
                "finding_code": code,
                "severity": severity,
                "meaning": meaning,
            })
            records.append(finding_record)

        for fixture_id in fixture_ids:
            fixture_entry = fixture_by_id.get(fixture_id)
            if fixture_entry is None:
                errors.append(f"{contract_id}: missing fixture metadata for {fixture_id}")
                continue
            metadata_path, metadata = fixture_entry
            if metadata.get("contract_id") != contract_id:
                errors.append(f"{fixture_id}: fixture contract differs from {contract_id}")
            if metadata.get("knowledge_ids") != knowledge_ids:
                errors.append(f"{fixture_id}: fixture knowledge IDs differ from {contract_id}")
            expected_codes = require_strings(
                fixture_id, "expected_finding_codes", metadata.get("expected_finding_codes"), errors
            )
            if not set(expected_codes).issubset(codes):
                errors.append(f"{fixture_id}: expected Finding codes are outside the contract registry")
            does_not_establish = require_strings(
                fixture_id, "does_not_establish", metadata.get("does_not_establish"), errors
            )
            file_keys = ["source_file", "transformed_file", "exact_target_file", "expected_file", "reproducer"]
            fixture_files: list[Path] = []
            for key in file_keys:
                filename = metadata.get(key)
                path = metadata_path.parent / filename if isinstance(filename, str) else metadata_path.parent / "<missing>"
                if not path.is_file():
                    errors.append(f"{fixture_id}: missing {key}: {filename}")
                else:
                    fixture_files.append(path)
            all_sources.update([metadata_path, *fixture_files])
            files = [
                {"path": path.relative_to(ROOT).as_posix(), "sha256": sha256_file(path)}
                for path in sorted(fixture_files)
            ]
            fixture_record = record_base(
                f"fixture:{fixture_id}", "fixture", knowledge_ids, metadata.get("title", fixture_id),
                f"Executable {metadata.get('kind')} fixture {fixture_id} for {contract_id}. "
                f"Scope: {metadata.get('scope')} Expected Findings: {', '.join(expected_codes)}. "
                f"Does not establish: {' '.join(does_not_establish)}",
                package, [REGISTRY, metadata_path, *fixture_files],
            )
            fixture_record.update({
                "contract_id": contract_id,
                "fixture_id": fixture_id,
                "kind": metadata.get("kind"),
                "expected_finding_codes": expected_codes,
                "does_not_establish": does_not_establish,
                "files": files,
            })
            records.append(fixture_record)

    records.sort(key=lambda record: record["record_id"])
    ids = [record["record_id"] for record in records]
    duplicates = sorted(item for item, count in Counter(ids).items() if count > 1)
    if duplicates:
        errors.append(f"duplicate record IDs: {duplicates}")
    corpus = "\n".join(canonical_json(record) for record in records) + ("\n" if records else "")
    all_sources.update({REGISTRY, SCHEMA, PROJECT})
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "manifest_id": f"bmopftools-executable-knowledge-{package['version']}",
        "package": package,
        "record_count": len(records),
        "record_counts": dict(sorted(Counter(record["record_type"] for record in records).items())),
        "knowledge_ids": sorted({value for record in records for value in record["knowledge_ids"]}),
        "contract_ids": sorted({record["contract_id"] for record in records}),
        "corpus_sha256": sha256_bytes(corpus.encode()),
        "source_files": [
            {"path": path.relative_to(ROOT).as_posix(), "sha256": sha256_file(path)}
            for path in sorted(all_sources)
            if path.is_file()
        ],
    }
    return records, manifest, errors


def rendered_payloads() -> tuple[str, str, list[str]]:
    records, manifest, errors = validate_and_build()
    corpus = "\n".join(canonical_json(record) for record in records) + ("\n" if records else "")
    manifest_text = json.dumps(manifest, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    return corpus, manifest_text, errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        corpus, manifest, errors = rendered_payloads()
    except (OSError, KeyError, TypeError, ValueError, tomllib.TOMLDecodeError, json.JSONDecodeError) as error:
        print(f"executable-knowledge generation failed: {error}")
        return 1
    if errors:
        for error in errors:
            print(f"error: {error}")
        return 1
    if args.write:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(corpus)
        MANIFEST.write_text(manifest)
        print(f"wrote {OUTPUT.relative_to(ROOT)} and {MANIFEST.relative_to(ROOT)}")
        return 0
    stale = []
    for path, expected in ((OUTPUT, corpus), (MANIFEST, manifest)):
        if not path.is_file() or path.read_text() != expected:
            stale.append(path.relative_to(ROOT).as_posix())
    if stale:
        print("stale executable-knowledge outputs: " + ", ".join(stale))
        print("run: python3 scripts/generate_executable_knowledge.py --write")
        return 1
    print("executable knowledge is valid and reproducible")
    return 0


if __name__ == "__main__":
    sys.exit(main())
