# Transformer equations in the OPF

This page is the equation-level reference for how each transformer subtype is
stamped into the [optimal power flow](opf.md). It continues the *Constraints*
section of that page: the variables, sign conventions, earth reference, and
per-unit bases are defined there and are used here without restating them.

Read [Transformer models](transformer_models.md) first for the data model — which
subtypes exist, what each field means, and which approximations are made. Read
this page when you need the exact constraint rows: to interpret a dual, to
audit a result against another solver, or to extend the formulation.

## Model and notation

A transformer is modeled as an **ideal ratio** between coil voltages, a
**series leakage impedance** carried by the winding currents, and a **no-load
(core) admittance** across one winding. Everything is written as voltage and
current equalities, which are **linear at a fixed tap**.

*Notation used throughout this section.*

- A **coil voltage** $U$ is the voltage across one winding: phase-to-neutral
  for a wye winding (phase-to-earth if the map has no neutral), line-to-line
  for a delta winding or a line-to-line single-phase winding.
- Every transformer current variable $c^x$ is the current flowing **from the
  bus into the transformer** at that terminal, so its KCL contribution is
  $-c^x$ at each terminal and the complex loss of the unit is the sum of
  $v\,\overline{c^x}$ over all its terminals.
- The nominal turns ratio of the four isolating two-winding subtypes is
  $N_0 = V^\text{nom}_\text{fr}/V^\text{nom}_\text{to}$ (fields `v_nom_from`,
  `v_nom_to`, SI volts; `v_ref_*` is accepted as a legacy alias at ingest), and
  the operating ratio is $N = N_0\cdot\texttt{tap}$ with a dimensionless
  multiplier `tap` (default 1).
- The two regulator subtypes (`single_phase_autotransformer`,
  `open_delta_regulator`) use an effective ratio $n_\text{eff}$ derived from
  `tap_ratio` and `regulator_type` (see below).
- $Y_0 = G_0 + jB_0$ (`g_no_load`, `b_no_load`, siemens) is the **total**
  no-load admittance of the unit.

**Where the no-load branch sits.** For the isolating subtypes the core branch
is connected across the coils of **winding 2, the to side**, and is driven by
that winding's coil voltage. It is not a phase-to-earth shunt at the
high-voltage terminals. This follows the OpenDSS convention and is verified
against its primitive admittance; the per-subtype placement is tabulated in
[Magnetizing-shunt placement](@ref Magnetising-shunt-placement). The two
regulator subtypes place it across the from-side winding instead.

## [Current ratings per subtype](@id opf-transformer-current-ratings)

The table describes native OPF current ratings, including legacy
`g_no_load`/`b_no_load`. A direct box is added only for a finite positive cap on
the represented variable. The magnitude row remains in place. Existing tighter
component bounds are preserved; absent/+Inf caps add neither row nor box, zero
caps use component equalities without fixed-variable bounds, and negative, NaN,
or -Inf caps are rejected. Ratings are converted into the side's working current
units before either constraint is stamped.

| Subtype / side | Rated quantity and index | Direct box |
|:--|:--|:--|
| `single_phase`, from | `i_max_from[k]`: bare series current for winding pair `k` | Yes |
| `single_phase`, to | `i_max_to[k]`: winding-pair current plus legacy excitation | Only without legacy excitation; otherwise the cap is on an expression |
| `center_tap`, from | `i_max_from[1:2]`: HV phase and mirrored neutral return, respectively | Yes, for each supplied entry |
| `center_tap`, to | `i_max_to[1:3]`: LV leg 1, center-tap neutral, LV leg 2; total winding-terminal currents including legacy excitation | Yes, in fixed-primitive and T-model paths |
| `wye_delta` / `delta_wye`, wye side | Side rating indexed by terminal-map position: bare phase winding current and, when present, summed neutral return | Yes |
| `wye_delta` / `delta_wye`, delta side | Side rating indexed by terminal-map position: bare delta **line** current, not individual delta-coil current | Yes |
| `single_phase_autotransformer`, from | `i_max_from[1]`: regulator input current plus legacy excitation | Only without legacy excitation |
| `single_phase_autotransformer`, to | `i_max_to[1]`: regulator output winding current | Yes |
| `open_delta_regulator`, both | `i_max_from[j]` / `i_max_to[j]`, `j=1,2`: bare currents of the two regulator pairs selected by `connection` | Yes |
| `n_winding`, each winding | Scalar `windings[k].i_max` caps each `cr_nw`/`ci_nw` coil current; WYE phase coil or DELTA pair coil | Yes |

