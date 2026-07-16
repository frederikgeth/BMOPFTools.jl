# Ground, neutral, and earth return — one experiment, then the mathematics.
#
#   julia --project=test examples/grounding_tutorial.jl
#
# Companion to docs/src/tutorial_grounding.md. Both share the same arc:
#   the three objects called "ground" → the engine's vocabulary
#   (terminal_conventions, perfectly_grounded_terminals, shunt electrodes) →
#   floating vs 10 Ω rod vs perfect grounding on one 4-wire feeder → the
#   ybus_passive null-space reading of "floating" → Kron reduction exact iff
#   the neutral is pinned at 0 V everywhere → SWER as the limiting case →
#   Fortescue transform (always) vs sequence decoupling (circulant only).
#
# The point. "Grounded" is a property of electrodes, not a word: a single
# 10 Ω rod barely moves NEV, while perfectly_grounded_terminals quietly
# reroutes ~90 % of the return current into a zero-impedance earth. Kron
# reduction inherits exactly that assumption; Z0 is where it hides in
# sequence coordinates.

using BMOPFTools, JuMP, Ipopt, LinearAlgebra

const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
sep(t) = println("\n" * "="^72 * "\n  " * t * "\n" * "="^72)

lc4 = Dict{String,Any}()
for i in 1:4, j in 1:4
    lc4["R_series_$(i)_$(j)"] = (i == j ? 0.5 : 0.02) / 1000
    lc4["X_series_$(i)_$(j)"] = (i == j ? 0.2 : 0.05) / 1000
end
function feeder(ground)
    net = Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                                      "perfectly_grounded_terminals" => ["n"]),
            "lb"  => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                     "perfectly_grounded_terminals" =>
                         ground == :perfect ? ["n"] : String[])),
        "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
            "bus" => "src", "terminal_map" => ["a","b","c","n"],
            "v_magnitude" => [230.0, 230.0, 230.0, 0.0],
            "v_angle" => [0.0, -2π/3, 2π/3, 0.0])),
        "linecode" => Dict{String,Any}("lc4" => deepcopy(lc4)),
        "line" => Dict{String,Any}("l1" => Dict{String,Any}(
            "bus_from" => "src", "bus_to" => "lb", "linecode" => "lc4",
            "length" => 500.0,
            "terminal_map_from" => ["a","b","c","n"],
            "terminal_map_to"   => ["a","b","c","n"])),
        "load" => Dict{String,Any}("ld" => Dict{String,Any}(
            "bus" => "lb", "terminal_map" => ["a","n"],
            "configuration" => "SINGLE_PHASE",
            "p_nom" => [3000.0], "q_nom" => [1000.0])))
    ground == :electrode && (net["shunt"] = Dict{String,Any}(
        "rod" => Dict{String,Any}("bus" => "lb", "terminal_map" => ["n"],
                                  "G_1_1" => 0.1)))
    net
end

# ── 1. Grounding variants ─────────────────────────────────────────────────────
sep("1. Floating vs 10 Ω rod vs perfect (3 kW + 1 kvar on phase a, 500 m)")
println("neutral       NEV      V_pn(load)   I_neutral wire")
for g in (:float, :electrode, :perfect)
    r  = solve_pf(feeder(g); optimizer = OPT)
    lb = r["bus"]["lb"]
    vn = abs(lb["n"]["vr"] + im*lb["n"]["vi"])
    va = abs((lb["a"]["vr"] + im*lb["a"]["vi"]) - (lb["n"]["vr"] + im*lb["n"]["vi"]))
    println(rpad(g, 12), lpad(round(vn; digits=2), 6), " V",
            lpad(round(va; digits=2), 10), " V",
            lpad(round(r["line"]["l1"]["n"]["cm_fr"]; digits=2), 10), " A")
end

# ── 2. ybus_passive null space ────────────────────────────────────────────────
sep("2. What \"floating\" means: near-zero singular values of ybus_passive")
for (name, net) in ["no grounding anywhere" => (n = feeder(:float);
                        delete!(n["bus"]["src"], "perfectly_grounded_terminals"); n),
                    "source neutral grounded" => feeder(:float),
                    "both neutrals grounded"  => feeder(:perfect)]
    sv = svdvals(Matrix(ybus_passive(net).Y))
    println(rpad(name, 26), "near-zero σ: ", count(s -> s < 1e-9*sv[1], sv),
            "  (sources pin phases; groundings tie to earth)")
