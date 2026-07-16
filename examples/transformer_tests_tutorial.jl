# From test report to transformer model — SC/OC data in, validated fields out.
#
#   julia --project=test examples/transformer_tests_tutorial.jl
#
# Companion to docs/src/tutorial_transformer_tests.md. Both share the same arc:
#   test-report percentages → SI fields on the right windings (single-phase,
#   then Dyn11) → validate the primitive admittance entry-wise against a hand
#   rank-one derivation → re-simulate the OC and SC factory tests on the
#   constructed model and recover the datasheet numbers → cross-check the whole
#   mapping through OpenDSS text + from_dss → n-winding x_sc/ZB with the PSD
#   realisability test.
#
# The point. %Z, Pcu, P0, I0 are per-unit on the machine's own bases; BMOPF
# wants ohms/siemens on specific windings (core branch on winding 2's coil).
# The SC test fixes only the SERIES SUM — the winding split is a convention,
# visible in the wild (from_dss splits X evenly; the sum is what must match).

using BMOPFTools, JuMP, Ipopt, LinearAlgebra

const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
sep(t) = println("\n" * "="^72 * "\n  " * t * "\n" * "="^72)

# ── 1. Single-phase 50 kVA 11000/240: report → fields ────────────────────────
sep("1. 50 kVA 11000/240 V single-phase: %Z=4, Pcu=1100 W, P0=150 W, I0=0.5 %")
S = 50_000.0; Vhv = 11_000.0; Vlv = 240.0
pctZ = 4.0; Pcu = 1_100.0; P0 = 150.0; I0 = 0.5
pctR = 100Pcu/S; pctX = sqrt(pctZ^2 - pctR^2); pct_b = sqrt(I0^2 - (100P0/S)^2)

xfmr = Dict{String,Any}(
    "bus_from" => "hv", "bus_to" => "lv",
    "terminal_map_from" => ["1","n"], "terminal_map_to" => ["1","n"],
    "v_nom_from" => Vhv, "v_nom_to" => Vlv, "s_rating" => S,
    "r_series_from" => (pctR/2)/100 * Vhv^2/S,
    "r_series_to"   => (pctR/2)/100 * Vlv^2/S,
    "x_series_from" => (pctX/2)/100 * Vhv^2/S,
    "x_series_to"   => (pctX/2)/100 * Vlv^2/S,
    "g_no_load"     =>  (P0/S)      * S/Vlv^2,
    "b_no_load"     => -(pct_b/100) * S/Vlv^2)
println("fields: ", [(k, round(xfmr[k]; sigdigits=5)) for k in
    ("r_series_from","x_series_from","r_series_to","x_series_to","g_no_load","b_no_load")])

# ── 2. Yprim by hand: Y = y·vvᵀ + Y0·ttᵀ ─────────────────────────────────────
sep("2. Hand admittance vs transformer_yprim (entry-wise)")
nodes, Y = transformer_yprim(xfmr, "single_phase")
N  = Vhv/Vlv
Z  = (xfmr["r_series_from"] + im*xfmr["x_series_from"]) +
     N^2*(xfmr["r_series_to"] + im*xfmr["x_series_to"])
Y0 = xfmr["g_no_load"] + im*xfmr["b_no_load"]
v = [1.0, -N, -1.0, N]; t = [0.0, 1.0, 0.0, -1.0]
Y_hand = (1/Z) .* (v*transpose(v)) .+ Y0 .* (t*transpose(t))
println("nodes ", nodes, "  max|ΔY| = ", maximum(abs.(Y .- Y_hand)), " S")
@assert isapprox(Y, Y_hand; rtol = 1e-8)

# ── 3. Re-run the factory tests on the model ─────────────────────────────────
sep("3. OC and SC tests re-simulated on the constructed model")
testnet(; short=false, vscale=1.0) = Dict{String,Any}(
    "bus" => Dict{String,Any}(
        "hv" => Dict{String,Any}("terminal_names" => ["1","n"],
                                 "perfectly_grounded_terminals" => ["n"]),
        "lv" => Dict{String,Any}("terminal_names" => ["1","n"],
                 "perfectly_grounded_terminals" => short ? ["1","n"] : ["n"])),
    "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
        "bus" => "hv", "terminal_map" => ["1","n"],
        "v_magnitude" => [Vhv*vscale, 0.0], "v_angle" => [0.0, 0.0])),
    "transformer" => Dict{String,Any}("single_phase" => Dict{String,Any}(
        "t1" => deepcopy(xfmr))))

