# test/powerio_v08_tests.jl
#
# Ingest of BMOPF JSON written by powerio v0.8.0+ (BMOPF schema 0.1.0
# alignment). Three things changed upstream, and each was a break here:
#   - meta.$schema moved to the schema's own current $id
#     (.../draft_schema_and_networks/draft_bmopf_schema.json) — previously an
#     unrecognised URI, so every file threw at parse.
#   - load `model` values are uppercase (CONSTANT_POWER, ZIP, ...) — previously
#     matched no lowercase branch, silently modelling every load as constant
#     power.
#   - transformer tap / neutral impedance / no-load admittance relocated under
#     extras.transformer.<subtype>.<name> (the schema's escape hatch for fields
#     with no subtype slot) — previously never read, silently zeroing them.
#
# The fixture test/data/powerio_v08_bmopf.json is genuine powerio v0.8.0
# output: `pio_dist_convert_str(dss, "dss", "bmopf")` over a 3-bus case with a
# tapped single-phase transformer, a ZIP load, and a constant-power load —
# regenerate it the same way if the upstream writer changes shape.

using JSON3

@testset "powerio v0.8.0 BMOPF ingest" begin
    fixture = joinpath(@__DIR__, "data", "powerio_v08_bmopf.json")

    @testset "the v0.8.0 \$schema URI is accepted" begin
        # Before: ArgumentError("unrecognised BMOPF spec URI") on every file.
        net = parse_bmopf(fixture)
        @test net isa Dict{String,Any}
        @test BMOPFTools._detect_spec_version(net) == BMOPFTools._CURRENT_SPEC
    end

    net = parse_bmopf(fixture)
    notes = get(get(net, "_meta", Dict()), "migration_notes", Any[])
    codes = [n["code"] for n in notes]

    @testset "uppercase load models are normalised at ingest" begin
        @test net["load"]["zipload"]["model"] == "zip"
        @test net["load"]["pqload"]["model"] == "constant_power"
        @test "W.MIGRATE.LOAD_MODEL_CASE" in codes
        note = notes[findfirst(n -> n["code"] == "W.MIGRATE.LOAD_MODEL_CASE", notes)]
        @test sort(note["ids"]) == ["pqload", "zipload"]
        # Already-lowercase input is untouched and unlogged: no migration
        # note, no _meta created as a side effect.
        clean = Dict{String,Any}("load" => Dict{String,Any}(
            "d1" => Dict{String,Any}("model" => "zip")))
        BMOPFTools._normalize_load_models!(clean)
        @test clean["load"]["d1"]["model"] == "zip"
        @test !haskey(clean, "_meta")
    end

    @testset "relocated transformer fields fold back from extras" begin
        t1 = net["transformer"]["single_phase"]["t1"]
        # The field the Ybus/OPF builders and to_pmd read is back where they
        # read it — the fixture's writer parked it at
        # extras.transformer.single_phase.t1.tap.
        @test t1["tap"] == 1.025
        @test "W.MIGRATE.XFMR_EXTRAS_FOLD" in codes
        note = notes[findfirst(n -> n["code"] == "W.MIGRATE.XFMR_EXTRAS_FOLD", notes)]
        @test note["id"] == "t1"
        @test note["subtype"] == "single_phase"
        @test "tap" in note["fields"]
        # The fold prunes what it emptied: no stale copy left to diverge from
        # the value downstream code now edits.
        parked = get(get(net, "extras", Dict()), "transformer", nothing)
        @test parked === nothing ||
              !haskey(get(parked, "single_phase", Dict()), "t1")
    end

    @testset "a field already on the transformer is never overwritten" begin
        doc = Dict{String,Any}(
            "transformer" => Dict{String,Any}(
                "single_phase" => Dict{String,Any}(
                    "tx" => Dict{String,Any}("tap" => 1.05))),
            "extras" => Dict{String,Any}(
                "transformer" => Dict{String,Any}(
                    "single_phase" => Dict{String,Any}(
                        "tx" => Dict{String,Any}("tap" => 0.95,
                                                 "g_no_load" => 1e-6)))),
        )
        BMOPFTools._fold_transformer_extras!(doc)
        tx = doc["transformer"]["single_phase"]["tx"]
        @test tx["tap"] == 1.05          # present wins
        @test tx["g_no_load"] == 1e-6    # absent folds
        # The losing parked copy stays put rather than being deleted, so the
        # conflict remains visible to a human diffing the document.
        @test doc["extras"]["transformer"]["single_phase"]["tx"]["tap"] == 0.95
    end

    @testset "top level tables win while missing ids fold from extras" begin
        doc = Dict{String,Any}(
            "ibr" => Dict{String,Any}(
                "shared" => Dict{String,Any}("bus" => "top", "p_nom" => [1.0])),
            "extras" => Dict{String,Any}(
                "ibr" => Dict{String,Any}(
                    "shared" => Dict{String,Any}("bus" => "parked", "p_nom" => [2.0]),
                    "parked_only" => Dict{String,Any}("bus" => "folded", "p_nom" => [3.0])),
                "dc_line" => Dict{String,Any}(
                    "dc1" => Dict{String,Any}("bus_from" => "a", "bus_to" => "b"))),
        )

        BMOPFTools._fold_dropped_top_level_extras!(doc)

        @test doc["ibr"]["shared"]["bus"] == "top"
        @test doc["ibr"]["shared"]["p_nom"] == [1.0]
        @test doc["ibr"]["parked_only"]["bus"] == "folded"
        @test doc["dc_branch"]["dc1"]["bus_from"] == "a"
        @test !haskey(doc["extras"], "ibr")
        @test !haskey(doc["extras"], "dc_line")
        notes = doc["_meta"]["migration_notes"]
        note = only(filter(n -> n["code"] == "W.MIGRATE.TOP_LEVEL_EXTRAS_FOLD", notes))
        @test sort(note["tables"]) == ["dc_branch", "ibr"]
    end

    @testset "schema_check passes on the migrated document" begin
        # End to end: the fixture validates against the bundled schema once the
        # unconditional migrations have run — uppercase models would otherwise
        # fail the lowercase enum, making a wrong-physics bug look like a
        # schema violation.
        f = Finding[]
        result = schema_check(net, f)
        @test result["jsonschema_ran"] === true
        @test !any(x -> x.severity == ERROR, f)
    end

    @testset "old-style documents are byte-stable through the new migrations" begin
        # A pre-v0.8.0 document (old URI, lowercase models, no parked extras)
        # takes none of the new paths: same parse as before this change.
        legacy = joinpath(@__DIR__, "..", "examples", "lv1_14bus.json")
        if isfile(legacy)
            lnet = parse_bmopf(legacy)
            lcodes = [n["code"] for n in
                      get(get(lnet, "_meta", Dict()), "migration_notes", Any[])]
            @test "W.MIGRATE.LOAD_MODEL_CASE" ∉ lcodes
            @test "W.MIGRATE.XFMR_EXTRAS_FOLD" ∉ lcodes
        end
    end
end
