# test/simplify_tests.jl
#
# Unit tests for network/simplify.jl.
# Each testset builds a minimal in-memory network Dict, runs one or more
# simplification functions, and asserts structural and log outcomes.

# ── Fixture helpers ────────────────────────────────────────────────────────────

# Minimal 1-phase linecode entry (content irrelevant to topology tests).
_lc(id) = Dict{String,Any}(id => Dict{String,Any}("R_series_1_1" => 1e-3))

function _bus(; terminals=["1","n"], grounded=nothing)
    b = Dict{String,Any}("terminal_names" => terminals)
    grounded !== nothing && (b["perfectly_grounded_terminals"] = grounded)
    b
end

function _line(from, to; lc="lc1", len=100.0, tmap=["1","n"])
    Dict{String,Any}(
        "bus_from"         => from,
        "bus_to"           => to,
        "terminal_map_from" => copy(tmap),
        "terminal_map_to"   => copy(tmap),
        "linecode"         => lc,
        "length"           => len,
    )
end

function _load(bus)
    Dict{String,Any}(
        "bus"           => bus,
        "terminal_map"  => ["1","n"],
        "configuration" => "SINGLE_PHASE",
        "p_nom"         => [1000.0],
        "q_nom"         => [0.0],
    )
end

function _vsource(bus)
    Dict{String,Any}(
        "bus"          => bus,
        "terminal_map" => ["1"],
        "v_magnitude"  => [230.0],
        "v_angle"      => [0.0],
    )
end

function _switch(from, to; open=false, tmap=["1","n"])
    Dict{String,Any}(
        "bus_from"          => from,
        "bus_to"            => to,
        "open_switch"       => open,
        "terminal_map_from" => copy(tmap),
        "terminal_map_to"   => copy(tmap),
    )
end

function _ibr(bus)
    Dict{String,Any}(
        "bus"          => bus,
        "terminal_map" => ["1","n"],
        "topology"     => "SINGLE_PHASE",
        "prime_mover"  => "PV",
        "s_max"        => [5000.0],
    )
end

function _capacitor(bus)
    Dict{String,Any}(
        "bus"           => bus,
        "terminal_map"  => ["1","n"],
        "configuration" => "SINGLE_PHASE",
        "q_rated"       => [1000.0],
        "v_nom"         => 230.0,
    )
end

# Minimal winding-list (n_winding) transformer spanning the given buses.
function _nwinding(buses)
    Dict{String,Any}(
        "windings" => [Dict{String,Any}(
            "bus"           => b,
            "terminal_map"  => ["1","n"],
            "v_nom"         => 230.0,
            "configuration" => "WYE") for b in buses],
        "x_sc" => Dict{String,Any}("1_2" => 0.05),
    )
end

_log_codes(net) = [e["code"] for e in get(net, "_simplification_log", [])]
_log_sevs(net)  = [e["severity"] for e in get(net, "_simplification_log", [])]

# ── merge_series_lines ─────────────────────────────────────────────────────────

@testset "merge_series_lines — basic two-line merge" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => _line("A", "B"; len=100.0),
            "l2" => _line("B", "C"; len=200.0)),
        "load"     => Dict("ld" => _load("C")),
    )
    net′ = merge_series_lines(net)

    # Bus B removed; A and C survive
    @test !haskey(net′["bus"], "B")
    @test  haskey(net′["bus"], "A")
    @test  haskey(net′["bus"], "C")

    # One line remains
    @test length(net′["line"]) == 1
    l = only(values(net′["line"]))
    @test Set([l["bus_from"], l["bus_to"]]) == Set(["A", "C"])
    @test l["length"]   ≈ 300.0

    # Provenance: whichever line was absorbed is recorded
    @test length(l["_merged_from"]) == 1

    # Log
    @test "LINES_MERGED" in _log_codes(net′)
    @test all(s == "info" for s in _log_sevs(net′))

    # Original is untouched
    @test length(net["line"]) == 2
    @test haskey(net["bus"], "B")
end