oc = solve_pf(testnet(); optimizer = OPT)
p_oc = sum(ph["ps"] for ph in values(oc["voltage_source"]["source"]))
sc = solve_pf(testnet(short=true, vscale=pctZ/100); optimizer = OPT)
p_sc = sum(ph["ps"] for ph in values(sc["voltage_source"]["source"]))
i_sc = only(ph["cm"] for ph in values(sc["voltage_source"]["source"]))
println("OC: P = ", round(p_oc; digits=2), " W (P0 = ", P0, ")")
println("SC: I = ", round(i_sc; digits=3), " A at ", pctZ, "% V (rated ",
        round(S/Vhv; digits=3), "), P = ", round(p_sc; digits=1), " W (Pcu = ", Pcu, ")")
@assert isapprox(p_oc, P0; rtol=5e-3) && isapprox(i_sc, S/Vhv; rtol=1e-3) &&
        isapprox(p_sc, Pcu; rtol=1e-3)

# ── 4. Dyn11 400 kVA + from_dss cross-check + tests ──────────────────────────
sep("4. Dyn11 400 kVA 11/0.416 kV: hand fields, from_dss cross-check, OC/SC")
S3 = 400_000.0; Vhv3 = 11_000.0; Vlv3 = 416.0
pctZ3 = 4.5; Pcu3 = 4_600.0; P03 = 610.0; I03 = 0.25
pctR3 = 100Pcu3/S3; pctX3 = sqrt(pctZ3^2 - pctR3^2)
pct_b3 = sqrt(I03^2 - (100P03/S3)^2); Vcoil2 = Vlv3/sqrt(3)

dyn11 = Dict{String,Any}(
    "bus_from" => "hv", "bus_to" => "lv",
    "terminal_map_from" => ["a","b","c"], "terminal_map_to" => ["a","b","c","n"],
    "v_nom_from" => Vhv3, "v_nom_to" => Vlv3, "s_rating" => S3,
    "r_series_from" => (pctR3/2)/100 * Vhv3^2/S3,
    "r_series_to"   => (pctR3/2)/100 * Vlv3^2/S3,
    "x_series_from" => (pctX3/2)/100 * Vhv3^2/S3,
    "x_series_to"   => (pctX3/2)/100 * Vlv3^2/S3,
    "g_no_load"     =>  (P03/S3)     * S3/Vcoil2^2,
    "b_no_load"     => -(pct_b3/100) * S3/Vcoil2^2)

deck = joinpath(mktempdir(), "Master.dss")
write(deck, """
Clear
New Circuit.dyn11 basekv=11 pu=1.0 phases=3 bus1=hvbus
New Transformer.tx1 phases=3 windings=2 buses=(hvbus, lvbus) conns=(delta, wye)
~ kvs=(11, 0.416) kvas=(400, 400) xhl=$(pctX3) %Rs=($(pctR3/2), $(pctR3/2))
~ %noloadloss=$(100P03/S3) %imag=$(pct_b3)
Set VoltageBases=[11, 0.416]
CalcVoltageBases
Solve
""")
imported = first(values(from_dss(deck)["transformer"]["delta_wye"]))
N3 = Vhv3/Vlv3
series(tx) = (tx["r_series_from"] + im*tx["x_series_from"]) +
             N3^2*(tx["r_series_to"] + im*tx["x_series_to"])
println("series sum hand / from_dss: ", round(series(dyn11); sigdigits=6), " / ",
        round(series(imported); sigdigits=6), " Ω  (split differs, sum must not)")
