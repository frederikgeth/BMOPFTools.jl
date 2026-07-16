# Grounding

Grounding is the subtle heart of a four-wire model: the neutral and earth are explicit,
and how each element connects to ground determines the return paths for current. This
page consolidates the grounding model that the component pages apply locally. Symbols
are defined in [Notation](notation.md). For a worked comparison of floating,
impedance-grounded, and perfectly-grounded neutrals — and the Kron-reduction
and sequence-coordinate consequences — see the
[grounding tutorial](../tutorial_grounding.md).

## Ground as a common reference

**Ground is a single $0\text{ V}$ reference** — a "copper plate" shared across the
entire network. It is not a per-element node: elements connect to a **bus terminal**,
and that terminal may (or may not) connect to ground. Because ground is a common
reference, no separate ground node is indexed in element matrices, and the terminal
name **`"g"` is reserved** for the common ground across all elements.

## Two ways a terminal reaches ground

- **Perfect grounding** — a bus terminal listed in `perfectly_grounded_terminals` is
  pinned to the reference, $\textcolor{blue}{U_{i,p}}=0$. Current can still flow into
  earth there: a free earth-injection current balances the terminal's KCL (see
  [Buses](bus.md#Perfect-grounding)). This is a **bus property**.
- **Grounding through an impedance** — modelled as a [shunt](shunt.md) (or capacitor)
  between the terminal and ground, e.g. a single-entry admittance
  $\textcolor{brown}{Y_{h,nn}}$ on the neutral grounds it through $1/\textcolor{brown}{Y_{h,nn}}$.

An **ungrounded** terminal has neither; its voltage floats, determined by the network
equations. A bus whose terminals are all ungrounded needs no grounding data.

## Which elements connect to ground

| Element | Connection to ground | Note |
|---------|:--------------------:|------|
| Load | never | Grounding is a bus property or a shunt |
| Generator | never | Grounding is a bus property or a shunt |
| Transformer | never | Winding neutral grounding via `r/x_neutral_*` is *internal*; external grounding is a bus/shunt |
| Switch | never | Switches are not grounded |
| Bus terminal | **optional** | `perfectly_grounded_terminals` for perfect grounding; a shunt for impedance grounding |
| Line | **always (implicit)** | A non-zero shunt admittance passes current to ground |
| Shunt | **always (implicit)** | The admittance is defined between terminals and ground |
| Voltage source | **always** | Source voltages are defined line-to-ground |

The "always" elements (lines, shunts, voltage sources) carry an implicit ground
connection and need no grounding declaration. The only element that *optionally*
declares grounding is the **bus** — everything else routes through a bus terminal or is
intrinsic to the element.

## In the mathematical model

Perfect grounding contributes the equality $\textcolor{blue}{U_{i,p}}=0$ for every
$ip\in\mathcal{M}^{\emptyset}$ (the ground map) and a free earth current so KCL still
balances. Impedance grounding contributes a linear admittance current
$\textcolor{brown}{Y}\,\textcolor{blue}{U}$ to KCL, exactly like any [shunt](shunt.md).
No grounding scheme reduces the conductor matrices — neutrals and earth conductors stay
explicit, which is what makes this a genuinely four-wire formulation.

The DC network follows the same idiom: a `dc_grounding` with $r=0$ is a perfect ground
($v^{\text{dc}}=0$, free earth current); $r>0$ grounds through an impedance (see
[DC networks](dc.md#dc_grounding)).
