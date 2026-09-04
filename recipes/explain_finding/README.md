# Explain one stable Finding code

Run from the repository root:

```sh
julia --startup-file=no --project=. recipes/explain_finding/recipe.jl
```

The equivalent CLI call is:

```sh
bin/bmopf explain-finding E.SOL.VOLT_VIOLATION --pretty
```

The response is a deterministic lookup in the checked offline registry generated
from `docs/src/findings.md`. It returns the code's canonical severity, namespace,
catalogue section, meaning, documentation hash, and any already-declared
scientific-contract links. It does not inspect a case or result.

This distinction matters pedagogically. `E.SOL.VOLT_VIOLATION` says what the
Finding class means; the particular Finding instance's `component_id`, `message`,
and `detail` say where and with what observed values it occurred. Neither layer
by itself proves the root cause or identifies a safe automatic repair. External
PowerIO conversion codes are deliberately refused because PowerIO owns their
catalogue.

The result has no PSK identity. A related tutorial or book claim does not turn
an ordinary package catalogue entry into a scientific assertion.
