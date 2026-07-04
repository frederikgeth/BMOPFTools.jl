# [Line impedance models: fidelity, symmetry, and OPF decisions](@id impedance-models)

*Why the impedance model you choose changes not just the numbers, but the
symmetry of the problem — and therefore the feasibility of an operating point,
the decision an OPF makes, and how well-posed the optimization is.*

This tutorial makes one argument, in four steps:

1. **More granularity and better data ⇒ more realism.** A geometry- or
   measurement-derived four-wire impedance captures per-conductor self and
   mutual terms, the neutral, and the earth return that a
   sequence/balanced/transposed model averages away.
2. **More realism ⇒ less symmetry ⇒ *natural* symmetry breaking.** A balanced,
   transposed line has a *circulant* impedance matrix; with balanced load it is
   a fixed point of the phase-rotation symmetry — zero neutral current, zero
   voltage unbalance, three identical phases. A real untransposed line breaks
   that symmetry *by construction*, with no load asymmetry required.
3. **Less symmetry ⇒ a better-posed optimization.** Symmetry is a source of
   degeneracy: coincident eigenvalues, a continuum/permutation of equivalent
   optima, and a rank-deficient KKT system that interior-point solvers must
   regularize. Physical asymmetry removes that source — it is a *free*
   regularizer, the same role a solver's own perturbation plays artificially.
4. **⇒ Better, feasible decisions.** A balanced model that reports zero
   unbalance also reports headroom that does not exist; the operating point it
   authorizes can violate a voltage, unbalance, or neutral limit on the true
   network.

Steps 1, 2, and 4 are well-established. Step 3 is the subtle one — the
*mechanism* (degeneracy → ill-conditioned KKT) is textbook, but "asymmetry
speeds up AC-OPF" is **not** a theorem, so below it is demonstrated and framed
carefully, never asserted. Every code block runs at build time; the numbers are
real.

