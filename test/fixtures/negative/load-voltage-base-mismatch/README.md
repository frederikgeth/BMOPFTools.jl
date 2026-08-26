# Load voltage-base mismatch fixture

This hand-minimized fixture executes scientific contract
`load_voltage_base_consistency` for `PSK-000004`.

The bus source declares a 230 V phase-to-neutral magnitude. The DELTA ZIP load
incorrectly uses the same 230 V numeric value as its nominal anchor, although
its connection observes line-to-line voltage and therefore expects
`230*sqrt(3) = 398.37` V. BMOPFTools emits
`E.CONTRACT.LOAD_VOLTAGE_BASE_MISMATCH`; ordinary domain validation also emits
the related `W.LOAD.VNOM_MISMATCH`. The companion validated network uses the
connection-consistent line-to-line anchor and passes the implemented contract.

Run from the repository root:

```bash
julia --project=test --startup-file=no \
  test/fixtures/negative/load-voltage-base-mismatch/reproduce.jl
```

The fixture does not validate the source or transformer declarations, load-law
coefficients, units, solved operating point, network equations, or equipment
limits.
