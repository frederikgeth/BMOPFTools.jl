@testset "OPF semantic coordinate and residual blocks" begin
    network = parse_bmopf("""
    {"bus":{
        "source":{"terminal_names":["1","n"],
                  "perfectly_grounded_terminals":["n"]},
        "loadbus":{"terminal_names":["1","n"],
                   "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"source":{"bus":"source","terminal_map":["1"],
         "v_magnitude":[1000.0],"v_angle":[0.0]}},
     "linecode":{"lc":{"R_series_1_1":0.5,"R_series_2_2":0.5}},
     "line":{"line":{"bus_from":"source","bus_to":"loadbus",
         "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
         "linecode":"lc","length":1.0}},
     "load":{"load":{"bus":"loadbus","terminal_map":["1","n"],
         "configuration":"WYE","p_nom":[100000.0],"q_nom":[20000.0]}}}
    """; from_string=true)
    policy = OpfScaling(
        name=:semantic_blocks,
        power_base=2e5,
        voltage_bases=Dict("source" => 500.0, "loadbus" => 500.0),
    )
    context = build_opf_model(
        network; scaling_policy=policy, add_objective=false,
    )
    enforce_kcl!(context)
    schema = opf_diagnostic_schema(context)
    @test schema.schema_version == v"1.0.0"
    @test schema.scaling["kind"] == "consistent_per_unit"
    @test Set(keys(schema.coordinate_bases["ac"])) ==
        Set(["source", "loadbus"])
    @test isempty(schema.coordinate_bases["dc"])
    @test schema.capabilities["semantic_blocks"] === true
    variable_blocks = filter(block -> block.kind == :variable,
                             schema.semantic_blocks)
    constraint_blocks = filter(block -> block.kind == :constraint,
                               schema.semantic_blocks)
    @test !isempty(variable_blocks)
    @test !isempty(constraint_blocks)
    @test all(block.kind == :variable for block in variable_blocks)
    @test all(block.kind == :constraint for block in constraint_blocks)
    @test all(length(block.members) == length(block.components) == 2
        for block in vcat(variable_blocks, constraint_blocks))
    @test all(block.model_to_canonical == [1.0 0.0; 0.0 1.0]
        for block in vcat(variable_blocks, constraint_blocks))

    voltage_block = only(filter(block ->
        block.members == [
            opf_bus_voltage_key("source", "1"; component=:real),
            opf_bus_voltage_key("source", "1"; component=:imag),
        ], variable_blocks))
    @test voltage_block.quantity == :voltage
    @test voltage_block.physical_unit == :V
    @test voltage_block.components == [:real, :imag]

    kcl_block = only(filter(block ->
        block.members == [
            OpfModelKey(:constraint, :kcl_r, ("loadbus", "1")),
            OpfModelKey(:constraint, :kcl_i, ("loadbus", "1")),
        ], constraint_blocks))
    @test kcl_block.quantity == :current
    @test kcl_block.set_contract == :zero_equality

    load_block = only(filter(block ->
        first(block.members).family == :load_power_real &&
        first(block.members).index == ("load", 1), constraint_blocks))
    @test load_block.components == [:active, :reactive]
    @test load_block.quantity == :power
    @test load_block.set_contract == :scalar_bounds
    @test load_block.reference_physical_scale ≈ hypot(100000.0, 20000.0)
    @test load_block.reference_scale_source ==
        "load per-phase nominal apparent power"

    line_block = only(filter(block ->
        first(block.members).family == :line_voltage_drop_real &&
        first(block.members).index == ("line", 1), constraint_blocks))
    @test line_block.quantity == :voltage
    @test line_block.set_contract == :zero_equality

    copy_blocks = opf_diagnostic_schema(context).semantic_blocks
    copy_blocks[1].metadata["mutated"] = true
    @test !haskey(
        opf_diagnostic_schema(context).semantic_blocks[1].metadata,
        "mutated",
    )
    @test_throws ArgumentError BMOPFTools.opf_semantic_blocks(context; kind=:objective)

    overlap = BMOPFTools.OpfSemanticBlock(
        "overlap",
        :variable,
        copy(voltage_block.members),
        [:real, :imag],
        :voltage,
        :V,
    )
    @test_throws ArgumentError BMOPFTools.register_opf_semantic_block!(context, overlap)
    @test_throws ArgumentError BMOPFTools.OpfSemanticBlock(
        "singular",
        :variable,
        copy(voltage_block.members),
        [:real, :imag],
        :voltage,
        :V;
        model_to_canonical=[1.0 0.0; 0.0 0.0],
    )

    # Native blocks are lazy, but a custom block registered after KCL must
    # still fail at its own registration call when it overlaps a native pair.
    late_context = build_opf_model(
        network; scaling_policy=policy, add_objective=false,
    )
    enforce_kcl!(late_context)
    late_overlap = BMOPFTools.OpfSemanticBlock(
        "late_overlap",
        :variable,
        [
            opf_bus_voltage_key("source", "1"; component=:real),
            opf_bus_voltage_key("source", "1"; component=:imag),
        ],
        [:real, :imag],
        :voltage,
        :V,
    )
    @test_throws ArgumentError BMOPFTools.register_opf_semantic_block!(
        late_context, late_overlap,
    )
    @test !isempty(opf_diagnostic_schema(late_context).semantic_blocks)

    # A conflict with a user block that predates KCL must roll back native
    # registration. Repeating the schema request should report the same user
    # conflict, rather than an unrelated duplicate native id from a partial
    # first pass.
    pre_context = build_opf_model(
        network; scaling_policy=policy, add_objective=false,
    )
    pre_overlap = BMOPFTools.OpfSemanticBlock(
        "mine",
        :variable,
        [
            opf_bus_voltage_key("source", "1"; component=:real),
            opf_bus_voltage_key("source", "1"; component=:imag),
        ],
        [:real, :imag],
        :voltage,
        :V,
    )
    BMOPFTools.register_opf_semantic_block!(pre_context, pre_overlap)
    enforce_kcl!(pre_context)
    first_schema_error = try
        opf_diagnostic_schema(pre_context)
        nothing
    catch error
        error
    end
    second_schema_error = try
        opf_diagnostic_schema(pre_context)
        nothing
    catch error
        error
    end
    @test first_schema_error isa ArgumentError
    @test second_schema_error isa ArgumentError
    @test occursin("mine", sprint(showerror, first_schema_error))
    @test occursin("mine", sprint(showerror, second_schema_error))

    provenance = opf_research_provenance(context)
    semantic = provenance["semantic_references"]
    @test semantic["semantic_block_counts_by_kind"]["variable"] ==
        length(variable_blocks)
    @test semantic["semantic_block_counts_by_kind"]["constraint"] ==
        length(constraint_blocks)
    @test length(semantic["semantic_blocks"]) ==
        length(variable_blocks) + length(constraint_blocks)
