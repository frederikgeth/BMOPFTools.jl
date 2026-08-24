# bench/sequence_objective_norms.jl
#
# Which formulation should back a MINIMISED magnitude objective (an L1 /
# group-lasso penalty on a sequence component)?  Three candidates, all
# implementing "make |V2| small" on a deliberately unbalanced 4-wire LV feeder
# with a per-phase STATCOM:
#
#   :squared   Σ (V2r² + V2i²)              — L2. A DIFFERENT objective, kept as
#                                             the reliability/effort reference.
#   :epigraph  min t s.t. V2r² + V2i² ≤ t²  — exact L1, no smoothing parameter.
#   :smooth    √(V2r² + V2i² + ε²) − ε      — smoothed L1, one ε knob.
#
# Ranked on the project's stated priority: convergence reliability first, wall
# clock second.  Run with:  julia --project=test bench/sequence_objective_norms.jl
#
# NOTE `build_opf_model` deliberately defers KCL so a `model_hook!` can
# contribute to the accumulators; a caller assembling its own objective MUST
# call `BMOPFTools.enforce_kcl!(ctx)` before solving. Without it the model is
# silently unconstrained and every formulation "converges" to |V2| = 0.
using BMOPFTools, JuMP, Ipopt, Printf, InteractiveUtils, Pkg

netdef(smax) = parse_bmopf("""
 {"bus":{
   "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
          "v_min":[180.0,180.0,180.0],"v_max":[280.0,280.0,280.0]},
   "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
          "v_min":[180.0,180.0,180.0],"v_max":[280.0,280.0,280.0]}},
  "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
      "v_magnitude":[230.0,230.0,230.0],
      "v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
  "linecode":{"lc":{"R_series_1_1":0.08,"R_series_2_2":0.08,"R_series_3_3":0.08,
                    "X_series_1_1":0.04,"X_series_2_2":0.04,"X_series_3_3":0.04}},
  "line":{"l1":{"bus_from":"src","bus_to":"b1",
      "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
      "linecode":"lc","length":1.0}},
  "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
      "configuration":"WYE","p_nom":[6000.0,1000.0,500.0],
      "q_nom":[1500.0,200.0,100.0]}},
  "ibr":{"pv1":{"bus":"b1","terminal_map":["1","2","3","n"],
      "topology":"FOUR_LEG","prime_mover":"STATCOM",
      "s_max":[$smax,$smax,$smax],"p_max":[0.0,0.0,0.0],"p_min":[0.0,0.0,0.0],
      "cost":[0.0,0.0,0.0]}}}
 """; from_string=true)

"Negative-sequence (V2r, V2i) at `bid`, mirroring ext/BMOPFOpfExt/bus.jl."
function v2_terms(ctx, bid)
    m = BMOPFTools.opf_model(ctx); vr = ctx.vars[:vr]; vi = ctx.vars[:vi]
    s3 = sqrt(3.0)/2; n = "n"
    floating = !((bid, n) in ctx.grounded)
    dv(t) = floating ? (@expression(m, vr[(bid,t)] - vr[(bid,n)]),
                        @expression(m, vi[(bid,t)] - vi[(bid,n)])) :
                       (vr[(bid,t)], vi[(bid,t)])
    (a_r,a_i) = dv("1"); (b_r,b_i) = dv("2"); (c_r,c_i) = dv("3")
    (@expression(m, (a_r - 0.5*b_r + s3*b_i - 0.5*c_r - s3*c_i)/3),
     @expression(m, (a_i - s3*b_r - 0.5*b_i + s3*c_r - 0.5*c_i)/3))
end

