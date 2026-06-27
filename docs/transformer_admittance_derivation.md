# Nodal admittance export for BMOPF transformers — derivation note

**Status:** implemented in `src/io/to_ybus.jl`; tested in `test/admittance_tests.jl`.
**Goal:** for every transformer subtype we support, export the *textbook nodal
admittance block* — a complex matrix $Y\in\mathbb{C}^{n\times n}$ over the
transformer's terminal nodes such that

$$\mathbf{I} = Y\,\mathbf{V},$$

where $\mathbf V$ are the node voltages and $\mathbf I$ are the currents **into
the transformer terminals** (out of the bus). This is the quantity OpenDSS
exposes as a PD-element `Yprim` (`Export Y` / `DumpYprim`) and what
PowerModelsDistribution assembles internally, so it is the natural artifact for
cross-tool validation.

This note derives $Y$ for the four two-winding subtypes plus the two regulator
subtypes (§4b) and lists the checks that gate correctness before we write the
exporter.

---

## 1. Conventions

| Item | Choice |
|---|---|
| Units | **SI** (siemens, volts, amperes). No per-unit base. |
| Current sign | $\mathbf I$ = current **into** the transformer at each node (out of the bus). Matches OpenDSS `Yprim` and equals $-$(the KCL contribution in `transformer.jl`, which adds $-I^\text{term}$ to the accumulator). |
| Node = | a `(bus, terminal)` pair. |
| Turns ratio | $N = V^\text{ref}_\text{fr}/V^\text{ref}_\text{to}$ (both SI volts; for `center_tap`, $V^\text{ref}_\text{to}$ is the per-leg 120 V rating). |
| Series impedance | $Z_1=R_1+jX_1$ from `r_series_from`/`x_series_from`; $Z_2=R_2+jX_2$ from `r_series_to`/`x_series_to`. |
| No-load shunt | $Y_0=G_0+jB_0$ from `g_no_load`/`b_no_load`, placed phase-to-ground at the **HV** terminals. |

**Reciprocity.** A transformer built from linear impedances and ideal cores is
a reciprocal network, so the exported $Y$ **must be symmetric**,
$Y = Y^{\mathsf T}$ (not Hermitian; $Y\neq Y^\dagger$ in general since the network
is lossy). We use $\|Y-Y^{\mathsf T}\|_\infty < \epsilon$ as a hard correctness gate.

**The construction we use.** We build $Y$ from the textbook *primitive
admittance + connection matrix* form

$$\boxed{\,Y = C^{\mathsf T}\, y_\text{prim}\, C \;+\; Y_0\,\text{(shunt at HV nodes)}\,}$$

where $C$ maps node voltages to per-core winding voltages and $y_\text{prim}$
is the (block-)diagonal primitive admittance of the winding-pairs. This form is
symmetric by construction ($C^{\mathsf T}$ and $C$ ensure $Y = Y^{\mathsf T}$ whenever
$y_\text{prim} = y_\text{prim}^{\mathsf T}$, which it is for any symmetric primitive
impedance). We then *verify* that the IVR constraints in
[`transformer.jl`](../ext/BMOPFOpfExt/transformer.jl) are consistent with it (§7).

> **Julia note.** In Julia, `A'` computes the *conjugate* transpose (adjoint),
> whereas `transpose(A)` computes the plain transpose. For a symmetric nodal
> admittance matrix we need `Y ≈ transpose(Y)`, **not** `Y ≈ Y'`. Confusing the
> two was the source of the apparent non-symmetry found during the derivation checks.

**Finiteness.** $Y$ is finite only for **nonzero leakage impedance**. The ideal
($Z\to 0$) transformer has infinite primitive admittance and a singular nodal
block — OpenDSS always carries a small nonzero leakage, and so must any case we
export.

---

## 2. `single_phase` (wye–wye, Γ-model)

Per phase-pair $k$: HV node $p=(b_\text{fr},t^\text{fr}_k)$, LV node
$q=(b_\text{to},t^\text{to}_k)$. The two windings of the pair are lumped into one
series leakage referred to HV (the Γ model used by the OPF):

