# Model specification

!!! note "Status: prototype"
    This section is a **prototype** of a new, self-contained model + data
    specification. It covers **[Notation](notation.md)** and the components:
    **[Buses](bus.md)**, **[Lines](line.md)**, **[Switches](switch.md)**,
    **[Loads](load.md)**, **[Generators](generator.md)**, **[Shunts](shunt.md)**,
    **[Capacitors](capacitor.md)**, **[Voltage sources](source.md)**,
    **[Transformers](transformer.md)**, **[IBRs](ibr.md)**, and
    **[DC networks](dc.md)**; the **[Objective and feasibility](objective.md)**
    formulation; and the **[Impedance derivation](impedance.md)** and
    **[Time series](timeseries.md)** data models. This now spans the full network model;
    remaining work is refinement and Task-Force review rather than new components.

## Purpose

This section documents the four-wire distribution-system OPF **exactly as
BMOPFTools implements it**. It is written to eventually **replace** the LaTeX/PDF
*Mathematical Model and Data Model* specification maintained by the IEEE PES Task
Force, and to be lifted — unchanged — into that Task Force's own Documenter site so
the specification can evolve through pull requests rather than by editing a PDF.

Two principles govern every page:

1. **The implementation is the source of truth.** BMOPFTools' OPF engine
   (`ext/BMOPFOpfExt/`) is validated against OpenDSS. Every symbol, equation and
   bound below is transcribed from that code and cross-referenced to the exact
   `file:function` it comes from — not restated from memory or from the older PDF.
   Where the PDF, the JSON Schema and the code disagree, we say so in a
   **Reconciliation note** rather than paper over it.

2. **Everything is in SI.** Voltages in volts, currents in amperes, impedances in
   ohms, admittances in siemens, powers in watts/var/VA, angles in radians. Per-unit
   scaling is a numerical convenience the solver may apply internally; it is **out
   of scope** for this specification, and no per-unit quantity appears here.

## How each component page is organised

Every component page is split into two halves. The **foundational model** (parts
1–5) states the physics — the equations and notation a reader familiar with the
Task Force spec expects, written in clean complex-vector form and independent of any
solver. **Implementation in BMOPFTools** (part 6) then records how that model is
*realised* in code, where the realisation departs from the textbook statement, and
any data-model discrepancies. Keeping the two apart means the physics reads as
physics; the code-specific manoeuvres (rectangular splitting, expression
substitution, variable elimination) do not clutter it.

| Part | Question it answers |
|------|---------------------|
| **1. Data model** | Which JSON fields describe this component, with types, units, and required/optional status. |
| **2. Input symbols** | The mathematical symbol each field maps to (a *parameter*). |
| **3. Variables** | The unknowns this component introduces (a *variable*). |
| **4. Equality constraints** | The device physics — what the component *is*. |
| **5. Inequality constraints** | The bounds, split into **cartesian variable bounds** (box bounds on a variable's own components) and **engineering bounds** (physically meaningful magnitude/angle limits). |
| **6. Implementation in BMOPFTools** | How parts 3–5 are realised in `ext/BMOPFOpfExt/`, where the realisation differs from the foundational statement, the source map, and any code-vs-spec reconciliation notes. |

The **cartesian vs engineering** split (part 5) is deliberate. A *cartesian bound*
constrains the real and imaginary components of a decision variable directly — a
rectangle in the complex plane, cheap and convex, used mainly to bound the search.
An *engineering bound* constrains a quantity an engineer cares about — a voltage
magnitude, a thermal current, a sequence-component unbalance — and is generally a
circle (quadratic) or an angle sector (bilinear). Conflating the two hides which
limits are physical and which are numerical hygiene.

### Foundational model vs implementation

The foundational model is stated in **complex phasors**; BMOPFTools solves in
**rectangular real** variables, and takes several deliberate shortcuts that are exact
but not literal. The recurring differences, called out per page in part 6, are:

- **Rectangular realisation.** Each complex equation is built as its two real
  (real/imaginary) parts; each complex variable is two real variables.
- **In-place expression substitution.** Quantities the physics writes as their own
  variables — notably line and shunt **currents defined by an admittance,
  $\mathbf{I}^{\text{sh}}=\mathbf{Y}\mathbf{U}$** — introduce *no* solver variable.
  They are kept as affine JuMP expressions in the voltages and substituted directly
  wherever they appear (KCL, current limits), which is algebraically identical.
- **Variable elimination.** Where conservation makes one quantity the negative of
  another (e.g. a branch's two directional series currents), only one variable is
  declared and the other is an expression alias.

## Reading order

Start with **[Notation](notation.md)**: it defines the typography (how variables,
parameters, real and complex quantities are distinguished), the complex-phasor
symbols and their rectangular realisation, the transform matrices, the
element-wise bound idiom, and the set/topology machinery used on every later page.
Then read **[Buses](bus.md)** and **[Lines](line.md)**.

## Self-containment

This section links only within itself, so the whole `spec/` folder can be moved to
another repository without dangling references. It intentionally does not depend on
the rest of the BMOPFTools manual.