function solve1(mode, net, pu, eps_rel)
    ctx = BMOPFTools.build_opf_model(net; per_unit=pu, add_objective=false)
    m = BMOPFTools.opf_model(ctx); vscale = pu ? 1.0 : 230.0
    (r,i) = v2_terms(ctx,"b1"); eps = eps_rel*vscale
    if mode == :smooth;       @objective(m, Min, sqrt(r^2+i^2+eps^2)-eps)
    elseif mode == :epigraph; t=@variable(m,lower_bound=0.0); @constraint(m, r^2+i^2<=t^2)
                              set_start_value(t,0.05*vscale); @objective(m,Min,t)
    else                      @objective(m, Min, r^2+i^2) end
    BMOPFTools.enforce_kcl!(ctx)
    tmp = tempname()
    tt = @elapsed (open(tmp,"w") do io; redirect_stdout(io) do
        set_attribute(m,"print_level",5); optimize!(m) end; end)
    out = read(tmp,String); rm(tmp,force=true)
    mm = match(r"Number of Iterations\.*:\s*(\d+)", out)
    (it = mm===nothing ? -1 : parse(Int,mm.captures[1]),
     st = string(termination_status(m)), t = tt,
     v2 = hypot(value(r), value(i)) * (pu ? 230.0 : 1.0))
end

"""
Record what the numbers below actually depend on. A convergence comparison is
not reproducible without the solver version and tolerance, and its conclusions
do not automatically transfer off the machine or the case family it was run on.
"""
function environment()
    deps = Pkg.dependencies()
    ver(name) = begin
        hit = findfirst(d -> d.name == name, deps)
        hit === nothing ? "?" : string(deps[hit].version)
    end
    println("environment")
    println("  julia        ", VERSION)
    println("  platform     ", Sys.MACHINE)
    println("  Ipopt.jl     ", ver("Ipopt"))
    println("  JuMP         ", ver("JuMP"))
    println("  BMOPFTools   ", ver("BMOPFTools"))
    println("  solver tol   Ipopt default (tol = 1e-8), max_iter default (3000)")
    println("  case family  one 2-bus unbalanced 4-wire LV feeder with a")
    println("               per-phase STATCOM; 5 load unbalances x 4 STATCOM")
    println("               ratings x 2 unit modes = 40 configurations")
    println()
    println("SCOPE: these are convergence counts for ONE case family on ONE")
    println("solver at its default tolerance. They justify the DEFAULTS chosen")
    println("in ext/BMOPFOpfExt/objectives.jl -- notably that a minimised norm")
    println("wants a large eps -- and they are strong enough to rule out the")
    println("alternatives tried here. They are NOT a general claim about the")
    println("reliability of these formulations on arbitrary networks, solvers")
    println("or tolerances. Re-run before relying on them elsewhere.")
    println()
end

function main()
    environment()
    modes = [(:squared,0.0), (:epigraph,0.0),
             (:smooth,1e-3), (:smooth,1e-6), (:smooth,1e-9)]
    loads = [(6000,1000,500),(4000,4000,500),(8000,200,200),
             (3000,2500,2000),(9000,50,50)]
    stats = Dict(m=>Int[] for m in modes); fails = Dict(m=>String[] for m in modes)
    times = Dict(m=>Float64[] for m in modes)
    for (p1,p2,p3) in loads, smax in (200.0,2000.0,20000.0,100000.0), pu in (true,false)
        net = netdef(smax)
        net["load"]["ld"]["p_nom"] = Float64[p1,p2,p3]
        net["load"]["ld"]["q_nom"] = Float64[p1/4,p2/4,p3/4]
        for md in modes
            r = solve1(md[1], deepcopy(net), pu, md[2])
            push!(stats[md], r.it); push!(times[md], r.t)
            r.st in ("LOCALLY_SOLVED","OPTIMAL") ||
                push!(fails[md], "p1=$(p1) smax=$(smax) pu=$pu → $(r.st)")
        end
    end
    n = length(loads)*4*2
    println("configs per mode: ", n)
    @printf("%-22s %6s %6s %10s %10s %9s\n","mode","ok","fail","med iters","max iters","tot s")
    for md in modes
        s = sort(stats[md])
        @printf("%-22s %6d %6d %10d %10d %9.2f\n",
            string(md[1], md[2]==0 ? "" : " eps=$(md[2])"),
            n - length(fails[md]), length(fails[md]), s[cld(end,2)], s[end], sum(times[md]))
    end
    for md in modes
        isempty(fails[md]) && continue
        println("\n  failures — ", md); foreach(f -> println("    ", f), fails[md])
    end
end

main()
