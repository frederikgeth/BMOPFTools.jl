# Installation & first steps

This page takes you from a bare machine to a Julia session where the
[end-to-end tutorial](tutorial_end_to_end.md) runs. If you already use Julia
day-to-day, the [Installing BMOPFTools](@ref installing-bmopftools) section is
all you need.

## Prerequisites: installing Julia

BMOPFTools is a [Julia](https://julialang.org) package and requires
**Julia ≥ 1.10**. The recommended way to install Julia on every platform is
[**juliaup**](https://github.com/JuliaLang/juliaup), the official version
manager — it installs the current release and keeps it updated:

- **Windows** — install from the
  [Microsoft Store](https://apps.microsoft.com/detail/9NJNWW8PVKMN), or from a
  terminal (Command Prompt or PowerShell):

  ```sh
  winget install julia -s msstore
  ```

- **macOS / Linux** — in a terminal:

  ```sh
  curl -fsSL https://install.julialang.org | sh
  ```

Standalone installers are also available from the
[official downloads page](https://julialang.org/downloads/). Either route puts
a `julia` command on your PATH; open a *new* terminal window afterwards so the
PATH change takes effect.

If Julia itself is new to you, the official
[Getting Started](https://docs.julialang.org/en/v1/manual/getting-started/)
manual page and the community
[“Get started with Julia”](https://julialang.org/learning/) learning hub
(free tutorials and courses) cover the basics in an hour or two. The
[Pkg documentation](https://pkgdocs.julialang.org/v1/getting-started/)
explains the package manager used below.

## The Julia REPL — where the commands go

Typing `julia` in your terminal (or launching Julia from the Start menu)
opens the **REPL**, Julia's interactive prompt:

```
julia>
```

This is where Julia code runs — **not** the Windows Command Prompt,
PowerShell, or a Unix shell. Throughout this documentation:

- ```` ```julia ```` code blocks (and the executed example blocks in the
  tutorials) are **Julia code**: type or paste them at the `julia>` prompt,
  or put them in a `.jl` script.
- ```` ```sh ```` code blocks are **system terminal commands**: run them in
  Command Prompt / PowerShell / bash, *not* inside Julia.

One more prompt you will meet: pressing `]` at the `julia>` prompt switches
the REPL into **package mode** (`pkg>`), Julia's built-in package manager.
Press backspace to return to `julia>`. Everything package mode does is also
available as ordinary function calls via `using Pkg` — this documentation
uses the function form (`Pkg.add(...)`) because it works identically in
scripts, but `pkg> add ...` and `Pkg.add("...")` are interchangeable.

## [Installing BMOPFTools](@id installing-bmopftools)

BMOPFTools is not yet in Julia's **General registry** (the default catalogue
`Pkg.add("SomePackage")` searches), so install it from its Git URL. At the
`julia>` prompt:

```julia
using Pkg
Pkg.add(url = "https://github.com/frederikgeth/BMOPFTools.jl")
```

The first install resolves and compiles the dependency tree, which takes a
few minutes; later sessions start fast. Then check it loads:

```julia
using BMOPFTools
```

Parsing, validation, analysis, reporting, and OpenDSS ingestion
([`from_dss`](@ref)) now work out of the box.

### Optional: the OPF / power-flow solvers

`solve_opf`, `solve_pf` and `solve_feasibility_opf` live in a **package
extension**: optional functionality that activates automatically once its
extra dependencies are installed. The tutorials that solve an OPF need
**JuMP** (the optimisation modelling layer) and a solver such as **Ipopt**:

```julia
Pkg.add(["JuMP", "Ipopt"])
using BMOPFTools, JuMP, Ipopt   # extension activates on load
```

!!! note "Tracking a moving target"
    The package is under rapid development, with breaking changes landing
    directly on `main`. Pin a specific revision when you need reproducibility:
    `Pkg.add(url = "https://github.com/frederikgeth/BMOPFTools.jl", rev = "<commit-sha>")`.

## Running the tutorials from a clone

Every tutorial can be followed by copy-pasting its code blocks into your own
REPL after the install above. If you would rather run against the bundled
test networks and the exact dependency versions the documentation is built
with, work from a clone of the repository:

```sh
git clone https://github.com/frederikgeth/BMOPFTools.jl
cd BMOPFTools.jl
julia --project=docs
```

`--project=docs` starts Julia with the `docs/` folder's **environment** — the
`Project.toml` file there pins the package set (BMOPFTools, JuMP, Ipopt, …).
The first time, materialise that environment from inside the REPL:

```julia
using Pkg
Pkg.develop(path = ".")   # use the cloned BMOPFTools source
Pkg.instantiate()         # download and install the pinned dependencies
```

After that, `julia --project=docs` from the repository folder drops you
straight into a session where every tutorial runs.

## Where to next

- The [end-to-end tutorial](tutorial_end_to_end.md) walks the primary
  pipeline — OpenDSS in, solved OPF benchmark out — on a real feeder.
- [Choose your tutorial](choose_tutorial.md) maps the rest of the tutorial
  library to what you want to do.
