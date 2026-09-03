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
SCHEMA_VERSION = "0.6.0"
PSK_ID = re.compile(r"^PSK-[0-9]{6}$")
CONTRACT_ID = re.compile(r"^[a-z][a-z0-9_]*$")
FINDING_CODE = re.compile(r"^[EWI]\.[A-Z0-9_]+(?:\.[A-Z0-9_]+)+$")
FIXTURE_ROOT = ROOT / "test/fixtures/negative"
RECIPE_ROOT = ROOT / "recipes"
RECIPE_ID = re.compile(r"^[a-z][a-z0-9_]*$")
PROPERTY_SUITE_ID = re.compile(r"^[a-z][a-z0-9_]*$")
SEED = re.compile(r"^0x[0-9a-f]{16}$")


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


def require_string_array(record_id: str, field: str, value: object,
                         errors: list[str], *, nonempty: bool = False) -> list[str]:
    if not isinstance(value, list) or not all(isinstance(item, str) and item.strip() for item in value):
        qualifier = "nonempty " if nonempty else ""
        errors.append(f"{record_id}: {field} must be a {qualifier}string array")
        return []
    if nonempty and not value:
        errors.append(f"{record_id}: {field} must be a nonempty string array")
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


def recipe_metadata() -> list[tuple[Path, dict]]:
    return [
        (path, tomllib.loads(path.read_text()))
        for path in sorted(RECIPE_ROOT.glob("*/metadata.toml"))
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
    contract_by_id = {item.get("id"): item for item in contracts}

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

    property_suites = registry.get("property_suite", [])
    property_suite_ids = [item.get("id") for item in property_suites]
    duplicates = sorted(item for item, count in Counter(property_suite_ids).items() if count > 1)
    if duplicates:
        errors.append(f"duplicate property-suite IDs: {duplicates}")
    for item in property_suites:
        suite_id = item.get("id", "<missing>")
        if not isinstance(suite_id, str) or not PROPERTY_SUITE_ID.fullmatch(suite_id):
            errors.append(f"invalid property-suite ID: {suite_id}")
            continue
        seed_path_string = item.get("seed_path")
        if not isinstance(seed_path_string, str) or not seed_path_string.strip():
            errors.append(f"{suite_id}: missing seed_path")
            continue
        seed_path = ROOT / seed_path_string
        if not seed_path.is_file():
            errors.append(f"{suite_id}: missing seed specification {seed_path_string}")
            continue
        try:
            seed_spec = json.loads(seed_path.read_text())
        except (OSError, json.JSONDecodeError) as exception:
            errors.append(f"{suite_id}: cannot read seed specification: {exception}")
            continue
        if not isinstance(seed_spec, dict):
            errors.append(f"{suite_id}: seed specification must be a JSON object")
            continue
        if seed_spec.get("schema_version") != "0.1.0":
            errors.append(f"{suite_id}: unsupported seed specification schema version")
        if seed_spec.get("property_suite_id") != suite_id:
            errors.append(f"{suite_id}: seed specification property-suite ID differs")
        contract_id = seed_spec.get("contract_id")
        contract = contract_by_id.get(contract_id)
        if contract is None:
            errors.append(f"{suite_id}: unknown contract {contract_id}")
            continue
        knowledge_ids = require_strings(
            suite_id, "knowledge_ids", seed_spec.get("knowledge_ids"), errors)
        if knowledge_ids != contract.get("knowledge_ids"):
            errors.append(f"{suite_id}: knowledge IDs differ from {contract_id}")
        title = item.get("title")
        scope = item.get("scope")
        generator = seed_spec.get("generator", {})
        minimization = seed_spec.get("minimization", {})
        if not isinstance(generator, dict):
            errors.append(f"{suite_id}: generator must be an object")
            generator = {}
        if not isinstance(minimization, dict):
            errors.append(f"{suite_id}: minimization must be an object")
            minimization = {}
        seed_algorithm = generator.get("algorithm")
        seed = generator.get("seed")
        case_count = generator.get("case_count")
        minimization_strategy = minimization.get("strategy")
        failure_classification = seed_spec.get("failure_classification")
        if not isinstance(title, str) or not title.strip():
            errors.append(f"{suite_id}: missing title")
        if not isinstance(scope, str) or not scope.strip():
            errors.append(f"{suite_id}: missing scope")
        if not isinstance(seed_algorithm, str) or not seed_algorithm.strip():
            errors.append(f"{suite_id}: missing seed algorithm")
        if not isinstance(seed, str) or not SEED.fullmatch(seed):
            errors.append(f"{suite_id}: seed must be a lowercase 64-bit hexadecimal value")
        if not isinstance(case_count, int) or isinstance(case_count, bool) or case_count < 1:
            errors.append(f"{suite_id}: case_count must be a positive integer")
        if not isinstance(minimization_strategy, str) or not minimization_strategy.strip():
            errors.append(f"{suite_id}: missing minimization strategy")
        if not isinstance(failure_classification, str) or not failure_classification.strip():
            errors.append(f"{suite_id}: missing failure classification")
        generator_domain = require_strings(
            suite_id, "generator_domain", item.get("generator_domain"), errors)
        properties_checked = require_strings(
            suite_id, "properties", seed_spec.get("properties"), errors)
        preserved_codes = minimization.get("preserved_finding_codes")
        if preserved_codes is None and minimization.get("preserved_finding_code") is not None:
            preserved_codes = [minimization.get("preserved_finding_code")]
        expected_codes = require_strings(
            suite_id, "minimization preserved Finding codes", preserved_codes, errors)
        if not set(expected_codes).issubset(set(contract.get("finding_codes", []))):
            errors.append(f"{suite_id}: expected Finding codes are outside {contract_id}")
        does_not_establish = require_strings(
            suite_id, "does_not_establish", seed_spec.get("does_not_establish"), errors)
        path_strings = require_strings(
            suite_id, "source_paths", item.get("source_paths"), errors)
        if seed_path_string not in path_strings:
            errors.append(f"{suite_id}: seed_path must also appear in source_paths")
        source_paths = [ROOT / path_string for path_string in path_strings]
        for path in source_paths:
            if not path.is_file():
                errors.append(f"{suite_id}: missing source path {path.relative_to(ROOT)}")
        all_sources.update(path for path in source_paths if path.is_file())
        files = [
            {"path": path.relative_to(ROOT).as_posix(), "sha256": sha256_file(path)}
            for path in sorted(source_paths)
            if path.is_file()
        ]
        suite_record = record_base(
            f"property_suite:{suite_id}", "property_suite", knowledge_ids, title,
            f"Seeded property suite {suite_id} for {contract_id}. Scope: {scope} "
            f"Generator: {seed_algorithm} seed {seed}, {case_count} cases. "
            f"Properties: {' '.join(properties_checked)} Minimization: {minimization_strategy} "
            f"Failure classification: {failure_classification}. "
            f"Does not establish: {' '.join(does_not_establish)}",
            package, [REGISTRY, *source_paths],
        )
        suite_record.update({
            "contract_id": contract_id,
            "property_suite_id": suite_id,
            "scope": scope,
            "generator_domain": generator_domain,
            "seed_algorithm": seed_algorithm,
            "seed": seed,
            "case_count": case_count,
            "properties_checked": properties_checked,
            "minimization_strategy": minimization_strategy,
            "failure_classification": failure_classification,
            "expected_finding_codes": expected_codes,
            "does_not_establish": does_not_establish,
            "files": files,
        })
        records.append(suite_record)

    recipe_entries = recipe_metadata()
    recipe_ids = [item.get("recipe_id") for _, item in recipe_entries]
    duplicates = sorted(item for item, count in Counter(recipe_ids).items() if count > 1)
    if duplicates:
        errors.append(f"duplicate recipe IDs: {duplicates}")
    recipe_index = RECIPE_ROOT / "README.md"
    if not recipe_index.is_file():
        errors.append("recipes/README.md is missing")
    else:
        all_sources.add(recipe_index)

    for metadata_path, item in recipe_entries:
        recipe_id = item.get("recipe_id", "<missing>")
        if item.get("schema_version") != SCHEMA_VERSION:
            errors.append(f"{recipe_id}: unexpected recipe schema version")
        if not isinstance(recipe_id, str) or not RECIPE_ID.fullmatch(recipe_id):
            errors.append(f"invalid recipe ID: {recipe_id}")
            continue
        title = item.get("title")
        purpose = item.get("purpose")
        operation = item.get("operation")
        contract_id = item.get("contract_id")
        command = item.get("command")
        expected_status = item.get("expected_status")
        knowledge_ids = require_string_array(
            recipe_id, "knowledge_ids", item.get("knowledge_ids"), errors)
        fixture_ids = require_string_array(
            recipe_id, "fixture_ids", item.get("fixture_ids"), errors)
        expected_codes = require_strings(
            recipe_id, "expected_finding_codes", item.get("expected_finding_codes"), errors
        )
        does_not_establish = require_strings(
            recipe_id, "does_not_establish", item.get("does_not_establish"), errors
        )
        interface_paths = require_strings(
            recipe_id, "interface_paths", item.get("interface_paths"), errors
        )
        if not isinstance(title, str) or not title.strip():
            errors.append(f"{recipe_id}: missing title")
        if not isinstance(purpose, str) or not purpose.strip():
            errors.append(f"{recipe_id}: missing purpose")
        if operation not in {"check_contract", "parse_case", "analyze_case", "verify_solution", "explain_finding"}:
            errors.append(f"{recipe_id}: unsupported recipe operation {operation}")
        if not isinstance(command, str) or not command.strip():
            errors.append(f"{recipe_id}: missing command")
        valid_statuses = ({"passed", "failed", "inapplicable", "indeterminate"}
                          if operation == "check_contract" else {"completed"})
        if expected_status not in valid_statuses:
            errors.append(f"{recipe_id}: invalid expected status {expected_status}")
        if operation == "check_contract":
            contract = contract_by_id.get(contract_id)
            if contract is None:
                errors.append(f"{recipe_id}: unknown contract {contract_id}")
                continue
            if not knowledge_ids:
                errors.append(f"{recipe_id}: check_contract recipes require knowledge IDs")
            if not fixture_ids:
                errors.append(f"{recipe_id}: check_contract recipes require fixture IDs")
            if knowledge_ids != contract.get("knowledge_ids"):
                errors.append(f"{recipe_id}: knowledge IDs differ from {contract_id}")
            if not set(fixture_ids).issubset(set(contract.get("fixture_ids", []))):
                errors.append(f"{recipe_id}: fixture IDs are outside {contract_id}")
            if not set(expected_codes).issubset(set(contract.get("finding_codes", []))):
                errors.append(f"{recipe_id}: expected Finding codes are outside {contract_id}")
            for fixture_id in fixture_ids:
                if fixture_id not in fixture_by_id:
                    errors.append(f"{recipe_id}: unknown fixture {fixture_id}")
        elif contract_id is not None:
            errors.append(f"{recipe_id}: package-operation recipes must not name a contract")
        elif knowledge_ids:
            errors.append(f"{recipe_id}: package-operation recipes must not claim PSK identities")
        elif fixture_ids:
            errors.append(f"{recipe_id}: package-operation inputs belong in input_paths, not contract fixture_ids")
        if operation in {"parse_case", "analyze_case", "verify_solution", "explain_finding"}:
            for code in expected_codes:
                if not FINDING_CODE.fullmatch(code):
                    errors.append(f"{recipe_id}: invalid Finding code {code}")
                if code not in finding_docs:
                    errors.append(f"{recipe_id}: expected Finding code {code} is absent from docs/src/findings.md")

        recipe_files: list[Path] = []
        for key in ("script", "readme"):
            filename = item.get(key)
            path = metadata_path.parent / filename if isinstance(filename, str) else metadata_path.parent / "<missing>"
            if not path.is_file():
                errors.append(f"{recipe_id}: missing {key}: {filename}")
            else:
                recipe_files.append(path)
        for path_string in interface_paths:
            path = ROOT / path_string
            if not path.is_file():
                errors.append(f"{recipe_id}: missing interface path {path_string}")
            else:
                recipe_files.append(path)
        support_paths = []
        if operation in {"parse_case", "analyze_case", "verify_solution"}:
            support_paths = [
                *require_strings(recipe_id, "input_paths", item.get("input_paths"), errors),
                *require_strings(recipe_id, "tutorial_paths", item.get("tutorial_paths"), errors),
            ]
        elif operation == "explain_finding":
            support_paths = require_strings(
                recipe_id, "tutorial_paths", item.get("tutorial_paths"), errors)
        for path_string in support_paths:
            path = ROOT / path_string
            if not path.is_file():
                errors.append(f"{recipe_id}: missing supporting path {path_string}")
            else:
                recipe_files.append(path)
        all_sources.update([metadata_path, *recipe_files])
        files = [
            {"path": path.relative_to(ROOT).as_posix(), "sha256": sha256_file(path)}
            for path in sorted(recipe_files)
        ]
        recipe_record = record_base(
            f"recipe:{recipe_id}", "recipe", knowledge_ids, title,
            f"Executable recipe {recipe_id} for operation {operation}. {purpose} "
            f"Expected status: {expected_status}. Expected Findings: {', '.join(expected_codes)}. "
            f"Does not establish: {' '.join(does_not_establish)}",
            package, [metadata_path, *recipe_files],
        )
        recipe_record.update({
            "recipe_id": recipe_id,
            "purpose": purpose,
            "operation": operation,
            "command": command,
            "fixture_ids": fixture_ids,
            "expected_status": expected_status,
            "expected_finding_codes": expected_codes,
            "does_not_establish": does_not_establish,
            "files": files,
        })
        if operation == "check_contract":
            recipe_record["contract_id"] = contract_id
        records.append(recipe_record)

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
        "contract_ids": sorted({record["contract_id"] for record in records if "contract_id" in record}),
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