@testset "merge_series_lines — absorbed line's i_max/s_max preserved" begin
    # Regression: the corridor rating was silently dropped when the rated
    # segment was the absorbed one; and with both present, the tighter wins.
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => _line("A", "B"; len=100.0),
            "l2" => _line("B", "C"; len=200.0)),
        "load"     => Dict("ld" => _load("C")),
    )
    net["line"]["l2"]["i_max"] = [80.0, 80.0]
    net′ = merge_series_lines(net)
    l = only(values(net′["line"]))
    @test l["i_max"] == [80.0, 80.0]

    net2 = deepcopy(net)
    net2["line"]["l1"]["i_max"] = [120.0, 60.0]
    net2′ = merge_series_lines(net2)
    l2 = only(values(net2′["line"]))
    @test l2["i_max"] == [80.0, 60.0]   # elementwise min
end

@testset "merge_series_lines — effective limit: linecode reliance vs loosening override" begin
    # Regression: one segment relied on the linecode rating (100 A) while the
    # other carried a LOOSER line-level override (150 A). Comparing raw overrides
    # alone would pin 150 A on the merged line — beating the 100 A linecode and
    # silently RELAXING the corridor. The effective-limit rule must keep 100 A.
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => Dict("lc1" => Dict{String,Any}(
            "R_series_1_1" => 1e-3, "i_max" => [100.0, 100.0])),
        "line"     => Dict(
            "l1" => _line("A", "B"; len=100.0),   # no override → effective 100 (linecode)
            "l2" => _line("B", "C"; len=200.0)),  # loosening override 150
        "load"     => Dict("ld" => _load("C")),
    )
    net["line"]["l2"]["i_max"] = [150.0, 150.0]
    l = only(values(merge_series_lines(net)["line"]))
    # Effective merged limit = min(linecode 100, override 150) = 100, not relaxed.
    @test get(l, "i_max", nothing) == [100.0, 100.0]

    # When neither segment overrides, the shared linecode still carries the
    # rating — no redundant override is pinned on the merged line.
    net2 = deepcopy(net); delete!(net2["line"]["l2"], "i_max")
    l2 = only(values(merge_series_lines(net2)["line"]))
    @test !haskey(l2, "i_max")   # relies on linecode, unchanged
end

@testset "merge_series_lines — grounded intermediate bus blocked, GROUNDED_BUS logged" begin
    # A modelled ground at the pass-through bus fixes terminal voltages; merging
    # would delete the bus and silently drop the ground.
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(grounded=["n"]), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => _line("A", "B"; len=100.0),
            "l2" => _line("B", "C"; len=200.0)),
        "load"     => Dict("ld" => _load("C")),
    )
    net′ = merge_series_lines(net)

    @test haskey(net′["bus"], "B")          # not deleted
    @test length(net′["line"]) == 2         # not merged
    @test "GROUNDED_BUS" in _log_codes(net′)
    @test "warning" in _log_sevs(net′)
end

@testset "merge_series_lines — self-loop line not merged or destroyed" begin
    # Regression: a self-loop registers twice at its bus, passed the two-line
    # gate with l1 ≡ l2, and the "merge" deleted the line and bus outright.
    # Bus B carries ONLY the self-loop: it registers twice, so B passes the
    # "exactly two lines, nothing else" pass-through gate.
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1"   => _line("A", "C"; len=100.0),
            "loop" => _line("B", "B"; len=5.0)),
        "load"     => Dict("ld" => _load("C")),
    )
    net′ = merge_series_lines(net)
    @test haskey(net′["line"], "loop")
    @test haskey(net′["line"], "l1")
    @test haskey(net′["bus"], "B")
end

@testset "merge_series_lines — reversed orientation" begin
    # l1: B→A, l2: B→C  (both depart from B — still a valid pass-through)
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => _line("B", "A"; len=50.0),
            "l2" => _line("B", "C"; len=75.0)),
        "load"     => Dict("ldA" => _load("A"), "ldC" => _load("C")),
    )
    net′ = merge_series_lines(net)

    @test !haskey(net′["bus"], "B")
    @test length(net′["line"]) == 1
    l = only(values(net′["line"]))
    @test l["length"] ≈ 125.0
end

