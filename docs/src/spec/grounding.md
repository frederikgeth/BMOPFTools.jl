# Grounding

In a four-wire model the neutral and earth are explicit, and how each element connects
to ground determines the return paths for current. For a worked comparison of floating,
impedance-grounded, and perfectly grounded neutrals, and the Kron-reduction and
sequence-coordinate consequences, see the [grounding tutorial](../tutorial_grounding.md).

The foundational model is in the [Grounding page of the BMOPF specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/stable/spec/grounding/). This page records where BMOPFTools extends it.

## BMOPFTools notes

- **Perfect grounding** of a bus terminal (`perfectly_grounded_terminals`) pins it to
  0 V with a free earth-injection current balancing its KCL; see
  [Buses](bus.md#Perfect-grounding).
- **Transformer winding neutrals.** BMOPFTools adds an *internal* winding-neutral
  grounding impedance, `r/x_neutral_from`/`_to` (OpenDSS `rneut`/`xneut`), on
  `single_phase`, `center_tap`, `wye_delta`, and `delta_wye` transformers; see
  [Transformers](transformer.md#Loss-components). In the specification transformers
  never connect to ground, and external grounding remains a bus property or a
  [shunt](shunt.md).
- **DC networks** follow the same idiom: a `dc_grounding` with $r=0$ is a perfect ground
  ($v^{\text{dc}}=0$, free earth current); $r>0$ grounds through an impedance (see
  [DC networks](dc.md#dc_grounding)).
