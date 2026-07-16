# Findings triage — from raw import to defensible case (no solver needed).
#
#   julia --project=test examples/triage_tutorial.jl
#
# Companion to docs/src/tutorial_triage.md. Both share the same arc:
#   load the deliberately messy MVLVmeshed case → layer one: the importer's
#   fidelity ledger (net["_meta"]["powerio_warnings"]) → layer two: analyze
#   severities (E = broken, W = decide, I = disclosure) → per-code verdicts
#   (fix / decide / disclose) → mechanical repairs with fix_case + manifest →
#   augment_case's provenance-stamped bounds → the preflight and
#   benchmark-readiness gates.
#
# The point. Triage is classification, not silencing: a defensible case ships
# with its residual warnings and written verdicts, its import ledger, and its
# transformation manifests — that bundle is what makes a benchmark reviewable.

using BMOPFTools

sep(t) = println("\n" * "="^72 * "\n  " * t * "\n" * "="^72)

# ── 1. The patient ────────────────────────────────────────────────────────────
sep("1. MVLVmeshed: a combined MV+LV network with deliberate mesh ties")
path = joinpath(pkgdir(BMOPFTools), "test", "data", "MVLVmeshed", "Master.dss")
net  = from_dss(path)
println(length(net["bus"]), " buses, ", length(net["line"]), " lines, ",
        length(net["switch"]), " switches, ", length(net["load"]), " loads")

# ── 2. Layer one: the import ledger ──────────────────────────────────────────
sep("2. powerio_warnings — what the import could not carry")
pw = net["_meta"]["powerio_warnings"]
println(length(pw), " import warnings; first three:")
for w in pw[1:3]; println("  • ", w); end

# ── 3. Layer two: analyze severities ─────────────────────────────────────────
sep("3. analyze: errors / warnings / infos")
report = analyze(net)
println("E/W/I = ", length(errors(report)), "/", length(warnings(report)), "/",
        length(infos(report)))
wcount = Dict{String,Int}()
for f in warnings(report)
    wcount[String(f.code)] = get(wcount, String(f.code), 0) + 1
end
for (c, n) in sort(collect(wcount)); println("  ", rpad(c, 26), n); end

# ── 4. Verdicts ───────────────────────────────────────────────────────────────
sep("4. Reading warnings like a reviewer")
for code in ("W.CONN.MESHED", "W.CONN.DANGLING", "W.DOM.XFMR_STEP_UP",
             "W.OPS.XFMR_OVERLOADED")
    f = first(f for f in warnings(report) if String(f.code) == code)
    println(f.code, ": ", f.message, "\n")
end

# ── 5. fix_case + manifest ────────────────────────────────────────────────────
sep("5. fix_case: lossless repairs, recorded")
fixed, manifest = fix_case(net)
d = manifest_to_dict(manifest)
counts = Dict{String,Int}()
for e in d["entries"]
    c = string(get(e, "field", "?"))
    counts[c] = get(counts, c, 0) + 1
end
println(length(d["entries"]), " manifest entries, by kind:")
for (c, n) in sort(collect(counts); by = x -> -x[2]); println("  ", rpad(c, 22), n); end
println("buses ", length(net["bus"]), " → ", length(fixed["bus"]),
        ", lines ", length(net["line"]), " → ", length(fixed["line"]))
report2 = analyze(fixed)
println("after fix: E/W/I = ", length(errors(report2)), "/", length(warnings(report2)),
        "/", length(infos(report2)))
w2 = Dict{String,Int}()
for f in warnings(report2)
    w2[String(f.code)] = get(w2, String(f.code), 0) + 1
end
for (c, n) in sort(collect(w2)); println("  ", rpad(c, 26), n); end

# ── 6. augment + gates ────────────────────────────────────────────────────────
sep("6. augment_case + the two gates")
ready, _ = augment_case(fixed; recipe = AugmentationRecipe())
report3 = analyze(ready)
println("after augment: E/W/I = ", length(errors(report3)), "/",
        length(warnings(report3)), "/", length(infos(report3)))
pre = infeasibility_preflight(ready, report3.findings)
rdy = benchmark_readiness_check(ready, report3.findings)
println("preflight keys : ", sort(collect(keys(pre))))
println("readiness keys : ", sort(collect(keys(rdy))))
for s in get(rdy, "suggestions", String[]); println("  suggestion: ", s); end
