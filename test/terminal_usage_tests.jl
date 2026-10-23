using Test, BMOPFTools, JSON3

_tu_net() = JSON3.read(read(joinpath(@__DIR__,"data","terminal_usage","usage.json"),String),Dict{String,Any})
function _tu_check(net; public=false)
    fs = Finding[]
    result = public ? domain_rules_check(net,fs)["terminal_conventions"] :
        BMOPFTools._check_terminal_conventions(net,fs,Ref(0))
    result, fs
end
_tu_code(fs,code) = [f for f in fs if f.code==code]
_tu_signature(fs) = [(f.code,f.component_type,f.component_id,f.detail) for f in fs]
_tu_winding(net) = net["transformer"]["n_winding"]["t"]["windings"][1]

@testset "Terminal declaration and usage inventory (#410)" begin
    @testset "minimal witness, public results and exact source paths" begin
        net = _tu_net(); original = deepcopy(net)
        report, fs = _tu_check(net; public=true)
        @test net == original
        @test report["status"] == "assessed"
        @test report["role_source"] == "declared"
        @test report["unused_labels"] == ["unused"]
        @test report["unclassified_labels"] == ["extra"]
        @test length(report["declarations"]) == 4
        unused = only(_tu_code(fs,"I.CONV.UNUSED_LABEL"))
        @test unused.severity == INFO
        @test unused.detail["declarations"] == [Dict("label"=>"unused","role"=>"phase",
            "path"=>"/terminal_conventions/phase/2")]
        f = only(_tu_code(fs,"W.CONV.TERMINAL_UNCLASSIFIED"))
        @test f.detail["labels"] == ["extra"]
        @test f.detail["buses"] == ["b"]
        @test [u["path"] for u in f.detail["usage"]] ==
            ["/bus/b/terminal_names/3", "/transformer/n_winding/t/windings/0/terminal_map/0"]
        @test f.detail["usage"][2]["winding"] == 1
        @test !any(f -> f.severity==ERROR,fs)
        # A spare conductor is a real use of its role label, even when unwired.
        @test "spare" ∉ unused.detail["labels"]
        @test JSON3.read(JSON3.write(report),Dict{String,Any}) == report
        @test all(JSON3.read(JSON3.write(f.detail),Dict{String,Any})==f.detail for f in fs)
        # Exercise the inventory through the public whole-case/report path.
        analyzed = analyze(net)
        buf = IOBuffer(); BMOPFTools.render_json(analyzed,buf)
        exported = JSON3.read(String(take!(buf)),Dict{String,Any})
        @test exported["results"]["domain_rules"]["terminal_conventions"]["unused_labels"] == ["unused"]
        @test net == original
    end

    @testset "nodal maps, both branch ends, windings and grounding" begin
        for kind in ("load","generator","ibr","shunt","voltage_source","capacitor")
            net = _tu_net()
            net[kind] = Dict("device"=>Dict("bus"=>"b","terminal_map"=>["extra","return"]))
            report, fs = _tu_check(net)
            f = only(_tu_code(fs,"W.CONV.TERMINAL_UNCLASSIFIED"))
            @test any(u -> u["path"]=="/$kind/device/terminal_map/0" &&
                u["reference_status"]=="resolved",f.detail["usage"])
            @test report["unused_labels"] == ["unused"]
        end
        for kind in ("line","switch")
            net = _tu_net()
            net[kind] = Dict("branch"=>Dict("bus_from"=>"b","bus_to"=>"b",
                "terminal_map_from"=>["extra","return"],"terminal_map_to"=>["return","extra"]))
            _, fs = _tu_check(net)
            paths = [u["path"] for u in only(_tu_code(fs,"W.CONV.TERMINAL_UNCLASSIFIED")).detail["usage"]]
            @test "/$kind/branch/terminal_map_from/0" in paths
            @test "/$kind/branch/terminal_map_to/1" in paths
        end
        for subtype in setdiff(BMOPFTools.TRANSFORMER_SUBTYPES,BMOPFTools.WINDING_LIST_SUBTYPES)
            net = _tu_net()
            net["transformer"] = Dict(subtype=>Dict("t"=>Dict("bus_from"=>"b","bus_to"=>"b",
                "terminal_map_from"=>["extra","return"],"terminal_map_to"=>["return","extra"])))
            _, fs = _tu_check(net)
            paths = [u["path"] for u in only(_tu_code(fs,"W.CONV.TERMINAL_UNCLASSIFIED")).detail["usage"]]
            @test "/transformer/$subtype/t/terminal_map_from/0" in paths
            @test "/transformer/$subtype/t/terminal_map_to/1" in paths
        end
        net = _tu_net(); push!(net["bus"]["b"]["perfectly_grounded_terminals"],"extra")
        _, fs = _tu_check(net)
        @test any(u -> u["path"]=="/bus/b/perfectly_grounded_terminals/1",
            only(_tu_code(fs,"W.CONV.TERMINAL_UNCLASSIFIED")).detail["usage"])
        # DC names and DC-side converter maps do not acquire AC roles.
        net["dc_bus"] = Dict("dc"=>Dict("terminal_names"=>["dc_only"]))
        net["ibr"] = Dict("i"=>Dict("bus"=>"b","terminal_map"=>["a","return"],
            "dc_terminal_map"=>["dc_only"]))
        report, _ = _tu_check(net)
        @test !any(u -> u["label"]=="dc_only",report["usage"])
    end

    @testset "component-only labels and unknown references retain integrity ownership" begin
        net = _tu_net()
        push!(net["terminal_conventions"]["phase"],"nested_only")
        _tu_winding(net)["terminal_map"][1] = "nested_only"
        report, fs = _tu_check(net)
        @test "nested_only" ∉ report["unused_labels"]
        u = only(filter(u -> u["label"]=="nested_only",report["usage"]))
        @test u["reference_status"] == "unknown_terminal"
        # Unclassified map-only ghosts are not an extra role warning for a
        # nonexistent bus terminal. Their raw usage is still inspectable.
        _tu_winding(net)["terminal_map"][1] = "ghost"
        report, fs = _tu_check(net)
        @test report["unclassified_labels"] == ["extra"]
        @test only(filter(u -> u["label"]=="ghost",report["usage"]))["reference_status"] == "unknown_terminal"
        ints = Finding[]; integrity_check(net,ints)
        @test length(_tu_code(ints,"E.INT.UNKNOWN_TERMINAL")) == 1
        _tu_winding(net)["bus"] = "missing"
        report, fs = _tu_check(net)
        @test !any(u -> u["reference_status"]=="unknown_bus",
            only(_tu_code(fs,"W.CONV.TERMINAL_UNCLASSIFIED")).detail["usage"])
        ints = Finding[]; integrity_check(net,ints)
        @test length(_tu_code(ints,"E.INT.UNKNOWN_BUS")) == 1
        @test isempty(_tu_code(ints,"E.INT.UNKNOWN_TERMINAL"))
        # Grounding has the same reference-error owner, with an exact field.
        net = _tu_net(); push!(net["bus"]["b"]["perfectly_grounded_terminals"],"ghost")
        _, fs = _tu_check(net)
        @test only(_tu_code(fs,"W.CONV.TERMINAL_UNCLASSIFIED")).detail["labels"] == ["extra"]
        ints = Finding[]; integrity_check(net,ints)
        @test only(_tu_code(ints,"E.INT.UNKNOWN_TERMINAL")).detail["field"] == "perfectly_grounded_terminals"
    end

    @testset "explicit bus metadata, overlap and multiple neutrals" begin
        for metadata in ("a", "absent", nothing, ["return"])
            net = _tu_net(); net["bus"]["b"]["neutral_terminal"] = metadata
            original = deepcopy(net); _, fs = _tu_check(net)
            f = only(_tu_code(fs,"E.CONV.BUS_ROLE_CONFLICT"))
            @test f.detail["path"] == "/bus/b/neutral_terminal"
            @test f.detail["label"] == metadata
            @test net == original
        end
        net = _tu_net(); net["bus"]["b"]["neutral_terminal"] = "return"
        _, fs = _tu_check(net)
        @test isempty(_tu_code(fs,"E.CONV.BUS_ROLE_CONFLICT"))
        push!(net["terminal_conventions"]["phase"],"return")
        _, fs = _tu_check(net)
        overlap = only(_tu_code(fs,"E.CONV.ROLE_OVERLAP"))
        @test overlap.detail["labels"] == ["return"]
        @test length(overlap.detail["declarations"]) == 2
        @test isempty(_tu_code(fs,"E.CONV.BUS_ROLE_CONFLICT"))
        pop!(net["terminal_conventions"]["phase"])
        push!(net["terminal_conventions"]["neutral"],"second")
        push!(net["bus"]["b"]["terminal_names"],"second")
        _, fs = _tu_check(net)
        @test only(_tu_code(fs,"W.CONV.MULTIPLE_NEUTRALS")).detail["terminals"] == ["return","second"]
        # Classifier does not duplicate the physical map checks from #409.
        net = _tu_net(); push!(net["terminal_conventions"]["phase"],"extra")
        net["switch"] = Dict("s"=>Dict("bus_from"=>"b","bus_to"=>"c",
            "terminal_map_from"=>["a","return"],"terminal_map_to"=>["return","a"]))
        _, fs = _tu_check(net)
        @test !any(f -> f.severity==ERROR,fs)
        spec = Finding[]; spec_conformance_check(net,spec)
        @test length(_tu_code(spec,"E.TMAP.PHASE_TO_NEUTRAL")) == 2
    end

    @testset "malformed declarations and incomplete inventories are explicit" begin
        for bad in (nothing, 7, "phase", ["a"], Dict("phase"=>nothing),
                    Dict("neutral"=>"return"), Dict("earth"=>["pe",4]))
            net = _tu_net(); net["terminal_conventions"] = bad
            original = deepcopy(net); report, fs = _tu_check(net; public=true)
            @test report["status"] == "indeterminate"
            @test report["role_source"] == "invalid"
            @test report["resolved_roles"] === nothing
            @test report["unused_labels"] === nothing
            @test length(_tu_code(fs,"E.CONV.DECLARATION_INVALID")) == 1
            @test isempty(_tu_code(fs,"W.CONV.TERMINAL_ROLES_INFERRED"))
            @test isempty(_tu_code(fs,"I.CONV.UNUSED_LABEL"))
            @test_throws ArgumentError BMOPFTools._terminal_roles(net)
            @test_throws ArgumentError parse_bmopf(JSON3.write(net); from_string=true)
            @test_throws ArgumentError write_bmopf(net,IOBuffer())
            # The public read-only analysis/report path must still diagnose
            # malformed declarations rather than invoking runtime resolution.
            analyzed = analyze(net)
            @test length(_tu_code(analyzed.findings,"E.CONV.DECLARATION_INVALID")) == 1
            output = IOBuffer(); BMOPFTools.render_json(analyzed,output)
            serialized = JSON3.read(String(take!(output)),Dict{String,Any})
            @test serialized["results"]["domain_rules"]["terminal_conventions"]["role_source"] == "invalid"
            @test net == original
        end
        for bad in (nothing, "a", ["a",4])
            net = _tu_net()
            net["shunt"] = Dict("s"=>Dict("bus"=>"b","terminal_map"=>bad))
            report, fs = _tu_check(net)
            @test report["status"] == "indeterminate"
            @test "/shunt/s/terminal_map" in report["unassessed_paths"]
            @test isempty(_tu_code(fs,"I.CONV.UNUSED_LABEL"))
        end
        for (table, value, path) in (("transformer",Dict("unsupported"=>Dict()),"/transformer/unsupported"),
                ("transformer",Dict("n_winding"=>Dict("t"=>Dict("windings"=>nothing))),"/transformer/n_winding/t/windings"),
                ("line",nothing,"/line"))
            net = _tu_net(); net[table] = value
            report, fs = _tu_check(net)
            @test report["status"] == "indeterminate"
            @test path in report["unassessed_paths"]
            @test isempty(_tu_code(fs,"I.CONV.UNUSED_LABEL"))
        end
        net = _tu_net(); net["bus"]["b"]["terminal_names"] = nothing
        report, _ = _tu_check(net)
        @test report["status"] == "indeterminate"
        @test "/bus/b/terminal_names" in report["unassessed_paths"]
        net = _tu_net(); net["terminal_conventions"] = Dict{String,Any}()
        report, fs = _tu_check(net)
        @test report["unclassified_labels"] == ["a","extra","return","spare"]
        @test isempty(_tu_code(fs,"W.CONV.TERMINAL_ROLES_INFERRED"))
    end

    @testset "unrelated malformed buses do not hide declaration evidence" begin
        net = JSON3.read(read(joinpath(@__DIR__,"data","terminal_usage","malformed_bus.json"),String),Dict{String,Any})
        original = deepcopy(net)
        report, fs = _tu_check(net)
        @test report["status"] == "indeterminate"
        @test report["unused_labels"] === nothing
        @test report["resolved_roles"] !== nothing
        @test only(_tu_code(fs,"E.CONV.ROLE_OVERLAP")).detail["labels"] == ["return"]
        @test only(_tu_code(fs,"E.CONV.BUS_ROLE_CONFLICT")).component_id == "c"
        @test only(_tu_code(fs,"W.CONV.TERMINAL_UNCLASSIFIED")).detail["labels"] == ["other"]
        @test net == original
        # Even a malformed whole bus table does not invalidate the independently
        # known role lists. Inventory-dependent conclusions stay unavailable.
        net["bus"] = nothing
        report, fs = _tu_check(net)
        @test report["status"] == "indeterminate"
        @test report["resolved_roles"] !== nothing
        @test length(_tu_code(fs,"E.CONV.ROLE_OVERLAP")) == 1
        @test isempty(_tu_code(fs,"I.CONV.UNUSED_LABEL"))
        # Absence of an explicit block still has its existing diagnostic, even
        # when malformed bus names prevent complete legacy role inference.
        net = _tu_net(); delete!(net,"terminal_conventions")
        net["bus"]["b"]["terminal_names"] = nothing
        report, fs = _tu_check(net)
        @test report["status"] == "indeterminate"
        @test report["resolved_roles"] === nothing
        @test length(_tu_code(fs,"W.CONV.TERMINAL_ROLES_INFERRED")) == 1
    end

    @testset "reference errors require a valid bus terminal list" begin
        for bad in (nothing,"a",["a",4])
            net = _tu_net(); net["bus"]["b"]["terminal_names"] = bad
            original = deepcopy(net)
            fs = Finding[]; integrity_check(net,fs)
            @test isempty(_tu_code(fs,"E.INT.UNKNOWN_TERMINAL"))
            @test net == original
        end
        # The new grounding diagnostics have stable bus order, independent of
        # dictionary insertion. Keep the genuine missing-terminal errors.
        net = Dict{String,Any}("terminal_conventions"=>Dict("phase"=>["a"]),
            "bus"=>Dict{String,Any}(id=>Dict("terminal_names"=>["a"],
                "perfectly_grounded_terminals"=>["missing"]) for id in ("z","a","q","b")))
        fs = Finding[]; integrity_check(net,fs)
        refs = _tu_code(fs,"E.INT.UNKNOWN_TERMINAL")
        @test [f.component_id for f in refs] == ["a","b","q","z"]
        @test all(f.detail["field"]=="perfectly_grounded_terminals" for f in refs)
        reordered = deepcopy(net)
        reordered["bus"] = Dict(k=>net["bus"][k] for k in reverse(sort!(collect(keys(net["bus"])))))
        other = Finding[]; integrity_check(reordered,other)
        @test _tu_signature(_tu_code(other,"E.INT.UNKNOWN_TERMINAL")) == _tu_signature(refs)
    end

    @testset "determinism, escaping, round trips and legacy writer behavior" begin
        reorder(x) = x isa AbstractDict ? Dict{String,Any}(k=>reorder(x[k]) for k in reverse(sort!(collect(keys(x))))) :
            x isa AbstractVector ? [reorder(v) for v in x] : x
        net = _tu_net(); a, fa = _tu_check(net); b, fb = _tu_check(reorder(net))
        @test a == b
        @test _tu_signature(fa) == _tu_signature(fb)
        raw = JSON3.read(JSON3.write(net),Dict{String,Any})
        c, fc = _tu_check(raw)
        @test c == a
        @test _tu_signature(fc) == _tu_signature(fa)
        net["shunt"] = Dict("s~/"=>Dict("bus"=>"b","terminal_map"=>["extra"]))
        report, _ = _tu_check(net)
        @test any(u -> u["path"]=="/shunt/s~0~1/terminal_map/0",report["usage"])
        # Valid nonstandard labels and map permutations keep their declared roles.
        for neutral in ("4","N-custom"), tm in (["a","return"],["return","a"])
            net = _tu_net(); push!(net["terminal_conventions"]["phase"],"extra")
            net["terminal_conventions"]["neutral"] = [neutral]
            for b in values(net["bus"])
                b["terminal_names"] = [t=="return" ? neutral : t for t in b["terminal_names"]]
                b["perfectly_grounded_terminals"] = [neutral]
            end
            for w in net["transformer"]["n_winding"]["t"]["windings"]
                w["terminal_map"] = [t=="return" ? neutral : t for t in tm]
            end
            _, fs = _tu_check(net)
            @test !any(f -> f.code in ("E.CONV.ROLE_OVERLAP","W.CONV.TERMINAL_UNCLASSIFIED","E.CONV.BUS_ROLE_CONFLICT"),fs)
            BMOPFTools._materialize_terminal_roles!(net)
            before = deepcopy(net); buf = IOBuffer(); write_bmopf(net,buf)
            parsed = parse_bmopf(String(take!(buf)); from_string=true)
            @test net == before
            @test all(parsed["terminal_conventions"][role] == sort!(unique(net["terminal_conventions"][role]))
                for role in ("phase","neutral","earth"))
            @test parsed["bus"]["b"]["neutral_terminal"] == neutral
            @test only(_tu_code(last(_tu_check(parsed)),"I.CONV.UNUSED_LABEL")).detail["labels"] == ["unused"]
        end
        legacy = Dict{String,Any}("bus"=>Dict("b"=>Dict("terminal_names"=>["a","n"])),
            "voltage_source"=>Dict("s"=>Dict("bus"=>"b","terminal_map"=>["a"],"v_magnitude"=>[230.0],"v_angle"=>[0.0])))
        original = deepcopy(legacy); report, fs = _tu_check(legacy)
        @test report["role_source"] == "inferred"
        @test report["resolved_roles"] == Dict("phase"=>["a"],"neutral"=>["n"],"earth"=>String[])
        @test only(_tu_code(fs,"W.CONV.TERMINAL_ROLES_INFERRED")).detail["rule"] == "n_or_N_is_neutral"
        @test legacy == original
        buf = IOBuffer(); write_bmopf(legacy,buf)
        parsed = parse_bmopf(String(take!(buf)); from_string=true)
        @test parsed["terminal_conventions"]["neutral"] == ["n"]
        @test isempty(_tu_code(last(_tu_check(parsed)),"W.CONV.TERMINAL_ROLES_INFERRED"))
    end
end