For `single_phase`, the index enumerates winding pairs rather than every map
terminal. A return terminal does not acquire a separate rating from a trailing
array entry. Autotransformer and open-delta shared-bond currents
likewise have no independent cap from trailing entries. N-winding neutral return
is a sum, without an independently rated neutral variable. Center-tap HV return
is constrained to minus the phase current: either provided cap restricts that
physical current, but a missing entry does not create a second row or box.

Yd/Dy and open-delta legacy excitation is added separately in KCL and is outside
their bare-current ratings. Separate neutral-to-earth branches are outside the
winding-current ratings. Normalized `no_load_shunt` records become explicit shunt
objects, also outside these variables and caps, even when their reporting ledger
associates them with a transformer. Equivalent bus voltages and source powers
therefore do not imply identical rated currents for legacy and explicit shunts.

**Center-tap:** the T-model (free tap or either zero leakage arm) uses the same
total winding-terminal current boundary as the fixed primitive path. With legacy
excitation, its LV leg-1 and neutral native variables and serialized currents are
total terminal currents; the internal equations subtract excitation to recover the
series current, and model hooks requiring that current must do the same. Both HV
ratings are enforced in both paths. No ratings are inferred from nameplates,
voltages or turns ratios.

## [Continuous tap optimization](@id Continuous-tap-optimisation)

The tap can be a **free continuous decision variable** instead of a constant, so the
OPF chooses OLTC/regulator settings to reduce losses and hold voltages in band. It
follows the implicit free-variable pattern (bounds make it optimizable):

| subtype | tap field | free when |
|---|---|---|
| `single_phase`, `center_tap`, `delta_wye`, `wye_delta` | `tap` (mult. on $N_0$) | `tap_min` < `tap_max` |
| `single_phase_autotransformer` | `tap_ratio` | `tap_ratio_min` < `tap_ratio_max` |
| `open_delta_regulator` | `tap_ratio` (per reg.) | `tap_ratio_min` < `tap_ratio_max` (element-wise) |

A free tap adds **one variable per tap** equal to the effective from→to ratio
coefficient ($N$ for `single_phase` and `center_tap`, $n_\text{eff}$
otherwise). A free `wye_delta`/`delta_wye` tap adds a second variable, the
reciprocal $n_\text{eff}^{-1}$, pinned by the bilinear row
$n_\text{eff}\,n_\text{eff}^{-1} = 1$ so that the leakage referral stays
quadratic instead of rational. Using the ideal-core
coupling $N\,I_\text{series} = -I_\text{to}$, the voltage drop stays **quadratic** in
the tap (no cubic), so it stays within the same smooth NLP class. For the YY family
the from-winding leakage of an OLTC scales with the winding turns ($\propto
\texttt{tap}^2$); referred to the to side it is **constant**
($R' = r_\text{to} + r_\text{fr}/N_0^2$, $X' = x_\text{to} + x_\text{fr}/N_0^2$) and
the drop is $v_\text{fr} - N v_\text{to} = -N\,(R'\,I_\text{to} \mp X'\,I_\text{to})$,
matching OpenDSS's turns-scaled `Yprim`; at `tap = 1` it is identical to the
fixed-tap stamping. (The `delta_wye`/`wye_delta` coupled delta-arm carries the same
exact ``\texttt{tap}^2`` referral — the short-circuit impedance referred to the
tapped side scales as ``\texttt{tap}^2``, the non-tapped side is held at nominal.) The
solved tap is reported in the [result dictionary](results.md) as `tap`/`tap_ratio`
with a `tap_binding` flag. See the
[tap-optimization tutorial](@ref tap-optimisation).

## Zero-impedance (ideal) transformers

Because every subtype is expressed as voltage/current **equalities** (the IVR
impedance form $v_\text{fr} - N v_\text{to} = Z\,I$) rather than a nodal
admittance $Y = Z^{-1}$, **zero winding resistance and zero leakage reactance are
admissible**: the constraints degrade to the ideal-transformer relation
$v_\text{fr} = N v_\text{to}$ (and, for `n_winding`, $V_1^r = V_{i+1}^r$ with
$\sum_k N_k I_k = 0$) with no inversion and no singularity. This holds for *all*
subtypes.
(The separate `transformer_yprim`/`nwinding_yprim` **admittance export** is the
one place that genuinely inverts $Z$. An ideal coupling has no admittance form,
so that export throws for leakage at or below its cutoff; use `ybus_augmented`
for the bordered representation, or `shunt_only=true` to inspect the no-load
part alone.)

