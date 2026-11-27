# [Spatial cleanup: coordinates against line lengths](@id spatial-cleanup)

*Use bus coordinates as an independent check on line lengths: declare the
coordinate frame, read the geometry findings, work a review queue, correct the
data, and check again.*

A line's electrical length sets its impedance, so a wrong length is a wrong
impedance. Coordinates give a second opinion: a line cannot be shorter than the
straight distance between its ends, and it is rarely many times longer. This
tutorial follows that check from start to finish on a small street feeder.
Every block is executed when the documentation is built.

For the full reference of the spatial result, the candidate codes and the
evidence model, see [Spatial diagnostics](spatial_diagnostics.md).

!!! note "Prerequisites"
    Only `BMOPFTools`.

## 1. A feeder with coordinates

Twelve spans of about 50 m along a street in Brisbane, one customer per pole.
The lengths are a few percent longer than the straight distances, as real
conductors are.

```@example spatial
using BMOPFTools

function street(; n = 12, lon0 = 153.02, lat0 = -27.47, span_m = 50.0)
    net = Dict{String,Any}(
        "meta" => Dict{String,Any}("crs" => "EPSG:7844"),          # GDA2020 longitude/latitude
        "terminal_conventions" => Dict{String,Any}("phase" => ["a", "b", "c"],
                                                   "neutral" => ["n"], "earth" => String[]),
        "bus" => Dict{String,Any}(), "line" => Dict{String,Any}(), "load" => Dict{String,Any}(),
        "voltage_source" => Dict{String,Any}("grid" => Dict{String,Any}("bus" => "p00",
            "terminal_map" => ["a", "b", "c"], "v_magnitude" => fill(240.0, 3),
            "v_angle" => [0.0, -2π / 3, 2π / 3])),
        "linecode" => Dict{String,Any}("abc" => merge(
            Dict{String,Any}("R_series_$(i)_$(j)" => (i == j ? 3e-4 : 5e-5) for i in 1:4, j in 1:4),
            Dict{String,Any}("X_series_$(i)_$(j)" => (i == j ? 3e-4 : 1e-4) for i in 1:4, j in 1:4),
            Dict{String,Any}("i_max" => fill(200.0, 4)))))
    step = span_m / (111_195.0 * cosd(lat0))                       # degrees of longitude per span
    for k in 0:n
        id = "p" * lpad(k, 2, '0')
        net["bus"][id] = Dict{String,Any}("terminal_names" => ["a", "b", "c", "n"],
            "longitude" => lon0 + k * step, "latitude" => lat0)
        k == 0 && (net["bus"][id]["perfectly_grounded_terminals"] = ["n"])
        k == 0 && continue
        prev = "p" * lpad(k - 1, 2, '0')
        net["line"]["s" * lpad(k, 2, '0')] = Dict{String,Any}("bus_from" => prev, "bus_to" => id,
            "terminal_map_from" => ["a", "b", "c", "n"], "terminal_map_to" => ["a", "b", "c", "n"],
            "linecode" => "abc", "length" => round(span_m * 1.04, digits = 1))
        net["load"]["h" * lpad(k, 2, '0')] = Dict{String,Any}("bus" => id,
            "terminal_map" => [("a", "b", "c")[mod1(k, 3)], "n"], "configuration" => "SINGLE_PHASE",
            "p_nom" => [1500.0 + 100k], "q_nom" => [300.0 + 20k])
    end
    net
end

net = street()
report = analyze(net)
spatial = report.results[:connectivity]["spatial"]
ref = spatial["coordinate_reference"]
println("frame status : ", ref["status"])
println("datum        : ", spatial["coordinate_semantics"]["datum"])
println("geo findings : ", [f.code for f in report.findings if startswith(f.code, "W.GEO.")])
```

The first thing to check is the **frame status**. Coordinates are only numbers
until the case says what they are. Here `meta.crs` declares GDA2020, the
Australian geographic datum, so distances can be computed and the length
checks run. On a clean feeder they find nothing.

### Declaring the frame

Without a declaration the spatial pass reports the coordinates but compares
nothing:

```@example spatial
undeclared = street(); delete!(undeclared, "meta")
u = analyze(undeclared).results[:connectivity]["spatial"]["coordinate_reference"]
println(u["status"], " — metric distances applicable: ", u["metric_distances_applicable"])
```

That is deliberate. A field named `longitude` may hold feet from a drawing, and
guessing would produce confident nonsense. What to declare:

| Your coordinates | Declaration |
|---|---|
| Longitude/latitude, WGS84 | `"crs": "EPSG:4326"` |
| Longitude/latitude in a national datum (GDA2020, JGD2011, NAD83, ETRS89, …) | its EPSG code, for example `"EPSG:7844"` |
| A plane in meters or feet (OpenDSS `Buscoords`, a site grid) | `{"type": "cartesian", "name": "...", "units": "ft"}` with bus `x`/`y` fields |
| A projected grid you do not want treated as a plane | its EPSG code; recorded, not interpreted |

The [declaration guide](@ref spatial-crs-declaration)
has the details.

## 2. Plant four defects

```@example spatial
messy = street()
messy["line"]["s03"]["length"] = 0.052        # typed in kilometers
messy["line"]["s07"]["length"] = 520.0        # a digit too many
messy["bus"]["p10"]["longitude"] = 0.0        # position lost: defaulted to (0, 0)
messy["bus"]["p10"]["latitude"] = 0.0
messy["line"]["s05"]["length"] = 46.0         # 4 m shorter than its 50 m chord
report = analyze(messy)
for f in report.findings
    startswith(f.code, "W.GEO.") || continue
    println(f.code, "  [", something(f.component_id, "network"), "]")
end
```

