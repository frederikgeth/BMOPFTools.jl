# Model specification

!!! note "Status: prototype"
    This section is a **prototype** of a new, self-contained model + data
    specification spanning the full network model: foundations
    ([Background & scope](scope.md), [Notation](notation.md),
    [Data input formatting](data-format.md), [Grounding](grounding.md),
    [Worked example](example.md), [Document metadata](metadata.md)); every component
    ([Buses](bus.md), [Lines](line.md), [Switches](switch.md), [Loads](load.md),
    [Generators](generator.md), [Shunts](shunt.md), [Capacitors](capacitor.md),
    [Voltage sources](source.md), [Transformers](transformer.md),
    [Regulators](regulator.md), [IBRs](ibr.md),
    [DC networks](dc.md)); the [Objective and feasibility](objective.md) formulation;
    and the [Impedance derivation](impedance.md), [Control profiles](control-profile.md),
    and [Time series](timeseries.md) data models. Remaining work is refinement and
    Task-Force review rather than new components.

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

## Model summary

The complete feasible set at a glance — the objective, every bound, and every device
constraint, with the page that defines each. Bounds are optional (an absent bound is
not enforced); constraints are always active for the elements present.

| Category | Item | Page |
|----------|------|------|
| **Objective** | Minimise active-power dispatch cost | [Objective](objective.md#Objective) |
| **Voltage bounds** | Phase-to-ground, -neutral, -phase, sequence, neutral cap, angle | [Buses](bus.md#Engineering-bounds) |
| **Current bounds** | Line / switch / transformer thermal, generator & IBR current | [Lines](line.md#Engineering-bounds), [Switches](switch.md), [Generators](generator.md#Engineering-bounds), [IBRs](ibr.md#Engineering-bounds) |
| **Power bounds** | Generator/IBR P·Q box + apparent-power circle; transformer rating; line apparent power | [Generators](generator.md#Engineering-bounds), [IBRs](ibr.md), [Transformers](transformer.md#Engineering-bounds) |
| **KVL / Ohm's law** | Line series drop + π-shunt; DC branch | [Lines](line.md#4.-Equality-constraints), [DC networks](dc.md#DC-branches) |
| **KCL** | Nodal current balance (AC and DC) | [Buses](bus.md#Kirchhoff's-current-law), [DC networks](dc.md#DC-buses) |
| **Device behaviour** | Load & generator power; IBR power + control law; transformer & regulator winding pairs; switch state; shunt/capacitor admittance current | [Loads](load.md), [Generators](generator.md), [IBRs](ibr.md), [Transformers](transformer.md), [Regulators](regulator.md), [Switches](switch.md), [Shunts](shunt.md), [Capacitors](capacitor.md) |
| **Reference / grounding** | Voltage-source fixing; perfect & impedance grounding | [Voltage sources](source.md), [Grounding](grounding.md) |
| **Relaxation** | Elastic-slack feasibility formulation | [Feasibility](objective.md#Feasibility-relaxation) |

## Reading order

Start with the **foundations**:

1. **[Background & scope](scope.md)** — why the specification exists, what it covers, and
   the design choices behind it.
2. **[Notation](notation.md)** — typography (variables vs parameters, real vs complex),
   the complex-phasor symbols and their rectangular realisation, transform matrices, the
   element-wise bound idiom, and the set/topology machinery used on every later page.
3. **[Data input formatting](data-format.md)** — units, how complex numbers and matrices
   are encoded in JSON, and required-vs-optional field semantics.
4. **[Grounding](grounding.md)** — the common-reference ground model that the component
   pages apply locally.
5. **[Worked example](example.md)** — every set constructed from one small network, to
   make the abstract machinery concrete.

Then the **components** (start with [Buses](bus.md) and [Lines](line.md)), the
[Objective and feasibility](objective.md) formulation, and the data-model pages
([Impedance derivation](impedance.md), [Control profiles](control-profile.md),
[Time series](timeseries.md), [Document metadata](metadata.md)). The
[Modelling notes & FAQ](faq.md) collects recurring case-building questions, and
[References & further reading](references.md) points to the textbooks and papers behind
the model.

## Self-containment

This section links only within itself, so the whole `spec/` folder can be moved to
another repository without dangling references. It intentionally does not depend on
the rest of the BMOPFTools manual.
