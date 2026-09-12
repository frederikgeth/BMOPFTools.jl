# Preparing and publishing releases

The first General registration is being prepared as **0.1.0**. No registration
has been requested. Do not tag or register until the remaining decisions below
are settled and the exact release commit has passed CI.

## Compatibility and support

The package supports Julia 1.10 and later compatible Julia 1.x versions. CI
uses a literal 1.10 job and latest stable. JuMP 1.29.4 is the conservative
first-release floor selected for validation; older releases are not promised.
The fresh-install matrix tests that exact version and latest JuMP on both
Julia versions. This is not an exhaustive test of every allowed transitive
version. Keep dependency bounds honest as new features are introduced.

The standard CI suite requires JuMP, Ipopt, MadNLP, and OpenDSSDirect to load.
An import failure must fail the job. Gurobi remains optional and licence-gated.
The installation matrix separately tests core-only operation, both JuMP load
orders without Ipopt, and a small Ipopt power-flow solve. It creates temporary
environments instead of using developer manifests. Linux is the CI target;
other platforms require their own validation before making stronger claims.

## Local release gates

Use Python 3.11+ for the metadata generators. Python is not required by the
Julia package test suite. Generator checks run separately in CI.

```sh
python3 scripts/generate_finding_registry.py --check
python3 scripts/generate_executable_knowledge.py --check
python3 scripts/check_release_metadata.py
python3 scripts/check_llms_entrypoint.py
julia --project=test --startup-file=no -e 'using Test, BMOPFTools; include("test/scientific_contract_tests.jl"); include("test/executable_knowledge_tests.jl"); include("test/execution_interface_tests.jl")'
BMOPF_REQUIRE_TEST_DEPS=true julia --project=test --startup-file=no test/runtests.jl
julia --startup-file=no test/fresh_install.jl 1.29.4
julia --startup-file=no test/fresh_install.jl latest
julia --project=docs --startup-file=no docs/make.jl
```

Instantiate the test and docs environments first. CI additionally runs the
isolated DiffOpt and downstream-extension suites. Local existing manifests
are useful for development but are not evidence of a fresh installation.

External dataset checks remain opt-in through `BMOPF_RESTRICTED_DATA`; see
`test/RESTRICTED_DATA.md`. Restricted CSIRO MV/LV and ENWL data live in
BMOPFDraftData, with all original licence notices preserved. Do not restore them
under the package tree or silently download them during package installation.

## Schema and public API baseline

`schemas/bundled-schema.toml` records the SHA-256 of the actual bundled schema
and the package commit that last changed it. The upstream draft is mutable;
its current contents differ from the bundled file. An identical upstream
revision has not been established, so the manifest explicitly does not claim
one. Review the bundled differences with the specification owner before the
first release. Do not replace the runtime schema just to match upstream main.

Public contracts include exported APIs and supported qualified APIs, Finding
codes and meanings, result/report shapes, execution envelopes, and documented
OPF extension records. Deprecations retain working old entry points until a
breaking release. Explicitly internal or experimental interfaces are excluded.
Keep package SemVer, data-model migrations, execution schema versions, and
provenance schema identifiers distinct. Scientific claims/PSK identities remain
book-owned; package changes must preserve the ARCHITECTURE.md boundaries.

## First-release decisions still requiring maintainer review

- Review and understand the final code, including generated/AI-assisted changes.
  The README discloses Codex's work on this release-preparation effort; expand
  that statement if earlier contributions also require disclosure.
- Review the bundled schema's differences from upstream and record the agreed
  supported snapshot. The fingerprint is evidence of identity, not approval.
- Review the remaining bundled fixtures' provenance and licences. Moving the
  two large datasets is not a legal certification of every remaining fixture.
- Verify the Registrator app installation. The local General name/similarity
  check passed for `BMOPFTools`; the registration PR must pass it again.
- Verify TagBot actually triggers tagged docs. A writable Documenter deploy key
  and the DOCUMENTER_KEY secret exist; their pairing and tag-triggered deployment
  still need an end-to-end check.
- Require green CI for the exact release commit and review coverage changes.

## Local preparation evidence (2026-09-12)

- Clean-source `Pkg.test` passed on macOS ARM64 with Julia 1.10.11 and pinned
  JuMP 1.29.4, and Julia 1.13.0 with latest resolved JuMP: each reported 9,170
  passes and 39 explicitly skipped/broken checks, with no failures.
- Fresh core installation, both JuMP load orders, and an Ipopt solve passed on
  those two configurations. CI covers the other matrix combinations.
- Isolated DiffOpt and downstream extension tests passed on Julia 1.13.0.
- Scientific-contract, executable-export, JSON-interface, Python metadata, and
  documentation build gates passed. The updated CI YAML parses locally.
- OpenDSSDirect 0.9.9 emits a method-overwrite precompilation diagnostic on
  Julia 1.13 and falls back to loading; its live comparison tests passed. This
  upstream issue is not treated as permission to skip a failed backend import.

These local results do not replace Linux CI on the final release commit.

## Registering the approved release

1. Finalize `Project.toml`, changelog, migration notes, and docs. Stay at 0.1.0
   for the first registration; do not claim 1.0 stability prematurely.
2. Regenerate the executable export after any version change:
   `python3 scripts/generate_executable_knowledge.py --write`. Review the diff
   and rerun the gates above before committing.
3. Install Julia Registrator for the public package repository. Comment
   `@JuliaRegistrator register` on the exact approved commit, followed by
   `Release notes:` and the release summary. This creates a General PR.
4. Resolve registry checks and feedback. Retrigger on corrected source commits.
   A new package normally waits three days; later versions normally wait
   fifteen minutes plus checks/review. Use `[noblock]` for non-blocking comments.
5. After acceptance, let TagBot create the matching tag and GitHub release.
   Verify versioned docs and install the registered version in a new environment.
6. Update the README/installation page to lead with `Pkg.add("BMOPFTools")`
   once that command really works. Keep the Git URL instructions for development.

## Later releases and mistakes to avoid

While on 0.x, compatible fixes/features increment the patch; incompatible
changes increment the minor. After 1.0, use patch/minor/major in the usual way.
Review CompatHelper PRs rather than automatically trusting broadened bounds.
Never overwrite registered releases, retarget their tags, or remove historical
release trees. A bad release normally needs a new corrective version. Severe
failures or incorrect historical bounds may also require registry compatibility
corrections or yanking; yanking does not prevent existing manifests reinstating
the old code. Do not change a registered UUID to solve ordinary release issues.

After both repositories' scientific changes are reviewed, repin the generated
book pairing from the book workflow. Do not edit its generated pair manifest
from this repository. Choose a sustainable support policy; there is no need to
publish on a fixed schedule or maintain every old branch indefinitely.

Primary references: [General](https://github.com/JuliaRegistries/General),
[AutoMerge](https://juliaregistries.github.io/RegistryCI.jl/stable/guidelines/),
[Registrator](https://github.com/JuliaRegistries/Registrator.jl),
[TagBot](https://github.com/JuliaRegistries/TagBot), and
[Pkg compatibility](https://pkgdocs.julialang.org/v1/compatibility/).
