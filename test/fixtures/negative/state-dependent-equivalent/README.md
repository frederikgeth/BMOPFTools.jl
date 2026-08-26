# Fixed versus state-dependent equivalent fixture

The source map varies with `load_scale` over `[0.8, 1.2]`. The negative target
freezes the map at the calibration state and omits an update rule, so it cannot
be promoted to a reusable state-dependent equivalent. The exact-target
companion declares the same domain, base state, and recomputation provenance;
the contract passes that declaration narrowly, without proving the nonlinear
map or decision equivalence.
