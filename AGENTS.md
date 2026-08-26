# Repository guidance for coding agents

Read `ARCHITECTURE.md` before changing scientific contracts or cross-repository metadata. This repository owns executable package behavior: APIs, applicability checks, structured results, Finding codes, fixtures, and executable export records. The sibling `multi-graph-book` owns scientific prose, evidence status, misconceptions, and stable `PSK-*` identities.

For scientific guardrails:

1. Link behavior to a stable PSK ID; do not restate or independently revise the scientific claim here.
2. Declare the supported domain in code and metadata. Return an explicit inapplicable or indeterminate result outside that domain instead of guessing.
3. Use stable Finding codes and structured evidence. Match and test codes, not message text.
4. Add positive, negative, boundary, and serialization tests, plus a minimized fixture when a failure witness is central.
5. Update `knowledge/executable.toml`, regenerate the executable export, and run its stale-output/schema checks whenever an API, Finding, fixture, or source path changes.
6. Do not edit the sibling book's generated pair manifest from this repository; repin it from the book after both sides are reviewed.

Primary gates:

```bash
python3 scripts/generate_executable_knowledge.py --check
julia --project=test --startup-file=no -e \
  'using Test, BMOPFTools; include("test/scientific_contract_tests.jl"); include("test/executable_knowledge_tests.jl")'
julia --project=test --startup-file=no test/runtests.jl
```

The executable metadata export is a package discovery surface, not a replacement for runtime API documentation or the book's scientific knowledge base.
