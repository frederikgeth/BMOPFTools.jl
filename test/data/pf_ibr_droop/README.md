# Power-flow inverter rating-base witness (#447)

This synthetic native BMOPF case minimizes #447 to an inverter connected
directly to a prescribed 250 V source. All quantities are SI. The inverter's
6000 VA rating is the per-phase base for its VAR_MAX Volt-var equality and
S_MAX Volt-watt cap. Deleting that rating incorrectly makes both bases zero.
At 250 V the Volt-var response is approximately -2000 var, not zero.

The deliberately small 0.01 A current limit must be ignored by `solve_pf`.
Test variants prescribe phase voltages and active power, exercise SINGLE_PHASE
and FOUR_LEG connections, and independently evaluate the smooth control laws.
Some variants exceed the apparent-power rating to verify that preserving the
controller base does not re-enable the power-flow apparent-power constraint.
Volt-watt remains an inequality; fixed active-power setpoints make these
witnesses determined without adding a dispatch objective.

These are executable equation/regression witnesses associated with the existing
PSK-000013 evidence paths, not a general feasibility or convergence claim.