## `single_phase` — per-phase YY, Γ-equivalent

One winding pair per phase $k$. $Z_1 = R_1 + jX_1$ (`r/x_series_from`, Ω on the
from-side base) and $Z_2 = R_2 + jX_2$ (`r/x_series_to`, Ω on the to-side base)
are the two winding leakages; $U_{\text{fr},k}$ and $U_{\text{to},k}$ are the
coil voltages.

*Ideal core* (ampere-turn balance):

```math
N\,c^{x}_{x,\text{fr},k} + c^{x}_{x,\text{to},k} = 0 .
```

*Voltage.* Both leakages are referred to the to side at the **nominal** ratio,
$Z' = Z_2 + Z_1/N_0^2$, and written on the to-side current:

```math
U_{\text{fr},k} - N\,U_{\text{to},k} = -N\,Z'\,c^{x}_{x,\text{to},k}
```

(real and imaginary parts as two rows). Eliminating $c_\text{to}$ with the
ampere-turn balance shows the from-side equivalent the stamp implies,

```math
U_{\text{fr},k} - N\,U_{\text{to},k}
  = \Bigl[\bigl(\tfrac{N}{N_0}\bigr)^2 Z_1 + N^2 Z_2\Bigr] c^{x}_{x,\text{fr},k},
```

which is the familiar $Z_1 + N^2 Z_2$ at `tap = 1`. Off nominal, the from
winding is the tapped one: its leakage scales with the square of its turns,
while $Z'$ seen from the to side stays constant. This matches OpenDSS's
turns-scaled primitive and keeps the row quadratic when the tap is a variable.

*No-load branch.* Each of the $n_c$ winding pairs carries $Y_0/n_c$ across its
**to** coil, so the to-side terminal current is series plus excitation and the
from side carries the series current only:

```math
I^\text{to,term}_{x,k} = c^{x}_{x,\text{to},k} + \tfrac{Y_0}{n_c}\,U_{\text{to},k},
\qquad
I^\text{fr,term}_{x,k} = c^{x}_{x,\text{fr},k}.
```

`i_max_to` limits $I^\text{to,term}$; `i_max_from` limits the from current.
Optional `r/x_neutral_from` and `r/x_neutral_to` add a grounding branch
$1/(R_n + jX_n)$ from that side's shared neutral terminal to earth.

When all loss fields are absent or zero the model reduces to the ideal
$U_{\text{fr},k} = N\,U_{\text{to},k}$.

## `center_tap` — coupled-coil 3-winding (primitive admittance)

Terminal map: `terminal_map_from = [t_ph, t_n]` (HV phase, HV neutral),
`terminal_map_to = [t₁, tₙ, t₂]` (leg-1, center-tap neutral, leg-2).
$V^\text{nom}_\text{to}$ is the **per-leg** voltage (e.g. 120 V for a
120-0-120 V unit), so $N = V^\text{nom}_\text{fr}/V^\text{nom}_\text{to} = 60$
for a 7.2 kV / 120 V unit.

The split-phase unit is a genuine 3-winding transformer whose two LV
half-windings are tightly coupled on the shared core. Modeling each leg with an
*independent* secondary impedance drop omits that mutual coupling and spreads the
two legs apart under load. The OPF therefore imposes the OpenDSS-consistent 5×5
primitive admittance $Y_\text{CT}$ (the same one the Ybus exporter builds; see
[Transformer primitive admittance](spec/transformer-admittance.md)) as nodal current injections —
element current into each of the five terminals
$\mathbf I = Y_\text{CT}\,\mathbf V$ — and pins the per-winding current variables
(HV series, leg-1, center, leg-2) to those injections for the `i_max` limits and
loss accounting. $Y_\text{CT}$ is reconstructed from the symmetric star leakage
arms $Z_1 = R_1+jX_1$ (HV) and $Z_2 = R_2+jX_2$ (each LV leg), with winding 3
dotted at the center tap (leg-2 voltage span $V_{t_n} - V_{t_2}$). It matches
OpenDSS's transformer `Yprim` to machine precision.