@testset "merge_series_lines — chain of three collapses fully" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus(), "D" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => _line("A", "B"; len=10.0),
            "l2" => _line("B", "C"; len=20.0),
            "l3" => _line("C", "D"; len=30.0)),
        "load"     => Dict("ld" => _load("D")),
        "voltage_source" => Dict("vs" => _vsource("A")),
    )
    net′ = merge_series_lines(net)

    @test length(net′["line"]) == 1
    @test length(net′["bus"])  == 2   # A and D only
    l = only(values(net′["line"]))
    @test l["length"] ≈ 60.0
    @test length(l["_merged_from"]) == 2
    @test count(e["code"] == "LINES_MERGED" for e in net′["_simplification_log"]) == 2
end

@testset "merge_series_lines — different linecodes blocked, LINECODE_MISMATCH logged" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => merge(_lc("lc1"), _lc("lc2")),
        "line"     => Dict(
            "l1" => _line("A", "B"; lc="lc1"),
            "l2" => _line("B", "C"; lc="lc2")),
        "load"     => Dict("ld" => _load("C")),
    )
    net′ = merge_series_lines(net)

    @test length(net′["line"]) == 2
    @test haskey(net′["bus"], "B")
    @test "LINECODE_MISMATCH" in _log_codes(net′)
    @test all(s == "info" for s in _log_sevs(net′))
end

@testset "merge_series_lines — load on intermediate bus blocked, NON_LINE_ON_BUS logged" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => _line("A", "B"),
            "l2" => _line("B", "C")),
        "load"     => Dict(
            "ld_b" => _load("B"),   # blocks merge
            "ld_c" => _load("C")),
    )
    net′ = merge_series_lines(net)

    @test length(net′["line"]) == 2
    @test haskey(net′["bus"], "B")
    @test "NON_LINE_ON_BUS" in _log_codes(net′)
    @test all(s == "info" for s in _log_sevs(net′))
end

@testset "merge_series_lines — switch on intermediate bus, SWITCH_IN_CHAIN warning" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus(), "D" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => _line("A", "B"),
            "l2" => _line("B", "C")),
        "switch"   => Dict("sw1" => _switch("B", "D"; open=false)),
        "load"     => Dict("ld" => _load("C")),
    )
    net′ = merge_series_lines(net)

    @test length(net′["line"]) == 2
    @test "SWITCH_IN_CHAIN" in _log_codes(net′)
    @test any(e["severity"] == "warning" for e in net′["_simplification_log"])
end

@testset "merge_series_lines — terminal map mismatch, TERMINAL_MISMATCH warning" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => Dict("bus_from" => "A", "bus_to" => "B",
                         "terminal_map_from" => ["1","n"],
                         "terminal_map_to"   => ["1","n"],
                         "linecode" => "lc1", "length" => 100.0),
            "l2" => Dict("bus_from" => "B", "bus_to" => "C",
                         "terminal_map_from" => ["1"],       # different at B
                         "terminal_map_to"   => ["1"],
                         "linecode" => "lc1", "length" => 100.0)),
        "load" => Dict("ld" => _load("C")),
    )
    net′ = merge_series_lines(net)

    @test length(net′["line"]) == 2
    @test "TERMINAL_MISMATCH" in _log_codes(net′)
    @test any(e["severity"] == "warning" for e in net′["_simplification_log"])
end

# ── remove_dangling_lines ──────────────────────────────────────────────────────

@testset "remove_dangling_lines — single stub removed" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "X" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "main" => _line("A", "B"),
            "stub" => _line("A", "X")),     # X is a leaf with nothing at it
        "load"     => Dict("ld" => _load("B")),
        "voltage_source" => Dict("vs" => _vsource("A")),
    )
    net′ = remove_dangling_lines(net)

    @test !haskey(net′["bus"],  "X")
    @test !haskey(net′["line"], "stub")
    @test  haskey(net′["line"], "main")
    @test "LINE_REMOVED" in _log_codes(net′)
end

@testset "remove_dangling_lines — chain of stubs pruned to convergence" begin
    # A(source)—l1—B—l2—C—l3—D  (no load anywhere past B)
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(),
                           "C" => _bus(), "D" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => _line("A", "B"),
            "l2" => _line("B", "C"),
            "l3" => _line("C", "D")),
        "voltage_source" => Dict("vs" => _vsource("A")),
    )
    net′ = remove_dangling_lines(net)

    # Everything past A should be gone (no load anywhere)
    @test isempty(net′["line"])
    @test length(net′["bus"]) == 1
    @test haskey(net′["bus"], "A")
    @test count(e["code"] == "LINE_REMOVED" for e in net′["_simplification_log"]) == 3
