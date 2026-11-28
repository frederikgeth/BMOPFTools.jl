# [Tune profiler thresholds](@id howto-thresholds)

Several checks compare a value with a threshold: a minimum power factor, a
feeder length that looks implausible, the impedance below which a line looks
like a switch. The defaults are order-of-magnitude norms, not standards. This
page shows how to change one, and lists every threshold with the finding it
drives.

## Change a threshold for one study

Load the defaults, change what you need, and pass the result to
[`analyze`](@ref):

```@example thresholds
using BMOPFTools

fixture = joinpath(pkgdir(BMOPFTools), "test", "data", "profiler_systems",
                   "eu_tn_four_wire.json")
net = parse_bmopf(fixture)
net["load"]["h3"]["q_nom"] = [3000.0]          # 4 kW at power factor 0.8

cfg = load_config()
println("default pf_min: ", cfg["domain_rules"]["pf_min"])
println("default : ", [f.code for f in warnings(analyze(net))])

cfg["domain_rules"]["pf_min"] = 0.85           # a stricter house rule
println("stricter: ", [f.code for f in warnings(analyze(net; config = cfg))])
```

## Keep the thresholds in a file

For a rule that applies to every case of a utility or a project, write a TOML
file that contains only the keys you change. It is merged over the packaged
defaults:

```@example thresholds
write("house_rules.toml", """
[domain_rules]
pf_min = 0.85

[operational.feeder_length.LV]
reach_long_m = 600.0
""")
cfg = load_config("house_rules.toml")
println(cfg["domain_rules"]["pf_min"], "  ", cfg["operational"]["feeder_length"]["LV"]["reach_long_m"],
        "  ", cfg["domain_rules"]["xfmr_ratio_max"], " (unchanged default)")
```

Keep that file with the cases it was used on. A report is only reproducible
together with the thresholds that produced it.

## Every threshold

The packaged defaults are in
[`config/default.toml`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/config/default.toml),
with the reasoning for each value in the comments. All of the sections below
follow the `config` passed to `analyze`.

### `[report]`

