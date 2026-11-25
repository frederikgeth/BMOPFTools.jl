# [Error-bounded bus reduction (Opti-KRON)](@id opti-kron)

!!! warning "Prototype"
    This feature is a prototype. Its behavior is tested and validated against
    the paper's published results, but it is not
    yet linked to a scientific-knowledge (`PSK-*`) claim or exposed through
    the JSON execution interface.

Robust Opti-KRON [1] chooses which buses of a distribution network to keep so
that the reduced network has as few buses as possible, while every original
bus voltage stays within a threshold Ē of its estimate, for **every** loading
in an uncertainty set. BMOPFTools implements the method and turns the result
into a solvable BMOPF case.

For a hands-on introduction, start with the [tutorial](@ref tutorial-opti-kron);
for how it compares with the other reductions, see
[Network reduction](@ref network-reduction).

## The idea in one paragraph

Every bus j is assigned to a *super-node* i within H tree hops (A_ij = 1);
super-nodes are kept, all other buses are eliminated. The devices of j move
to i, phase by phase, and i's voltage stands in for j's. Moving a load changes
voltages, so this has an error. Under a linear voltage model the error is
linear in the injections, which makes "the error stays within Ē for every
loading in a set" an exact, solvable constraint. With no injection left on
them, the eliminated buses can then be removed *exactly* by Kron reduction.

## Linear voltage model

Let u = [p; q] be the active and reactive power injections per node-phase
(generation positive, in kW and kvar) and v the voltage magnitudes in p.u. of
each node-phase's no-load magnitude U₀. BMOPFTools linearizes the full
multiconductor network at its no-load operating point:

```math
\Delta V = Y_{ff}^{-1}\,\Delta I, \qquad
\Delta I_k = \frac{\overline{\Delta S_k}}{\overline{U_{0,k}}}, \qquad
\Delta v_r = \frac{\operatorname{Re}\!\big(\overline{U_{0,r}}\,\Delta U_r\big)}{|U_{0,r}|^2},
```

where Y_ff is the passive admittance matrix ([`ybus_passive`](@ref)) of all
nodes not fixed by the source, and U is the phase-to-neutral voltage (or
phase-to-earth where there is no ungrounded neutral). This gives v = 1 + K u
with K = [K_P K_Q] ([`opti_kron_model`](@ref)). For a single-phase radial
feeder with a flat no-load profile this is exactly LinDistFlow [2]: K_P is the
resistance shared by the two buses' paths to the source, K_Q the shared
reactance. The general form also includes neutrals, MEN earthing, mutual
coupling, transformers and meshes.

## The error and the robust problem

When all devices of a cluster sit at its super-node i, the reduced voltages
are ṽ = 1 + K A u. The error of bus j represented by super-node i is

```math
e_{ij}(A, u) = \tilde v_i - v_j = c_{ij}(A)^\top u,
\qquad c_{ij}(A)_k = K_{i,\,b(k)} - K_{j,k},
```

where b(k) is the super-node of node k. The coefficient c_ij(A) is affine in
A, so the robust reduction problem is a mixed-integer program:

```math
\begin{aligned}
\min_A\ & \textstyle\sum_i A_{ii} \\
\text{s.t. }\ & \max_{u \in \mathcal U}\ c_{ij}(A)^\top u \le \bar E + M_{ij}(1 - A_{ij}) && \forall (i,j) \in \mathcal C \\
& \min_{u \in \mathcal U}\ c_{ij}(A)^\top u \ge -\bar E - M_{ij}(1 - A_{ij}) && \forall (i,j) \in \mathcal C \\
& \textstyle\sum_i A_{ij} = 1,\quad A_{ij} \le A_{ii},\quad A_{ss} = 1 && \text{(every bus has one super-node; slack kept)} \\
& A_{ij} \le A_{ik} \quad \forall k \in \mathcal P_{ij} && \text{(clusters are connected subtrees)}
\end{aligned}
```

𝒞 holds the candidate pairs within H hops, and 𝒫_ij is the path between i and j.

## Uncertainty sets

| Set | Built from N training samples | Worst case of cᵀu | Constructor |
|---|---|---|---|
| Box | per-coordinate range [ℓ, h] | cᵀū + δᵀ\|c\| | [`OptiKronBox`](@ref) |
| Convex hull | the samples themselves | max_k cᵀuᵏ | [`OptiKronHull`](@ref) |
| Ellipsoid | mean μ, covariance Σ = LLᵀ (POET), radius Ω | cᵀμ + Ω‖Lᵀc‖₂ | [`OptiKronEllipsoid`](@ref) |
| Wasserstein | empirical distribution, radius ρ/ε, ℓ_p transport cost | CVaR_{1−ε} of cᵀu (eq. 7 of [1]) | [`OptiKronWasserstein`](@ref) |