Read each one from its evidence:

```@example spatial
for f in report.findings
    f.code in ("W.GEO.LINE_SHORTER_THAN_CHORD", "W.GEO.LINE_LONGER_THAN_CHORD") || continue
    d = f.detail
    println(rpad(f.component_id, 5), rpad(f.code, 30), "length ", rpad(d["length_m"], 8),
            "chord ", round(d["chord_m"], digits = 1), " m")
end
```

- `s03` is 0.052 m long against a 50 m chord: a line cannot be shorter than
  the distance between its ends. The factor of a thousand suggests kilometers.
- `s07` is ten times its chord. Lines are longer than their chord (sag, routing
  around a corner), but not ten times.
- `s10` and `s11` both touch bus `p10`, whose position is the problem, not
  their lengths.
- `s05`, four meters short of its chord, is **not** flagged: the tolerance is
  `max(5 m, 10 %)`, because coordinates and lengths both carry survey error.

The misplaced bus has its own finding, which explains the two lines around it:

```@example spatial
outlier = only(f for f in report.findings if f.code == "W.GEO.COORDINATE_OUTLIER")
println(outlier.detail["buses"], "  ", outlier.detail["reasons"]["p10"]["reason"])
```

Longitude 0, latitude 0 is a point in the Atlantic Ocean that systems write
when they have no position. Fix the bus and the two line findings go with it:
one root cause, three findings.

## 3. When every line is off by the same factor

If lengths were exported in feet into a field that means meters, every line is
wrong, and a finding per line would hide the pattern. The profiler looks at the
network-wide ratio of length to distance:

```@example spatial
feet = street()
for line in values(feet["line"])
    line["length"] = round(line["length"] / 0.3048, digits = 1)   # the same lengths, in feet
end
r = analyze(feet)
scale = only(f for f in r.findings if f.code == "W.GEO.LENGTH_SCALE_SUSPECT")
println(scale.message)
```

One finding names the unit. Convert the lengths once at the source; do not
edit lines one by one.

## 4. The review queue

Beyond the findings, the spatial pass keeps a queue of items for a person to
look at. Findings are contradictions; queue items also include things that are
merely unusual and may be perfectly correct.

```@example spatial
review = report.results[:connectivity]["spatial"]["cleanup_review"]
println(review["n_items"], " items; by category: ", review["category_counts"])
for item in review["items"]
    println("P", item["priority"], "  ", rpad(item["code"], 24), item["bus_ids"])
end
```

Each item states what was observed, what else could explain it and what to
inspect. It never says which value is wrong:

```@example spatial
item = first(review["items"])
a = item["assessment"]
println("observation : ", a["observation"])
println("uncertainty : ", a["uncertainty"])
println("inspect     : ", a["inspect"])
```

## 5. Record a decision

Suppose you check line `s07` against the drawings and find its length was
mistyped. That is a decision about evidence, and you record it:

```@example spatial
target = only(i for i in review["items"] if sort(i["bus_ids"]) == ["p06", "p07"])
record = spatial_review_decision(review, target["item_id"];
    disposition = "confirmed_issue", reviewer = "j.doe",
    recorded_at = "2026-11-26T03:00:00Z",
    rationale = "Length 520 m is a typing error; drawing sheet 14 gives 52 m.",
    evidence_refs = ["drawing:sheet-14"])
reviewed = apply_spatial_review(review, [record])
println(reviewed["disposition_counts"])
```

The record is a statement by a named reviewer at a time, with a reason and a
reference. It changes nothing in the network. Keep every record in a ledger
file and replay the whole ledger on each new analysis.

The queue can be exported for a map or a meeting:

```@example spatial
files = export_spatial_review(reviewed, "spatial-review")
println(sort(readdir("spatial-review")))
```

## 6. Correct the data and check again

```@example spatial
fixed = deepcopy(messy)
fixed["line"]["s03"]["length"] = 52.0
fixed["line"]["s07"]["length"] = 52.0
clean = street()
fixed["bus"]["p10"]["longitude"] = clean["bus"]["p10"]["longitude"]
fixed["bus"]["p10"]["latitude"] = clean["bus"]["p10"]["latitude"]
after = analyze(fixed)
println("geo findings after: ", [f.code for f in after.findings if startswith(f.code, "W.GEO.")])
```

Replay the ledger on the new analysis:

```@example spatial
new_review = after.results[:connectivity]["spatial"]["cleanup_review"]
replayed = apply_spatial_review(new_review, [record])
println("items now: ", replayed["n_items"])
println("unmatched records: ", replayed["decision_audit"]["n_unmatched_records"])
```

The item the decision was about no longer exists, so the record is reported as
unmatched. That is the expected outcome for a corrected issue, and the record
stays in the audit trail.

!!! note "Decisions do not carry over to a changed case"
    A decision is bound to the exact case and settings it was made on. After
    any correction, earlier decisions on items that still exist become
    `stale_decision` and must be confirmed again. Work in batches: review,
    correct together, re-analyze, re-record what still applies.

## What to take away

- **Declare the frame first.** Without it nothing is compared, by design.
- **A length finding is evidence about a pair** — the length and the two
  positions. Read the detail before deciding which one is wrong.
- **Look for the common cause.** One misplaced bus explains every line that
  touches it; one unit explains every line.
- **Tolerances are generous** (`max(5 m, 10 %)`), so a finding is a real
  disagreement.
- **A decision is a record, not an edit.** The network changes only when you
  change it.

Next: [Visualizing a case with Tellegen](visualization.md) shows the same loop
on a map.