**Prerequisites:** `BMOPFTools`, `JuMP`, `Ipopt`, and the
[line-geometry workflow](tutorial_line_geometry.md). This page is the "why it
matters" companion to that "how to" page, and it extends the
[impedance fidelity ladder](semantic_modeling.md#impedance-ladder).

## The three representations, and what symmetry each admits

A line's impedance can be recorded at three fidelities (the
[fidelity ladder](semantic_modeling.md#impedance-ladder)): a **geometry**
compiled to a linecode, a **per-length matrix** (linecode), or **inline totals**
on the line. Orthogonal to fidelity is a modelling *assumption* that recurs at
every level — is the 3×3 phase block **balanced/transposed** (all self terms
equal, all mutual terms equal: a circulant matrix) or **distinct** (a real
untransposed line)?

The distinction is not cosmetic. Distribution lines are **not transposed**
(Kersting, *Distribution System Modeling and Analysis*, §4.1.2), so their phase
matrices are genuinely non-circulant. A circulant 3×3 is diagonalised by the
**Fortescue / symmetrical-component transform — which is exactly the 3-point
discrete Fourier transform** (Gray 2006; the Fortescue matrix `A = (1/√3)[1 1 1;
1 a a²; 1 a² a]`, `a = e^{j2π/3}`, is the unitary DFT matrix). Diagonalising
decouples the network into independent zero/positive/negative-sequence circuits
whose positive-sequence eigenvalue is *doubly degenerate* (`Z₁ = Z₂ = Z_s −
Z_m`). That degeneracy — coincident eigenvalues, decoupled identical per-phase
subproblems — **is** the phase-rotation symmetry. An untransposed matrix is not
circulant, the DFT does not diagonalise it, the sequences stay coupled
(`Z₀₁, Z₁₂, … ≠ 0`), and the degeneracy is lifted (Glover, *Power System
Analysis and Design*, §8.4: "In general `Z_S` is not diagonal. However, if the
line is completely transposed, [it is]").

BMOPFTools already *detects* the idealisation: the provenance analysis flags a
circulant linecode as `I.PROV.SEQ_DERIVED` (exactly balanced ⇒ sequence-derived
or transposed) and a diagonal one as `I.PROV.DECOUPLED_PHASES`. Those findings
are, precisely, "this linecode carries the symmetry-inducing idealisation."

## Step 2, demonstrated: the physics breaks the symmetry for free

We compile the real IEEE-13 config-601 four-wire geometry, then build its
*transposed idealisation* by replacing the self and mutual blocks with their
averages — the matrix a sequence model implicitly uses. Same conductors, same
line; the only difference is the symmetry.

```@example imp
using BMOPFTools, JuMP, Ipopt
ft = 0.3048; inch = 0.0254; mi = 1609.344

net0 = Dict{String,Any}(
    "wire_data" => Dict{String,Any}(
        "p" => Dict{String,Any}("kind"=>"overhead","r_ac"=>0.1859/mi,"gmr"=>0.0313ft,"radius"=>0.927/2*inch,"i_max"=>730.0),
        "n" => Dict{String,Any}("kind"=>"overhead","r_ac"=>0.592/mi,"gmr"=>0.00814ft,"radius"=>0.563/2*inch,"i_max"=>340.0)),
    "line_geometry" => Dict{String,Any}("g" => Dict{String,Any}(
        "frequency"=>60.0, "earth_model"=>"modified_carson", "earth_resistivity"=>100.0,
        "conductors" => Any[
            Dict{String,Any}("wire_data"=>"p","x"=>2.5ft,"y"=>29ft,"terminal"=>"a"),
            Dict{String,Any}("wire_data"=>"p","x"=>0.0, "y"=>29ft,"terminal"=>"b"),
            Dict{String,Any}("wire_data"=>"p","x"=>7.0ft,"y"=>29ft,"terminal"=>"c"),
            Dict{String,Any}("wire_data"=>"n","x"=>4.0ft,"y"=>25ft,"terminal"=>"n")])))
compile_linecode(net0, "g")
lc_geo = net0["linecode"]["g"]
R = BMOPFTools._pattern_keys_to_matrix(lc_geo, "R_series_")
X = BMOPFTools._pattern_keys_to_matrix(lc_geo, "X_series_")

# transposed idealisation: average self, average phase-mutual, average phase-neutral
function transposed_of(R, X)
    avg(M, S) = sum(M[i, j] for (i, j) in S) / length(S)
    diag3 = [(1, 1), (2, 2), (3, 3)]
    mut3  = [(1, 2), (1, 3), (2, 3)]
    pn    = [(1, 4), (2, 4), (3, 4)]
    sR, sX = avg(R, diag3), avg(X, diag3)
    mR, mX = avg(R, mut3),  avg(X, mut3)
    pR, pX = avg(R, pn),    avg(X, pn)
    lc = Dict{String,Any}()
    for i in 1:4, j in 1:4
        lc["R_series_$(i)_$(j)"] = i==j ? (i<=3 ? sR : R[4,4]) : (i<=3 && j<=3 ? mR : pR)
        lc["X_series_$(i)_$(j)"] = i==j ? (i<=3 ? sX : X[4,4]) : (i<=3 && j<=3 ? mX : pX)
    end
    lc
end
lc_bal = transposed_of(R, X)
nothing # hide
```

Now solve the **same balanced load** on each, with the load-bus neutral floating
(grounded only at the source — the common European/Australian LV configuration):

```@example imp
function feeder(lc; p_nom)
    Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}("terminal_names"=>["a","b","c","n"], "perfectly_grounded_terminals"=>["n"]),
            "b1"  => Dict{String,Any}("terminal_names"=>["a","b","c","n"])),
        "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}("bus"=>"src","terminal_map"=>["a","b","c"],
            "v_magnitude"=>[2401.8,2401.8,2401.8], "v_angle"=>[0.0,-2.0944,2.0944])),
        "linecode" => Dict{String,Any}("lc"=>lc),
        "line" => Dict{String,Any}("l1" => Dict{String,Any}("bus_from"=>"src","bus_to"=>"b1",
            "terminal_map_from"=>["a","b","c","n"], "terminal_map_to"=>["a","b","c","n"],
            "linecode"=>"lc", "length"=>1200.0)),
        "load" => Dict{String,Any}("ld" => Dict{String,Any}("bus"=>"b1","terminal_map"=>["a","b","c","n"],
            "configuration"=>"WYE", "p_nom"=>p_nom, "q_nom"=>0.3 .* p_nom)))
end

function vuf(r)
    b = r["bus"]["b1"]; a = exp(im*2pi/3)
    V = [b[t]["vm"]*exp(im*b[t]["va"]) for t in ("a","b","c")]
    Vp = (V[1] + a*V[2] + a^2*V[3])/3
    Vn = (V[1] + a^2*V[2] + a*V[3])/3
    abs(Vn)/abs(Vp)*100
end

pbal = [100e3, 100e3, 100e3]   # perfectly balanced load
rb = solve_pf(feeder(lc_bal; p_nom=pbal))
rg = solve_pf(feeder(lc_geo; p_nom=pbal))
(transposed_VUF = round(vuf(rb), digits=4),
 transposed_Vn  = round(rb["bus"]["b1"]["n"]["vm"], digits=3),
 geometry_VUF   = round(vuf(rg), digits=4),
 geometry_Vn    = round(rg["bus"]["b1"]["n"]["vm"], digits=3))
```

The transposed model returns **numerically zero** voltage unbalance and neutral
shift (the residual `≈0.0003 %` is solver tolerance; in exact arithmetic it is
zero by symmetry) — the three phases are a fixed point of the phase-rotation
symmetry. The **same balanced load** on the real geometry produces a VUF two to
three orders of magnitude larger and a neutral-point shift approaching a volt.
No load asymmetry was needed;
the untransposed geometry generated the unbalance on its own (Survilo 2014
measures exactly this: an untransposed line generates ~2.5 % negative sequence
under balanced load). This is step 2, exactly: realism breaks the symmetry that
the idealisation manufactures.

## Step 4, demonstrated: the decision changes at the feasibility boundary

The symmetry a balanced model imposes is not free — it hides constraints. Put a
single-phase rooftop PV on phase a of a long LV feeder and ask each model for the
**hosting capacity**: the maximum export before a 1.10 pu voltage limit binds.

```@example imp
Vph = 230.0; vmax = 1.10Vph
function lv_feeder(lc)
    net = Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}("terminal_names"=>["a","b","c","n"], "perfectly_grounded_terminals"=>["n"]),
            "b1"  => Dict{String,Any}("terminal_names"=>["a","b","c","n"],
                "v_min"=>[0.9Vph,0.9Vph,0.9Vph], "v_max"=>[vmax,vmax,vmax])),
        "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}("bus"=>"src","terminal_map"=>["a","b","c"],
            "v_magnitude"=>[Vph,Vph,Vph], "v_angle"=>[0.0,-2.0944,2.0944])),
        "linecode" => Dict{String,Any}("lc"=>lc),
        "line" => Dict{String,Any}("l1" => Dict{String,Any}("bus_from"=>"src","bus_to"=>"b1",
            "terminal_map_from"=>["a","b","c","n"], "terminal_map_to"=>["a","b","c","n"],
            "linecode"=>"lc", "length"=>4000.0)),
        "load" => Dict{String,Any}("ld" => Dict{String,Any}("bus"=>"b1","terminal_map"=>["a","b","c","n"],
            "configuration"=>"WYE", "p_nom"=>[3e3,3e3,3e3], "q_nom"=>[1e3,1e3,1e3])),
        # single-phase PV rewarded to export (negative cost) up to a voltage cap
        "generator" => Dict{String,Any}("pv" => Dict{String,Any}("bus"=>"b1","terminal_map"=>["a","n"],
            "configuration"=>"SINGLE_PHASE", "p_min"=>[0.0], "p_max"=>[100e3],
            "q_min"=>[0.0], "q_max"=>[0.0], "cost"=>[-1.0])))
    net
end
hosting(lc) = abs(sum(solve_opf(lv_feeder(lc))["generator"]["pv"]["a"]["pg"])) / 1e3  # kW

E_bal = hosting(lc_bal)
E_geo = hosting(lc_geo)
(balanced_kW = round(E_bal, digits=2),
 geometry_kW = round(E_geo, digits=2),
 overstatement_pct = round((E_bal - E_geo)/E_geo*100, digits=1))
```

The balanced model authorises a few percent more single-phase PV than the true
untransposed feeder can actually host. It is a modest margin — but it is on the
wrong side: an operator who sized the connection on the balanced model would
over-authorise, and the extra export pushes a voltage the balanced model never
saw. This is the same effect Claeys, Geth & Deconinck
(PSCC 2022) quantified across 128 real LV feeders: dispatch optimised on a
Kron-reduced/balanced model, re-evaluated on the true four-wire network,
**violates the phase-to-neutral voltage bound by 1–4 %**; and Antić et al.
(2024) found phase-modelling assumptions swing hosting capacity by tens of
percent. The direction is context-dependent — a balanced model *overstates*
headroom when it hides voltage-unbalance/neutral limits, but can *understate* it
when it ignores the freedom to place single-phase DER on the least-loaded phase
(Antić et al.) — the point is that the decision is *different*, and only the
higher-fidelity model gets it right.

## Step 3: symmetry, degeneracy, and the algorithm — carefully

Symmetry is a well-known source of numerical trouble
in optimization:

- In interior-point solvers a **rank-deficient or degenerate KKT system is
  singular/ill-conditioned**; Ipopt handles it by adding `δ_w·I` to the Hessian
  block (and `−δ_c·I` to the constraint block) — its *inertia correction*
  (Wächter & Biegler 2006). That is a **Tikhonov/Levenberg–Marquardt
  regularization**: perturb a singular matrix by a small multiple of the
  identity to make it invertible and better-conditioned.
- Symmetry produces **many equivalent optima** (a continuum or permutation
  orbit); in combinatorial optimization this inflates the search because no
  branch can be pruned (Liberti 2012; Margot 2010), and the standard remedy is a
  *symmetry-breaking constraint* or a small perturbation that keeps one
  representative.

The link to impedance is the punchline: **a high-fidelity untransposed
impedance is itself a symmetry-breaking perturbation — a free, physically
meaningful regulariser.** It does for the OPF what the solver's `δ_w·I` and the
modeller's symmetry-breaking constraints do artificially. The closest in-domain
precedent is Lavaei & Low (2012): their zero-duality-gap guarantee for OPF fails
for lossless (zero-resistance) transformers, and is *restored* by adding a tiny
`10⁻⁵` resistance to each — an explicit "break the degenerate structure to
recover a well-posed problem" result. A four-wire model with real, distinct
line impedances supplies that same structure-breaking from the physics, not as a
numerical hack.

Two caveats, both important:

1. **It is not a guaranteed speed-up.** On the small, well-scaled feeders above,
   the symmetric and asymmetric OPFs take the *same* handful of Ipopt
   iterations — the solver's own regularization already absorbs the degeneracy.
   The benefit that is real and robust is **well-posedness and uniqueness** (no
   spurious orbit of symmetric optima; a determinate per-phase decision), not a
   measured iteration count. Do not expect, or claim, a universal performance
   win.
2. **AC-OPF is non-convex regardless.** Its documented local optima and
   disconnected feasible regions (Bukhsh et al. 2013; Molzahn 2017) come from
   *nonlinearity*, not from phase symmetry. Breaking the impedance symmetry
   removes one specific, avoidable source of degeneracy; it does not make the
   problem convex.

There is a genuinely load-bearing conditioning result in this library's
lineage, though it is about *formulation*, not impedance symmetry: for four-wire
networks the power–voltage (ACR) formulation admits non-physical multiple
solutions (equivalent to spuriously grounding the neutral) and failed to
converge within 500 iterations for 35 % of 128 instances, whereas the
current–voltage (IVR) formulation BMOPFTools uses is robust (Claeys, Geth &
Deconinck 2022). Retaining the neutral explicitly *and* choosing IVR is what
keeps the four-wire problem well-posed.

## Practical guidance

- **At fundamental frequency the magnitude differences are modest** — a few
  percent (Kersting & Green 2011 put modified-vs-full Carson under 1 %;
  Urquhart & Thomson 2015 found sector-geometry effects of ~7–14 % on
  reactance; the balanced-vs-untransposed gap is typically a few percent). The
  case for high fidelity is not "the numbers are wildly off" — it is that the
  **structure** (unbalance, neutral shift, the coupled sequences) is *entirely
  absent* from the balanced model, so any decision gated on those quantities is
  made blind.
- **Prefer geometry** ([fidelity ladder](semantic_modeling.md#impedance-ladder)):
  it is the only representation whose realisability is checkable directly, that
  recompiles at other frequencies (harmonic impedance models, where the fidelity
  gap grows to tens of percent — Urquhart & Thomson), and that keeps the
  provenance link the analysis layer cross-checks.
- **Watch for `I.PROV.SEQ_DERIVED` / `I.PROV.DECOUPLED_PHASES`** in the
  provenance report: they mark a linecode that carries the balanced/transposed
  idealisation. That is fine if the idealisation is intended, and a red flag if
  a real untransposed feeder was flattened into it.
- **Keep the neutral explicit and use the IVR solver** (both are defaults here):
  it is what makes the four-wire decision both faithful and well-posed.

## References

- W. H. Kersting, *Distribution System Modeling and Analysis*, CRC Press — §4.1 (untransposed lines, Carson, Kron reduction, sequence impedances).
- W. H. Kersting & R. K. Green, "The application of Carson's equation to the steady-state analysis of distribution feeders," *IEEE PES PSCE*, 2011, DOI 10.1109/PSCE.2011.5772579.
- J. D. Glover, M. S. Sarma, T. Overbye, *Power System Analysis and Design*, §8 (transposed ⇒ circulant ⇒ Fortescue-diagonal; "in general `Z_S` is not diagonal").
- R. M. Gray, *Toeplitz and Circulant Matrices: A Review*, Found. Trends Commun. Inf. Theory 2(3):155–239, 2006, DOI 10.1561/0100000006 (circulant ⇔ DFT-diagonalisable).
- A. Ferrero et al., "100 Years of Symmetrical Components," *Energies* 12(3):450, 2019, DOI 10.3390/en12030450.
- J. Survilo, "Impact of Untransposed Power Lines," *Power and Electrical Engineering* 32, 2014, DOI 10.7250/pee.2014.005 (untransposed line generates 2.54 % negative sequence under balanced load).
- S. Claeys, F. Geth, G. Deconinck, "Optimal Power Flow in Four-Wire Distribution Networks: Formulation and Benchmarking," *PSCC 2022 / EPSR* 213:108522, arXiv:2204.08126 (Kron/balanced dispatch violates the true four-wire bound by 1–4 %; IVR vs ACR robustness across 128 LV networks).
- F. Geth, R. Heidari, A. Koirala, "Computational Analysis of Impedance Transformations for Four-Wire Power Networks with Sparse Neutral Grounding," *ACM e-Energy 2022*, arXiv:2206.07274, DOI 10.1145/3538637.3538844.
- A. J. Urquhart & M. Thomson, "Series impedance of distribution cables with sector-shaped conductors," *IET GTD* 9(16):2679–2685, 2015, DOI 10.1049/iet-gtd.2015.0546.
- T. Antić, A. Keane, T. Capuder, "Impact of Phase Selection on Accuracy and Scalability in Calculating DER Hosting Capacity," 2024, arXiv:2405.20682.
- W. A. Bukhsh, A. Grothey, K. I. M. McKinnon, P. A. Trodden, "Local Solutions of the Optimal Power Flow Problem," *IEEE TPWRS* 28(4):4780–4788, 2013, DOI 10.1109/TPWRS.2013.2274577.
- D. K. Molzahn, "Computing the Feasible Spaces of Optimal Power Flow Problems," *IEEE TPWRS* 32(6):4752–4763, 2017, arXiv:1608.00598.
- J. Lavaei & S. H. Low, "Zero Duality Gap in Optimal Power Flow Problem," *IEEE TPWRS* 27(1):92–107, 2012, DOI 10.1109/TPWRS.2011.2160974 (add small transformer resistance ⇒ restore the guarantee).
- L. Liberti, "Reformulations in mathematical programming: automatic symmetry detection and exploitation," *Math. Prog.* 131:273–304, 2012, DOI 10.1007/s10107-010-0351-0.
- F. Margot, "Symmetry in Integer Linear Programming," *50 Years of Integer Programming*, Springer 2010, pp. 647–686.
- A. Wächter & L. T. Biegler, "On the implementation of an interior-point filter line-search algorithm for large-scale nonlinear programming," *Math. Prog.* 106:25–57, 2006, DOI 10.1007/s10107-004-0559-y (`δ_w`/`δ_c` inertia correction as Tikhonov regularization).
- EN 50160 / IEC 61000-2-2: voltage unbalance limit `VUF = |V₂|/|V₁| ≤ 2 %` (3 % where single-/two-phase loads dominate).