end


@testset "late transformer power auxiliaries have semantic ownership" begin
    network = parse_bmopf(raw"""
    {"bus":{
        "hv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
        "lv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"source":{"bus":"hv","terminal_map":["1"],
        "v_magnitude":[11000.0],"v_angle":[0.0]}},
     "transformer":{"single_phase":{"t1":{"bus_from":"hv","bus_to":"lv",
        "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
        "v_nom_from":11000.0,"v_nom_to":240.0,"s_rating":50000.0,
        "r_series_from":24.2,"r_series_to":0.01152,
        "x_series_from":96.8,"x_series_to":0.0}}},
     "load":{"load":{"bus":"lv","terminal_map":["1","n"],
        "configuration":"WYE","p_nom":[30000.0],"q_nom":[10000.0]}}}
    """; from_string=true)
    context = build_opf_model(network; add_objective=false)
    keys = Set(opf_object_keys(context))
    index = ("t1", "fr", 1)
    # Device-stage diagnostics must see dynamically created transformer
    # auxiliaries without mutating the staged model by enforcing KCL.
    @test OpfModelKey(:variable, :transformer_coil_p, index) in keys
    @test OpfModelKey(:variable, :transformer_coil_q, index) in keys
    enforce_kcl!(context)
    keys = Set(opf_object_keys(context))
    @test OpfModelKey(:constraint, :transformer_power_link_p,
                      ("t1", "from", 1)) in keys
    @test OpfModelKey(:constraint, :transformer_power_link_q,
                      ("t1", "from", 1)) in keys
    power_blocks = filter(block -> block.quantity == :power,
                          BMOPFTools.opf_semantic_blocks(context))
    @test any(block -> first(block.members).family == :transformer_coil_p,
              power_blocks)
    @test any(block -> first(block.members).family == :transformer_power_link_p,
              power_blocks)
end