end

@testset "remove_dangling_lines — shunt-bearing stub still removed but flagged" begin
    # A stub with shunt admittance is a shunt-to-earth: pruning it can move the
    # feasible set, so it is still removed (topology pass) but flagged.
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "X" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "main" => _line("A", "B"),
            "stub" => _line("A", "X")),
        "load"     => Dict("ld" => _load("B")),
        "voltage_source" => Dict("vs" => _vsource("A")),
    )
    net["line"]["stub"]["B_from_1_1"] = 3.0e-6   # non-zero charging susceptance
    net′ = remove_dangling_lines(net)

    @test !haskey(net′["bus"],  "X")             # still pruned
    @test !haskey(net′["line"], "stub")
    @test "SHUNT_DROPPED" in _log_codes(net′)
    shunt_entry = only(e for e in net′["_simplification_log"] if e["code"] == "SHUNT_DROPPED")
    @test shunt_entry["severity"] == "warning"
    @test shunt_entry["detail"]["surviving_bus"] == "A"

    # A shunt-free stub is removed with no SHUNT_DROPPED entry.
    net2 = deepcopy(net); delete!(net2["line"]["stub"], "B_from_1_1")
    @test "SHUNT_DROPPED" ∉ _log_codes(remove_dangling_lines(net2))
end

@testset "remove_dangling_lines — shunt via linecode also flagged" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "X" => _bus()),
        "linecode" => Dict(
            "lc1" => Dict{String,Any}("R_series_1_1" => 1e-3),
            "cab" => Dict{String,Any}("R_series_1_1" => 1e-3, "B_from_1_1" => 1.0e-7)),
        "line"     => Dict(
            "main" => _line("A", "B"; lc="lc1"),
            "stub" => _line("A", "X"; lc="cab")),
        "load"     => Dict("ld" => _load("B")),
        "voltage_source" => Dict("vs" => _vsource("A")),
    )
    @test "SHUNT_DROPPED" in _log_codes(remove_dangling_lines(net))
end

@testset "remove_dangling_lines — load at leaf prevents removal" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict("l1" => _line("A", "B")),
        "load"     => Dict("ld" => _load("B")),
        "voltage_source" => Dict("vs" => _vsource("A")),
    )
    net′ = remove_dangling_lines(net)

    @test length(net′["line"]) == 1
    @test haskey(net′["bus"], "B")
    @test isempty(_log_codes(net′))
end

# ── remove_open_switches ───────────────────────────────────────────────────────

@testset "remove_open_switches — open switch removed, buses kept" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict("l1" => _line("A", "B")),
        "switch"   => Dict(
            "sw_open"   => _switch("A", "B"; open=true),
            "sw_closed" => _switch("A", "B"; open=false)),
        "voltage_source" => Dict("vs" => _vsource("A")),
        "load"           => Dict("ld" => _load("B")),
    )
    net′ = remove_open_switches(net)

    @test !haskey(net′["switch"], "sw_open")
    @test  haskey(net′["switch"], "sw_closed")
    @test  haskey(net′["bus"], "A")
    @test  haskey(net′["bus"], "B")
    @test "SWITCH_REMOVED" in _log_codes(net′)
    @test !("ISOLATED_BUS" in _log_codes(net′))
end

@testset "remove_open_switches — isolated bus after removal, ISOLATED_BUS warning" begin
    # C is only connected via the open switch; nothing else touches it.
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict("l1" => _line("A", "B")),
        "switch"   => Dict("sw" => _switch("B", "C"; open=true)),
        "voltage_source" => Dict("vs" => _vsource("A")),
        "load"           => Dict("ld" => _load("B")),
    )
    net′ = remove_open_switches(net)

    @test !haskey(net′["switch"], "sw")
    @test "ISOLATED_BUS" in _log_codes(net′)
    @test any(e["severity"] == "warning" for e in net′["_simplification_log"])
end

@testset "remove_open_switches — closed switch untouched" begin
    net = Dict{String,Any}(
        "bus"    => Dict("A" => _bus(), "B" => _bus()),
        "switch" => Dict("sw" => _switch("A", "B"; open=false)),
    )
    net′ = remove_open_switches(net)

    @test haskey(net′["switch"], "sw")
    @test isempty(_log_codes(net′))