The implied current relations are the ampere-turn

```math
N\,c^{r,x}_{x,s} + c^{r,x}_{x,\ell_1} - c^{r,x}_{x,\ell_2} = 0
\quad\text{(and imaginary)}
```

and the center-tap KCL (variable index 2 on `to` side):

```math
c^{r,x}_{x,n} + c^{r,x}_{x,\ell_1} + c^{r,x}_{x,\ell_2} = 0
\quad\text{(and imaginary)}
```

Under zone-local `OpfScaling(...; power_bases=...)`, the ampere-turn equation in model coordinates is
`N (S_primary/S_secondary) c_s + c_l1 - c_l2 = 0`. For the fixed primitive,
BMOPFTools assembles a reciprocal intermediate primitive on the primary power
base, then transforms the three secondary current rows to the secondary base.
The normalized matrix is therefore generally nonsymmetric; transforming it
back to dimensional coordinates recovers the reciprocal physical primitive.

The no-load shunt $Y_0$ is folded into $Y_\text{CT}$ across winding 2,
the LV leg-1 span $(t_1,t_n)$, undivided, following the OpenDSS convention.

*Two equivalent stamps.* The admittance stamp needs both star arms to be
nonzero (it inverts them) and a fixed ratio (it folds $N$ into the matrix). It
is therefore used only when $Z_1 \ne 0$, $Z_2 \ne 0$, **and** the tap is fixed.
A **free tap** (`tap_min < tap_max`), or **either arm equal to zero**, switches
to the impedance form of the same model, which is linear in the leakages. With
$U_\text{hv} = v_{t_\text{ph}} - v_{t_n}$, leg voltages
$u_1 = v_{t_1} - v_{t_n}$ and $u_2 = v_{t_n} - v_{t_2}$, HV current $c_s$, and
leg-1 series current $c^\text{ser}_{\ell_1} = c_{\ell_1} - Y_0 u_1$:

```math
U_\text{hv} - N u_1 = \bigl(\tfrac{N}{N_0}\bigr)^2 Z_1\,c_s - N Z_2\,c^\text{ser}_{\ell_1},
\qquad
U_\text{hv} - N u_2 = \bigl(\tfrac{N}{N_0}\bigr)^2 Z_1\,c_s + N Z_2\,c_{\ell_2},
```

with the ampere-turn balance $N c_s + c^\text{ser}_{\ell_1} - c_{\ell_2} = 0$,
the center-tap balance above, and the HV return $c_{x,\text{fr},2} = -c_s$. The
shared $Z_1 c_s$ term is what carries the coupling between the two half
windings. In the stamped rows $N c_s$ is replaced by
$c_{\ell_2} - c^\text{ser}_{\ell_1}$, so they stay quadratic for a variable $N$.
At zero leakage both forms give the ideal $U_\text{hv} = N u_1 = N u_2$.

!!! note "Leakage from OpenDSS XHL/XLT/XHT"
    For a 3-winding OpenDSS unit, the per-pair leakage values must be
    star-converted before storing in `x_series_from`/`x_series_to`:
    ```
    x_series_from = (XHL + XHT − XLT) / 2 × Vhv² / (100 · s_rating)
    x_series_to   = (XHL + XLT − XHT) / 2 × Vlv² / (100 · s_rating)
    ```
    Using the 2-winding shortcut (full `XHL` on the HV side, `x_series_to = 0`)
    drops the LV-side leakage and spreads the legs apart under load.
    PowerIO's BMOPF export carries the correct star split for
    [`from_dss`](@ref); BMOPFTools normalizes the no-load shunt convention.

## Wye–delta (Yd) / Delta–wye (Dy)

`wye_delta` has the wye on the from side, `delta_wye` the delta on the from
side. Each core leg $k$ links one wye coil (phase $k$ to the star point) with
one delta coil (between two delta terminals). Nominal voltages are given on the
same basis on both sides (line-to-line nameplate values by convention), so the
coil ratio carries the $\sqrt3$ of the delta connection:

$$n_\text{eff} = \begin{cases} \sqrt{3}/N & \text{Yd} \\ N\sqrt{3} & \text{Dy} \end{cases}
\qquad\text{(delta coil volts per wye coil volt)}$$

