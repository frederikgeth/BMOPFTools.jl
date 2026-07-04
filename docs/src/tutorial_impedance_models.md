# [Line impedance models: fidelity, symmetry, and OPF decisions](@id impedance-models)

*Why the impedance model you choose changes the **symmetry** of the problem —
and what that does, and does not, mean for the feasibility of an operating
point, the decision an OPF makes, and how well-posed the optimization is.*

This tutorial makes a four-step argument, and is deliberately careful about how
far each step is supported by evidence — including evidence generated in this
repository, which does not always flatter the strong version of the claim.

1. **More granularity and better data ⇒ more realism.** A geometry- or
   measurement-derived four-wire impedance carries per-conductor self and mutual
   terms, the neutral, and the earth return that a sequence/balanced/transposed
   model averages away. *Well established.*
2. **More realism ⇒ less symmetry ⇒ *natural* symmetry breaking.** A balanced,
   transposed line has a *circulant* phase matrix; with balanced operation it is
   a fixed point of the phase-rotation symmetry — identically zero neutral
   current and voltage unbalance. A real untransposed line breaks that symmetry
   *by construction*, with no load asymmetry required. *Well established, and
   demonstrated below as an exact structural difference.*
3. **Less symmetry ⇒ a better-posed optimization.** Symmetry is a *potential*
   source of degeneracy — coincident eigenvalues, orbits of equivalent optima,
   ill-conditioned KKT systems. This is the **weakest** step: the mechanisms are
   textbook, but "physical asymmetry speeds up AC-OPF" is *not* a theorem, and
   the measurements below show **no** solver-effort difference on small
   problems. Treated as motivated analogy, never asserted.
4. **⇒ Better decisions.** At fundamental frequency, on a single line segment,
   the *magnitude* of the decision difference is **small — a percent or two,
   within impedance parameter uncertainty**, and its *direction* is
   context-dependent. What is not small or ambiguous is that the balanced model
   reports unbalance, neutral shift, and inter-sequence coupling as *identically
   zero*, so any decision gated on those quantities is made blind; and the
   per-segment error compounds on real feeders to the 1–4 % that the literature
   measures.