end

# ── collapse_closed_switches ───────────────────────────────────────────────────

@testset "collapse_closed_switches — basic bus merge" begin
    net = Dict{String,Any}(
        "bus" => Dict(
            "A" => _bus(; terminals=["1","n"], grounded=["n"]),
            "B" => _bus(; terminals=["1","n"])),
        "switch" => Dict("sw" => _switch("A", "B"; open=false)),
        "load"   => Dict("ld" => _load("B")),
        "voltage_source" => Dict("vs" => _vsource("A")),
    )
    net′ = collapse_closed_switches(net)

    # B absorbed into A
    @test !haskey(net′["bus"],    "B")
    @test !haskey(net′["switch"], "sw")

    # Load redirected to A
    @test net′["load"]["ld"]["bus"] == "A"

    # Grounding from A preserved
    @test "n" in get(net′["bus"]["A"], "perfectly_grounded_terminals", [])

    @test "SWITCH_COLLAPSED" in _log_codes(net′)
    @test all(s == "info" for s in _log_sevs(net′))
end

@testset "collapse_closed_switches — rated switch flags SWITCH_LIMIT_DROPPED" begin
    # A closed switch with an enforced i_max is flow-limited in the OPF; the
    # collapse fuses its buses into one node so the limit cannot be projected and
    # is lost. It is still collapsed, but flagged so the loss is on the record.
    net = Dict{String,Any}(
        "bus"    => Dict("A" => _bus(), "B" => _bus()),
        "switch" => Dict("sw" => _switch("A", "B"; open=false)),
        "load"   => Dict("ld" => _load("B")),
        "voltage_source" => Dict("vs" => _vsource("A")),
    )
    net["switch"]["sw"]["i_max"] = [100.0, 100.0]
    net′ = collapse_closed_switches(net)

    @test !haskey(net′["bus"], "B")              # still collapsed
    @test !haskey(net′["switch"], "sw")
    entry = only(e for e in net′["_simplification_log"] if e["code"] == "SWITCH_LIMIT_DROPPED")
    @test entry["severity"] == "warning"
    @test entry["detail"]["i_max"] == [100.0, 100.0]

    # A switch with no limit (or an all-zero one) collapses without the flag.
    net2 = deepcopy(net); delete!(net2["switch"], "sw")
    net2["switch"] = Dict("sw" => _switch("A", "B"; open=false))
    @test "SWITCH_LIMIT_DROPPED" ∉ _log_codes(collapse_closed_switches(net2))
end

@testset "collapse_closed_switches — voltage bounds tightened" begin
    net = Dict{String,Any}(
        "bus" => Dict(
            "A" => Dict("terminal_names" => ["1","n"],
                        "v_min" => [200.0], "v_max" => [260.0]),
            "B" => Dict("terminal_names" => ["1","n"],
                        "v_min" => [210.0], "v_max" => [250.0])),
        "switch" => Dict("sw" => _switch("A", "B"; open=false)),
    )
    net′ = collapse_closed_switches(net)

    @test net′["bus"]["A"]["v_min"] ≈ [210.0]   # max of 200, 210
    @test net′["bus"]["A"]["v_max"] ≈ [250.0]   # min of 260, 250
end