Let $U_{\text{wye},k} = v_{\text{wye},t^\phi_k} - v_{\text{wye},n}$ be the wye
coil voltage, and write $k^+$, $k^-$ for the next and previous phase,
cyclically. The delta coil of leg $k$ spans terminals $(k, k^+)$ for **Yd** and
$(k, k^-)$ for **Dy** (the backward-delta convention, matching OpenDSS). Call
that partner terminal $k'$.

*Voltage.* The delta coil voltage is the wye coil voltage times the ratio, less
one series drop driven by the **wye** coil current:

```math
v_{\text{del},t_k} - v_{\text{del},t_{k'}}
= n_\text{eff}\,U_{\text{wye},k} - Z_\text{eff}\,c^{x}_{x,\text{wye},k}.
```

$Z_\text{eff}$ collects both winding leakages, $Z^\text{w}$ (wye) and
$Z^\text{d}$ (delta), as seen from the delta coil. At nominal tap, with
$n_\varphi$ phases,

```math
Z_\text{eff} = n_\text{eff}\,Z^\text{w} + \frac{n_\varphi}{n_\text{eff}}\,Z^\text{d}.
```

The factor $n_\varphi$ converts the stored delta-side ohms, which are on the
delta *bus* (line-to-neutral) base, to the delta *coil* (line-to-line) base.
The drop uses the wye current, not the delta terminal current, because the
current in a delta **coil** is the image $c_{\text{wye},k}/n_\text{eff}$ of the
wye coil current, whereas the delta terminal variable is the difference of two
coil currents.

Off nominal, the from winding is the tapped one and the leakage referred to it
scales with $\texttt{tap}^2$. With $n_{\text{eff},0}$ the nominal ratio:

```math
Z_\text{eff} =
\begin{cases}
\dfrac{n_{\text{eff},0}^2\,Z^\text{w} + n_\varphi\,Z^\text{d}}{n_\text{eff}} & \text{Yd (wye tapped)}\\[2ex]
n_\text{eff}\Bigl(Z^\text{w} + \dfrac{n_\varphi}{n_{\text{eff},0}^2}\,Z^\text{d}\Bigr) & \text{Dy (delta tapped)}
\end{cases}
```

Both reduce to the nominal expression at $n_\text{eff} = n_{\text{eff},0}$.

*Current* (the transpose of the voltage relation, so the ideal part conserves
power). With every current measured into the transformer, a delta terminal
collects two coil currents of opposite sense:

```math
n_\text{eff}\,c^{x}_{x,\text{del},k}
= -\bigl(c^{x}_{x,\text{wye},k} - c^{x}_{x,\text{wye},k''}\bigr),
\qquad k'' = k^- \text{ (Yd)},\quad k'' = k^+ \text{ (Dy)}.
```

Note the index: the current row pairs leg $k$ with the *other* neighbor than the
voltage row does. The three delta terminal currents sum to zero identically, so
a delta winding passes no zero-sequence current.

*Star point.* The wye neutral terminal returns the sum of the wye coil
currents:

```math
c^{x}_{x,\text{wye},n} + \sum_{k} c^{x}_{x,\text{wye},k} = 0 .
```

If the wye map lists no neutral there is no such variable and the star point is
solidly grounded (see [return paths](@ref opf-earth-reference)). Optional
`r/x_neutral_*` on the wye side adds a grounding branch $1/(R_n+jX_n)$ from the
wye neutral terminal to earth; on the delta side it is rejected.

*No-load branch.* $Y_0$ is split equally over the $n_\varphi$ coils of the
**to** winding: a delta of branches across the delta coils for Yd, and
phase-to-neutral branches on the wye for Dy.

A legacy combined `r_series`/`x_series` is assigned to the wye winding at
ingest ($Z^\text{d} = 0$); the builder itself reads only the split fields. When
all impedance fields are zero the model collapses to the ideal transform.

With zone-local `OpfScaling(...; power_bases=...)`, the current row becomes
`n_eff (S_delta/S_wye) c_del = −(c_wye,k − c_wye,k″)` in model coordinates.
Delta-arm leakage referral carries the reciprocal `S_wye/S_delta`. This
reciprocal pair preserves both the connection incidence and
`V_base*I_base=S_base`; omitting either changes the physical transformer rather
than merely scaling it.