@assert isapprox(series(dyn11), series(imported); rtol=1e-6)
@assert isapprox(dyn11["g_no_load"], Float64(imported["g_no_load"]); rtol=1e-6)
@assert isapprox(dyn11["b_no_load"], Float64(imported["b_no_load"]); rtol=1e-6)

vph = Vhv3/sqrt(3)
net3(; short=false, vscale=1.0) = Dict{String,Any}(
    "bus" => Dict{String,Any}(
        "hv" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                                 "perfectly_grounded_terminals" => ["n"]),
        "lv" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                 "perfectly_grounded_terminals" => short ? ["a","b","c","n"] : ["n"])),
    "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
        "bus" => "hv", "terminal_map" => ["a","b","c","n"],
        "v_magnitude" => [vph*vscale, vph*vscale, vph*vscale, 0.0],
        "v_angle" => [0.0, -2π/3, 2π/3, 0.0])),
    "transformer" => Dict{String,Any}("delta_wye" => Dict{String,Any}(
        "t1" => deepcopy(dyn11))))

oc3 = solve_pf(net3(); optimizer = OPT)
p_oc3 = sum(ph["ps"] for ph in values(oc3["voltage_source"]["source"]))
sc3 = solve_pf(net3(short=true, vscale=pctZ3/100); optimizer = OPT)
i_sc3 = [ph["cm"] for ph in values(sc3["voltage_source"]["source"])]
p_sc3 = sum(ph["ps"] for ph in values(sc3["voltage_source"]["source"]))
println("OC: P = ", round(p_oc3; digits=1), " W (P0 = ", P03, ")")
println("SC: I = ", round.(i_sc3; digits=2), " A (rated ",
        round(S3/(sqrt(3)*Vhv3); digits=2), "), P = ", round(p_sc3; digits=0),
        " W (Pcu = ", Pcu3, ")")
@assert isapprox(p_oc3, P03; rtol=5e-3) && isapprox(p_sc3, Pcu3; rtol=1e-3)

# ── 5. n-winding: x_sc → ZB + realisability ──────────────────────────────────
sep("5. 20 MVA 33/11/6.6 kV 3-winding: x_sc matrix, ZB, PSD realisability")
Sn = 20e6
v_coil = [33_000.0, 11_000.0/sqrt(3), 6_600.0/sqrt(3)]
z_coil1 = 3*v_coil[1]^2/Sn
x_sc = Dict("1_2" => 0.10z_coil1, "1_3" => 0.17z_coil1, "2_3" => 0.06z_coil1)
r_w = [0.004 * 3*v_coil[k]^2/Sn for k in 1:3]
nw = Dict{String,Any}(
    "s_rating" => Sn, "x_sc" => x_sc,
    "windings" => [
        Dict{String,Any}("bus" => "hv", "terminal_map" => ["a","b","c"],
            "configuration" => "DELTA", "delta_roll" => -1,
            "v_nom" => v_coil[1], "r_winding" => r_w[1]),
        Dict{String,Any}("bus" => "mv", "terminal_map" => ["a","b","c","n"],
            "configuration" => "WYE", "v_nom" => v_coil[2], "r_winding" => r_w[2]),
        Dict{String,Any}("bus" => "lv", "terminal_map" => ["a","b","c","n"],
            "configuration" => "WYE", "v_nom" => v_coil[3], "r_winding" => r_w[3])])

Nk = v_coil ./ v_coil[1]
r1 = r_w ./ Nk.^2
Zp(i,j) = (r1[i]+r1[j]) + im*x_sc["$(min(i,j))_$(max(i,j))"]
ZB_hand = [Zp(1,2) (Zp(1,2)+Zp(1,3)-Zp(2,3))/2; (Zp(1,2)+Zp(1,3)-Zp(2,3))/2 Zp(1,3)]
ZB_engine = BMOPFTools._nw_zb_matrix(nw)
@assert isapprox(ZB_hand, ZB_engine; rtol=1e-12)
println("ZB = ", round.(ZB_hand; sigdigits=5))
println("eigvals(imag ZB) = ", round.(eigvals(imag.(ZB_hand)); sigdigits=4),
        "  (all ≥ 0 → realisable)")