@testset "collapse_closed_switches — bounds aligned by phase name" begin
    # Regression: bounds were combined element-wise by INDEX, so two buses
    # ordering their phases differently had different phases' bounds paired.
    net = Dict{String,Any}(
        "bus" => Dict(
            "A" => Dict("terminal_names" => ["1","2","n"],
                        "v_min" => [200.0, 220.0], "v_max" => [260.0, 262.0]),
            "B" => Dict("terminal_names" => ["2","1","n"],       # reversed order
                        "v_min" => [230.0, 210.0], "v_max" => [250.0, 252.0])),
        "switch" => Dict("sw" => _switch("A", "B"; open=false, tmap=["1","2","n"])),
    )
    net′ = collapse_closed_switches(net)
    A = net′["bus"]["A"]
    # Merged phase order follows A: ["1","2"].
    # phase 1: max(200, 210) = 210; min(260, 252) = 252
    # phase 2: max(220, 230) = 230; min(262, 250) = 250
    @test A["v_min"] ≈ [210.0, 230.0]
    @test A["v_max"] ≈ [252.0, 250.0]

    # A phase only one side bounds keeps that side's bound; a phase neither
    # side bounds drops the field with a warning log entry.
    net2 = Dict{String,Any}(
        "bus" => Dict(
            "A" => Dict("terminal_names" => ["1","n"], "v_max" => [260.0]),
            "B" => Dict("terminal_names" => ["1","2","n"], "v_max" => [250.0, 255.0])),
        "switch" => Dict("sw" => _switch("A", "B"; open=false, tmap=["1","n"])),
    )
    net2′ = collapse_closed_switches(net2)
    A2 = net2′["bus"]["A"]
    @test A2["terminal_names"] == ["1","n","2"]
    @test A2["v_max"] ≈ [min(260.0, 250.0), 255.0]   # phase 2 from B only

    net3 = Dict{String,Any}(
        "bus" => Dict(
            "A" => Dict("terminal_names" => ["1","n"], "v_max" => [260.0]),
            "B" => Dict("terminal_names" => ["1","2","n"])),   # no bounds, adds phase 2
        "switch" => Dict("sw" => _switch("A", "B"; open=false, tmap=["1","n"])),
    )
    net3′ = collapse_closed_switches(net3)
    @test !haskey(net3′["bus"]["A"], "v_max")
    @test "BOUND_DROPPED" in _log_codes(net3′)
end

@testset "collapse_closed_switches — terminal union from both buses" begin
    net = Dict{String,Any}(
        "bus" => Dict(
            "A" => Dict("terminal_names" => ["1","2","3"]),
            "B" => Dict("terminal_names" => ["1","2","3","n"])),
        "switch" => Dict("sw" => Dict(
            "bus_from" => "A", "bus_to" => "B",
            "open_switch" => false,
            "terminal_map_from" => ["1","2","3"],
            "terminal_map_to"   => ["1","2","3"])),
    )
    net′ = collapse_closed_switches(net)

    @test Set(net′["bus"]["A"]["terminal_names"]) == Set(["1","2","3","n"])
end

@testset "collapse_closed_switches — dual voltage sources blocked, MERGE_CONFLICT_SOURCE" begin
    net = Dict{String,Any}(
        "bus" => Dict("A" => _bus(), "B" => _bus()),
        "switch" => Dict("sw" => _switch("A", "B"; open=false)),
        "voltage_source" => Dict(
            "vs1" => _vsource("A"),
            "vs2" => _vsource("B")),
    )
    net′ = collapse_closed_switches(net)

    @test haskey(net′["switch"], "sw")
    @test haskey(net′["bus"],    "B")
    @test "MERGE_CONFLICT_SOURCE" in _log_codes(net′)
    @test any(e["severity"] == "warning" for e in net′["_simplification_log"])
end

@testset "collapse_closed_switches — arity mismatch blocked, MERGE_CONFLICT_TERMINALS" begin
    net = Dict{String,Any}(
        "bus" => Dict("A" => _bus(), "B" => _bus()),
        "switch" => Dict("sw" => Dict(
            "bus_from"          => "A", "bus_to" => "B",
            "open_switch"       => false,
            "terminal_map_from" => ["1","n"],
            "terminal_map_to"   => ["1"])),   # different arity
    )
    net′ = collapse_closed_switches(net)

    @test haskey(net′["switch"], "sw")
    @test "MERGE_CONFLICT_TERMINALS" in _log_codes(net′)
end

@testset "collapse_closed_switches — self-loop blocked" begin
    net = Dict{String,Any}(
        "bus" => Dict("A" => _bus()),
        "switch" => Dict("sw" => _switch("A", "A"; open=false)),
    )
    net′ = collapse_closed_switches(net)

    @test haskey(net′["switch"], "sw")
    @test "MERGE_CONFLICT_TERMINALS" in _log_codes(net′)
end

@testset "collapse_closed_switches — chain of two closed switches collapses" begin
    # A—sw1—B—sw2—C, no other elements
    net = Dict{String,Any}(
        "bus" => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "switch" => Dict(
            "sw1" => _switch("A", "B"; open=false),
            "sw2" => _switch("B", "C"; open=false)),
        "voltage_source" => Dict("vs" => _vsource("A")),
        "load"           => Dict("ld" => _load("C")),
    )
    net′ = collapse_closed_switches(net)

    @test length(net′["bus"])    == 1
    @test isempty(get(net′, "switch", Dict()))
    @test net′["load"]["ld"]["bus"]            == "A"
    @test net′["voltage_source"]["vs"]["bus"]  == "A"
    @test count(e["code"] == "SWITCH_COLLAPSED"
                for e in net′["_simplification_log"]) == 2