| Key | Default | Effect |
|---|---|---|
| `rollup_threshold` | 25 | An `I.` or `W.` code raised on more components than this is reported as one roll-up Finding ([Report consolidation](analysis.md#Report-consolidation)). `0` disables roll-up. |

### `[domain_rules]`

| Key | Default | Finding |
|---|---|---|
| `pf_min` | 0.70 | `W.DOM.LOAD_PF_LOW` below this load power factor |
| `cost_max_per_kwh` | 10.0 | `W.DOM.GEN_COST_HIGH` above this generator cost |
| `r_series_min` | 1e-9 Ω/m | `W.DOM.LC_ZERO_R` when a linecode resistance diagonal is below this |
| `xfmr_ratio_max` | 1000 | `W.DOM.XFMR_RATIO_OOB` beyond this transformer step ratio |
| `xfmr_z_min_ohm` | 1e-6 Ω | at or below this a winding is exactly ideal (`I.DOM.XFMR_IDEAL`) |
| `xfmr_z_min_pu` | 1e-3 | tiny non-zero leakage, likely a placeholder (`W.DOM.XFMR_LOW_IMPEDANCE`) |
| `z_line_min_ohm` | 1e-4 Ω | `W.DOM.LINE_LOW_IMPEDANCE` below this total series impedance |
| `z_spread_info`, `z_spread_warn` | 1e3, 1e5 | `I.` / `W.DOM.LINE_IMPEDANCE_SPREAD` for adjacent-line impedance ratios |
| `source_v_margin_frac` | 0.05 | `W.DOM.SOURCE_V_NEAR_BOUND` when a source voltage is this close to a bus bound |

### `[operational.feeder_length.<band>]`

One table per voltage band (`LV` below 1 kV, `MV` 1–35 kV, `HV` 35–100 kV,
`EHV` above). The band is chosen from the per-conductor (phase-to-neutral)
nominal voltage, not the line-to-line rating: a 400 V feeder (230 V per
conductor) is `LV`, 11 kV and 33 kV feeders (6.35 kV and 19.1 kV) are `MV`, and
a 66 kV line (38.1 kV) is `HV`.

| Key | Defaults (LV / MV / HV / EHV) | Finding |
|---|---|---|
| `reach_short_m` | 30 / 200 / 0 / 0 | `I.OPS.FEEDER_SHORT` when a zone's reach (the farthest bus's declared line length to its nearest supply boundary) is below this; `0` disables |
| `reach_long_m` | 1000 / 20000 / 100000 / 300000 | `I.OPS.FEEDER_LONG` above this; `0` disables |

These are the thresholds most worth adapting to a region. A North American
rural 12.47 kV feeder, or an Australian SWER line, runs well beyond 20 km, and
a service drop is legitimately shorter than 30 m:

```toml
[operational.feeder_length.MV]
reach_long_m = 60000.0      # long rural feeders are normal here

[operational.feeder_length.LV]
reach_short_m = 0.0         # do not report service drops
```

These thresholds apply to zones with at most one qualified supply-boundary
bus. A zone with more than one uses the `multi_boundary` subtable of its band
instead. It is absent from the defaults, so `I.OPS.FEEDER_LONG` and `I.OPS.FEEDER_SHORT`
are not raised for such zones unless you configure it:

```toml
[operational.feeder_length.LV.multi_boundary]
reach_short_m = 0.0
reach_long_m = 500.0
```

The [feeder-length reference](analysis_results.md#Feeder-length-and-supply-boundaries)
explains how reach is measured.

### `[provenance.dss_defaults]`

Values that OpenDSS substitutes when a field is missing. A match means the
value probably came from the tool, not from data.

| Key | Default | Finding |
|---|---|---|
| `normamps` | 400 A | `I.PROV.DSS_DEFAULT_AMPS` |
| `xhl_pu`, `rw_pu` | 0.07, 0.004 | `I.PROV.DSS_DEFAULT_XFMR` |
| `pf` | 0.88 | `I.PROV.DSS_DEFAULT_PF` |
| `basekv_v`, `kv_v` | 115 kV, 12.47 kV | `I.PROV.DSS_DEFAULT_KV` |

`I.PROV.DSS_DEFAULT_KV` is expected on a genuine North American 12.47 kV
feeder. Set `kv_v` to a value your network does not use to silence it there.

### `[provenance.switch_like]`

| Key | Default | Finding |
|---|---|---|
| `z_per_m` | 1e-6 Ω/m | `I.PROV.LINE_SWITCH_LIKE` when every linecode diagonal is below this |
| `z_total` | 1e-4 Ω | `I.PROV.LINE_SWITCH_LIKE` when impedance × length is below this |

### `[spatial]`

| Key | Default | Effect |
|---|---|---|
| `enabled` | true | `false` skips the whole spatial pass |
| `proximity_enabled`, `discrepancy_enabled`, `review_enabled` | true | `false` turns off the proximity inventory, the discrepancy checks, or the capture of review candidates |
| `proximity_radius_m` | 1.0 | buses within this distance are proximity neighbors |
| `long_span_threshold_m` | 10000 | review candidate `S.LONG_BRANCH_SPAN` above this |
| `route_endpoint_tolerance_m` | 5.0 | route endpoint gaps above this are counted |
| `max_candidate_pairs`, `max_topology_pairs` | 1e6, 1e5 | search budgets; exceeding one makes that check indeterminate |
| `max_series_hops` | 8 | longest line-only series path (in edges, 2–64) compared with a direct line |
| `witness_limit`, `max_review_candidates` | 20, 5000 | how much evidence is kept |

The length tolerances of the `W.GEO.*` Findings (`max(5 m, 10 %)` for a line
shorter than its chord, `max(5 × chord, chord + 100 m)` for one far longer) are
fixed. See [Spatial diagnostics](spatial_diagnostics.md).

### Not used by `analyze`

`[thermal]` and `[augment.*]` configure [`augment_case`](@ref) and the IBR
presets. The two `[provenance.grounding]` keys are ignored by every report;
[`load_config`](@ref) warns when a file sets them.

## Thresholds that are fixed in the code

Some checks use a fixed value because changing it would change what the finding
means: the 5 % tolerance for a voltage-level mismatch, the 5 % of load below
which local generation is negligible, the 90 % transformer loading mark. They
are stated in the [finding-code reference](findings.md) entry of each code. If
one of them does not fit your network, the right response is to record a
decision about that finding, not to move the threshold:
see [Accept and track findings](howto_accept_findings.md).