## `single_phase_autotransformer` — step voltage regulator

A step voltage regulator is an autotransformer: its series and common windings
share a bushing, so the from and to sides are galvanically tied, not isolated.
With tap ratio $a$ (`tap_ratio`, regulated volts per source volt) the effective
from→to ratio is

```math
n_\text{eff} = \begin{cases} 1/a & \text{Type B (standard SVR, default)} \\ a & \text{Type A} \end{cases}
```

The regulating winding is written like a `single_phase` pair with
$N := n_\text{eff}$. With coil voltages $U_\text{fr}$, $U_\text{to}$ (phase to
the winding's reference terminal: the neutral for a line-to-neutral regulator,
the second phase for a line-to-line one):

```math
U_\text{fr} - n_\text{eff}\,U_\text{to}
= Z_1\,c^{x}_{x,\text{fr}} - n_\text{eff}\,Z_2\,c^{x}_{x,\text{to}},
\qquad
n_\text{eff}\,c^{x}_{x,\text{fr}} + c^{x}_{x,\text{to}} = 0 ,
```

equivalent to a series impedance $Z_1 + n_\text{eff}^2 Z_2$ on the from
current. The leakage is not rescaled with the tap. The no-load branch $Y_0$
sits across the **from** coil.

*The shared bushing.* The data model exposes the one physical reference
bushing as two terminals, one on each bus. When both sides list a reference
terminal, the model bonds them with a zero-impedance tie carrying its own
current $c^\text{bond}$:

```math
v_{b^\text{fr},q} = v_{b^\text{to},q},
```

with KCL contributions $+(c_\text{fr} + Y_0 U_\text{fr}) - c^\text{bond}$ at
the from reference and $+c_\text{to} + c^\text{bond}$ at the to reference. Each
coil thus returns at its own reference terminal and the bond carries whatever
passes between the two buses on the shared conductor. If only one side lists a
reference terminal, both returns close there
($I_\text{ref} + c_\text{fr} + c_\text{to} = 0$ plus the excitation).

A lossless ideal regulator ($Z = Y_0 = 0$) collapses to
$U_\text{fr} = n_\text{eff}\,U_\text{to}$, that is $U_\text{to} = a\,U_\text{fr}$
for Type B.