end

@testset "collapse_closed_switches — lines redirected to surviving bus" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict("l1" => _line("B", "C")),
        "switch"   => Dict("sw" => _switch("A", "B"; open=false)),
        "load"     => Dict("ld" => _load("C")),
        "voltage_source" => Dict("vs" => _vsource("A")),
    )
    net′ = collapse_closed_switches(net)

    @test net′["line"]["l1"]["bus_from"] == "A"
    @test net′["line"]["l1"]["bus_to"]   == "C"
end

# ── simplify_network ───────────────────────────────────────────────────────────

@testset "simplify_network — runs all operations, log accumulates" begin
    # Network with: closed switch A—B, open switch B—X, dangling line A—Z,
    # then two same-linecode lines in series B—C—D.
    net = Dict{String,Any}(
        "bus" => Dict(
            "A" => _bus(), "B" => _bus(), "C" => _bus(),
            "D" => _bus(), "X" => _bus(), "Z" => _bus()),
        "linecode" => _lc("lc1"),
        "line" => Dict(
            "l_BC" => _line("B", "C"),
            "l_CD" => _line("C", "D"),
            "l_AZ" => _line("A", "Z")),  # dangling (nothing at Z)
        "switch" => Dict(
            "sw_closed" => _switch("A", "B"; open=false),
            "sw_open"   => _switch("B", "X"; open=true)),
        "voltage_source" => Dict("vs" => _vsource("A")),
        "load"           => Dict("ld" => _load("D")),
    )
    net′ = simplify_network(net)

    # After collapse_closed_switches: B merged into A
    # After remove_open_switches: sw_open gone (X becomes isolated, warns)
    # After remove_dangling_lines: l_AZ and Z removed
    # After merge_series_lines: l_BC and l_CD merged

    @test !haskey(get(net′, "switch", Dict()), "sw_closed")
    @test !haskey(get(net′, "switch", Dict()), "sw_open")
    @test !haskey(net′["bus"], "Z")
    @test !haskey(net′["bus"], "C")
    @test length(net′["line"]) == 1
    l = only(values(net′["line"]))
    @test l["length"] ≈ 200.0
    @test l["bus_to"] == "D"

    log = net′["_simplification_log"]
    codes = [e["code"] for e in log]
    @test "SWITCH_COLLAPSED" in codes
    @test "SWITCH_REMOVED"   in codes
    @test "LINE_REMOVED"     in codes
    @test "LINES_MERGED"     in codes
    @test "ISOLATED_BUS"     in codes   # X isolated after sw_open removed
end

@testset "simplify_network — individual operations can be disabled" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => _line("A", "B"),
            "l2" => _line("B", "C")),
        "load"     => Dict("ld" => _load("C")),
        "voltage_source" => Dict("vs" => _vsource("A")),
    )

    # disable merge → two lines stay
    net_no_merge = simplify_network(net; series_lines=false)
    @test length(net_no_merge["line"]) == 2

    # enable merge → fused
    net_merged = simplify_network(net; series_lines=true)
    @test length(net_merged["line"]) == 1
end

@testset "simplify_network — log key present even when no operations fire" begin
    net = Dict{String,Any}(
        "bus"  => Dict("A" => _bus()),
        "load" => Dict("ld" => _load("A")),
    )
    net′ = simplify_network(net)
    @test haskey(net′, "_simplification_log")
    @test net′["_simplification_log"] isa Vector
end

@testset "simplify_network — original network is not mutated" begin
    net = Dict{String,Any}(
        "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
        "linecode" => _lc("lc1"),
        "line"     => Dict(
            "l1" => _line("A", "B"),
            "l2" => _line("B", "C")),
        "load"     => Dict("ld" => _load("C")),
    )
    _  = simplify_network(net)
    @test length(net["line"]) == 2
    @test haskey(net["bus"], "B")
    @test !haskey(net, "_simplification_log")
