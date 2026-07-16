# Choosing and identifying a load model — five models, one feeder, one weak line.
#
#   julia --project=test examples/load_models_tutorial.jl
#
# Companion to docs/src/tutorial_load_models.md. Both share the same arc:
#   the five model strings and their common ZIP root → v_nom anchor sweep on
#   LV1_14bus → feeder-level consequences at nominal and depressed voltage →
#   stress a weak 2-bus feeder to collapse and check the constant-P nose against
#   the analytic limit → identify ZIP parameters from PF "measurements" and show
#   identifiability collapse on a narrow voltage window.
#
# The point. `model` is a scientific choice, not a formality: near nominal the
# five models agree to ~1 %, but CVR results, hosting extremes, and collapse
# margins are *written* by the choice. And the engine's W-box floor
# (0.5·v_nom) is a model-validity boundary, not physics — voltage-dependent
# fits must not be extrapolated toward collapse.

using BMOPFTools, JuMP, Ipopt, LinearAlgebra

const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
sep(t) = println("\n" * "="^72 * "\n  " * t * "\n" * "="^72)

MODELS = [
    "constant_power"     => Dict{String,Any}(),
    "constant_current"   => Dict{String,Any}(),
    "constant_impedance" => Dict{String,Any}(),
    "zip"                => Dict{String,Any}(
        "alpha_z" => [0.4], "alpha_i" => [0.3], "alpha_p" => [0.3],
        "beta_z"  => [0.4], "beta_i"  => [0.3], "beta_p"  => [0.3]),
    "exponential"        => Dict{String,Any}("gamma_p" => [1.5], "gamma_q" => [2.0]),
]

# ── 1–2. v_nom anchor sweep on LV1_14bus ─────────────────────────────────────
sep("1. All five models cross at v_nom (LV1 14-bus, one 10 kW customer)")
lv1 = from_dss(joinpath(pkgdir(BMOPFTools), "test", "data", "LV", "LV1_14bus", "Master.dss"))
src_id = first(keys(lv1["voltage_source"]))
vm0 = Float64.(lv1["voltage_source"][src_id]["v_magnitude"])

function with_model(net, model, extra)
    n = deepcopy(net)
    for (_, d) in n["load"]
        d["model"] = model
        merge!(d, extra)
    end
    n
end

println("source   ", join(rpad.(first.(MODELS), 20)))
for scale in (0.90, 1.00, 1.10)
    row = map(MODELS) do (m, extra)
        n = with_model(lv1, m, extra)
        n["voltage_source"][src_id]["v_magnitude"] = vm0 .* scale
        r = solve_pf(n; optimizer = OPT)
        rpad(round(sum(ph["pd"] for ph in values(r["load"]["ld3313_load_a"])); digits = 0), 20)
    end
    println(scale, "     ", join(row))
end

# ── 4. Weak feeder: analytic nose vs where each model stops ──────────────────
sep("2. Stress to collapse on a weak 2-bus feeder (240 V, Z = 0.25+j0.10 Ω)")
weak(model, extra; λ = 1.0) = Dict{String,Any}(
    "bus" => Dict{String,Any}(
        "src" => Dict{String,Any}("terminal_names" => ["1"]),
        "lb"  => Dict{String,Any}("terminal_names" => ["1"])),
    "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
        "bus" => "src", "terminal_map" => ["1"],
        "v_magnitude" => [240.0], "v_angle" => [0.0])),
    "linecode" => Dict{String,Any}("weak" => Dict{String,Any}(
        "R_series_1_1" => 0.5e-3, "X_series_1_1" => 0.2e-3)),
    "line" => Dict{String,Any}("l1" => Dict{String,Any}(
        "bus_from" => "src", "bus_to" => "lb", "linecode" => "weak",
        "length" => 500.0, "terminal_map_from" => ["1"], "terminal_map_to" => ["1"])),
    "load" => Dict{String,Any}("ld1" => merge(Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["1"], "configuration" => "WYE",
        "model" => model, "v_nom" => [240.0],
        "p_nom" => [10_000.0 * λ], "q_nom" => [3_000.0 * λ]), extra)))

V0 = 240.0; R = 0.25; X = 0.10; P = 10_000.0; Q = 3_000.0
disc(λ) = (2λ*(P*R + Q*X) - V0^2)^2 - 4λ^2 * (P^2 + Q^2) * (R^2 + X^2)
λ_nose = let lo = 1.0, hi = 20.0
    for _ in 1:60; m = (lo + hi)/2; disc(m) > 0 ? (lo = m) : (hi = m); end
    lo
end
println("analytic constant-power nose: λ_max = ", round(λ_nose; digits = 3),
        ", V_nose = ", round(sqrt((V0^2 - 2λ_nose*(P*R + Q*X)) / 2); digits = 1), " V")

println("model                 last λ    V there    stopped by")
for (m, extra) in MODELS
    lastλ, lastV = 0.0, NaN
    for λ in 0.25:0.25:12.0
        r = solve_pf(weak(m, extra; λ = λ); optimizer = OPT)
        r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL") || break
        lastλ = λ
        lastV = r["bus"]["lb"]["1"]["vm"]
    end
    cause = lastλ == 12.0         ? "nothing — still solving"              :
            m == "constant_power" ? "the physical nose"                    :
            lastV < 0.55 * 240.0  ? "the W-box validity floor (0.5·v_nom)" :
                                    "its own (constant-P share) nose"
    println(rpad(m, 20), lpad(lastλ, 7), lpad(round(lastV; digits = 1), 10), "    ", cause)
end

# ── 6. ZIP identification: excitation buys identifiability ───────────────────
sep("3. ZIP identification — wide vs narrow voltage window, one bad meter")
function campaign(scales)
    V = Float64[]; Pm = Float64[]
    for s in scales
        n = weak("zip", Dict{String,Any}(
            "alpha_z" => [0.4], "alpha_i" => [0.3], "alpha_p" => [0.3],
            "beta_z"  => [0.4], "beta_i"  => [0.3], "beta_p"  => [0.3]))
        n["voltage_source"]["source"]["v_magnitude"] = [240.0 * s]
        r = solve_pf(n; optimizer = OPT)
        push!(V, r["bus"]["lb"]["1"]["vm"])
        push!(Pm, sum(ph["pd"] for ph in values(r["load"]["ld1"])))
    end
    V, Pm
end
function fit_zip(V, Pm; v_nom = 240.0, p_nom = 10_000.0)
    x = V ./ v_nom
    A = [x .^ 2 .- 1  x .- 1]
    αz, αi = A \ (Pm ./ p_nom .- 1)
    (αz = αz, αi = αi, αp = 1 - αz - αi, cond = cond(A))
end
for (name, (V, Pm)) in ("wide 0.85–1.10" => campaign(0.85:0.05:1.10),
                        "narrow 0.98–1.02" => campaign(0.98:0.005:1.02))
    f = fit_zip(V, Pm)
    println(rpad(name, 18), "exact data: α = (", round(f.αz; digits = 3), ", ",
            round(f.αi; digits = 3), ", ", round(f.αp; digits = 3),
            "), cond(A) = ", round(f.cond; sigdigits = 3))
    P2 = copy(Pm); P2[1] *= 1.005
    f2 = fit_zip(V, P2)
    println(rpad("", 18), "one +0.5% reading: α = (", round(f2.αz; digits = 3), ", ",
            round(f2.αi; digits = 3), ", ", round(f2.αp; digits = 3), ")")
end