Every code block runs at build time; the numbers are real. **Prerequisites:**
`BMOPFTools`, `JuMP`, `Ipopt`, and the
[line-geometry workflow](tutorial_line_geometry.md). This is the "why it matters"
companion to that "how to" page, and extends the
[impedance fidelity ladder](semantic_modeling.md#impedance-ladder).

## The idealisation and its symmetry

Distribution lines are **not transposed** (Kersting, *Distribution System
Modeling and Analysis*, §4.1.2), so their 3×3 phase matrices have genuinely
distinct self and mutual entries. The balanced/transposed idealisation replaces
those entries with their averages, producing a **circulant** matrix (all self
terms equal, all mutual terms equal). Circulance is the whole story:

- A circulant matrix is diagonalised by the discrete Fourier transform (Gray
  2006). For a reciprocal three-phase line the **Fortescue / symmetrical-
  component transform is that DFT** — `A = (1/√3)[1 1 1; 1 a a²; 1 a² a]`,
  `a = e^{j2π/3}`, is the (conjugate/inverse) 3-point unitary DFT matrix.
- Diagonalising decouples the network into independent zero/positive/negative-
  sequence circuits, and — *for a symmetric (reciprocal) circulant* — the
  positive- and negative-sequence eigenvalues **coincide**, `Z₁ = Z₂ = Z_s −
  Z_m`. That spectral degeneracy, and the resulting decoupled identical per-phase
  subproblems, is the mathematical content of the phase-rotation symmetry.
- An untransposed matrix is **not** circulant, the DFT does not diagonalise it,
  the sequences stay coupled (`Z₀₁, Z₁₂, … ≠ 0`), and the degeneracy is lifted
  (Glover, *Power System Analysis and Design*, §8.4: "In general `Z_S` is not
  diagonal. However, if the line is completely transposed, [it is]").

BMOPFTools already *detects* the idealisation: the provenance analysis flags a
circulant linecode as `I.PROV.SEQ_DERIVED` (exactly balanced ⇒ sequence-derived
or transposed) and a diagonal one as `I.PROV.DECOUPLED_PHASES`. Those are
precisely "this linecode carries the symmetry-inducing idealisation."

We work with one line throughout: a 50 Hz, four-wire LV overhead feeder (a small
AAC phase conductor on a 0.3 m cross-arm at 8 m, an offset neutral — an
untransposed arrangement), and its transposed idealisation built by averaging.
Same conductors, same line; the only difference is the symmetry.

```@example imp
using BMOPFTools, JuMP, Ipopt
mm = 1e-3

net0 = Dict{String,Any}(
    "wire_data" => Dict{String,Any}(
        "ph" => Dict{String,Any}("kind"=>"overhead","r_ac"=>0.9e-3,"radius"=>3.75mm,"gmr"=>2.9mm,"i_max"=>150.0),
        "nt" => Dict{String,Any}("kind"=>"overhead","r_ac"=>0.9e-3,"radius"=>3.75mm,"gmr"=>2.9mm,"i_max"=>150.0)),
    "line_geometry" => Dict{String,Any}("g" => Dict{String,Any}(
        "frequency"=>50.0, "earth_model"=>"modified_carson", "earth_resistivity"=>100.0,
        "conductors" => Any[
            Dict{String,Any}("wire_data"=>"ph","x"=>0.0,"y"=>8.0,"terminal"=>"a"),
            Dict{String,Any}("wire_data"=>"ph","x"=>0.3,"y"=>8.0,"terminal"=>"b"),
            Dict{String,Any}("wire_data"=>"ph","x"=>0.6,"y"=>8.0,"terminal"=>"c"),
            Dict{String,Any}("wire_data"=>"nt","x"=>0.3,"y"=>7.7,"terminal"=>"n")])))
compile_linecode(net0, "g")
lc_geo = net0["linecode"]["g"]
R = BMOPFTools._pattern_keys_to_matrix(lc_geo, "R_series_")
X = BMOPFTools._pattern_keys_to_matrix(lc_geo, "X_series_")

# transposed idealisation: average self, average phase-mutual, average phase-neutral
function transposed_of(R, X)
    avg(M, S) = sum(M[i, j] for (i, j) in S) / length(S)
    d3, m3, pn = [(1,1),(2,2),(3,3)], [(1,2),(1,3),(2,3)], [(1,4),(2,4),(3,4)]
    sR, sX = avg(R, d3), avg(X, d3); mR, mX = avg(R, m3), avg(X, m3); pR, pX = avg(R, pn), avg(X, pn)
    lc = Dict{String,Any}()
    for i in 1:4, j in 1:4
        lc["R_series_$(i)_$(j)"] = i==j ? (i<=3 ? sR : R[4,4]) : (i<=3 && j<=3 ? mR : pR)
        lc["X_series_$(i)_$(j)"] = i==j ? (i<=3 ? sX : X[4,4]) : (i<=3 && j<=3 ? mX : pX)
    end
    lc
end
lc_bal = transposed_of(R, X)

# the untransposed asymmetry lives in the phase-mutual reactances (Ω/km):
(X_ab = round(X[1,2]*1e3, digits=4), X_ac = round(X[1,3]*1e3, digits=4), X_bc = round(X[2,3]*1e3, digits=4))
```

The outer phase pair (a–c) is more widely spaced than the adjacent pairs, so its
mutual reactance is genuinely smaller — the physical asymmetry a transposed
model erases.

## Step 2, demonstrated: the physics breaks the symmetry, exactly

Solve the **same perfectly balanced load** on each model, with the load-bus
neutral floating (grounded only at the source — the common European/Australian
four-wire configuration):

```@example imp
function feeder(lc; p_nom, len)
    Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}("terminal_names"=>["a","b","c","n"], "perfectly_grounded_terminals"=>["n"]),
            "b1"  => Dict{String,Any}("terminal_names"=>["a","b","c","n"])),
        "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}("bus"=>"src","terminal_map"=>["a","b","c"],
            "v_magnitude"=>[230.0,230.0,230.0], "v_angle"=>[0.0,-2.0944,2.0944])),
        "linecode" => Dict{String,Any}("lc"=>lc),
        "line" => Dict{String,Any}("l1" => Dict{String,Any}("bus_from"=>"src","bus_to"=>"b1",
            "terminal_map_from"=>["a","b","c","n"], "terminal_map_to"=>["a","b","c","n"],
            "linecode"=>"lc", "length"=>len)),
        "load" => Dict{String,Any}("ld" => Dict{String,Any}("bus"=>"b1","terminal_map"=>["a","b","c","n"],
            "configuration"=>"WYE", "p_nom"=>p_nom, "q_nom"=>0.2 .* p_nom)))
end

# VUF from phase-to-ground phasors (zero-sequence-blind, so a floating neutral is fine)
function vuf(r)
    b = r["bus"]["b1"]; a = exp(im*2pi/3)
    V = [b[t]["vm"]*exp(im*b[t]["va"]) for t in ("a","b","c")]
    Vp = (V[1] + a*V[2] + a^2*V[3])/3
    Vn = (V[1] + a^2*V[2] + a*V[3])/3
    abs(Vn)/abs(Vp)*100
end

rb = solve_pf(feeder(lc_bal; p_nom=[8e3,8e3,8e3], len=300.0))
rg = solve_pf(feeder(lc_geo; p_nom=[8e3,8e3,8e3], len=300.0))
(transposed_VUF_pct = round(vuf(rb), digits=4),
 transposed_Vn_V    = round(rb["bus"]["b1"]["n"]["vm"], digits=3),
 geometry_VUF_pct   = round(vuf(rg), digits=4),
 geometry_Vn_V      = round(rg["bus"]["b1"]["n"]["vm"], digits=3))
```

The transposed model returns **numerically zero** voltage unbalance and neutral
shift — the residual (`≈ 4×10⁻⁴ %`) is solver tolerance; in exact arithmetic it
is zero, because a balanced load on a circulant matrix is a fixed point of the
phase-rotation symmetry (the power flow's determinate high-voltage solution is
that symmetric point). The **same balanced load** on the real geometry produces
a VUF two to three orders of magnitude larger and a fraction-of-a-volt
neutral-point shift. No load asymmetry was needed; the untransposed geometry
*generates* the unbalance on its own — Survilo (2014) computes exactly this
effect, of the order of a couple of percent negative sequence, for an
untransposed line under balanced load. This is step 2 as an **exact structural
fact**, independent of any parameter value: the idealisation manufactures a
symmetry the real line does not have.

## Step 4, demonstrated — and its honest magnitude

Put a single-phase rooftop PV cluster on phase a of a long rural LV feeder and
ask each model for the **hosting capacity**: the maximum export before a 1.10 pu
voltage limit binds. The PV carries a negative cost, so the OPF maximises its
active injection `pg` (positive = injection into phase a), and the exported
magnitude is that `pg`.

```@example imp
function lv_opf(lc; len=700.0)
    net = feeder(lc; p_nom=[2.5e3,2.5e3,2.5e3], len=len)
    net["bus"]["b1"]["v_min"] = [0.90*230, 0.90*230, 0.90*230]
    net["bus"]["b1"]["v_max"] = [1.10*230, 1.10*230, 1.10*230]
    net["generator"] = Dict{String,Any}("pv" => Dict{String,Any}("bus"=>"b1","terminal_map"=>["a","n"],
        "configuration"=>"SINGLE_PHASE", "p_min"=>[0.0], "p_max"=>[25e3],
        "q_min"=>[0.0], "q_max"=>[0.0], "cost"=>[-1.0]))   # negative cost ⇒ reward export
    net
end
hosting(lc) = sum(solve_opf(lv_opf(lc))["generator"]["pv"]["a"]["pg"]) / 1e3   # kW injected on phase a

E_bal = hosting(lc_bal)
E_geo = hosting(lc_geo)
(transposed_kW = round(E_bal, digits=2),
 geometry_kW   = round(E_geo, digits=2),
 difference_pct = round((E_bal - E_geo)/E_geo*100, digits=1))
```

The two models disagree — but by only about a percent, and note the **sign**:
here the transposed model authorises *less* than the true untransposed feeder
can host (its averaged mutual reactance over-predicts the phase-a voltage rise).
So the balanced decision is *conservative*, not dangerously optimistic. That
direction is not universal — Antić et al. (2024) find phase-modelling
assumptions swing hosting capacity in either direction by up to tens of percent
once optimal single-phase placement is in play; and Claeys, Geth & Deconinck
(PSCC 2022), across 128 real LV feeders, found Kron-reduced/balanced dispatch
re-evaluated on the true four-wire network **violates** the phase-to-neutral
bound by 1–4 %. The single-segment, fundamental-frequency gap here is at the
small end of that range.

**Be honest about what this magnitude means.** A one-percent gap does **not**
clear the noise floor of the impedance data itself: conductor manufacturing
tolerances alone permit ~3 % impedance variation, and temperature adds ~4 % per
10 °C (Urquhart & Thomson 2015). At fundamental frequency, on one segment, the
fidelity gap is *within parameter uncertainty* — a referee is right to ask
whether it is distinguishable from noise, and for the headline number the answer
is often no. Three things nonetheless make the higher-fidelity model the right
one:

1. **Structural blindness.** The transposed model computed unbalance and neutral
   shift as *identically zero* under balanced operation (previous section). Any
   operational limit on VUF, neutral-earth voltage, or negative-sequence current
   is invisible to it — not mis-estimated by 1 %, but absent. (Here the
   single-phase injection is itself unbalanced, so *both* four-wire models see a
   large neutral rise — of order 30 V on this deliberately stressed feeder, a
   safety concern that a three-wire *Kron-reduced* model would report as zero
   entirely; that is the four-wire-vs-Kron gap, quantified by Claeys, Geth &
   Deconinck.)
2. **Aggregation.** The per-segment error is small but *systematic*, not random;
   across a feeder of many untransposed segments and single-phase laterals it
   accumulates to the measured 1–4 %.
3. **Frequency.** The gap grows sharply with frequency — Urquhart & Thomson
   report 16–33 % impedance differences at 450 Hz. This engine is
   fundamental-frequency (constant-`r_ac` modified Carson), but only a geometry
   *retains the physical data* a frequency-dependent method would need; a frozen
   50 Hz matrix cannot be re-derived at harmonics at all (see
   [Where the fidelity actually bites](#Where-the-fidelity-actually-bites)).

## Step 3: symmetry, degeneracy, and the algorithm — carefully

It is tempting to argue that because symmetry causes degeneracy, and degeneracy
hurts solvers, the asymmetric model must solve better. That argument conflates
three distinct objects, and the evidence does not support the strong form.

- **Spectral degeneracy of the impedance** (`Z₁ = Z₂` for a symmetric circulant)
  is a property of the *matrix*. It does not, by itself, make the *optimization*
  degenerate.
- **Multiplicity of optima** requires the symmetry to act on *decision variables
  with a nontrivial orbit* — genuinely interchangeable resources. A balanced load
  (or a single-phase PV) on a symmetric network has a **unique** symmetric (or
  determinate) solution; there is no orbit, so nothing for the symmetry to make
  non-unique. Consistent with that, the barrier-iteration counts are identical
  whether the impedance is transposed or geometric, balanced load or unbalanced:

```@example imp
const MOI = JuMP.MOI
function barrier_iterations(lc; p_nom)
    mref = Ref{Any}(nothing)
    solve_opf(feeder(lc; p_nom=p_nom, len=300.0); model_hook! = ctx -> (mref[] = ctx.model))
    Int(MOI.get(mref[], MOI.BarrierIterations()))
end
(transposed_balanced = barrier_iterations(lc_bal; p_nom=[8e3,8e3,8e3]),
 geometry_balanced   = barrier_iterations(lc_geo; p_nom=[8e3,8e3,8e3]),
 geometry_unbalanced = barrier_iterations(lc_geo; p_nom=[14e3,5e3,3e3]))
```

  There is **no measured speed-up**, and none should be expected here: the
  solution is unique in every case, and Ipopt's own regularization (it adds
  `δ_w·I` to the Hessian and `−δ_c·I` to the constraint block — a
  Tikhonov/Levenberg–Marquardt perturbation; Wächter & Biegler 2006) absorbs any
  ill-conditioning that a near-symmetric point would create.

- **Where symmetry genuinely produces multiplicity** is when it acts on
  interchangeable *decisions*: e.g. identical-cost single-phase resources on
  symmetric phases, whose optimal dispatch split is then a continuum. That is a
  real degeneracy — and BMOPFTools already flags one instance of it, identical
  generator cost vectors, as a dispatch-degeneracy finding. Note it is *cost*
  symmetry there; asymmetric impedance breaks the *network* side of such
  symmetries, giving each phase a distinct sensitivity and a unique optimal
  split. This is the defensible version of "asymmetry helps": it removes a source
  of *non-uniqueness*, not (measurably here) a source of *iterations*.

The honest summary of step 3: high-fidelity asymmetry is best understood as a
**free, physically meaningful regulariser** — it plays the role that a solver's
`δ_w·I` and a modeller's symmetry-breaking constraints (Liberti 2012; Margot
2010) play artificially. But those results are from adjacent domains (continuous
KKT regularization; discrete branch-and-bound), so the transfer to AC-OPF is by
analogy, not theorem. The nearest in-domain precedent, Lavaei & Low (2012),
restores their zero-duality-gap *sufficient condition* by adding a tiny
resistance to lossless transformers — but what that repairs is **connectivity of
the resistive graph `Re{Y}`**, not a phase symmetry; cite it for the *idea* that
a small structural perturbation can restore a well-posedness guarantee, not as a
symmetry result. And regardless of symmetry, AC-OPF remains non-convex with
genuine local optima from the nonlinear power-flow constraints (Bukhsh et al.
2013; Molzahn 2017) — breaking the impedance symmetry removes one avoidable
source of degeneracy; it does not convexify the problem.

## Where the fidelity actually bites

Putting the honest pieces together, the case for high-fidelity impedance is
**not** "the fundamental-frequency numbers are far off" — on a single segment
they differ by about as much as the data is uncertain. The case is:

- **Structure**: unbalance, neutral shift, and coupled sequences are *entirely
  absent* from a balanced model, so any decision or limit involving them is made
  blind — a qualitative gap, not a 1 % one.
- **The neutral**: retaining it explicitly (four-wire, not Kron-reduced) is where
  the largest, best-quantified errors live — 1–4 % voltage-limit violations on
  real feeders (Claeys, Geth & Deconinck 2022), because the neutral is grounded
  only at the transformer in most LV networks.
- **Harmonics and estimation**: the fidelity gap grows sharply with frequency
  (Urquhart & Thomson 2015) and materially changes state-estimation and
  impedance-identification outcomes. This engine does not yet compute harmonic
  impedances, but only geometry — not a frozen matrix — preserves the data a
  future frequency-dependent method (or an external tool) would need.

## Practical guidance

- **Prefer geometry** ([fidelity ladder](semantic_modeling.md#impedance-ladder)):
  its realisability is checkable directly, it recompiles at other frequencies,
  and it keeps the provenance link the analysis layer cross-checks.
- **Watch for `I.PROV.SEQ_DERIVED` / `I.PROV.DECOUPLED_PHASES`**: they mark a
  linecode carrying the balanced/transposed idealisation — fine if intended, a
  red flag if a real untransposed feeder was flattened into it.
- **Keep the neutral explicit and use the IVR solver** (both defaults here). For
  four-wire networks the power–voltage (ACR) formulation admits non-physical
  multiple solutions — equivalent to spuriously grounding the neutral — and
  failed to converge within 500 iterations for 35 % of 128 instances, whereas the
  current–voltage (IVR) formulation BMOPFTools uses is robust (Claeys, Geth &
  Deconinck 2022). *This* is a real, in-domain conditioning result — about
  formulation, not impedance symmetry.
- **Do not oversell the fundamental-frequency magnitude.** State the parameter-
  uncertainty caveat, and reach for geometry because of structure, the neutral,
  and frequency-extensibility — not a headline number.

## References

- W. H. Kersting, *Distribution System Modeling and Analysis*, CRC Press — §4.1 (untransposed lines, Carson, Kron reduction, sequence impedances).
- W. H. Kersting & R. K. Green, "The application of Carson's equation to the steady-state analysis of distribution feeders," *IEEE PES PSCE*, 2011, DOI 10.1109/PSCE.2011.5772579.
- J. D. Glover, M. S. Sarma, T. Overbye, *Power System Analysis and Design*, §8 (transposed ⇒ circulant ⇒ Fortescue-diagonal; "in general `Z_S` is not diagonal").
- R. M. Gray, *Toeplitz and Circulant Matrices: A Review*, Found. Trends Commun. Inf. Theory 2(3):155–239, 2006, DOI 10.1561/0100000006 (circulant ⇔ DFT-diagonalisable).
- A. Ferrero et al., "100 Years of Symmetrical Components," *Energies* 12(3):450, 2019, DOI 10.3390/en12030450.
- J. Survilo, "Impact of Untransposed Power Lines," *Power and Electrical Engineering* 32, 2014, DOI 10.7250/pee.2014.005 (computes ~2.5 % negative sequence from an untransposed line under balanced load; case-specific).
- S. Claeys, F. Geth, G. Deconinck, "Optimal Power Flow in Four-Wire Distribution Networks: Formulation and Benchmarking," *PSCC 2022 / EPSR* 213:108522, arXiv:2204.08126 (Kron/balanced dispatch violates the true four-wire bound by 1–4 %; IVR vs ACR robustness across 128 LV networks).
- F. Geth, R. Heidari, A. Koirala, "Computational Analysis of Impedance Transformations for Four-Wire Power Networks with Sparse Neutral Grounding," *ACM e-Energy 2022*, arXiv:2206.07274, DOI 10.1145/3538637.3538844.
- A. J. Urquhart & M. Thomson, "Series impedance of distribution cables with sector-shaped conductors," *IET GTD* 9(16):2679–2685, 2015, DOI 10.1049/iet-gtd.2015.0546 (manufacturing/temperature uncertainty ~3 %/~4 % per 10 °C; 16–33 % impedance change at 450 Hz).
- T. Antić, A. Keane, T. Capuder, "Impact of Phase Selection on Accuracy and Scalability in Calculating DER Hosting Capacity," 2024, arXiv:2405.20682.
- W. A. Bukhsh, A. Grothey, K. I. M. McKinnon, P. A. Trodden, "Local Solutions of the Optimal Power Flow Problem," *IEEE TPWRS* 28(4):4780–4788, 2013, DOI 10.1109/TPWRS.2013.2274577.
- D. K. Molzahn, "Computing the Feasible Spaces of Optimal Power Flow Problems," *IEEE TPWRS* 32(6):4752–4763, 2017, arXiv:1608.00598.
- J. Lavaei & S. H. Low, "Zero Duality Gap in Optimal Power Flow Problem," *IEEE TPWRS* 27(1):92–107, 2012, DOI 10.1109/TPWRS.2011.2160974 (small transformer resistance restores resistive-graph connectivity and the zero-gap condition).
- L. Liberti, "Reformulations in mathematical programming: automatic symmetry detection and exploitation," *Math. Prog.* 131:273–304, 2012, DOI 10.1007/s10107-010-0351-0.
- F. Margot, "Symmetry in Integer Linear Programming," *50 Years of Integer Programming*, Springer 2010, pp. 647–686.
- A. Wächter & L. T. Biegler, "On the implementation of an interior-point filter line-search algorithm for large-scale nonlinear programming," *Math. Prog.* 106:25–57, 2006, DOI 10.1007/s10107-004-0559-y (`δ_w`/`δ_c` inertia correction as Tikhonov regularization).
- EN 50160: voltage unbalance limit `VUF = |V₂|/|V₁| ≤ 2 %` (up to ~3 % where single-/two-phase loads dominate); IEC 61000-2-2 sets a 2 % compatibility level.
