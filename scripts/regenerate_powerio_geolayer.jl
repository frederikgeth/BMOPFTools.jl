# Regenerate test/data/powerio_geolayer_bmopf.json: a synthetic three-bus BMOPF
# case with bus Points and line LineStrings, round-tripped through PowerIO so
# the geometry lands in PowerIO's own `extras.geojson` GeoLayer. The fixture
# pins the format that sideload_geolayer! reads against upstream drift.
#
#     julia --project=. scripts/regenerate_powerio_geolayer.jl
using PowerIO, JSON3

source = raw"""{
  "meta":{"schema_version":"0.2.0"},
  "bus":{
    "a":{"terminal_names":["1"],"geo":{"type":"Point","coordinates":[10.0,50.0]}},
    "b":{"terminal_names":["1"],"geo":{"type":"Point","coordinates":[10.001,50.0]}},
    "c":{"terminal_names":["1"],"geo":{"type":"Point","coordinates":[10.001,50.001]}}},
  "line":{
    "ab":{"bus_from":"a","bus_to":"b","terminal_map_from":["1"],"terminal_map_to":["1"],
      "R_series_1_1":0.1,"X_series_1_1":0.2,
      "geo":{"type":"LineString","coordinates":[[10.0,50.0],[10.0005,50.0],[10.001,50.0]]}},
    "bc":{"bus_from":"b","bus_to":"c","terminal_map_from":["1"],"terminal_map_to":["1"],
      "R_series_1_1":0.1,"X_series_1_1":0.2,
      "geo":{"type":"LineString","coordinates":[[10.001,50.0],[10.001,50.001]]}}}}"""

m = PowerIO.parse(IOBuffer(source); format="bmopf-json", name="geolayer.bmopf.json")
# Same-type emission would return the source bytes unchanged; a serialize /
# deserialize round trip drops them so PowerIO writes its typed geometry.
typed = PowerIO.deserialize(Vector{UInt8}(PowerIO.serialize(m).text))
text = PowerIO.emit(typed, "bmopf-json@0.2.0").text
doc = JSON3.read(text, Dict{String,Any})
haskey(get(doc, "extras", Dict()), "geojson") || error("PowerIO wrote no extras.geojson")
out = joinpath(@__DIR__, "..", "test", "data", "powerio_geolayer_bmopf.json")
open(out, "w") do io
    JSON3.pretty(io, doc)
    println(io)
end
println("wrote ", normpath(out), " (PowerIO ", pkgversion(PowerIO), ")")