$$Z = (R_1 + N^2 R_2) + j(X_1 + N^2 X_2),\qquad y = 1/Z,\qquad Y_0' = Y_0/n_c$$

(the no-load shunt is split equally across the $n_c$ pairs, matching the code).

The $2\times2$ block for pair $k$, from $C^{\mathsf T}y_\text{prim}C$ with
$C=\begin{psmallmatrix}1&-N\end{psmallmatrix}$ (one winding spanning $p$ and $q$
with ratio $1\!:\!N$) plus the HV shunt, is

$$\begin{bmatrix}I_p\\ I_q\end{bmatrix}
=\begin{bmatrix} y+Y_0' & -Ny\\[2pt] -Ny & N^2 y\end{bmatrix}
\begin{bmatrix}V_p\\ V_q\end{bmatrix}.$$

The full block is **block-diagonal** over the $n_c$ phase-pairs. Symmetric ✓
(verified: `‖Y − Yᵀ‖ = 0` analytically). Ideal limit $Z\to0$: entries $\to\infty$
(expected). This block serves as the closed-form oracle for unit tests.

---

## 3. `wye_delta` (Yd) and `delta_wye` (Dy)

### Connection matrix

Take $n_\phi=3$ (general $n_\phi$ analogous). Node ordering:
$[\,w_1,w_2,w_3,w_n,\,d_1,d_2,d_3\,]$ (wye phases, wye neutral, delta nodes).

Each core $k$ couples wye winding voltage $U^w_k=V^w_k-V^w_n$ with delta
winding voltage $U^d_k=V^d_k-V^d_{k+1}$ (cyclic next). The $6\times7$ connection
matrix $C$ (rows = winding voltages, cols = nodes):

$$C=\begin{bmatrix} \mathbf{1}_3 & -\mathbf{1} & 0\\[2pt] 0 & 0 & D\end{bmatrix},
\qquad
D=\begin{bmatrix}1&-1&0\\0&1&-1\\-1&0&1\end{bmatrix}.$$

Top block rows give the wye phase-to-neutral winding voltages; bottom rows
give the delta line-to-line winding voltages. $C^{\mathsf T}$ (the plain transpose,
not the adjoint) then maps winding currents back to node terminal currents.

### Primitive admittance

The effective per-winding turns ratio is

$$n_\text{eff}=\frac{\sqrt3}{N}\ \text{(Yd)},\qquad n_\text{eff}=N\sqrt3\ \text{(Dy)},$$

where $N = V^\text{ref}_\text{fr}/V^\text{ref}_\text{to}$ with both voltages as
phase-to-neutral equivalents (same convention as the OPF, see math-model §3).

Per core, fold both winding leakages into one referred-to-wye series admittance
(Γ, matching the Yd voltage equation structure):

$$y_t = \frac{1}{Z_w + n_\text{eff}^2 Z_d},$$

where $Z_w$ = from-side winding impedance and $Z_d$ = to-side winding impedance
(mapped by `wye_is_from`). The $2\times2$ per-core primitive is

$$y_\text{prim}^{(k)}=y_t\begin{bmatrix}1 & -n_\text{eff}\\ -n_\text{eff} & n_\text{eff}^2\end{bmatrix},$$

symmetric by construction. Stack 3 such blocks block-diagonally with ordering
[wye-winding-1, delta-winding-1, wye-winding-2, delta-winding-2, ...] (reordering
rows/cols of $C$ accordingly).

### Nodal block

$$Y_\text{Yd}=C^{\mathsf T} y_\text{prim} C + Y_0\,\text{(wye phases)}.$$

Numerically verified symmetric ($\|Y-Y^{\mathsf T}\|=0$ to machine precision).
For the common lossless-delta case ($Z_d=0$, $y_t=y_w=1/Z_w$, no shunt) this
evaluates to the explicit symmetric block:

$$Y_\text{Yd}=y_w
\begin{bmatrix}
 \mathbf{1}_3 & -\mathbf{1} & -D\\[4pt]
 -\mathbf{1}^{\mathsf T} & 3 & \mathbf{1}^{\mathsf T}D\\[4pt]
 -D^{\mathsf T} & D^{\mathsf T}\mathbf{1} & D^{\mathsf T}D
