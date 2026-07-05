# Notation

This page defines the notation used throughout the [Model specification](index.md):
the typography that distinguishes variables from parameters and real from complex,
the voltage and current symbols and their rectangular realisation, the standard
transform matrices, the element-wise idiom used to write magnitude bounds, and the
set/topology machinery that links elements to buses.

All quantities are in **SI** units (V, A, Ω, S, W, var, VA, rad).

## Typography

A symbol's *typeface* and *colour* encode its type. This lets an equation be read at
a glance: whether a quantity is known input data or a solved unknown, and whether it
is real or complex.

| Symbol | Meaning |
|:------:|---------|
| $x$ | real scalar **variable** |
| $\mathbf{x}$ | real vector/matrix **variable** |
| $\textcolor{blue}{x}$ | complex scalar **variable** |
| $\textcolor{blue}{\mathbf{x}}$ | complex vector/matrix **variable** |
| $\textcolor{red}{x}$ | real scalar **parameter** |
| $\textcolor{red}{\mathbf{x}}$ | real vector/matrix **parameter** |
| $\textcolor{brown}{x}$ | complex scalar **parameter** |
| $\textcolor{brown}{\mathbf{x}}$ | complex vector/matrix **parameter** |
| $\textcolor{purple}{x}$ | string **parameter** |
| $\textcolor{purple}{\mathbf{x}}$ | array of string **parameters** |
| $\mathcal{X}$ | set |

Operators and accessors:

| Symbol | Meaning |
|:------:|---------|
| $\mathbf{X}^{\text{T}}$ | transpose |
| $\textcolor{blue}{\mathbf{X}}^{*}$ | (element-wise) complex conjugate |
| $\textcolor{blue}{\mathbf{X}}^{\text{H}}$ | conjugate transpose |
| $\circ$ | element-wise (Hadamard) product |
| $\textcolor{brown}{j}$ | imaginary unit, $\textcolor{brown}{j}^2=-1$ |
| $a \textcolor{brown}{\angle} b$ | polar form $a\, e^{\textcolor{brown}{j} b}$ |
| $\mathfrak{R}(\cdot),\ \mathfrak{I}(\cdot)$ | real / imaginary part |
| $\mathbf{1},\ \mathbf{0}$ | all-ones / all-zeros vector |

!!! note "Colour in this web rendering"
    Colour is applied to **symbol and parameter definitions** and to the headline
    equations, exactly as in the Task Force PDF. In long derivations colour is
    sometimes dropped for legibility; the type of any symbol is always its type at
    definition. Nothing about the model depends on colour — it is a reading aid.

## Voltage: complex phasor and its rectangular realisation

The primary voltage quantity at bus $\textcolor{red}{i}$ is a **complex, stacked
per-terminal vector**. For a four-terminal bus with phases $a,b,c$ and neutral $n$,

```math
\textcolor{blue}{\mathbf{U}_i}
=
\begin{bmatrix}
\textcolor{blue}{U_{i,a}} \\ \textcolor{blue}{U_{i,b}} \\ \textcolor{blue}{U_{i,c}} \\ \textcolor{blue}{U_{i,n}}
\end{bmatrix}
\in \mathbb{C}^{|\mathcal{N}_i|},
```

where $\textcolor{blue}{U_{i,p}}$ is the voltage of terminal $p$ **to ground**
(ground is a single $0\text{ V}$ reference across the network). The stacking order is
the bus's declared terminal order (see [Terminal names](#Terminal-names-and-maps)).

The complex vector decomposes into real components in rectangular or polar form:

```math
\textcolor{blue}{\mathbf{U}_i}
= \mathbf{U}_i^{\Re} + \textcolor{brown}{j}\,\mathbf{U}_i^{\Im}
= \mathbf{U}_i^{\text{mag}} \textcolor{brown}{\angle}\, \boldsymbol{\theta}_i,
```

with $\mathbf{U}_i^{\Re},\mathbf{U}_i^{\Im}\in\mathbb{R}^{|\mathcal{N}_i|}$ the real
and imaginary parts (black — real variables), $\mathbf{U}_i^{\text{mag}}$ the
magnitude and $\boldsymbol{\theta}_i$ the angle.

The foundational model on each page is written with the **complex** vectors. The
implementation solves in the **rectangular real** parts — one variable per part per
terminal — so every complex equality becomes a pair of real equalities; this
realisation is described in each page's *Implementation* section, not repeated in the
physics.

