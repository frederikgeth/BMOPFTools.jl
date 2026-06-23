# Known Traps

A gallery of small instances that *exhibit* each pathology from
[Bounds, Branches, and Feasibility](index.md). Each entry states what it demonstrates,
a minimal construction, the expected behaviour per formulation, and what to look for. A
validator can use these as targeted tests: *"give me the input that should expose my
bug."*

!!! note "For maintainers"
    The constructions below are minimal and self-contained. Each trap ends with an
    *Instance* line: where a BMOPFTools case or test already exhibits the behaviour it
    is linked, and where none exists yet the construction is small enough to add as a
    named case — please link it here when you do, so the gallery and the benchmark
    library cross-reference.

## Trap 1 — Unbounded without bounds

**Shows:** [§1](index.md) — a
non-coercive objective over a non-compact set has no optimum.

**Construction:** any feeder, remove voltage magnitude bounds and generator limits, set
a *linear* objective (e.g. minimize a single weighted injection, or maximize
$\sum |V_i|$).

**Expected behaviour:**

| Formulation | Outcome |
|---|---|
| Linear | unbounded (`DUAL_INFEASIBLE`) |
| SOC / SDP relaxation | unbounded |
| Nonconvex AC | unbounded or solver failure (`NORM_LIMIT`-class) |

**Look for:** after the bound-everything recipe ([Diagnostics §1](diagnostics.md)),
voltage magnitudes pinned at the artificial bound. *Adding $\underline v,\overline v$
alone makes it finite.*

*Instance:* take any augmented benchmark feeder and strip its voltage/generator bounds
(the inverse of the [case augmentation](../augmentation.md) step); not yet a named case.

## Trap 2 — Branch multiplicity (high vs low voltage)

**Shows:** [§2](index.md) —
"square" is not "unique."

**Construction:** the two-bus system of §2 — source $E = 1.0\angle 0$, lossless
reactance $X$, constant-power load $P + jQ$ chosen so the radicand
$\tfrac{E^4}{4} - X^2P^2 - XE^2Q$ is small and positive (loaded but below the nose).

**Expected behaviour:** two real AC solutions $V_+ \approx 1$ p.u. and
$V_- \ll 1$ p.u.; an exact relaxation and a high-voltage-started nonconvex solve both
return $V_+$; a flat-but-low or adversarially started Newton solve can land on $V_-$.

**Look for:** different solutions from different starts ⇒ multiplicity. The low-voltage
cluster is the tell ([Diagnostics §4](diagnostics.md)).

*Instance:* the single-phase resistive two-bus of OPF test **T1**
([Validating the OPF](../validation.md)) solves the high-voltage root of this same
quadratic, `V = (V_s + √(V_s² − 4RP))/2`; a low-`R/X` reactive variant loaded toward
the nose exposes the second root. The reactive two-bus is not yet a named case.

## Trap 3 — Relaxation feasible *past* collapse

**Shows:** [§3](index.md)
and [§4](index.md) — a relaxation
enlarges the feasible set beyond the true AC boundary, so it can certify feasibility for
a loading the network cannot serve.

**Construction:** the two-bus, one-generator characterization of
[Kocuk, Dey & Sun (2016)](https://doi.org/10.1109/TPWRS.2015.2402640). Pick a
load just beyond the nose (radicand $< 0$).

**Expected behaviour:**

| Formulation | Outcome |
|---|---|
| Nonconvex AC | infeasible (no real solution past the nose) |
| SOC / SDP relaxation | **may report feasible / "optimal"** — non-physical |

**Look for:** relaxation `OPTIMAL` while the AC solve is `LOCALLY_INFEASIBLE`; large
per-branch cone gap ([Diagnostics §3](diagnostics.md)). This is the headline reason a
feasible relaxation is only a one-sided certificate.

*Instance:* the two-bus, one-generator system of
[Kocuk, Dey & Sun (2016)](https://doi.org/10.1109/TPWRS.2015.2402640) with a
load just past the nose; verify the AC side with [`solve_feasibility_opf`](../validation.md)
(non-zero `total_slack_magnitude_A`). Not yet a named case.

## Trap 4 — Loss-maximizing objective breaks exactness

**Shows:** [§5](index.md) and the
[loss-maximization list](loss_maximization.md) — an objective that rewards current makes
the relaxed $\ell_{ij}$ slack.

**Construction:** a small radial feeder with DER; objective = **maximize PV injection**
(or maximize export), full bounds, SOC-BFM.

**Expected behaviour:** the SOC solution reports inflated currents; the cone gap
$\ell_{ij} - |S_{ij}|^2/v_i$ is strictly positive on loaded branches;
`primal_feasibility_report` against the AC model is non-empty. Switching the objective to
*maximize injection net of losses* restores exactness.

**Look for:** positive cone gaps concentrated where upper voltage bounds bind
([Diagnostics §3](diagnostics.md)).

*Instance:* a small radial DER feeder with objective = maximize PV injection; the
[DER placement tutorial](../tutorial_ders.md) builds suitable feeders to adapt. Not yet
a named case.

## Trap 5 — Generator lower bounds break exactness

**Shows:** the standard escape-hatch conditions in
[§5](index.md) — exactness proofs often assume *no
generator lower bounds* or *load over-satisfaction*; reintroducing a lower bound can make
the relaxation inexact, exact, or feasible-while-AC-infeasible
([Kocuk, Dey & Sun, 2016](https://doi.org/10.1109/TPWRS.2015.2402640)).

**Construction:** the same two-bus, one-generator system with a binding
$\underline{P}^g > 0$; sweep the lower bound to move between the three outcomes.

**Expected behaviour:** a single small instance reproduces all three approximation
outcomes as the lower bound varies — a compact regression test for any relaxation
implementation.

**Look for:** the outcome flipping as a single parameter sweeps; tabulate cone gap vs
$\underline{P}^g$.

*Instance:* the same two-bus, one-generator system as Trap 3 with a swept binding
$\underline{P}^g > 0$ — a compact regression fixture worth adding as a named case.

## Suggested test matrix

For a formulation under validation, the minimal coverage is one instance per trap:

| Trap | Property tested | Pass criterion |
|---|---|---|
| 1 | Well-posedness / bounds | unbounded without bounds, finite with them |
| 2 | Branch selection | high-voltage solution recovered from a sane start |
| 3 | One-sided certificate | AC-infeasible past nose; relaxation gap detected |
| 4 | Objective monotonicity | exact under loss-min; inexact (detected) under loss-max |
| 5 | Exactness escape hatches | three outcomes reproduced across a bound sweep |

---

See also: [Bounds, Branches, and Feasibility](index.md) ·
[Decision matrix](decision_matrix.md) ·
[Objectives that imply loss maximization](loss_maximization.md) ·
[Diagnostics & validation](diagnostics.md) · [References](references.md)