\end{bmatrix}.$$

The cross blocks $-y_wD$ (wye↔delta) and $-y_w D^{\mathsf T}$ (delta↔wye) are
transposes of each other, confirming symmetry. The $3$ on the wye neutral is the
zero-sequence admittance path ($\propto y_w$), so a zero from-side impedance
makes the neutral row singular.

**Dy** is identical with from/to swapped, $n_\text{eff}=N\sqrt3$, shunt on delta
phases, and the delta winding voltage convention uses $k_\text{prev}$ (backward
delta), i.e. $D\to D^{\mathsf T}$ in the bottom block of $C$.

---

## 4. `center_tap` (split-phase, coupled-coil)

Five nodes: $p$ (HV-phase), $m$ (HV-neutral), $a$ (LV-leg-1), $g$ (LV-center-tap),
$c$ (LV-leg-2).

This is a genuine **3-winding** unit (1 HV + 2 LV). The two LV half-windings share
the center-tap node $g$ and are **series-aiding**: winding 2 spans $a\to g$ and
winding 3 spans $g\to c$, both dotted at the same end (winding 3 dotted at the
center tap), so $V_a-V_g$ and $V_g-V_c$ carry the *same* sign and a 120-0-120 unit
puts $a$ and $c$ in anti-phase about $g$ ($V_a-V_c\approx 2V_\text{hv}/N$).
The 3-port star reduction below is exact for a 3-winding transformer and
reproduces OpenDSS's own transformer $Y_\text{prim}$ to machine precision.

### 3-port star admittance

Refer all quantities to the LV base. The three winding arms meet at an internal
star node $\star$:

| Arm | Winding impedance (LV-referred) | Terminal |
|---|---|---|
| HV | $Z_1/N^2$ | $(V_p-V_m)/N$ |
| LV-leg-1 | $Z_2$ | $V_a - V_g$ |
| LV-leg-2 | $Z_2$ | $V_g - V_c$ |

The LV-leg-2 arm spans $g\to c$ (winding 3 is dotted at the center tap $g$), giving
it the **same polarity** as LV-leg-1 ($V_a-V_g$). This series-aiding orientation —
not the $V_c-V_g$ span — is what reproduces OpenDSS: the opposite sign would make
the two legs identical instead of series-aiding, spreading them apart under load.

The shunt admittance of each arm referred to LV:
$$y_1=N^2/Z_1,\qquad y_2=1/Z_2.$$

Eliminate the star-node voltage $V_\star$ via KCL at $\star$:

$$Y_\Sigma = y_1+y_2+y_2,\qquad
[Y_\text{3port}]_{ij}=\begin{cases} y_i(Y_\Sigma-y_i)/Y_\Sigma & i=j,\\ -y_iy_j/Y_\Sigma & i\neq j.\end{cases}$$

This $3\times3$ matrix in the winding-terminal ordering [HV-ref, LV-leg1, LV-leg2]
is **symmetric** by inspection.

### Connection matrix and nodal block

Map node voltages $[p,m,a,g,c]$ to the three winding terminal voltages:

$$C=\begin{bmatrix}1/N & -1/N & 0 & 0 & 0\\ 0 & 0 & 1 & -1 & 0\\ 0 & 0 & 0 & 1 & -1\end{bmatrix}.$$

Then

$$Y_\text{CT}=C^{\mathsf T}\,Y_\text{3port}\,C + Y_0\,e_p\,e_p^{\mathsf T},$$

which is symmetric by construction ($C^{\mathsf T}[\text{symmetric}]C$).
**Numerically verified:** $\|Y_\text{CT}-Y_\text{CT}^{\mathsf T}\|=0$ and
power-balance ($\operatorname{Re}[\bar{\mathbf V}^{\mathsf T}\mathbf I] = $ resistive loss)
holds for any voltage vector.

