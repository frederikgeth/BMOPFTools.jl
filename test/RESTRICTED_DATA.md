# External restricted dataset integration

The CSIRO Australian MV/LV dataset (DOI: 10.25919/ghnz-bk28) is CC BY-NC-SA
4.0. Its `LV/`, `MV/`, `MVLVmeshed/`, and combined `Master.dss` now live in
`BMOPFDraftData/test/data`. The derived `lv1_14bus.json`,
`lv1_14bus_timeseries.json`, and `lv1_14bus_report.md` live under its `LV/`.
Original licence files and relative OpenDSS redirects are preserved.

Run the complete package suite including these optional integration tests:

```sh
BMOPF_RESTRICTED_DATA=/path/to/BMOPFDraftData/test/data julia --project=test --startup-file=no test/runtests.jl
```

The normal package suite requires no companion checkout. It reports one skipped
integration group when the variable is unset. An explicitly configured directory
with missing fixtures fails; it never silently substitutes another network.
`restricted_data_tests.jl` retains the real-feeder import/source-ledger,
transformer serialization, and daily OPF checks. Synthetic snapshot and
transport tests run without external data. The analysis recipe uses its own
BSD-licensed synthetic input.

Dataset tutorials use the same environment variable and display static code;
the documentation build does not execute these external-data examples.
`scripts/regenerate_lv1_14bus.jl` writes derivatives into the external `LV/`
directory. It requires the variable explicitly, including for output.

ENWL is now also external in BMOPFDraftData/test/data/ENWL. Its top-level
CC BY notice and older non-commercial headers remain unchanged and unresolved.
The corpus scripts use the same environment variable to include it. Git history
has not been rewritten.
