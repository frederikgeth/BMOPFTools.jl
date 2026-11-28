# [Accept and track findings](@id howto-accept-findings)

Not every finding is a defect. A dangling bus can be a deliberate spare way; a
uniform load allocation can be the study design. This page shows how to live
with such a finding without losing track of it.

BMOPFTools has **no switch that silences a code**;
[report consolidation](analysis.md#Report-consolidation) only merges findings
that state the same fact. A finding you accept is still raised on the next
run. That is intentional: a silenced finding is invisible to the
next person, and to you in six months. What you keep instead is a short record
of the decision, and a check that tells you when something *new* appears.

```@example accept
using BMOPFTools

fixture = joinpath(pkgdir(BMOPFTools), "test", "data", "profiler_systems",
                   "eu_tn_four_wire.json")
net = parse_bmopf(fixture)
# A spare feeder way, kept on purpose.
net["bus"]["spare"] = Dict{String,Any}("terminal_names" => ["a", "b", "c", "n"])
net["line"]["spare_way"] = Dict{String,Any}("bus_from" => "lv1", "bus_to" => "spare",
    "terminal_map_from" => ["a", "b", "c", "n"], "terminal_map_to" => ["a", "b", "c", "n"],
    "linecode" => "cable", "length" => 25.0)
report = analyze(net)
for f in warnings(report)
    println(f.code, "  ", f.message)
end
```

## Filter by code

Findings are plain values. Select by code and component, never by message
text:

```@example accept
dangling = [f for f in report.findings if f.code == "W.CONN.DANGLING"]
println(length(dangling), " finding; buses: ",
        report.results[:connectivity]["dangling_buses"])
```

## Keep a decision ledger

A ledger is a small table next to the case: which finding, on which component,
what was decided, by whom and why. Any format works; a vector of named tuples
is enough to show the idea.

```@example accept
ledger = [
    (code = "W.CONN.DANGLING", component = nothing, decision = "accepted",
     by = "j.doe", on = "2026-11-26",
     reason = "Bus 'spare' is a deliberate spare way for a planned customer."),
]

accepted(f) = any(d -> d.code == f.code && d.component == f.component_id, ledger)

open_items = [f for f in report.findings if f.severity != INFO && !accepted(f)]
println(length(open_items), " open warning(s) or error(s)")
```

The finding is still in the report. The ledger says it has been looked at.

A decision is about evidence, so record what you saw. If the list of dangling
buses changes, the old decision no longer covers it:

```@example accept
net["bus"]["orphan"] = Dict{String,Any}("terminal_names" => ["a", "b", "c", "n"])
net["line"]["orphan_way"] = Dict{String,Any}("bus_from" => "lv2", "bus_to" => "orphan",
    "terminal_map_from" => ["a", "b", "c", "n"], "terminal_map_to" => ["a", "b", "c", "n"],
    "linecode" => "cable", "length" => 12.0)
later = analyze(net)
println(later.results[:connectivity]["dangling_buses"])
```

The code is the same, and the ledger would call it accepted. Guard against that
by recording the evidence the decision was about, and comparing it:

```@example accept
decided_buses = ["spare"]
current_buses = sort(later.results[:connectivity]["dangling_buses"])
println(current_buses == decided_buses ? "decision still applies" :
        "evidence changed: review again (now $(current_buses))")
```

## Gate on what is new

In a script or a CI job, fail on errors, and on warnings nobody has decided
about:

```@example accept
function gate(report, ledger)
    isempty(errors(report)) || return "FAIL: $(length(errors(report))) error(s)"
    undecided = [f.code for f in warnings(report)
                 if !any(d -> d.code == f.code && d.component == f.component_id, ledger)]
    isempty(undecided) ? "PASS" : "REVIEW: undecided $(sort(unique(undecided)))"
end

println(gate(report, ledger))
println(gate(report, []))
```

A second useful gate is a diff against the last accepted report: the set of
codes should not grow without a reason.

```@example accept
baseline = Set(f.code for f in report.findings)
println("new codes: ", sort(collect(setdiff(Set(f.code for f in later.findings), baseline))))
```

## Roll-ups and per-component decisions

A [roll-up](analysis.md#Report-consolidation) Finding has `component_id`
`nothing`, so a per-component ledger cannot match it. Expand the report first:

```julia
per_component = expand_findings(report)       # one Finding per component
undecided = [f for f in per_component if f.severity != INFO && !accepted(f)]
```

## Disclose what you accepted

When a case is shared or published, ship three things together: the case, the
rendered report, and the ledger. A reader then sees every finding, and for each
one you chose to live with, the reason.

```@example accept
render(report, "case-report.md")
open("case-decisions.tsv", "w") do io
    println(io, "code\tcomponent\tdecision\tby\ton\treason")
    for d in ledger
        println(io, join((d.code, something(d.component, ""), d.decision, d.by, d.on, d.reason), '\t'))
    end
end
print(read("case-decisions.tsv", String))
```

## Related

- Spatial review candidates have a built-in decision record with evidence
  fingerprints: see the [spatial cleanup tutorial](tutorial_spatial_cleanup.md).
- To change when a finding fires at all, see
  [Tune profiler thresholds](howto_thresholds.md).
- For deciding *what* to accept, see the
  [findings triage tutorial](tutorial_triage.md).