> **OPF correspondence.** The OPF (`_add_center_tap_transformer!`) imposes *this
> same* $Y_\text{CT}$ as nodal current injections, so the two paths cannot drift
> apart (a test asserts it). The leg-2 voltage span is $V_g-V_c$ on both sides, the
> ampere-turn is $N I_s + I_{\ell1} - I_{\ell2}=0$, and the center-tap KCL is
> $I_n + I_{\ell1} + I_{\ell2}=0$. The star arms come from the symmetric short-circuit
> split $X_{1,\text{star}}=(X_{HL}+X_{HT}-X_{LT})/2$,
> $X_{2,\text{star}}=(X_{HL}+X_{LT}-X_{HT})/2$, which `from_dss` recovers from
> PowerIO's `pmd` export (the `bmopf` export drops the LV-side leakage).

---

## 4b. Regulators — `single_phase_autotransformer` and `open_delta_regulator`

Both regulator subtypes replace the nameplate turns ratio $N$ with the
fixed-tap **effective ratio** $n_\text{eff}$ (`tap_ratio` $a$ with
`regulator_type`): $n_\text{eff}=1/a$ (Type B, default) or $a$ (Type A).

**`single_phase_autotransformer`.** Structurally the §2 Γ-model block with
$N:=n_\text{eff}$, but with the shared neutral kept explicit. Nodes
$[t^\text{ph}_\text{fr},\,t^\text{ph}_\text{to},\,t^\text{n}_\text{fr},\,t^\text{n}_\text{to}]$
and one winding spanning phase-to-neutral on each side,
$C=\begin{psmallmatrix}1&-n_\text{eff}&-1&n_\text{eff}\end{psmallmatrix}$
folded as the $2\times2$ core. The reduced phase block (neutrals at 0) is the
familiar $\begin{psmallmatrix}y & -n_\text{eff}y\\ -n_\text{eff}y & n_\text{eff}^2 y\end{psmallmatrix}$,
and every column of the full $4\times4$ sums to zero (current conservation
through the shared neutral). Type A/B differ only through $n_\text{eff}$.

**`open_delta_regulator`.** Two **line-to-line** cores across the phase pairs of
`connection` (`ABBC`/`BCAC`/`CABA`), each
$C_j=\begin{psmallmatrix}1&-1\;(\text{fr }p,q)&\,-n_{\text{eff},j}&n_{\text{eff},j}\;(\text{to }p,q)\end{psmallmatrix}$
with primitive $y_t[\,1\;-n_{\text{eff},j};\,-n_{\text{eff},j}\;n_{\text{eff},j}^2]$,
summed: $Y=\sum_j C_j^{\mathsf T}y_{\text{prim},j}C_j$. This is the device's
natural line-to-line admittance and reproduces **Yan et al. (2018)**, IEEE Trans.
Smart Grid 9(3):2224, Eq. (11) (the "unspecified neutral" matrix) *term-by-term*
in per unit, where the paper's effective ratio $r=1-n_R$ maps to our
$n_\text{eff}$. The shared-phase diagonal carries $2y_t$ (both regulators) and
the from↔to coupling scales as $n_\text{eff}$ and $n_\text{eff}^2$ — the
autotransformer factor, not an isolated-transformer ratio.

The galvanic **straight-through** of the shared phase (the paper's
*common-neutral* model, Eq. 14: $V_\text{shared,fr}=V_\text{shared,to}$) is the
physically-correct connection but is **not** folded into the exported $Y$ — it is
a topological constraint imposed in the OPF (`_add_open_delta_regulator!`). The
paper's Eq. (15) is one particular elimination of the shared node and is *not*
the device primitive; conflating the two would misrepresent the exported
admittance. So the export keeps the Eq. (11) primitive, and the common-neutral
behaviour is validated by power flow rather than by the $Y$ block (see §7).

---

## 5. OPF current-variable convention (informational)

During the derivation it was found that the OPF winding-current variables for
Yd/Dy are **not** the physical terminal currents used in $Y_\text{nodal}$. Specifically,
the OPF variable $I^w_k$ (wye winding) satisfies the voltage equation

$$V^d_k - V^d_{k+1} = n_\text{eff}(V^w_k-V^w_n) - Z_w I^w_k,$$