**Phase selection.** $\textcolor{blue}{\mathbf{U}_i}[\mathcal{P}]$ selects the phase
(non-neutral) sub-vector $[\textcolor{blue}{U_{i,a}};\textcolor{blue}{U_{i,b}};\textcolor{blue}{U_{i,c}}]$.

## Currents

Complex current vectors follow the same stacking. The **terminal current flowing
into element** at its bus is the primary quantity; for a line $\textcolor{red}{\ell}$
from bus $\textcolor{red}{i}$ toward bus $\textcolor{red}{j}$ it is
$\textcolor{blue}{\mathbf{I}_{\ell ij}}$, and it splits into a series and a shunt part
(see [Lines](line.md)):

```math
\textcolor{blue}{\mathbf{I}_{\ell ij}}
= \textcolor{blue}{\mathbf{I}^{\text{s}}_{\ell ij}} + \textcolor{blue}{\mathbf{I}^{\text{sh}}_{\ell ij}}.
```

The sign convention throughout is **positive current flows into the bus** at the
terminal where it is summed by Kirchhoff's current law (KCL).

## Standard transforms and constants

Several fixed matrices recur. With the unit rotation
$\textcolor{brown}{\alpha}=e^{\textcolor{brown}{j}2\pi/3}$:

**Phase-to-neutral** (four-terminal bus → three phase-to-neutral voltages):

```math
\textcolor{red}{\mathbf{M}^{Y}} =
\begin{bmatrix}
1 & 0 & 0 & -1\\
0 & 1 & 0 & -1\\
0 & 0 & 1 & -1
\end{bmatrix}.
```

**Phase-to-phase / delta** (line-to-line differences of the three phases):

```math
\textcolor{red}{\mathbf{M}^{\Delta}} =
\begin{bmatrix}
\phantom{-}1 & -1 & \phantom{-}0\\
\phantom{-}0 & \phantom{-}1 & -1\\
-1 & \phantom{-}0 & \phantom{-}1
\end{bmatrix}.
```

**Symmetrical components (Fortescue)**, mapping three phase quantities to
zero/positive/negative sequence:

```math
\textcolor{brown}{\mathbf{F}} = \frac{1}{3}
\begin{bmatrix}
1 & 1 & 1\\
1 & \textcolor{brown}{\alpha} & \textcolor{brown}{\alpha}^2\\
1 & \textcolor{brown}{\alpha}^2 & \textcolor{brown}{\alpha}
\end{bmatrix},
\qquad
\textcolor{blue}{\mathbf{U}^{\text{sym}}_i}
= \begin{bmatrix}\textcolor{blue}{U^{0}_i}\\ \textcolor{blue}{U^{1}_i}\\ \textcolor{blue}{U^{2}_i}\end{bmatrix}.
```

## The element-wise bound idiom

Magnitude bounds are written first as a vector inequality on magnitudes, then in an
equivalent **smooth (quadratic) form** using the Hadamard product $\circ$ and the
conjugate, which is what the solver receives. For a generic complex vector
$\textcolor{blue}{\mathbf{z}}$ with real bound vectors
$\textcolor{red}{\mathbf{z}^{\min}},\textcolor{red}{\mathbf{z}^{\max}}$:

```math
\textcolor{red}{\mathbf{z}^{\min}} \le |\textcolor{blue}{\mathbf{z}}| \le \textcolor{red}{\mathbf{z}^{\max}}
\quad\Longleftrightarrow\quad
\textcolor{red}{\mathbf{z}^{\min}}\!\circ\textcolor{red}{\mathbf{z}^{\min}}
\ \le\
\textcolor{blue}{\mathbf{z}}\circ\textcolor{blue}{\mathbf{z}}^{*}
\ \le\
\textcolor{red}{\mathbf{z}^{\max}}\!\circ\textcolor{red}{\mathbf{z}^{\max}}.
```

The upper (circle) bound is convex; a non-zero lower bound is non-convex. Component
$k$ reads $(\textcolor{red}{z^{\min}_k})^2 \le \mathfrak{R}(\textcolor{blue}{z_k})^2 + \mathfrak{I}(\textcolor{blue}{z_k})^2 \le (\textcolor{red}{z^{\max}_k})^2$,
i.e. `vr^2 + vi^2` in the code.

This is the **engineering-bound** idiom. It is distinct from a **cartesian bound**,
which constrains a variable's own real/imaginary components with a box
$\underline{x}\le\mathfrak{R}(\textcolor{blue}{z_k})\le\overline{x}$ (and likewise for
$\mathfrak{I}$) — a rectangle, not a circle. Both appear in part 5 of each component
page and are kept separate.

## Sets and indices

Finite sets collect the network's elements; each element is referenced by a unique
string ID.

