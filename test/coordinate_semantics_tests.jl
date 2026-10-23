using Test, BMOPFTools, JSON3

@testset "coordinate semantics" begin
    fixture = joinpath(@__DIR__, "data", "spatial_cartesian.json")
    cart = JSON3.read(read(fixture, String), Dict{String,Any})
    levels = Dict{String,Any}()
    spatial(net) = BMOPFTools._spatial_analysis(net, levels)
    original = deepcopy(cart)
    r = spatial(cart)
    @test cart == original
    @test r["coordinate_reference"]["status"] == "declared_cartesian"
    @test r["coordinate_reference"]["metric_distances_applicable"]
    @test !r["coordinate_reference"]["geodesic_distances_applicable"]
    @test r["coordinate_semantics"]["unit_scale_to_m"] == 0.3048
    @test r["coordinate_semantics"]["n_metric_eligible_buses"] == 2
    @test r["coordinate_semantics"]["n_with_reported_accuracy"] == 4
    @test r["coordinate_semantics"]["bus_issue_counts"]["bus_crs_conflict"] == 1
    @test r["coordinate_semantics"]["bus_issue_counts"]["nonphysical_coordinate_provenance"] == 1
    @test r["transformers"]["separation_m"]["max"] ≈ 1.524
    @test r["length_context"]["comparison_status_counts"]["chord_check"]["passed"] == 1
    # The foreign frame cannot create an exact-coordinate group with local data.
    @test r["coincidence"]["n_buses_in_groups"] == 2 # b and schematic, raw equality only
    @test JSON3.read(JSON3.write(BMOPFTools._jsonable(r))).coordinate_semantics.units == "ft"
    for (unit, distance) in (("m", 5.0), ("km", 5000.0), ("international_foot", 1.524))
        n = deepcopy(cart)
        n["meta"]["coordinate_reference_system"]["units"] = unit
        @test spatial(n)["transformers"]["separation_m"]["max"] ≈ distance
    end
    for (key, value, code) in (("units", "degrees", "coordinate_unit_domain_conflict"),
                               ("units", "furlongs", "unsupported_coordinate_units"),
                               ("axis_order", ["y", "x"], "axis_order_conflict"))
        n = deepcopy(cart)
        n["meta"]["coordinate_reference_system"][key] = value
        q = spatial(n)
        @test q["coordinate_reference"]["status"] == "ambiguous"
        @test code in q["coordinate_semantics"]["issues"]
        @test q["coordinate_semantics"]["n_metric_eligible_buses"] == 0
    end
    n = deepcopy(cart)
    delete!(n["meta"]["coordinate_reference_system"], "units")
    @test "missing_cartesian_units" in spatial(n)["coordinate_semantics"]["issues"]
    n = deepcopy(cart)
    n["crs"] = "EPSG:4326"
    @test "conflicting_crs_declarations" in spatial(n)["coordinate_semantics"]["issues"]
    @test spatial(n)["coincidence"]["n_groups"] == 0
    n = deepcopy(cart)
    n["meta"]["coordinate_units"] = "m"
    @test "conflicting_coordinate_units" in spatial(n)["coordinate_semantics"]["issues"]
    n = deepcopy(cart)
    n["bus"]["a"]["meta"] = Dict{String,Any}("coordinate_accuracy_m" => true)
    q = spatial(n)
    @test q["coordinate_semantics"]["bus_issue_counts"]["invalid_coordinate_accuracy"] == 1
    @test q["coordinate_semantics"]["n_metric_eligible_buses"] == 2
    n["bus"]["a"]["coordinate_accuracy_m"] = 0.2
    @test spatial(n)["coordinate_semantics"]["bus_issue_counts"]["conflicting_coordinate_accuracy"] == 1

    geo = Dict{String,Any}("crs" => "EPSG:4326", "meta" => Dict{String,Any}("crs" => "WGS84"),
        "bus" => Dict("a" => Dict("longitude" => 153.0, "latitude" => -27.0),
                      "b" => Dict("longitude" => 153.001, "latitude" => -27.0)))
    @test spatial(geo)["coordinate_semantics"]["n_metric_eligible_buses"] == 2
    geo["meta"]["coordinate_axis_order"] = ["latitude", "longitude"]
    @test spatial(geo)["coordinate_reference"]["status"] == "ambiguous"
    @test spatial(geo)["coordinate_semantics"]["n_metric_eligible_buses"] == 0
    delete!(geo["meta"], "coordinate_axis_order")
    geo["meta"]["crs"] = "EPSG:28356"
    @test spatial(geo)["coordinate_reference"]["status"] == "ambiguous"
    delete!(geo, "crs")
    @test spatial(geo)["coordinate_reference"]["status"] == "declared_other"
    geo["meta"]["crs"] = Dict("epsg" => 4326, "code" => "EPSG:28356")
    @test "invalid_crs_declaration" in spatial(geo)["coordinate_semantics"]["issues"]
    io = IOBuffer()
    BMOPFTools._md_spatial(r, io)
    @test occursin("units `ft`", String(take!(io)))
    huge = deepcopy(cart)
    huge["meta"]["coordinate_reference_system"]["units"] = "m"
    huge["bus"]["a"]["x"] = -1e308
    huge["bus"]["b"]["x"] = 1e308
    @test spatial(huge)["transformers"]["n_indeterminate"] == 1
    @test spatial(huge)["length_context"]["comparison_status_counts"]["chord_check"]["indeterminate"] == 1
end
