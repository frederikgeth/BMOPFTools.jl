# Documentation

The site is built with [Documenter.jl](https://documenter.juliadocs.org/).

## Building locally

```julia
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

The output lands in `docs/build/`. The end-to-end tutorial executes a real OPF
solve at build time via Documenter `@example` blocks, so the docs environment
includes `JuMP` and `Ipopt` (see `docs/Project.toml`). A failed `@example` block
fails the build — that is intentional, so executable docs cannot silently rot.

## Authoring conventions

**Math notation.**

- **Units and standalone symbols** in prose and tables stay Unicode: `Ω`, `√3`,
  `°`, `²`, `·`, `Γ`, `Π`. A lone `$\Omega$` is overkill and does not sit well in
  table cells.
- **Equations and relations** — anything with an `=`, subscripted variables, or a
  fraction — use LaTeX: inline `$...$`, or a fenced ` ```math ` block for display
  equations (not `$$...$$`). Documenter renders both via KaTeX.
- **Field-assignment recipes** that reference literal BMOPF JSON keys (e.g. the
  impedance-base conversions in `conversion.md`) stay in plain code fences, not
  `math` — the literal key names must remain greppable.

**Cross-references.**

- Use `@ref` for docstrings/API symbols and for in-page anchors with an explicit
  `@id`. Use relative `file.md` / `file.md#Anchor` links between pages.
- From `bounds/` (a subfolder), link up to top-level pages with `../file.md` and
  to sibling pages with a bare `file.md`.
- `checkdocs = :exports` and the build's cross-reference checks will flag broken
  `@ref`/anchors — keep the build warning-clean.