Because the two buses are joined by copper, a regulator does **not** change the
per-unit voltage base (see [Units and scaling](opf.md#Units-and-scaling)); nameplate
`v_nom_*` fields on a regulator play no part in its equations.

## `open_delta_regulator` — monolithic open-delta

Two single-phase autotransformer windings connected **line-to-line** across the
phase pairs implied by `connection` (`ABBC`/`BCAC`/`CABA`); per-regulator taps
`tap_ratio = [a_1, a_2]` give $n_{\text{eff},j}$ as above. For each regulator
$j$ spanning from-phase pair $(p, q)$ and the matching to-phase pair:

```math
\bigl(v_{b^\text{fr},t_p} - v_{b^\text{fr},t_q}\bigr)
- n_{\text{eff},j}\bigl(v_{b^\text{to},t_p} - v_{b^\text{to},t_q}\bigr)
= Z_1\,c^{x}_{x,\text{fr},j} - n_{\text{eff},j}\,Z_2\,c^{x}_{x,\text{to},j}
```

```math
n_{\text{eff},j}\,c^{r,x}_{x,\text{fr},j} + c^{r,x}_{x,\text{to},j} = 0
```

If `tap_ratio` has one entry, the second regulator uses the same ratio. KCL
injects each regulator's line current at the two phases it spans ($+I$ at one,
$-I$ at the other); the per-regulator no-load branch $Y_0$ sits across its
from-side line-to-line pair. The phase **common to both regulators** (B in
the ABBC arrangement) is a **galvanic straight-through** — a zero-impedance wire
with its own current variable, enforcing

```math
v_{b^\text{fr},t_\text{shared}} = v_{b^\text{to},t_\text{shared}}
```

This is the "common neutral" model of Yan et al. (2018) ([ref. 29](references.md#refs)): the
shared phase passes through unchanged while the two regulated line-to-line
voltages are boosted by their taps. Without it the line-to-line voltages are
still correct but the per-phase reference floats (the unphysical
"unspecified neutral" model). See
[Transformer primitive admittance](spec/transformer-admittance.md) for the matching bus-admittance form.

**The neutral is not part of the bank.** No winding of an open-delta bank
touches the neutral, and the model does **not** connect the neutral terminals
of its two buses: only the shared phase is bonded. On a four-wire feeder the
neutral conductor physically runs past the bank, and that continuity is a
separate, explicit element in the case:

- a neutral-only `line` with exact zero impedance, or a closed `switch`, for an
  ideal through-connection;
- a neutral-only `line` with its real impedance when the jumper resistance
  matters.

Keeping the path explicit is deliberate. A bond built into the regulator would
silently short out a finite-impedance neutral path that the case does model,
and every tool reading the case has to agree on connectivity: the OPF, the
admittance builders, and the provenance analysis all treat the bank's neutral
terminals as unconnected. If no explicit path is given, the downstream neutral
is a separate island; provenance reports it as `E.PROV.FLOATING_NEUTRAL`, and a
phase-to-neutral load there has no return path unless that neutral is earthed.
Two OpenDSS cases pin the behavior, one with an ideal and one with a 0.5 Ω
neutral jumper (`pf_open_delta_neutral`, `pf_open_delta_neutral_jumper`; see
[Engine validation evidence](validation.md)).

## `n_winding` — general n-winding (ZB model, WYE and/or DELTA)

The general n-winding transformer keeps the **explicit per-winding current
variables** $c^{r,w}_{x,j,k}, c^{i,w}_{x,j,k}$ (one per winding $j$ and phase
$k$) — it is the same rectangular IVR style as the other devices, **not** an
admittance model that eliminates currents. Keeping both current and voltage
variables (rather than substituting an admittance) is what lets the leakage be
parameterized down to **zero impedance** (a lossless / ideal transformer): the
leakage equation below stays well-posed at $ZB = 0$ (it collapses to the ideal
ratio $V^r_1 = V^r_{i+1}$) with no division by an impedance.

The leakage is the OpenDSS-style $ZB$ matrix referred to winding 1 (an
$(n{-}1)\times(n{-}1)$ impedance, exact for any $n$; see
[Conversion § n-winding](@ref n-winding)). With winding-local power bases, let
$f_j=S_j/S_1$. The referred currents in winding-1 current coordinates are
$I^r_{j} = N_j f_j\,c^{w}_{x,j,k}$
($N_j = V^\text{nom}_j / V^\text{nom}_1$); every $f_j=1$ in SI and ordinary
system-base per-unit. With referred coil voltages $V^r_j = U_{j,k}/N_j$, per
phase/leg $k$:

```math
\sum_{j=1}^{n} N_j f_j\,c^{r,w}_{x,j,k} = 0 \quad\text{(ideal core / ampere-turn; and imaginary)}
```

```math
V^r_1 - V^r_{i+1} = -\sum_{j=1}^{n-1} ZB_{i,j}\,I^r_{j+1},
\qquad i = 1,\dots,n-1 \quad\text{(complex; real/imag split)}
```

The per-leg leakage/ampere-turn structure is identical for `WYE` and `DELTA`
windings — only the coil↔terminal incidence differs. The coil voltage $U_{j,k}$
is **phase-to-neutral** for a `WYE` winding and **line-to-line** (phase $k$ minus
its delta partner $k^{\pm}$, selected by the winding's `delta_roll`) for a
`DELTA` winding, whose $V^\text{nom}$ is its line-to-line coil voltage — so the
$\sqrt{3}$ coil-base factor lives entirely in $N_j$, and $V^r_j$ stays consistent
(per-unit needs no $\sqrt3$ correction, since the bus base is line-to-neutral).
A `WYE` coil injects $-c^{w}_{x,j,k}$ at its phase and $+\sum_k c^{w}_{x,j,k}$ at
its neutral; a `DELTA` coil injects $-c^{w}_{x,j,k}$ at phase $k$ and
$+c^{w}_{x,j,k}$ at its delta partner. Referencing winding 1 folds out the core
node, so **no internal star-node variable is introduced**; the optional no-load
shunt sits across winding 2, matching the engine's OpenDSS convention. The
constraints are all linear. An `n_winding` unit has no tap: any tap field on
the transformer or a winding is rejected at build. This path is
independent of the two-bus transformer code and is validated against OpenDSS's
own 3- and 4-winding solves, including delta (`Dyn`/`Dyyn`) configurations.