The **element sets** each collect one kind of network element:

| Symbol | Represents | Index | Alt. index |
|:------:|------------|:-----:|:----------:|
| $\mathcal{P}$ | phases, e.g. $\{a,b,c\}$ | $p$ | $q$ |
| $\mathcal{N}$ | terminals (nodes), e.g. $\mathcal{P}\cup\{n\}$ | $p$ | $q$ |
| $\mathcal{F}$ | configurations, $\{\text{WYE},\text{DELTA},\text{SINGLE\_PHASE}\}$ | $f$ | |
| $\mathcal{B}$ | buses | $i$ | $j$ |
| $\mathcal{L}$ | lines | $\ell$ | |
| $\mathcal{X}$ | transformers & regulators | $x$ | |
| $\mathcal{W}$ | switches | $w$ | |
| $\mathcal{S}$ | voltage sources | $s$ | |
| $\mathcal{G}$ | generators | $g$ | |
| $\mathcal{D}$ | loads (demand) | $d$ | |
| $\mathcal{H}$ | shunts | $h$ | |
| $\mathcal{V}$ | IBRs | $r$ | |
| $\mathcal{K}$ | capacitors | $\kappa$ | |

$\mathcal{N}_i\subseteq\mathcal{N}$ denotes the terminals of bus $i$. (Libraries —
linecodes, wire data, line geometries, control profiles, time series — are referenced
by string id, not collected as topological sets.)

From these, **derived sets** capture how elements attach to buses. There are four
families — topology, connectivity, terminal mappings, and configurations — summarised
in one table at the [end of this section](#Overview-of-derived-sets); the prose below
defines each family, and $\mathcal{T},\mathcal{C},\mathcal{M},\mathcal{R}$ are reserved
for them (distinct from the element sets above).

### Topology: linking branches to buses

Branch elements (lines, transformers, switches) connect two buses. A **triple index**
$\ell i j$ names line $\ell$ oriented from bus $i$ to bus $j$; the *forward* topology set
and its *reverse* are

```math
\ell ij \in \mathcal{T}^{L\rightarrow} \subset \mathcal{L}\times\mathcal{B}\times\mathcal{B},
\qquad
\mathcal{T}^{L\leftarrow} = \{\,\ell ji \mid \ell ij \in \mathcal{T}^{L\rightarrow}\,\},
\qquad
\mathcal{T}^{L} = \mathcal{T}^{L\rightarrow}\cup\mathcal{T}^{L\leftarrow}.
```

The triple index allows parallel branches between the same bus pair. Transformer and
switch topologies $\mathcal{T}^{X},\mathcal{T}^{W}$ are defined identically, and the
**network topology** is their union, $\mathcal{T}=\mathcal{T}^{L}\cup\mathcal{T}^{X}\cup\mathcal{T}^{W}$
(likewise for the forward and reverse senses).

### Connectivity: linking nodal elements to buses

Nodal elements attach to a single bus, indexed by (element, bus):

```math
d i \in \mathcal{C}^{D}\subset\mathcal{D}\times\mathcal{B},
\quad
g i \in \mathcal{C}^{G},
\quad
h i \in \mathcal{C}^{H},
\quad
r i \in \mathcal{C}^{V},
\quad
\kappa i \in \mathcal{C}^{K},
\quad
s i \in \mathcal{C}^{S}.
```

This model version permits a single voltage source, so the source bus set
$\mathcal{I}^{\text{source}}=\{i : si\in\mathcal{C}^{S}\}$ has $|\mathcal{I}^{\text{source}}|=1$.

### Terminal names and maps

A bus declares an **ordered** list of terminal names
$\textcolor{purple}{\mathbf{N}_i}$ (`terminal_names`), e.g.
$[\texttt{"a"},\texttt{"b"},\texttt{"c"},\texttt{"n"}]$. Element vectors and matrices
stack in this order. Terminal names are strings; common conventions include
$\{a,b,c,n\}$, $\{1,2,3,n\}$, and IEC $\{L1,L2,L3,N\}$.

Every element carries a **terminal map** — the string array
$\textcolor{purple}{\mathbf{N}_{\ell i}}$ (`terminal_map_from`),
$\textcolor{purple}{\mathbf{N}_{\ell j}}$ (`terminal_map_to`) for a line — listing which
of its bus's terminals each conductor connects to, so per-phase properties align across
the network. As a *set*, a terminal mapping is written $\mathcal{M}^{\bullet}$: a member
$d\,z\,p$ of the load mapping $\mathcal{M}^{D}$ says load $d$'s conductor at order $z$
maps to bus terminal $p$; branch mappings carry an extra bus index ($\ell i z p$).

The **neutral terminal** $n$ of a bus is identified by the bus's declaration (an
explicit neutral field, or a terminal named `"n"`/`"N"`). If a bus has no neutral,
all its terminals are treated as phases.

