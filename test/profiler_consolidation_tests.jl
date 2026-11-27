# Report proportionality: consolidation of findings and the noise budget on
# decks an independent engine solves.

using Test
using BMOPFTools
isdefined(@__MODULE__, :_PG_PF) || include("profiler_test_helpers.jl")

@testset "Profiler: consolidation and noise" begin
    @testset "consolidation: roll-up is thresholded, lossless and never hides errors" begin
        mk(sev, code, id; ctype=:line) = Finding(sev, code, :domain_rules, ctype, id,
            "msg $id", Dict{String,Any}("k" => id))
        cfg(n) = Dict{String,Any}("report" => Dict{String,Any}("rollup_threshold" => n))
        raw = Finding[mk(WARNING, "W.X.MANY", "l$(lpad(k, 2, '0'))") for k in 30:-1:1]
        push!(raw, mk(INFO, "I.X.FEW", "a"), mk(INFO, "I.X.FEW", "b"))
        append!(raw, [mk(ERROR, "E.X.MANY", "e$k") for k in 1:30])
        push!(raw, Finding(WARNING, "W.X.NET", :domain_rules, :network, nothing, "net"))

        out, summary = BMOPFTools._consolidate_findings(raw; config=cfg(25))
        rolled = filter(is_rolled_up, out)
        @test length(rolled) == 1
        r = only(rolled)
        @test r.code == "W.X.MANY" && r.severity == WARNING && r.component_id === nothing
        @test r.detail["count"] == 30
        @test r.detail["components"] == ["l$(lpad(k, 2, '0'))" for k in 1:30]
        @test count(f -> f.code == "E.X.MANY", out) == 30        # errors stay per component
        @test count(f -> f.code == "I.X.FEW", out) == 2          # below threshold
        @test summary["rolled_up"] == [Dict{String,Any}("code" => "W.X.MANY", "n" => 30)]
        @test summary["n_findings_before"] == 63 && summary["n_findings_after"] == 34

        # Lossless: expansion restores every per-component record.
        expanded = expand_findings(out)
        @test length(expanded) == length(raw)
        key(f) = (f.code, string(f.component_id), f.message, f.detail)
        @test Set(key.(expanded)) == Set(key.(raw))
        @test !any(is_rolled_up, expanded)

        # Boundary: exactly the threshold is not rolled up; one more is.
        at = Finding[mk(INFO, "I.X.AT", "c$k") for k in 1:25]
        @test !any(is_rolled_up, BMOPFTools._consolidate_findings(at; config=cfg(25))[1])
        push!(at, mk(INFO, "I.X.AT", "c26"))
        @test any(is_rolled_up, BMOPFTools._consolidate_findings(at; config=cfg(25))[1])
        # Disabled, and malformed thresholds fall back to the default.
        @test !any(is_rolled_up, BMOPFTools._consolidate_findings(at; config=cfg(0))[1])
        @test BMOPFTools._rollup_threshold(cfg(-1)) == 25
        @test BMOPFTools._rollup_threshold(cfg(true)) == 25
        @test BMOPFTools._rollup_threshold(Dict{String,Any}()) == 25
        # A component that raises one code twice cannot be keyed: left as is.
        dup = vcat(at, [mk(INFO, "I.X.AT", "c1")])
        @test !any(is_rolled_up, BMOPFTools._consolidate_findings(dup; config=cfg(25))[1])
    end

    @testset "consolidation: a stronger finding subsumes the weaker one" begin
        sw(id) = Finding(INFO, "I.PROV.LINE_SWITCH_LIKE", :provenance, :line, id, "s")
        lo(id) = Finding(WARNING, "W.DOM.LINE_LOW_IMPEDANCE", :domain_rules, :line, id, "l")
        out, summary = BMOPFTools._consolidate_findings(Finding[sw("a"), sw("b"), lo("b")])
        @test [(f.code, f.component_id) for f in out] ==
              [("I.PROV.LINE_SWITCH_LIKE", "a"), ("W.DOM.LINE_LOW_IMPEDANCE", "b")]
        @test summary["subsumed"][1]["components"] == ["b"]

        ops(n) = Finding(WARNING, "W.OPS.LINE_UNCONSTRAINED", :operational, :line, nothing,
            "o", Dict{String,Any}("n_unconstrained" => n))
        prov(ids) = Finding(WARNING, "W.PROV.I_MAX_ABSENT", :provenance, :line, nothing,
            "p", Dict{String,Any}("lines" => ids))
        same, _ = BMOPFTools._consolidate_findings(Finding[ops(2), prov(["x","y"])])
        @test [f.code for f in same] == ["W.PROV.I_MAX_ABSENT"]
        # Different counts are different facts: both stay.
        differ, _ = BMOPFTools._consolidate_findings(Finding[ops(3), prov(["x","y"])])
        @test length(differ) == 2
        alone, _ = BMOPFTools._consolidate_findings(Finding[ops(3)])
        @test length(alone) == 1
    end

    @testset "analyze reports a segmented feeder in proportion to its problems" begin
        # 40 sub-meter segments: one root cause, formerly 80 findings.
        net = _pg_feeder(; n_lines=40, len=0.1)
        report = _pg_analyze(net)
        low = [f for f in report.findings if f.code == "W.DOM.LINE_LOW_IMPEDANCE"]
        @test length(low) == 1 && is_rolled_up(low[1]) && low[1].detail["count"] == 40
        @test !any(f -> f.code == "I.PROV.LINE_SWITCH_LIKE", report.findings)
        @test report.results[:consolidation]["n_findings_after"] == length(report.findings)
        @test length(expand_findings(report)) > length(report.findings)
        # Rendering a roll-up works in every format.
        for ext in (".md", ".json", ".txt")
            path = tempname() * ext
            render(report, path)
            @test filesize(path) > 0
        end
        # Opting out restores the per-line findings.
        cfg = load_config(); cfg["report"]["rollup_threshold"] = 0
        flat = redirect_stderr(devnull) do; analyze(net; config=cfg); end
        @test count(f -> f.code == "W.DOM.LINE_LOW_IMPEDANCE", flat.findings) == 40
    end

    # ── Noise budget on decks an independent engine solves ──────────────────
    #
    # Every deck in test/data/pf_comparison (and the SWER feeder) is solved by
    # OpenDSS in the power-flow comparison tests: these are valid networks. The
    # profiler may comment on them, but an ERROR on one is a false flag, and
    # the warning count is a budget: raise it only with a reason.
    @testset "noise budget on OpenDSS-validated decks" begin
        own(f) = first(f.code, 2) in ("E.", "W.", "I.")
        decks = sort!([f for f in readdir(_PG_PF) if endswith(f, ".dss")])
        @test length(decks) >= 30
        # The one known exception: the deck leaves a PV terminal on OpenDSS
        # node 0, which the import does not materialize at that bus.
        known_errors = Dict("pf_pv_1ph.dss" => ["E.INT.UNKNOWN_TERMINAL"])
        total_warnings = 0; worst = 0
        cases = vcat([(d, () -> _pg_dss(d)) for d in decks],
                     [("SWER", () -> _pg_dss("../SWER/Master.dss"))])
        for (name, load) in cases
            report = _pg_analyze(load())
            errs = sort!([f.code for f in errors(report) if own(f)])
            @test errs == get(known_errors, name, String[])
            n = count(own, warnings(report))
            total_warnings += n; worst = max(worst, n)
        end
        @test worst <= 7                       # measured: 7 (pf_zip_delta.dss)
        @test total_warnings <= 95             # measured: 87 over 38 cases
    end
end
