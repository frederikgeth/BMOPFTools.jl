# Floating reference and singularity fixture

The source declares one connected, fully referenced island. The target loses
the reference and one rank, so a solver-facing transformation must stop rather
than treating the target as an equivalent network. The exact companion keeps
both declarations aligned and passes only the reference/rank boundary; it does
not replace equation-level or solver-specific validation.
