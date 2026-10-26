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

function _fmt_finding(f::Finding, io::IO; color::Bool=false, prefix::String="  ")
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
