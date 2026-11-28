# Solution projection and power-flow comparison

After [independently checking a solution](tutorial_trust_but_verify.md),
use this workflow to compare its predicted state with a re-solved power flow.
[`project_solution`](@ref) pins supported dispatch and tap decisions onto a copy
of the network. Comparing that snapshot in BMOPFTools and an external engine
can help investigate discrepancies, subject to the conversion coverage below.

**Prerequisites:** a solved case, BMOPFTools, JuMP and a suitable optimizer.
The BMOPF comparison needs no external dataset; the additional OpenDSS
comparison requires OpenDSS and a supported export. The file-based code below
is a workflow template, not an example executed during the docs build.
For the package's test fixtures and coverage, see [engine validation](validation.md).

## The idea: pin the solution, re-solve as a determined power flow

An OPF can choose generator/IBR dispatch, transformer taps and inverter
setpoints. Pinning the supported decisions to their solved values produces a
snapshot for a power-flow comparison. Check that the projection recorded every
intended device and that the case has valid references; pinning dispatch does
not establish uniqueness of the power-flow solution or cover arbitrary custom
controls. Missing or nonfinite dispatch records can leave a device unpinned.

[`project_solution(net, result)`](@ref) does exactly this pinning and returns a
deep copy of `net` (the input is never mutated):

- **Generators and IBRs** — per-phase active/reactive dispatch is frozen to the
  solved values (`p_min == p_max == pg`, `q_min == q_max == qg`). An IBR with a
  `control_profile` (power factor, Volt-var, or Volt-watt) has the profile
  reference removed and the fixed bounds written instead, freezing the control at
  its solved operating point.
- **Free transformer taps** — a tap that was an OPF decision variable (reported as
  `tap` / `tap_ratio` in the result) is written back onto the winding. Fixed-tap
  transformers are left untouched.

The projected network can be passed to [`solve_pf`](@ref), and exported for
comparison where [`to_dss`](@ref) supports the represented model.
`net_projected["_meta"]["projection"]` on the returned network records what was
pinned (`generators`, `ibrs`, `control_profiles_frozen`, `free_taps`) so a later
oracle mismatch can be attributed.

## The three-way triangulation

With a determined snapshot in hand there are three computational routes to the
same voltages. Only route C uses an external engine; comparing all three still
helps localize disagreements:

| | Source | What it is |
|---|---|---|
| **A** | `result["bus"]` | the OPF's own predicted voltages |
| **B** | `solve_pf(project_solution(net, result))` | BMOPF re-solving the pinned snapshot as a power flow (self-consistency check, not an independent oracle) |
| **C** | OpenDSS solving `to_dss(...)` of the snapshot | an external engine (independent implementation comparator, not ground truth) |

Reading the pattern:

- **A ≈ B** provides self-consistency evidence for the projected case within
  the checked quantities and tolerances. A discrepancy calls for inspection of
  the projection, controls, references, residuals and selected solution branch.
- **A ≈ B ≉ C** motivates checking export fidelity and conventions, as well as
  numerical tolerances and solution-branch differences. It does not by itself
  identify which implementation or model assumption is responsible.

The A/B comparison uses the package's own engine. The C comparison uses an
independent implementation and must account for
[`to_dss` fidelity warnings and coverage](conversion.md#to-dss-export).
Check the returned warnings and inspect whether the exported case represents
the intended controls, references and devices before comparing voltages.

## Exporting the dispatch to OpenDSS — `dispatch_as_loads`

[`to_dss`](@ref) exports pinned generators and IBRs as OpenDSS `Generator`
objects, so the projected snapshot can be exported directly. [`dispatch_as_loads`](@ref)
gives an alternative, load-only deck, for when you want the comparison to rest
on OpenDSS's load model alone: it rewrites every **pinned**
generator/IBR as an equivalent constant-power **negative load**
(`p_nom = -p_min`, `q_nom = -q_min`) — carrying
the device's terminal map and connection. A fixed PQ injection *is* a negative
constant-power load, so under the determined power flow the two forms give the
same voltages. Generation sitting on a
`voltage_source` bus is **dropped, not converted** — the slack source is the
reference injector in a power flow and its dispatch must not be re-imposed as a
load. This representation checks the pinned injection; it does not preserve the
original device's control law or dispatch flexibility.

## Putting it together

```julia
net    = from_dss("my_feeder.dss")
result = solve_opf(net)                    # your OPF solution

snap   = project_solution(net, result)     # pin every setpoint → determined snapshot
res_B  = solve_pf(snap)                     # B: BMOPF self-check  (expect A ≈ B)

deck   = dispatch_as_loads(snap)            # optional: generators/IBRs → negative loads
# The deck is for a power-flow comparison, so ratings need not survive export;
# allow_unverified_ratings=true accepts that (OPF studies keep the BMOPF JSON).
export_warnings = to_dss(deck, "snap.dss"; allow_unverified_ratings=true)  # inspect before running OpenDSS
# Run the exported deck in OpenDSS and align terminal names, units and references
# before comparing its voltages with result and res_B.
```

[Validating the OPF](validation.md#Feasibility-—-agreement-with-OpenDSS) describes
how terminal names are matched and which near-zero nodes are skipped when the
package compares voltages with OpenDSS; use the same rules for your own comparison.
