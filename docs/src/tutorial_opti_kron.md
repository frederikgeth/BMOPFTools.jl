# [Reducing a feeder with a voltage guarantee](@id tutorial-opti-kron)

*How much of this feeder can I remove and still know every voltage to within
a set threshold?*

This tutorial answers that question on a six-bus feeder, small enough to
check every step by hand. It builds up the idea in five steps: the linear
voltage model, the error of one merge, why "it worked on my scenarios" is not
enough, uncertainty sets, and finally a solvable reduced case whose answer is
mapped back to every original bus. The method is robust Opti-KRON [1]; the
[reference page](@ref opti-kron) has the full mathematics.

*Prerequisites: `BMOPFTools`, `JuMP`, `HiGHS` (any MILP solver works; use
Gurobi for real feeders) and `Ipopt`. The complete script is
`examples/opti_kron/tutorial_feeder.jl`, and every number below is its output.*

## 1. The feeder and its linear voltage model

```text
s ── b1 ── b2 ── b3
             └── b4 ── b5        100 m sections, R = 0.04 Ω, X = 0.025 Ω per phase
```

Loads sit at b1, b3, b4 and b5; `s` is an ideal 230 V source. Build the model:

```julia
net = tutorial_feeder()                 # defined in the example script
m = opti_kron_model(net; H=4)           # candidate super-nodes within 4 hops
# OptiKronModel(6 buses, 18 rows, 31 candidate pairs, H=4)
```

`m.K` maps injections (in kW, kvar) to voltage magnitudes (in p.u.):
v = 1 + K u. On this feeder K is exactly LinDistFlow. The sensitivity of b2's
voltage to power injected at b5 is the resistance their two paths to the
source share (two sections, s–b1–b2), divided by U²:

```julia
K_P[b2,b5] = 1.5123e-03 p.u./kW;  2 × 0.04 Ω × 1 kW / (230 V)² = 1.5123e-03
```

A kilowatt at b5 lifts b2's voltage by 0.15%, through the impedance they
share. Keep this picture in mind: K encodes *shared* impedance.

## 2. Training data

Reductions are judged on loadings, so we need some. Here, 24 hourly samples:
a common daily level times independent noise per load.

```julia
U = opti_kron_load_injections(m, net, mult)  # mult[load_id][hour]
# 24 samples, 24 active coordinates, largest |v - 1| = 0.0278 p.u.
```

## 3. The error of one merge, by hand

Merge b3 into b2: b3's load moves to b2, and b2's voltage stands in for b3's.

```julia
sup = collect(1:6); sup[m.busof["b3"]] = m.busof["b2"]
opti_kron_errors(m, sup, U)     # error of every bus-phase, every sample
# b3 → b2: worst error over the samples 4.00e-03 p.u.
```

Moving b3's load to b2 leaves the current through s–b1–b2 unchanged, so the
reduced voltage ṽ_b2 equals b2's original voltage (in the linear model). What
is lost is the drop across the b2–b3 section, caused by b3's own load
current. The error is ṽ_b2 − v_b3 = cᵀu, a *linear* function of the loading.
That linearity is what makes everything below tractable.

## 4. Why a few scenarios are not enough

Choose a threshold Ē = 0.008 p.u. (deliberately loose, so that six buses can
cluster) and ask for the fewest super-nodes. First the classical way: guarantee
the bound only on the two most extreme training samples.

```julia
tot = vec(sum(U, dims=1))
scen = U[:, [argmax(tot), argmin(tot)]]
res = opti_kron_reduction(m, OptiKronHull(scen), 8e-3; optimizer=HiGHS.Optimizer)
# scenario  super-nodes ["s", "b1", "b2"]       worst sample error 1.26 Ē
```

Three buses suffice for those two loadings, but on the other 22 samples the
error reaches 1.26 Ē. The bound holds on the scenarios and fails on other,
less extreme loadings: the worst case depends on *how* the load is
distributed, not only on how much there is.

Robust Opti-KRON instead guarantees the bound on an **uncertainty set** built
from all samples:

```julia
# hull      super-nodes ["s", "b1", "b2", "b5"] worst sample error 0.76 Ē
# box       super-nodes ["s", "b1", "b2", "b5"] worst sample error 0.76 Ē
# ellipsoid super-nodes ["s", "b1", "b2", "b4"] worst sample error 0.50 Ē
```

One more super-node buys a certificate: the bound holds for every loading in
the set, not just the ones you tried. The sets differ in how far they trust
the data:

- the **convex hull** covers every mixture of the samples;
- the **box** lets each injection vary independently within its sampled range;
- the **ellipsoid** follows the samples' covariance, but extends past the
  sampled range in directions of real variation;
- the **Wasserstein** set covers distributions close to the empirical one.

Wider sets can need more super-nodes; here all three keep four.

## 5. A solvable reduced case

The assignment is only a decision. [`kron_reduce_buses`](@ref) turns it into a
BMOPF case: devices move to their super-nodes, and the eliminated buses,
which now carry no injection, are removed by exact Kron reduction.

```julia
res = opti_kron_reduction(m, OptiKronHull(U), 8e-3; optimizer=HiGHS.Optimizer,
                          keep=opti_kron_required_buses(net))
red = kron_reduce_buses(net, m, res; Ebar=8e-3)
# reduced buses: ["b1", "b2", "b5", "s"]
# equivalent lines: ["kron_eq:b2:b5"]
```

b3 and b4 are gone. The two sections b2–b4–b5 became one equivalent line,
and the loads of b3 and b4 now sit at b2. With `Ebar`, the voltage limits of
b2 are tightened so that b3 and b4 stay inside theirs. Solve both cases and
compare:

```julia
pf_full = solve_pf(net; optimizer=ipopt)
pf_red  = solve_pf(red; optimizer=ipopt)
lifted  = lift_solution(net, red, pf_red; model=m)
# b3 (→ b2): full 225.283 V, super-node 225.886 V, lifted 225.310 V
# b4 (→ b2): full 224.689 V, super-node 225.886 V, lifted 224.734 V
```

The super-node voltage is the certified estimate: 0.6 V and 1.2 V off, within
Ē = 1.84 V. [`lift_solution`](@ref) does better after the fact. Once the
reduced case is solved, the loading u is known, so the error cᵀu can be
subtracted: the lifted voltages are within 0.05 V.

## 6. Verify, don't trust

The certificate is for the linear model and for loadings in the set. Before
relying on a reduced case:

- check `res.status == :optimal` (certified and minimal) or `:feasible`
  (certified; the final master hit its time limit);
- leave a margin on Ē for the linear-versus-AC gap; in the AC comparisons on
  [Network reduction](@ref network-reduction), Opti-KRON alone reached up to
  1.04 Ē, and 1.44 Ē when a neutral reduction preceded it;
- for important studies, run an AC power flow on the original network at the
  reduced solution's set-points, as in
  [Simplifying a network](@ref tutorial-simplify).

## Where next

- [Reducing a four-wire feeder, step by step](@ref tutorial-network-reduction):
  the full workflow (neutral Kron, simplification, Opti-KRON, verification) on
  a realistic feeder.
- [Network reduction](@ref network-reduction): how Opti-KRON compares with
  [`simplify_network`](@ref) and [`kron_reduce_neutrals`](@ref) on real
  feeders, and how to combine them.
- [Error-bounded bus reduction](@ref opti-kron): the mathematics, the
  guarantees, and how the implementation differs from the paper.

[1] O. Mokhtari, J. Bagrow, M. R. Almassalkhi, S. Chevalier, "Robust optimal
network reduction for distribution systems," arXiv:2611.21313, 2026.