### Configurations

Loads and generators declare a connection **configuration** $f\in\mathcal{F}$
(WYE / DELTA / SINGLE\_PHASE). The configuration sets pair each element with its
configuration: $d f\in\mathcal{R}^{D}$ for loads, $g f\in\mathcal{R}^{G}$ for generators.

### Grounding

**Ground** is a single $0\text{ V}$ reference. Terminals listed in a bus's
`perfectly_grounded_terminals` form the ground mapping
$i p \in \mathcal{M}^{\emptyset}\subset\mathcal{B}\times\mathcal{N}$; their voltage is
fixed to zero. Lines and shunts always carry an implicit ground connection (their
shunt admittance is defined to ground). See [Grounding](grounding.md) for the full model.

### Overview of derived sets

All topology, connectivity, terminal-mapping, and configuration sets, with the tuple
that indexes each:

| Symbol | Represents | Member tuple |
|:------:|------------|:------------:|
| $\mathcal{T}^{L\rightarrow},\ \mathcal{T}^{L\leftarrow},\ \mathcal{T}^{L}$ | line topology — forward, reverse, combined | $\ell ij$ |
| $\mathcal{T}^{X\rightarrow},\ \mathcal{T}^{X\leftarrow},\ \mathcal{T}^{X}$ | transformer topology | $x ij$ |
| $\mathcal{T}^{W\rightarrow},\ \mathcal{T}^{W\leftarrow},\ \mathcal{T}^{W}$ | switch topology | $w ij$ |
| $\mathcal{T}^{\rightarrow},\ \mathcal{T}^{\leftarrow},\ \mathcal{T}$ | network topology (union of the above) | $\cdot\,ij$ |
| $\mathcal{C}^{S}$ | voltage-source–bus connectivity | $s i$ |
| $\mathcal{C}^{G}$ | generator–bus connectivity | $g i$ |
| $\mathcal{C}^{D}$ | load–bus connectivity | $d i$ |
| $\mathcal{C}^{H}$ | shunt–bus connectivity | $h i$ |
| $\mathcal{C}^{V}$ | IBR–bus connectivity | $r i$ |
| $\mathcal{C}^{K}$ | capacitor–bus connectivity | $\kappa i$ |
| $\mathcal{I}^{\text{source}}$ | source bus set ($\lvert\cdot\rvert=1$) | $i$ |
| $\mathcal{M}^{S},\mathcal{M}^{G},\mathcal{M}^{D},\mathcal{M}^{H},\mathcal{M}^{V},\mathcal{M}^{K}$ | nodal terminal mappings | $\cdot\,z\,p$ |
| $\mathcal{M}^{L},\mathcal{M}^{X},\mathcal{M}^{W}$ | branch terminal mappings | $\cdot\,i\,z\,p$ |
| $\mathcal{M}^{\emptyset}$ | ground terminal mapping | $i p$ |
| $\mathcal{R}^{D},\ \mathcal{R}^{G}$ | load / generator configurations | $\cdot\,f$ |

**Matrices** (e.g. impedance) are stored **row-first** with an underscore delimiter:
matrix entry $A_{kj}$ is the field `A_k_j`, 1-indexed. So `R_series_1_2` is the
$(1,2)$ entry of the series-resistance matrix.

## A minimal example (bus + line)

Two four-terminal buses $\mathcal{B}=\{\texttt{A},\texttt{B}\}$ joined by one line
$\mathcal{L}=\{\ell\}$ from `A` to `B`, each terminal mapped straight through:

```math
\mathcal{T}^{L\rightarrow} = \{\ell\,\texttt{A}\,\texttt{B}\},\quad
\textcolor{purple}{\mathbf{N}_\texttt{A}} = \textcolor{purple}{\mathbf{N}_\texttt{B}} = [a,b,c,n],\quad
\textcolor{purple}{\mathbf{N}_{\ell\texttt{A}}} = \textcolor{purple}{\mathbf{N}_{\ell\texttt{B}}} = [a,b,c,n].
```

If terminal `n` of bus `B` is perfectly grounded,
$\mathcal{M}^{\emptyset}=\{\texttt{B}\,n\}$ and $\textcolor{blue}{U_{\texttt{B},n}}=0$.
This is the running example used on the [Buses](bus.md) and [Lines](line.md) pages.