end

# ── Component-blindness regressions (#275) ──────────────────────────────────────
# The connectivity helpers (_bus_connectivity / _bus_has_connections /
# _redirect_bus!) used to enumerate only load/generator/shunt/voltage_source
# and two-bus transformers, silently ignoring `ibr`, `capacitor`, and
# winding-list (`n_winding`) transformers. That let a series merge or dangling
# prune delete a bus hosting one of those elements (orphaning it), and let a
# switch collapse absorb a bus without redirecting the element's `bus`.

@testset "merge_series_lines — ibr/capacitor on intermediate bus blocks merge (#275)" begin
    for (cat, elt) in (("ibr", _ibr("B")), ("capacitor", _capacitor("B")))
        net = Dict{String,Any}(
            "bus"      => Dict("A" => _bus(), "B" => _bus(), "C" => _bus()),
            "linecode" => _lc("lc1"),
            "line"     => Dict("l1" => _line("A", "B"), "l2" => _line("B", "C")),
            "load"     => Dict("ld" => _load("C")),
            cat        => Dict("e1" => elt),
        )
        net′ = merge_series_lines(net)
        @test length(net′["line"]) == 2                 # not merged
        @test haskey(net′["bus"], "B")                  # intermediate bus kept
        @test net′[cat]["e1"]["bus"] == "B"             # element still attached
        @test "NON_LINE_ON_BUS" in _log_codes(net′)
    end
end

@testset "remove_dangling_lines — ibr/capacitor at leaf prevents removal (#275)" begin
    for (cat, elt) in (("ibr", _ibr("B")), ("capacitor", _capacitor("B")))
        net = Dict{String,Any}(
            "bus"            => Dict("A" => _bus(), "B" => _bus()),
            "linecode"       => _lc("lc1"),
            "line"           => Dict("l1" => _line("A", "B")),
            "voltage_source" => Dict("vs" => _vsource("A")),
            cat              => Dict("e1" => elt),
        )
        net′ = remove_dangling_lines(net)
        @test length(net′["line"]) == 1                 # stub not pruned
        @test haskey(net′["bus"], "B")
    end
end

@testset "collapse_closed_switches — ibr/capacitor bus redirected (#275)" begin
    for (cat, elt) in (("ibr", _ibr("B")), ("capacitor", _capacitor("B")))
        net = Dict{String,Any}(
            "bus"            => Dict("A" => _bus(), "B" => _bus()),
            "switch"         => Dict("sw" => _switch("A", "B"; open=false)),
            "voltage_source" => Dict("vs" => _vsource("A")),
            cat              => Dict("e1" => elt),
        )
        net′ = collapse_closed_switches(net)
        @test !haskey(net′["bus"], "B")                 # B absorbed into A
        @test net′[cat]["e1"]["bus"] == "A"             # element redirected, not orphaned
    end
end

@testset "n_winding transformer visible to simplify helpers (#275)" begin
    # A winding on the intermediate bus B blocks the series merge.
    net = Dict{String,Any}(
        "bus"         => Dict("A" => _bus(), "B" => _bus(), "C" => _bus(), "D" => _bus()),
        "linecode"    => _lc("lc1"),
        "line"        => Dict("l1" => _line("A", "B"), "l2" => _line("B", "C")),
        "load"        => Dict("ld" => _load("C")),
        "transformer" => Dict("n_winding" => Dict("t1" => _nwinding(["B", "D"]))),
    )
    net′ = merge_series_lines(net)
    @test length(net′["line"]) == 2
    @test haskey(net′["bus"], "B")
    @test "NON_LINE_ON_BUS" in _log_codes(net′)

    # A switch collapse redirects the winding's bus from B to A.
    net2 = Dict{String,Any}(
        "bus"            => Dict("A" => _bus(), "B" => _bus(), "D" => _bus()),
        "switch"         => Dict("sw" => _switch("A", "B"; open=false)),
        "voltage_source" => Dict("vs" => _vsource("A")),
        "transformer"    => Dict("n_winding" => Dict("t1" => _nwinding(["B", "D"]))),
    )
    net2′ = collapse_closed_switches(net2)
    @test !haskey(net2′["bus"], "B")
    @test net2′["transformer"]["n_winding"]["t1"]["windings"][1]["bus"] == "A"
end