which — compared to the standard KVL form $(V^w_k-V^w_n) - (V^d_k-V^d_{k+1})/n_\text{eff} = Z_w I^\text{phys}_w$ — implies $I^w_k = n_\text{eff}\cdot I^\text{phys}_{w,k}$.

The delta-side variable satisfies $n_\text{eff}I^d_k = I^w_k - I^w_{k-1}$, giving
$I^d_k = I^\text{phys}_{d,k}/n_\text{eff}$ (physical delta terminal current scaled down by $n_\text{eff}$).

**The OPF is internally consistent** because the voltage equations and current
coupling are derived from the same scaled convention, and the KCL accumulator uses
these scaled variables throughout. Solving the OPF gives correct voltages and
correct *power flows* even though the intermediate winding-current variables carry
the $n_\text{eff}$ scaling. The admittance exporter uses physical terminal currents
via $C^{\mathsf T}y_\text{prim}C$ and is therefore directly comparable to OpenDSS `Yprim`.

---

## 6. Output format

A core function `transformer_yprim(xfmr, subtype) -> (nodes, Y)` returning the
SI block, plus a network-level exporter:

```json
{
  "transformer": {
    "<subtype>": {
      "<id>": {
        "nodes":  [["busA","1"], ["busA","n"], ["busB","1"], ...],
        "Y_real": [[...], ...],
        "Y_imag": [[...], ...]
      }
    }
  }
}
```

Explicit node ordering so the block aligns mechanically with OpenDSS `Export Y`.
Lives in `src/io/to_ybus.jl` (core, no JuMP/PMD dependency); the few pure-data
helpers it needs (`_xfmr_turns_ratio`, field getters) move out of the OPF ext
into core so both share one definition.

---

## 7. Correctness gates (tests)

1. **Symmetry:** `‖Y − Yᵀ‖∞ < ε` for every exported block (use `transpose`,
   not `'`). Hard gate — any failure is a sign/convention bug.
2. **Closed-form oracle:** the `single_phase` $2\times2$ block matches the §2
   formula exactly.
3. **Power balance:** for arbitrary $V$, $\operatorname{Re}[\bar{\mathbf V}^{\mathsf T}YV]
   = $ sum of winding resistive losses $\sum_k |I_k|^2 R_k$. Verified analytically
   for `single_phase` and `center_tap`; for Yd/Dy verify numerically with a balanced
   three-phase excitation.
4. **OpenDSS cross-check:** dump `Yprim` per fixture, permute to the same node
   order, assert `‖Y_\text{bmopf} - Y_\text{dss}\|_\infty < \text{tol}`. Catches
   turns-ratio direction, $\sqrt3$ scaling, delta phase-shift, and shunt-placement
   errors in one shot. _Implemented_ for `single_phase` and `center_tap` (the
   testset "Transformer Yprim matches OpenDSS" in `powerflow_comparison_tests.jl`);
   this is the gate that would have caught the original `center_tap` winding-3
   polarity bug. The delta blocks are basis-dependent in the raw matrix, so Yd/Dy
   are instead validated terminally by the unbalanced-load PF comparisons.
   Mirror [`powerflow_comparison_tests.jl`](../test/powerflow_comparison_tests.jl).
5. **Self-consistency with the OPF:** for a consistent $(V,I)$ pair recovered
   from $I=YV$ (i.e., the transformer equations are satisfied), verify that the
   OPF voltage and current coupling constraints in `transformer.jl` hold to
   numerical tolerance.
6. **Open-delta vs published model:** the `open_delta_regulator` $Y$ block
   matches Yan et al. (2018) Eq. (11) term-by-term in per unit ($r=1-n_R\equiv
   n_\text{eff}$). The galvanic straight-through (common-neutral, Eq. 14/15) is
   not in the $Y$ block; it is validated by a power-flow test asserting
   $V_\text{shared,fr}=V_\text{shared,to}$ with the two regulated phases boosted
   ([`powerflow_comparison_tests.jl`](../test/powerflow_comparison_tests.jl)).
