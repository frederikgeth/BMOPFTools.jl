# Device-indexing witness (#408)

`roles.json` is a synthetic one-bus validation fixture with a declared `return`
neutral. Its three-phase star generator and phase-to-phase single-phase
generator have valid power-vector lengths. The source deliberately omits its
already-grounded trailing reference from both reference arrays. The IBR's
two-entry `q_max` is deliberately too short for its three phase branches.

At main `df6bc42bf`, `integrity_check` reports false dimension mismatches for
both generators and both source reference arrays, while missing the IBR defect.
The regression also adds a two-entry `vpp_max`: three phases have three unordered
pairs, which the old validator did not check.

The regression retains the invalid fields as negative controls and constructs
valid variants in memory. Tests cover neutral renaming, topology/pair counts,
permutations, scalar and length-one load-coefficient broadcasts, absent/empty
optional limits, malformed indexed values, role ambiguity, and JSON evidence.
Native OPF row tests independently check that each supported count matches the
rows actually stamped, including SI and per-unit builds. This is package-owned
evidence linked to PSK-000002, not a new scientific claim or physics model.