end

# ── 3. Kron reduction ─────────────────────────────────────────────────────────
sep("3. Kron: exact iff the neutral is pinned at 0 V everywhere")
Z4 = [(i == j ? 0.5 : 0.02) + im*(i == j ? 0.2 : 0.05) for i in 1:4, j in 1:4] ./ 2
Zk = Z4[1:3,1:3] .- Z4[1:3,4:4] * (Z4[4:4,4:4] \ Matrix(transpose(Z4[1:3,4:4])))
lc3 = Dict{String,Any}()
for i in 1:3, j in 1:3
    lc3["R_series_$(i)_$(j)"] = real(Zk[i,j]) / 500.0
    lc3["X_series_$(i)_$(j)"] = imag(Zk[i,j]) / 500.0
end
net3w = Dict{String,Any}(
    "bus" => Dict{String,Any}(
        "src" => Dict{String,Any}("terminal_names" => ["a","b","c"]),
        "lb"  => Dict{String,Any}("terminal_names" => ["a","b","c"])),
    "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
        "bus" => "src", "terminal_map" => ["a","b","c"],
        "v_magnitude" => [230.0, 230.0, 230.0], "v_angle" => [0.0, -2π/3, 2π/3])),
    "linecode" => Dict{String,Any}("lc3" => lc3),
    "line" => Dict{String,Any}("l1" => Dict{String,Any}(
        "bus_from" => "src", "bus_to" => "lb", "linecode" => "lc3",
        "length" => 500.0,
        "terminal_map_from" => ["a","b","c"], "terminal_map_to" => ["a","b","c"])),
    "load" => Dict{String,Any}("ld" => Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["a"], "configuration" => "WYE",
        "p_nom" => [3000.0], "q_nom" => [1000.0])))
va3 = let r = solve_pf(net3w; optimizer = OPT)
    abs(r["bus"]["lb"]["a"]["vr"] + im*r["bus"]["lb"]["a"]["vi"])
end
for g in (:perfect, :electrode, :float)
    r  = solve_pf(feeder(g); optimizer = OPT)
    lb = r["bus"]["lb"]
    va = abs((lb["a"]["vr"] + im*lb["a"]["vi"]) - (lb["n"]["vr"] + im*lb["n"]["vi"]))
    println(rpad(g, 12), " 4-wire V_pn = ", round(va; digits=3),
            " V   Kron error = ", round(abs(va - va3); digits=3), " V")
end

# ── 4. SWER + Fortescue ───────────────────────────────────────────────────────
sep("4. SWER (earth as the return) and Fortescue vs decoupling")
swer = from_dss(joinpath(pkgdir(BMOPFTools), "test", "data", "SWER", "Master.dss"))
rep = analyze(swer)
println("SWER zones: ", rep.results[:connectivity]["n_swer_zones"],
        "   electrodes: ", length(swer["shunt"]))

a = cis(2π/3)
F = (1/sqrt(3)) .* [1 1 1; 1 a a^2; 1 a^2 a]
offdiag_max(M) = maximum(abs(M[i,j]) for i in 1:3, j in 1:3 if i != j)
Zs = inv(F) * Zk * F
Zu = copy(Zk)
Zu[1,2] = Zu[2,1] = 0.015 + 0.040im
Zu[2,3] = Zu[3,2] = 0.010 + 0.025im
Zu[1,3] = Zu[3,1] = 0.008 + 0.020im
Zsu = inv(F) * Zu * F
println("circulant:    Z0 = ", round(Zs[1,1]; sigdigits=3), ", Z1 = ", round(Zs[2,2]; sigdigits=3),
        ", max seq coupling = ", round(offdiag_max(Zs); sigdigits=2), " Ω")
println("untransposed: Z0 = ", round(Zsu[1,1]; sigdigits=3), ", Z1 = ", round(Zsu[2,2]; sigdigits=3),
        ", max seq coupling = ", round(offdiag_max(Zsu); sigdigits=2), " Ω")
println("Z0 ≠ Z1 even when balanced: zero sequence is the return-path story.")
