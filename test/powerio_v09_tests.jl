# PowerIO 0.9 BMOPF writer contracts consumed by BMOPFTools.

@testset "PowerIO 0.9 BMOPF writer" begin
    @testset "pairable regulator legs merge into one open delta regulator" begin
        # OpenDSS represents an open delta regulator bank as two independent
        # single phase transformers. RegControl marks both as regulator legs;
        # PowerIO must pair them while writing BMOPF rather than leave this test
        # to a hand built BMOPF object that bypasses the writer.
        source = read(
            joinpath(@__DIR__, "data", "pf_comparison", "pf_open_delta_reg.dss"),
            String,
        ) * """

        New RegControl.rc1 Transformer=reg1
        New RegControl.rc2 Transformer=reg2
        """

        net = mktempdir() do dir
            path = joinpath(dir, "pairable_open_delta.dss")
            write(path, source)
            from_dss(path)
        end

        transformers = net["transformer"]
        @test Set(keys(transformers)) == Set(["open_delta_regulator"])
        regulator = only(values(transformers["open_delta_regulator"]))
        @test regulator["connection"] == "ABBC"
        @test regulator["tap_ratio"] == [1.05, 1.025]
        @test regulator["terminal_map_from"] == ["a", "b", "c"]
        @test regulator["terminal_map_to"] == ["a", "b", "c"]

        diagnostics = net["_meta"]["powerio_diagnostics"]
        merged = only(filter(
            d -> d["code"] == "EMIT.BMOPF.TRANSFORMER_OPEN_DELTA_MERGED",
            diagnostics,
        ))
        @test merged["component_type"] == "transformer"
        @test merged["component_id"] == "reg1"
    end
end
