# Switch-state topology scenarios

Status: steps 1 and 2 implemented on `codex/switch-topology-scenarios`;
mapped-conductor consequences and case trials remain. Keep this as
a branch planning artifact; replace its settled behavior with runtime
documentation and remove the plan before merging the implementation.

## Goal and data boundary

Explain how each **declared BMOPF switch state** changes the supplied network's
bus graph and mapped-conductor paths. The analysis reads one materialized BMOPF
snapshot, including its buses, lines, switches, transformers, voltage sources,
loads, and terminal maps. It needs no GIS, raw feeder export, inferred switch,
power-flow solution, or OPF result.

The current `connectivity_analysis` and `structure` results already include
closed switches as physical edges and omit open switches. They report the
declared-state graph, including physical cycle rank and parallel excess. The
new result should explain the *effect* of a declared switch, while preserving
the meaning of those existing fields and Findings.

## Scenarios and interpretation

| View | Edge rule | Main use |
|---|---|---|
| Declared snapshot | Lines, transformer winding branches, and closed switches | Reference component, cycle, and source-path counts. |
| Fixed backbone | Remove every switch edge | Show which connections rely on switching assets. |
| All-closed envelope | Include every valid switch edge | Show possible connectivity and physical cycles if all switches were closed. This is not an operating instruction. |
| One open switch closed | Change only that switch | Classify restoration versus cycle/parallel closure and source-component joining. |
| One closed switch opened | Change only that switch | Classify a bridge versus an alternate path and locate any lost source paths. |

An open switch whose endpoints are in **different** declared-state components
joins those components when closed; its physical cycle rank does not change.
If its endpoints are already connected, closing it raises physical cycle rank
by one, including when it parallels another branch. Opening a closed bridge
raises the component count by one; opening a non-bridge lowers cycle rank by
one. These are identities for valid bus-to-bus edges, not claims about whether
an operation is safe or feasible.

Record whether each affected component has zero, one, or multiple declared
voltage sources. This gives useful descriptions: a possible source path to an
unreached component, a loop within one source-connected component, or a tie
between source-containing components. A graph path is not proof that a bus is
energized: switch operability, protection, phase compatibility, voltage,
capacity, and synchronization remain unassessed. `all_closed_envelope` may
combine mutually exclusive switch positions.

## Proposed result contract

Add `report.results[:connectivity]["switch_scenarios"]` for every case. Return
an explicit `status = "inapplicable"` with zero switch count when no switch
records exist. For each assessment layer, use `assessed`, `inapplicable`, or
`indeterminate` with a reason; do not turn an invalid or absent `open_switch`
value into an assumed closed position. The BMOPF schema requires a Boolean
`open_switch`; the current general connectivity pass defaults missing values to
closed on malformed input, so the new result must state its own stricter
applicability clearly.

Suggested stable groups:

- `declared`, `fixed_backbone`, `all_closed_envelope`: bus, physical-edge,
  component, physical/simple-cycle, parallel-excess, and source-containing
  component counts. Keep all declared buses, including isolated buses.
- `switch_counts`: declared open/closed, valid/skipped, and assessed counts.
- `transition_counts`: classifications for open-to-closed and closed-to-open,
  source-path gains/losses, and source-component joins.
- `witnesses`: a deterministic, bounded list with switch ID, declared state,
  endpoints, class, `delta_components`, `delta_cycle_rank`, and compact source
  and bus/load counts. Counts cover all assessed switches even when witnesses
  are capped.
- `assessment`: scope and reasons for skipped or indeterminate comparisons.
  Bus-graph assessment needs valid state and endpoints; conductor assessment
  additionally needs valid terminal maps and declared bus terminals.

Keep the standard `analyze` report compact. If users need every switch record,
provide a Julia analysis API that returns the complete sorted table from the
same computation; add a curated JSON adapter only after its output and size
contract are reviewed. Do not infer switch states from graph cycles or raw
files.

Source-propagated voltage-tier labels are properties of the declared graph.
Annotate switch endpoints with those labels when available, but do not carry
them into a counterfactual as if they were independently measured nameplates.
Any voltage-compatibility check needs explicit comparable voltage evidence and
its own applicability rules.

## Implementation sequence

1. **Build one physical branch inventory.** Reuse the present bus/transformer
   projection and make switch edge IDs and validity explicit. Exclude invalid
   endpoints and self-loops from graph counts, retain their IDs as skipped
   evidence, and keep parallel members distinct. Preserve existing
   `structure` and `W.CONN.MESHED` semantics. Add unit tests for parity with
   the current declared-state graph.
2. **Add bus-graph scenario counts.** Compute declared and fixed-backbone
   components and the all-closed envelope. Classify each open switch from
   declared component IDs. Find closed-switch bridges using edge-ID-aware
   multigraph logic, so a parallel switch is not mistakenly called a bridge.
   Compute source-component and affected bus/load counts without rerunning a
   full graph search for every switch. Expose bounded witnesses in Markdown
   and complete counts in JSON. Emit no new Findings in this slice.
3. **Add mapped-conductor consequences.** Reuse terminal-map rules from
   `conductor_paths`; assess phase/neutral reachability independently of bus
   reachability. Transformer winding and voltage-source ports remain boundary
   ports: do not infer phase conversion or a solved operating point. Mark this
   layer inapplicable where maps are incomplete, without discarding a valid
   bus-graph assessment.
4. **Trial on switch-rich BMOPF cases and review Finding policy.** Compare
   source-path and conductor-path witnesses with the source model, document
   reproducible structural examples in tests, and measure runtime and report
   size. Review whether `E.CONN.DISCONNECTED` needs more precise evidence for
   a declared open-switch island. Keep `W.CONN.MESHED` tied to the declared
   snapshot; potential cycles in the all-closed envelope are descriptive.
   Introduce a new Finding only for a precise contradiction with explicit
   evidence, a stable code, and a reviewed applicability boundary.

The first public increment is complete when steps 1 and 2 produce deterministic
results on synthetic switch networks, render in Markdown/JSON, and preserve all
existing connectivity Findings and result fields. Steps 3 and 4 can follow as
separate reviewable increments. A case with no switch records must return
`inapplicable`, not a fabricated operational state.

## Verification and maintenance

Test the positive, negative, boundary, and serialization cases: zero switches;
open tie between source-fed and source-free components; open tie between two
source-containing components; open switch within one component; closed bridge;
closed switch with a parallel branch; transformer-mediated alternate path;
isolated buses; invalid/missing switch state or endpoint; partial terminal map;
and insertion-order independence. Check physical cycle identities after every
single-switch transition and retain a minimized witness for any algorithmic
failure. Add a synthetic large-case check so per-switch analysis does not
become a full graph traversal per switch.

When implementation changes APIs, Findings, fixtures, or source paths, update
`knowledge/executable.toml` and recipe metadata, regenerate the executable
export, and run the repository's stale-output/schema checks and Julia gates in
`AGENTS.md`. This plan makes no scientific preservation claim or new PSK
identity; any future contract that does must first link to a stable PSK ID.
