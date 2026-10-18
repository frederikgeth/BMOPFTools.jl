# Terminal-usage bookkeeping witness (#410)

This synthetic native case distinguishes three labels: `extra` exists on a
bus and a nested transformer winding but has no declared role; `spare` is a
declared bus conductor without a component connection; and `unused` is a role
declaration with no use anywhere in the supported AC representation.

Only `unused` merits the informational unused-role-label Finding. The existing
unclassified-terminal Finding for `extra` must retain both bus and winding
paths. This fixture tests representation bookkeeping associated with PSK-000002;
it makes no electrical-feasibility or grounding-sufficiency claim. No solver or
external equipment data is required.
