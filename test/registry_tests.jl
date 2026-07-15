# registry_tests.jl
#
# Completeness guard for COMPONENT_COLLECTIONS.
#
# COMPONENT_COLLECTIONS is the single source of truth for "every top-level
# component collection", consumed by each_terminal_array, _any_component_has_ts_ref
# and get_snapshot. Historically each of those kept its own inline tuple and the
# three drifted apart from one another and from the schema.
#
# This testset makes that drift impossible to introduce silently: every top-level
# property in the bundled JSON Schema must be classified as EITHER a component
# collection (it lives in COMPONENT_COLLECTIONS) OR an explicitly-known
# non-component (it lives in _NON_COMPONENT_KEYS below, with a reason). A schema
# key that is neither fails the test and names itself, forcing a decision.

using JSON3

# Top-level schema keys that are deliberately NOT component collections.
# Each entry is a decision, not an oversight — keep the rationale current.
const _NON_COMPONENT_KEYS = Dict{String,String}(
    "transformer"          => "subtype dispatch via TRANSFORMER_SUBTYPES, not a flat instance collection",
    "linecode"             => "shared catalog referenced by lines; defines no terminals of its own",
    "wire_data"            => "shared catalog of conductor properties",
    "line_geometry"        => "shared catalog of tower/cable geometries",
    "time_series"          => "data store keyed by series id, not a component",
    "name"                 => "scalar document field",
    "meta"                 => "document metadata",
    "extras"               => "free-form passthrough block",
    "terminal_conventions" => "document-level terminal-role convention block",
)

@testset "Component registry completeness" begin
    schema_path = joinpath(@__DIR__, "..", "src", "validation", "schemas",
                           "draft_bmopf_schema.json")
    schema = JSON3.read(read(schema_path, String))

    schema_keys = Set{String}(string(k) for k in keys(schema["properties"]))
    registry    = Set{String}(BMOPFTools.COMPONENT_COLLECTIONS)
    known_other = Set{String}(keys(_NON_COMPONENT_KEYS))

    # 1. Every schema key is classified: component, or known non-component.
    unclassified = setdiff(schema_keys, registry, known_other)
    @test isempty(unclassified) ||
        error("Top-level schema key(s) not classified: " *
              join(sort(collect(unclassified)), ", ") *
              " — add to COMPONENT_COLLECTIONS in src/BMOPFTools.jl if they are " *
              "component collections, or to _NON_COMPONENT_KEYS here (with a reason) if not")

    # 2. The registry contains no phantom types the schema has dropped.
    phantom = setdiff(registry, schema_keys)
    @test isempty(phantom) ||
        error("COMPONENT_COLLECTIONS names type(s) absent from the schema: " *
              join(sort(collect(phantom)), ", ") * " — remove them or update the schema")

    # 3. Likewise for the non-component deny-list, so it cannot rot either.
    stale = setdiff(known_other, schema_keys)
    @test isempty(stale) ||
        error("_NON_COMPONENT_KEYS names key(s) absent from the schema: " *
              join(sort(collect(stale)), ", "))

    # 4. A key cannot be both.
    @test isempty(intersect(registry, known_other))

    # 5. The time-series subset is a genuine subset. control_profile is the one
    #    documented exclusion (nested control-law params the resolver cannot scale).
    ts = Set{String}(BMOPFTools.TS_COMPONENT_COLLECTIONS)
    @test issubset(ts, registry)
    @test setdiff(registry, ts) == Set(["control_profile"])
end

@testset "Registry is actually consumed by the iteration helpers" begin
    # A regression guard with teeth: build a net whose DC components carry
    # integer terminals. each_terminal_array must normalise them, which only
    # happens if it iterates the registry rather than a stale inline tuple.
    raw = """
    {"bus":{"b1":{"terminal_names":["1","2","3","n"],
                  "perfectly_grounded_terminals":["n"],
                  "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
     "voltage_source":{"vs":{"bus":"b1","terminal_map":["1","2","3"],
         "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
     "dc_bus":{"d1":{"terminal_names":[1,2]}},
     "dc_load":{"dl1":{"dc_bus":"d1","terminal_map":[1,2],"p":1000.0}}}
    """
    net = parse_bmopf(raw; from_string=true)

    @test all(t isa AbstractString for t in net["dc_bus"]["d1"]["terminal_names"])
    @test all(t isa AbstractString for t in net["dc_load"]["dl1"]["terminal_map"])
end
