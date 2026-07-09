# Transformer primitive admittance

Every transformer and regulator model in this specification has an exact **nodal
admittance block** (a *primitive admittance*, or `Yprim`): the complex matrix
$\textcolor{brown}{\mathbf{Y}_x}$ over the element's terminal nodes such that

```math
\textcolor{blue}{\mathbf{I}_x} = \textcolor{brown}{\mathbf{Y}_x}\,\textcolor{blue}{\mathbf{U}_x},
```

where $\textcolor{blue}{\mathbf{U}_x}$ stacks the node voltages (each terminal to
ground) and $\textcolor{blue}{\mathbf{I}_x}$ the **currents into the element** at
those terminals (out of the bus). This is the object OpenDSS exposes as a PD-element
`Yprim` (`Export Y` / `DumpYprim`) and that PowerModelsDistribution assembles
internally, so it is the natural artifact for **cross-tool validation**: an informed
reader can compare our block against their own implementation term-by-term, before any
topology or Kirchhoff law enters.

This page gives $\textcolor{brown}{\mathbf{Y}_x}$ in **symbolic** form for all six
transformer/regulator models — the [Transformers](transformer.md) subtypes
(`single_phase`, `center_tap`, `wye_delta`, `delta_wye`, `n_winding`) and the
[Regulators](regulator.md) (`single_phase_autotransformer`, `open_delta_regulator`).
The [OPF constraints](transformer.md#4.-Equality-constraints) stamp the *same*
relations as nodal current injections, so the two paths cannot drift apart (a test
pins each solved setpoint against $\textcolor{brown}{\mathbf{Y}_x}\textcolor{blue}{\mathbf{U}_x}$).
Symbols are defined in [Notation](notation.md) and the loss elements
($\textcolor{brown}{Z^{\text{fr}}_x}$, $\textcolor{brown}{Z^{\text{to}}_x}$,
$\textcolor{brown}{Y_0}$, $\textcolor{brown}{y_n}$) in
[Transformers §4](transformer.md#4.-Equality-constraints).

## 1. Conventions and construction

| Item | Choice |
|------|--------|
| Units | **SI** — siemens, volts, amperes. No per-unit base. |
| Node | a `(bus, terminal)` pair; $\textcolor{blue}{\mathbf{U}_x}$ stacks them in the order listed for each subtype. |
| Current sign | $\textcolor{blue}{\mathbf{I}_x}$ = current **into** the element (out of the bus), matching OpenDSS `Yprim`. |
| Turns ratio | $\textcolor{red}{N}=\textcolor{red}{N_0}\,\textcolor{red}{t}$ with nameplate $\textcolor{red}{N_0}=\textcolor{red}{v^{\text{nom}}_{\text{fr}}}/\textcolor{red}{v^{\text{nom}}_{\text{to}}}$ and fixed tap multiplier $\textcolor{red}{t}$ (`tap`, default 1). For `center_tap`, $\textcolor{red}{v^{\text{nom}}_{\text{to}}}$ is the per-leg rating. |
| Winding leakage | $\textcolor{brown}{Z^{\text{fr}}_x}=\textcolor{red}{R_1}+\textcolor{brown}{j}\textcolor{red}{X_1}$ (`r/x_series_from`), $\textcolor{brown}{Z^{\text{to}}_x}=\textcolor{red}{R_2}+\textcolor{brown}{j}\textcolor{red}{X_2}$ (`r/x_series_to`). |
| No-load shunt | $\textcolor{brown}{Y_0}=\textcolor{red}{G_0}+\textcolor{brown}{j}\textcolor{red}{B_0}$ (`g/b_no_load`), across **winding 2** (the to-side coil) — the OpenDSS placement. Inductive: $\textcolor{red}{B_0}<0$. |
| Neutral grounding | $\textcolor{brown}{y_n}=1/(\textcolor{red}{R_n}+\textcolor{brown}{j}\textcolor{red}{X_n})$ (`r/x_neutral_from`, `r/x_neutral_to`): an **internal** branch from a shared neutral terminal to earth — a **diagonal add** at that node (OpenDSS's Yprim gains exactly $\textcolor{brown}{y_n}$ on the neutral diagonal). |

**The construction.** Every block is built in the textbook *primitive-admittance ×
connection-matrix* form

```math
\textcolor{brown}{\mathbf{Y}_x}
= \textcolor{brown}{\mathbf{C}}^{\text{T}}\,\textcolor{brown}{\mathbf{y}_{\text{prim}}}\,\textcolor{brown}{\mathbf{C}}
\;+\; \text{(winding-2 shunt)}\;+\;\text{(neutral diagonal }\textcolor{brown}{y_n}),
```

where $\textcolor{brown}{\mathbf{C}}$ maps node voltages to per-core winding voltages
and $\textcolor{brown}{\mathbf{y}_{\text{prim}}}$ is the (block-)diagonal primitive of
the winding pairs. Because $\textcolor{brown}{\mathbf{y}_{\text{prim}}}$ is symmetric,
so is the result:

!!! note "Reciprocity — the hard correctness gate"
    A transformer built from linear impedances and ideal cores is a **reciprocal**
    network, so $\textcolor{brown}{\mathbf{Y}_x}=\textcolor{brown}{\mathbf{Y}_x}^{\text{T}}$
    (a plain transpose — **not** Hermitian; the network is lossy, so
    $\textcolor{brown}{\mathbf{Y}_x}\neq\textcolor{brown}{\mathbf{Y}_x}^{\text{H}}$).
    Every block below satisfies $\lVert\textcolor{brown}{\mathbf{Y}_x}-\textcolor{brown}{\mathbf{Y}_x}^{\text{T}}\rVert_\infty<\epsilon$; any asymmetry is a sign/convention bug.

!!! warning "Finiteness — nonzero leakage required"
    $\textcolor{brown}{\mathbf{Y}_x}$ is finite only for **nonzero leakage**. An ideal
    ($\textcolor{brown}{Z}\to 0$) winding has infinite primitive admittance and a
    singular block; OpenDSS always carries a small leakage, and so must any exported
    case. A zero-leakage unit that still has core loss exports its (singular)
    shunt-only block rather than zeros.

## 2. `single_phase` (wye–wye, Γ-model)

Per phase-pair $k$: HV node $p$, LV node $q$. The two coils lump into one leakage
referred to HV (the Γ model). With $\textcolor{brown}{y}=1/\textcolor{brown}{Z}$ and the
no-load shunt split over the $\textcolor{red}{n_c}$ pairs,

```math
\textcolor{brown}{Z} = \textcolor{red}{t}^2\,\textcolor{brown}{Z^{\text{fr}}_x} + \textcolor{red}{N}^2\,\textcolor{brown}{Z^{\text{to}}_x},
\qquad
\textcolor{brown}{Y_0'} = \textcolor{brown}{Y_0}/\textcolor{red}{n_c},
```

so the off-nominal tap scales the from-coil leakage by $\textcolor{red}{t}^2$
(equivalently $\textcolor{brown}{Z}=\textcolor{red}{N}^2(\textcolor{brown}{Z^{\text{to}}_x}+\textcolor{brown}{Z^{\text{fr}}_x}/\textcolor{red}{N_0}^2)$, the to-referred
leakage held at nominal — matching OpenDSS's turns-scaled `Yprim`). The $2\times2$ block
for pair $k$ (nodes $[p,q]$), with $\textcolor{brown}{\mathbf{C}}=[\,1\;\;-\textcolor{red}{N}\,]$ and the shunt on the **to** node, is

```math
\begin{bmatrix}\textcolor{blue}{I_p}\\ \textcolor{blue}{I_q}\end{bmatrix}
=
\begin{bmatrix}
\textcolor{brown}{y} & -\textcolor{red}{N}\textcolor{brown}{y}\\[2pt]
-\textcolor{red}{N}\textcolor{brown}{y} & \textcolor{red}{N}^2\textcolor{brown}{y}+\textcolor{brown}{Y_0'}
\end{bmatrix}
\begin{bmatrix}\textcolor{blue}{U_p}\\ \textcolor{blue}{U_q}\end{bmatrix}.
```

The full block is **block-diagonal** over the $\textcolor{red}{n_c}$ phase-pairs. Each
grounded neutral (from and/or to) that a phase-pair returns to adds
$\textcolor{brown}{y_n}$ to that neutral node's diagonal.

## 3. `center_tap` (split-phase, 3-winding)

Five nodes $[\,p,\,m,\,a,\,g,\,c\,]$: HV-phase, HV-neutral, LV-leg-1, LV-centre-tap,
LV-leg-2. This is a genuine **3-winding** unit (1 HV + 2 series-aiding LV legs sharing
$g$). Refer all arms to the LV base:

```math
\textcolor{brown}{y_1}=\textcolor{red}{N}^2/\textcolor{brown}{Z^{\text{fr}}_x},\qquad
\textcolor{brown}{y_2}=1/\textcolor{brown}{Z^{\text{to}}_x},\qquad
\textcolor{brown}{Y_\Sigma}=\textcolor{brown}{y_1}+2\,\textcolor{brown}{y_2}.
```

Eliminating the internal star node gives the symmetric 3-port star admittance in the
winding-terminal ordering $[\text{HV-ref},\,\text{leg-1},\,\text{leg-2}]$, with
$\textcolor{brown}{\mathbf{y}}=(\textcolor{brown}{y_1},\textcolor{brown}{y_2},\textcolor{brown}{y_2})$:

```math
[\textcolor{brown}{\mathbf{Y}_{\text{3port}}}]_{ij}=
\begin{cases}
\textcolor{brown}{y_i}(\textcolor{brown}{Y_\Sigma}-\textcolor{brown}{y_i})/\textcolor{brown}{Y_\Sigma} & i=j,\\[4pt]
-\textcolor{brown}{y_i}\textcolor{brown}{y_j}/\textcolor{brown}{Y_\Sigma} & i\neq j.
\end{cases}
```

The connection matrix maps node voltages $[p,m,a,g,c]$ to the three winding voltages —
the HV winding sees $(\textcolor{blue}{U_p}-\textcolor{blue}{U_m})/\textcolor{red}{N}$,
leg 1 sees $\textcolor{blue}{U_a}-\textcolor{blue}{U_g}$, and leg 2 sees
$\textcolor{blue}{U_g}-\textcolor{blue}{U_c}$ (both legs the *same* polarity about the
centre tap — series-aiding):

```math
\textcolor{brown}{\mathbf{C}}=
\begin{bmatrix}
1/\textcolor{red}{N} & -1/\textcolor{red}{N} & 0 & 0 & 0\\
0 & 0 & 1 & -1 & 0\\
0 & 0 & 0 & 1 & -1
\end{bmatrix}.
```

With the no-load shunt across winding 2 = LV leg 1 (the $a$–$g$ coil,
$\textcolor{brown}{\mathbf{c}}_{ag}=\mathbf{e}_a-\mathbf{e}_g$) and the two optional
neutral-grounding branches — $\textcolor{brown}{y_n^{\text{fr}}}$ at the HV neutral $m$
(node 2) and $\textcolor{brown}{y_n^{\text{to}}}$ at the centre tap $g$ (node 4):

```math
\textcolor{brown}{\mathbf{Y}_x}=
\textcolor{brown}{\mathbf{C}}^{\text{T}}\,\textcolor{brown}{\mathbf{Y}_{\text{3port}}}\,\textcolor{brown}{\mathbf{C}}
+\textcolor{brown}{Y_0}\,\textcolor{brown}{\mathbf{c}}_{ag}\textcolor{brown}{\mathbf{c}}_{ag}^{\text{T}}
+\textcolor{brown}{y_n^{\text{fr}}}\,\mathbf{e}_m\mathbf{e}_m^{\text{T}}
+\textcolor{brown}{y_n^{\text{to}}}\,\mathbf{e}_g\mathbf{e}_g^{\text{T}}.
```

This reproduces OpenDSS's own transformer `Yprim` to machine precision. The star arms
come from the symmetric short-circuit split
$\textcolor{red}{X_{1,\star}}=(\textcolor{red}{X_{HL}}+\textcolor{red}{X_{HT}}-\textcolor{red}{X_{LT}})/2$,
$\textcolor{red}{X_{2,\star}}=(\textcolor{red}{X_{HL}}+\textcolor{red}{X_{LT}}-\textcolor{red}{X_{HT}})/2$.

## 4. `wye_delta` (Yd) and `delta_wye` (Dy)

Take $\textcolor{red}{n_\phi}=3$. Node ordering $[\,w_1,w_2,w_3,w_n,\,d_1,d_2,d_3\,]$
(wye phases, wye neutral, delta nodes). Each core couples a wye phase-to-neutral
winding voltage with a delta line-to-line winding voltage; the $6\times7$ connection
matrix is

```math
\textcolor{brown}{\mathbf{C}}=
\begin{bmatrix}\mathbf{I}_3 & -\mathbf{1} & \mathbf{0}\\[2pt] \mathbf{0} & \mathbf{0} & \textcolor{red}{\mathbf{D}}\end{bmatrix},
\qquad
\textcolor{red}{\mathbf{D}}=\begin{bmatrix}1&-1&0\\0&1&-1\\-1&0&1\end{bmatrix},
```

where $\textcolor{red}{\mathbf{D}}$ (forward delta) is used for **Yd** and
$\textcolor{red}{\mathbf{D}}^{\text{T}}$ (backward delta) for **Dy**. The effective
per-winding turns ratio and the wye-referred short-circuit admittance are

```math
\textcolor{red}{n^{\text{eff}}}=
\begin{cases}\sqrt3/\textcolor{red}{N} & \text{Yd},\\ \textcolor{red}{N}\sqrt3 & \text{Dy},\end{cases}
\qquad
\textcolor{brown}{y_t}=\frac{1}{\textcolor{brown}{Z_{\text{sc}}}},\quad
\textcolor{brown}{Z_{\text{sc}}}=\textcolor{brown}{Z^w}+\frac{\textcolor{red}{n_\phi}}{(\textcolor{red}{n^{\text{eff}}_0})^2}\,\textcolor{brown}{Z^d},
```

with $\textcolor{brown}{Z^w},\textcolor{brown}{Z^d}$ the wye- and delta-side leakages
(mapped by which side is `from`) and $\textcolor{red}{n^{\text{eff}}_0}$ the nominal
(tap-1) ratio. A non-nominal tap scales the short-circuit impedance by
$(\textcolor{red}{n^{\text{eff}}_0}/\textcolor{red}{n^{\text{eff}}})^2$ on the tapped
(wye=from) side. The ideal coil relation is
$\textcolor{blue}{U^d_k}=\textcolor{red}{n^{\text{eff}}}\,\textcolor{blue}{U^w_k}$, so with
$\textcolor{red}{a}=1/\textcolor{red}{n^{\text{eff}}}$ the per-core primitive (rows
$[w_k,d_k]$) is

```math
\textcolor{brown}{\mathbf{y}^{(k)}_{\text{prim}}}=\textcolor{brown}{y_t}
\begin{bmatrix}1 & -\textcolor{red}{a}\\ -\textcolor{red}{a} & \textcolor{red}{a}^2\end{bmatrix}.
```

!!! warning "Orientation matters"
    Stamping $\textcolor{red}{n^{\text{eff}}}$ instead of $\textcolor{red}{a}$ builds the
    *inverse* transformer — its no-load point lands at
    $\textcolor{blue}{U^d}=\textcolor{blue}{U^w}/\textcolor{red}{n^{\text{eff}}}$ instead
    of $\textcolor{red}{n^{\text{eff}}}\textcolor{blue}{U^w}$ (an $\sim(\textcolor{red}{n^{\text{eff}}})^2$ error) — yet passes every symmetry and passivity check. Only the
    OpenDSS `Yprim` cross-check catches it.

The nodal block is $\textcolor{brown}{\mathbf{Y}_x}=\textcolor{brown}{\mathbf{C}}^{\text{T}}\textcolor{brown}{\mathbf{y}_{\text{prim}}}\textcolor{brown}{\mathbf{C}}+\textcolor{brown}{Y_0}\,(\text{winding-2 shunt})+\textcolor{brown}{y_n}\,(\text{wye-neutral diagonal})$,
with the shunt a delta of $\textcolor{brown}{Y_0}/\textcolor{red}{n_\phi}$ branches on
the LV delta (Yd) or phase-to-neutral on the LV wye (Dy). For the common lossless-delta
case ($\textcolor{brown}{Z^d}=0$, $\textcolor{brown}{y_w}=1/\textcolor{brown}{Z^w}$, no
shunt) it evaluates to the explicit symmetric block

```math
\textcolor{brown}{\mathbf{Y}_x}=\textcolor{brown}{y_w}
\begin{bmatrix}
\mathbf{I}_3 & -\mathbf{1} & -\textcolor{red}{a}\textcolor{red}{\mathbf{D}}\\[4pt]
-\mathbf{1}^{\text{T}} & 3 & \textcolor{red}{a}\,\mathbf{1}^{\text{T}}\textcolor{red}{\mathbf{D}}\\[4pt]
-\textcolor{red}{a}\textcolor{red}{\mathbf{D}}^{\text{T}} & \textcolor{red}{a}\,\textcolor{red}{\mathbf{D}}^{\text{T}}\mathbf{1} & \textcolor{red}{a}^2\textcolor{red}{\mathbf{D}}^{\text{T}}\textcolor{red}{\mathbf{D}}
\end{bmatrix}.
```

The wye↔delta cross blocks are transposes of each other; the $3$ on the wye neutral is
the zero-sequence admittance path, so a zero from-side impedance makes that row
singular.

## 5. `n_winding` (general, WYE and/or DELTA)

For $\textcolor{red}{n_W}\ge 2$ windings, start from the OpenDSS-style short-circuit
matrix $\textcolor{brown}{\mathbf{Z}_B}$ (the $(\textcolor{red}{n_W}-1)\times(\textcolor{red}{n_W}-1)$
leakage referred to winding 1, built from the pairwise $\textcolor{red}{x_{\text{sc}}[i,j]}$
and per-winding resistances) and invert it, $\textcolor{brown}{\mathbf{Y}_B}=\textcolor{brown}{\mathbf{Z}_B}^{-1}$.
Expanding with winding 1 as the reference node and de-referring by the turns ratios
$\textcolor{red}{\mathbf{D}}=\operatorname{diag}(\textcolor{red}{N_k})$ gives the
per-winding admittance

```math
\textcolor{brown}{\mathbf{Y}_w}=\textcolor{red}{\mathbf{D}}^{-1}\,\textcolor{brown}{\mathbf{C}_{\text{ref}}}^{\text{T}}\,\textcolor{brown}{\mathbf{Y}_B}\,\textcolor{brown}{\mathbf{C}_{\text{ref}}}\,\textcolor{red}{\mathbf{D}}^{-1},
\qquad
[\textcolor{brown}{\mathbf{C}_{\text{ref}}}]_{i,:}=\mathbf{e}_1-\mathbf{e}_{i+1}.
```

This $\textcolor{red}{n_W}\times\textcolor{red}{n_W}$ winding admittance is stamped onto
the terminal nodes, once per phase $p$, through a connection-aware **coil incidence**
$\textcolor{brown}{\mathbf{P}}$: a WYE coil maps to its phase-neutral pair, a DELTA coil
to its phase-phase pair (selected by the winding's `delta_roll`, the vector-group
orientation). Summing over phases and adding the winding-2 shunt,

```math
\textcolor{brown}{\mathbf{Y}_x}=\sum_{p}\ \textcolor{brown}{\mathbf{P}}_p^{\text{T}}\,\textcolor{brown}{\mathbf{Y}_w}\,\textcolor{brown}{\mathbf{P}}_p
\;+\;\textcolor{brown}{Y_0}\,\text{(winding-2 coil)}.
```

This is the exact multi-winding leakage star; the 2-winding subtypes above are its
closed-form specialisations.

## 6. Regulators

Both regulator subtypes replace the nameplate ratio with the fixed-tap **effective
ratio** $\textcolor{red}{n^{\text{eff}}}$ from `tap_ratio` $\textcolor{red}{a}$ and
`regulator_type`: $\textcolor{red}{n^{\text{eff}}}=1/\textcolor{red}{a}$ (Type B,
default) or $\textcolor{red}{a}$ (Type A). Because an autotransformer is not galvanically
isolated, the leakage is the autotransformer sum
$\textcolor{brown}{Z}=\textcolor{brown}{Z^{\text{fr}}_x}+(\textcolor{red}{n^{\text{eff}}})^2\textcolor{brown}{Z^{\text{to}}_x}$
and the no-load shunt sits on the **from** side.

**`single_phase_autotransformer`.** Nodes
$[\,t^{\text{ph}}_{\text{fr}},\,t^{\text{ph}}_{\text{to}},\,t^{n}_{\text{fr}},\,t^{n}_{\text{to}}\,]$,
one core spanning phase-to-neutral on each side. With
$\textcolor{brown}{y_t}=1/\textcolor{brown}{Z}$, the primitive and connection are

```math
\textcolor{brown}{\mathbf{y}_{\text{prim}}}=\textcolor{brown}{y_t}
\begin{bmatrix}1 & -\textcolor{red}{n^{\text{eff}}}\\ -\textcolor{red}{n^{\text{eff}}} & (\textcolor{red}{n^{\text{eff}}})^2\end{bmatrix},
\qquad
\textcolor{brown}{\mathbf{C}}=
\begin{bmatrix}1 & 0 & -1 & 0\\ 0 & 1 & 0 & -1\end{bmatrix},
```

giving $\textcolor{brown}{\mathbf{Y}_x}=\textcolor{brown}{\mathbf{C}}^{\text{T}}\textcolor{brown}{\mathbf{y}_{\text{prim}}}\textcolor{brown}{\mathbf{C}}$ plus the from-winding shunt.
Reducing to the two phase nodes (neutrals at 0) recovers the familiar
$\bigl[\begin{smallmatrix}\textcolor{brown}{y_t} & -\textcolor{red}{n^{\text{eff}}}\textcolor{brown}{y_t}\\ -\textcolor{red}{n^{\text{eff}}}\textcolor{brown}{y_t} & (\textcolor{red}{n^{\text{eff}}})^2\textcolor{brown}{y_t}\end{smallmatrix}\bigr]$;
every column of the full $4\times4$ sums to zero (current conservation through the shared
neutral).

**`open_delta_regulator`.** Two **line-to-line** cores across the phase pairs implied by
`connection` (`ABBC`/`BCAC`/`CABA`), each with its own tap
$\textcolor{red}{n^{\text{eff}}_j}$ and primitive
$\textcolor{brown}{y_{t,j}}\bigl[\begin{smallmatrix}1 & -\textcolor{red}{n^{\text{eff}}_j}\\ -\textcolor{red}{n^{\text{eff}}_j} & (\textcolor{red}{n^{\text{eff}}_j})^2\end{smallmatrix}\bigr]$
across the from/to pair $(p,q)$, summed with the from-side shunt:

```math
\textcolor{brown}{\mathbf{Y}_x}=\sum_{j=1}^{2}\ \textcolor{brown}{\mathbf{C}}_j^{\text{T}}\,\textcolor{brown}{\mathbf{y}_{\text{prim},j}}\,\textcolor{brown}{\mathbf{C}}_j.
```

This is the device's natural line-to-line admittance — the "unspecified neutral" matrix
of Yan et al. (2018), IEEE Trans. Smart Grid **9**(3):2224–2234, [doi:10.1109/TSG.2016.2609440](https://doi.org/10.1109/TSG.2016.2609440), Eq. (11): the shared phase
carries $2\textcolor{brown}{y_t}$ on its diagonal (both regulators) and the from↔to
coupling scales as $\textcolor{red}{n^{\text{eff}}}$ and $(\textcolor{red}{n^{\text{eff}}})^2$ — the autotransformer factor, not an isolated-transformer ratio. The galvanic
straight-through of the shared phase (the paper's *common-neutral* model, its Eq. 14) is
a **topological constraint imposed in the OPF**, not folded into this primitive — folding
it in would conflate the device admittance with one particular elimination of the shared
node.

## 7. Validation and implementation

The blocks are built by
[`transformer_yprim`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/src/io/to_ybus.jl)
(`nwinding_yprim` for `n_winding`) and exported node-aligned via `export_yprim` /
`write_yprim`, for direct comparison with OpenDSS `Export Y`. Four gates hold each block
to the physics:

| Gate | Check |
|------|-------|
| **Symmetry** | $\lVert\textcolor{brown}{\mathbf{Y}_x}-\textcolor{brown}{\mathbf{Y}_x}^{\text{T}}\rVert_\infty<\epsilon$ for every block. |
| **Closed form** | the `single_phase` $2\times2$ block matches §2 exactly (unit-test oracle). |
| **Power balance** | $\mathfrak{R}[\textcolor{blue}{\mathbf{U}}^{\text{H}}\textcolor{brown}{\mathbf{Y}_x}\textcolor{blue}{\mathbf{U}}]=\sum_k\lvert\textcolor{blue}{I_k}\rvert^2\textcolor{red}{R_k}$ (winding resistive loss) for arbitrary $\textcolor{blue}{\mathbf{U}}$. |
| **OpenDSS cross-check** | dump `Yprim` per fixture, permute to the same node order, assert $\lVert\textcolor{brown}{\mathbf{Y}_x}^{\text{bmopf}}-\textcolor{brown}{\mathbf{Y}_x}^{\text{dss}}\rVert_\infty<\text{tol}$ — catches turns-ratio direction, $\sqrt3$ scaling, delta phase-shift, and shunt placement in one shot. |

A fifth gate ties this export to the [OPF constraints](transformer.md#6.-Implementation-in-BMOPFTools):
at a solved power-flow setpoint, the nodal currents $\textcolor{brown}{\mathbf{Y}_x}\textcolor{blue}{\mathbf{U}_x}$ match the OPF's own winding-current variables node-by-node,
including off-nominal fixed taps — so the admittance export and the optimisation model
cannot diverge.

!!! note "Current-variable convention (informational)"
    The Yd/Dy OPF winding-current *variables* are not the physical terminal currents used
    here: the OPF's $\textcolor{blue}{I^w_k}=\textcolor{red}{n^{\text{eff}}}\,\textcolor{blue}{I^{\text{phys}}_{w,k}}$ and $\textcolor{blue}{I^d_k}=\textcolor{blue}{I^{\text{phys}}_{d,k}}/\textcolor{red}{n^{\text{eff}}}$ carry the ratio scaling. The OPF is internally
    consistent (its voltage equations and current coupling use the same scaled
    convention throughout), so it produces correct voltages and power flows; this export
    uses the physical terminal currents via
    $\textcolor{brown}{\mathbf{C}}^{\text{T}}\textcolor{brown}{\mathbf{y}_{\text{prim}}}\textcolor{brown}{\mathbf{C}}$ and is therefore directly comparable to OpenDSS.