The box and the hull stay within the sampled range of each coordinate; the
ellipsoid and the Wasserstein ball extrapolate beyond it. Passing only a few
chosen samples to [`OptiKronHull`](@ref) gives the classical scenario-based
Opti-KRON [3].

## Solving: screening and adversarial constraint generation

[`opti_kron_screen`](@ref) removes candidate pairs that no feasible reduction
can use and error constraints that always hold. Two tests are used: a
worst-case voltage difference above 2Ē along a path (test 1), and interval
bounds on the coefficients over the remaining candidates (test 2; box and hull
only).

[`opti_kron_reduction`](@ref) then runs Algorithm 1 of [1]. A master MILP
enforces the error bound only at a finite set of loadings 𝒰ᵗ. A closed-form
adversary finds, for the master's assignment, the worst loading in 𝒰 for each
bus, and adds those of the K most-violated buses to 𝒰ᵗ. The loop ends when the
adversary finds no violation (Δ ≤ 0). User-supplied `initial` loadings must
lie in 𝒰, or the master would over-constrain the problem and its optimum
would no longer be a lower bound; membership is checked exactly (an LP for
the hull and the Wasserstein ball). The result is then **certified** for
the whole set and, if every master was solved to optimality, minimal. The
master's optimum is always a valid lower bound (`result.lower_bound`). A good
MILP solver matters: on real feeders HiGHS often stalls, and Gurobi solves the
same masters in seconds to minutes.

## From an assignment to a solvable case

[`kron_reduce_buses`](@ref) builds the reduced BMOPF case:

1. **Relocate devices.** Every load, generator and IBR of an eliminated bus is
   re-attached to its super-node with the same terminal labels. Devices stay
   separate objects, so their limits and costs survive.
2. **Eliminate exactly.** The passive elements touching eliminated buses are
   Kron-reduced (Schur complement of their multiconductor admittance matrix)
   and written back as lines with inline series impedance and matrix shunts.
   Transformers and elements between kept buses are copied unchanged. For the
   AC model this step introduces no error: on a real four-wire feeder, the
   reduced case reproduces the full network with relocated devices to
   5 × 10⁻¹³ p.u.
3. **Certify voltage limits (optional).** If bus j is within ±Ē of its
   super-node i, then tightening i's band to
   ``(U_j^{\min} + \bar E\,U_{0,j})\,U_{0,i}/U_{0,j}`` (and likewise for the
   maximum) keeps j within its own limits, within the certificate.

Two conditions apply. Transformer and source buses must be kept
([`opti_kron_required_buses`](@ref)), because a Kron equivalent across a
transformer is not a BMOPF line. And with `preserve_radial=true` (the
default), the reduced network stays radial: eliminating a bus that joins three
or more directions containing super-nodes would couple them all (mesh
fill-in). [`kron_reduce_buses`](@ref) checks fill-in on the physical graph,
so it also catches fill-in through meshed edges that the MILP's tree-based
constraint does not see. Current limits of eliminated lines have no exact
equivalent; they are dropped and listed in the log.

The builder also refuses a few cases rather than silently approximating:
time-varying impedances or limits on eliminated elements (the equivalent is
one snapshot; reduce [`get_snapshot`](@ref) instead), and, with `Ebar`, a bus
represented by the slack whose tightened band excludes the slack's fixed
voltage (keep that bus). A kept neutral that reaches earth only through an
eliminated bus keeps its ideal ground.

[`lift_solution`](@ref) maps a solution of the reduced case back to every
original bus. The default linear lift uses the certificate itself:
v_j = ṽ_i − c_ij(A)ᵀu holds exactly in the linear model, and u (the solved
device powers) is known after a solve. Only the second-order AC part of the
error remains; on the feeders tested this cut the error by 10–150×.

## What is and is not guaranteed

| Guaranteed | Not guaranteed |
|---|---|
| \|ṽ_i − v_j\| ≤ Ē under the linear model for every u in the set (when Δ ≤ 0) | the same bound under AC power flow (it held within a few percent of Ē in all tests) |
| exact AC equivalence of the reduced passive network, given the relocated devices | anything for loadings outside the set |
| eliminated-bus voltage limits, via tightening, within the certificate | currents and current limits of eliminated lines |
| minimality, if every master solved to optimality (`:optimal`) | minimality when a master hit its time limit (`:feasible`) |

## Validation against the paper

The IEEE European LV test feeder (907 nodes, 1,440 one-minute samples, H = 5,
ε = 0.01, 95% quantile radii, K = 3), reproduced with
`scripts/opti_kron_eulv.jl` (Gurobi, at most 1 h per cell).

**Structure.** The candidate set has 11,227 pairs and the structural maximum
(no error bound) is 88.6% (103 super-nodes), both exactly as in the paper.
The maximum is reproduced only when the reduced network must stay radial;
the paper does not state this constraint, and without it the maximum is 91.1%.

