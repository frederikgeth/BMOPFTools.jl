# OpenDSS semantic intake witness

`Master.dss` is an independently authored three-bus, four-conductor fixture.
The transformer wye star defaults to node 0; the feeder neutral is node 4,
earthed through 0.3 Ω at the transformer bus and 10 Ω at the customer.
These identities are associated with PSK-000002. Phase evidence is associated
with PSK-000006; this fixture does not widen either scientific claim.

`test/opendss_semantics_tests.jl` makes explicit-neutral and `leadlag` variants
without external input. It checks terminal identity, perfect versus finite
grounding, native OpenDSS transformer primitives, optional native SI/per-unit
power-flow neutral voltages, qualified reports, and JSON round trips.
The `leadlag` export loss remains a blocking source-preservation gap rather
than being repaired by an inferred terminal permutation.

This finite fixture does not certify arbitrary OpenDSS node labels, protective
earthing installations, fault behavior, source/session frequency equivalence,
or lossless PowerIO conversion outside its tested domain.
