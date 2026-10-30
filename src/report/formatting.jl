# report/formatting.jl

const _SEV_SYMBOL = Dict(ERROR => "✗", WARNING => "⚠", INFO => "ℹ")
const _SEV_LABEL  = Dict(ERROR => "ERROR", WARNING => "WARN", INFO => "INFO")

# ANSI colour codes
const _ANSI_RED    = "\e[31m"
const _ANSI_YELLOW = "\e[33m"
const _ANSI_CYAN   = "\e[36m"
const _ANSI_BOLD   = "\e[1m"
const _ANSI_RESET  = "\e[0m"

function _sev_color(sev::Severity, color::Bool)
    !color && return ("", "")
    sev == ERROR   && return (_ANSI_RED,    _ANSI_RESET)
    sev == WARNING && return (_ANSI_YELLOW, _ANSI_RESET)
    return (_ANSI_CYAN, _ANSI_RESET)
end

function _fmt_finding(f::Finding, io::IO; color::Bool=false, prefix::String="  ", interpretation::Bool=false)
    pre, post = _sev_color(f.severity, color)
    label = _SEV_LABEL[f.severity]
    sym   = _SEV_SYMBOL[f.severity]
    print(io, prefix)
    print(io, pre)
    print(io, "[$label] $(f.code)")
    print(io, post)
    if f.component_id !== nothing
        print(io, "  $(f.component_type)/$(f.component_id)")
    end
    println(io)
    println(io, "$prefix  $(f.message)")
    interpretation && _fmt_interpretation(f, io; prefix="$prefix    ")
end

_finding_interpretation_record(f::Finding) =
    f.detail isa AbstractDict ? get(f.detail, "interpretation", nothing) : nothing

# The message already says why it matters; add the main alternative and the
# first check. Full lists stay in JSON and the markdown report.
function _fmt_interpretation(f::Finding, io::IO; prefix::String="      ")
    interp = _finding_interpretation_record(f)
    interp isa AbstractDict || return
    for (key, label) in (("alternatives", "Or"), ("suggested_checks", "Check"))
        list = get(interp, key, Any[])
        isempty(list) || println(io, "$prefix$label: $(first(list)["text"])")
    end
end

# Per-instance observations worth showing a reader (pattern comparisons).
function _interpretation_observation_lines(interp)
    lines = String[]
    by = get(get(interp, "observations", Dict()), "by_linecode", Dict())
    for id in sort!(collect(keys(by)))
        cmp = get(by[id], "pattern_comparison", nothing)
        cmp isa AbstractDict && push!(lines, "`$id`: $(cmp["summary"])")
    end
    lines
end

function _md_interpretation(f::Finding, io::IO; indent::String="  ")
    interp = _finding_interpretation_record(f)
    interp isa AbstractDict || return
    println(io, "$indent<details><summary>How to read this</summary>\n")
    obs = _interpretation_observation_lines(interp)
    if !isempty(obs)
        println(io, "$indent**Observed:**\n")
        for line in obs; println(io, "$indent- $line"); end
        println(io)
    end
    for (key, label) in (("possible_explanations", "Likely meaning"), ("implications", "Why it matters"),
                         ("alternatives", "Other explanations"), ("suggested_checks", "What to check"))
        list = get(interp, key, Any[])
        isempty(list) && continue
        println(io, "$indent**$label:**\n")
        for h in list; println(io, "$indent- $(h["text"])"); end
        println(io)
    end
    links = get(interp, "learn_more", Any[])
    if !isempty(links)
        println(io, "$indent**Learn more:** " *
            join(["[$(l["section"])]($(l["url"]))" for l in links], " · ") * "\n")
    end
    println(io, "$indent*A hint to review, not a verified cause; gather evidence before changing the model. " *
        "Full record: `explain_finding(f)` or the JSON report.*\n")
    println(io, "$indent</details>\n")
end

function _section_header(io::IO, title::String; color::Bool=false, width::Int=70)
    bar = "─" ^ width
    color && print(io, _ANSI_BOLD)
    println(io, "\n$bar")
    println(io, "  $title")
    println(io, bar)
    color && print(io, _ANSI_RESET)
end

function _kv_row(io::IO, label::String, value; indent::Int=2, width::Int=30)
    pad = max(1, width - length(label))
    println(io, " "^indent * label * " "^pad * string(value))
end

function _fmt_power(w::Real, unit::String)
    m = w / 1e6
    abs(m) >= 1 && return "$(round(m, digits=2)) M$unit"
    k = w / 1e3
    abs(k) >= 1 && return "$(round(k, digits=1)) k$unit"
    return "$(round(Float64(w), digits=0)) $unit"
end

_fmt_mw(w::Real)   = _fmt_power(w, "W")
_fmt_mvar(q::Real) = _fmt_power(q, "var")
_fmt_mva(s::Real)  = _fmt_power(s, "VA")

function _fmt_kv(v::Real)
    kv = v / 1e3
    kv >= 1 && return "$(round(kv, digits=2)) kV"
    return "$(round(Float64(v), digits=0)) V"
end

function _fmt_pct(x::Real)
    "$(round(Float64(x), digits=1))%"
end

function _count_table(io::IO, counts::Dict; indent::Int=2)
    ks = sort(collect(keys(counts)))
    w  = isempty(ks) ? 10 : maximum(length.(string.(ks))) + 2
    for k in ks
        println(io, " "^indent * rpad(string(k), w) * string(counts[k]))
    end
end
function _star_earthing_label(zone)
    kind=get(zone,"star_earthing","indeterminate")
    kind=="perfect" && return "perfect (0 Ω)"
    kind=="impedance" && return "|Z|≈$(round(zone["star_R_ohm"],sigdigits=3)) Ω"
    kind=="none" && return "no local earth represented"
    kind=="solid" && return "solid (legacy threshold)"
    "indeterminate"
end