**Reduction (% of buses removed) by set and threshold.** Unmarked cells are
certified for their set and minimal. Cells marked † hit the time limit before
the adversary certified an assignment; the value shown is a proven upper bound
on the reduction, the tighter of the master's lower bound and the certified
result at the next threshold (a larger Ē never needs more super-nodes).

| Set | Ē = 0.001 | 0.002 | 0.003 | 0.004 | 0.005 | Paper, Ē = 0.001 |
|---|---|---|---|---|---|---|
| scenario baseline | 86.7 | 88.2 | 88.3 | 88.5 | 88.6 | 86.7 |
| convex hull | 83.7 | 87.4 | 87.9 | 88.2 | 88.5 | 83.0 |
| box | 79.4 | 85.2 | 86.7 | 87.5 | 88.0 | ≈ 79.5 |
| ellipsoid | ≤ 68.8 † | 68.8 | 76.2 | 79.3 | 81.6 | ≈ 76 |
| Wasserstein ℓ1 | ≤ 83.1 † | 87.1 | 87.7 | 88.4 | 88.6 | 75.0 |
| Wasserstein ℓ2 | ≤ 84.9 † | 87.4 | 88.2 | 88.3 | 88.5 | ≈ 81 |
| Wasserstein ℓ∞ | 69.1 | 78.1 | 84.6 | 86.4 | 87.4 | ≈ 80 |

Paper values marked ≈ are read from its Fig. 2(a); the others are stated in
its text. Screening keeps 64–89% of the candidate pairs at Ē = 0.001 and
90–100% at Ē = 0.005 (paper: 54–70% and 89–98%).

How to read the comparison:

- **The scenario baseline, convex hull and box agree with the paper** to
  within 0.7 percentage points. These sets have no tuning: they are fixed by
  the samples.
- **The ellipsoid and Wasserstein sets depend on calibration choices the paper
  does not fully specify** (the POET covariance tuning and the Wasserstein
  radius). Ours come out more conservative for the ellipsoid and ℓ∞ and less
  conservative for ℓ1 and ℓ2. All of them approach the structural maximum as
  Ē grows, as in the paper.
- **A Wasserstein certificate is a CVaR bound.** With N = 1,440 and ε = 0.01
  it bounds the average error over the worst 1% of the distribution, not
  every individual sample, so single training samples can exceed Ē
  (by up to 1.9 Ē in this sweep).

**AC validation.** On the same feeder (convex hull, Ē = 0.001, 48 loadings)
the largest actual AC error is 0.96 Ē, against 0.92 Ē for the linear model,
and 0.07 Ē after the linear lift (`scripts/opti_kron_ac_validation.jl`).

## Differences from the paper

- **Linear model.** Ybus-based sensitivities instead of phase-coupled
  LinDistFlow; identical for single-phase radial feeders, and more general
  otherwise.
- **Clusters do not cross transformers,** except that the slack may represent
  buses within H hops across one (its voltage is fixed). This reproduces the
  paper's candidate count.
- **Meshed networks** use the breadth-first spanning tree from the source for
  hops, paths and radiality; the sensitivities come from the meshed Ybus.
- **Ellipsoid.** POET covariance with an eigenvalue-ratio factor choice
  (at most five factors) and soft thresholding; the paper does not state its
  tuning.
- **Wasserstein radius.** The paper calibrates ρ/ε from distances of the
  training samples to the d = 0 part of 𝒰_W, which is zero for every training
  sample whenever 1/(Nε) ≥ 1. BMOPFTools uses leave-one-out distances to the
  hull of the nearest other samples instead (`radius=:hull`).
- **Only Algorithm 1** is implemented. Passing all samples as `initial` with
  the convex hull reproduces the direct model.
- **Screening test 2** covers the box and the convex hull only.

## References

1. O. Mokhtari, J. Bagrow, M. R. Almassalkhi, S. Chevalier, "Robust optimal
   network reduction for distribution systems," arXiv:2611.21313, 2026.
2. M. E. Baran, F. F. Wu, "Network reconfiguration in distribution systems for
   loss reduction and load balancing," *IEEE Trans. Power Del.* 4(2), 1989.
3. O. Mokhtari, S. Chevalier, M. Almassalkhi, "Structure-preserving optimal
   Kron-based reduction of radial distribution networks," *IEEE Trans. Power
   Syst.*, 2026.
4. F. Dörfler, F. Bullo, "Kron reduction of graphs with applications to
   electrical networks," *IEEE Trans. Circuits Syst. I* 60(1):150–163, 2013.
5. J. Fan, Y. Liao, M. Mincheva, "Large covariance estimation by thresholding
   principal orthogonal complements," *J. R. Stat. Soc. B* 75(4), 2013.
