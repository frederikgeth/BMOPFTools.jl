# Descriptive connection evidence linked to PSK-000006. This is an ideal
# winding-incidence relation, not a loaded voltage, nameplate or loop certificate.
function _source_phase_preservation(net,subtype,xf)
    sources=get(get(get(net,"_meta",Dict()),"powerio_source_semantics",Dict()),
        "transformer_phase_relations",Any[])
    for (id,target) in get(get(net,"transformer",Dict()),subtype,Dict())
        target === xf || continue # exact target identity, never infer a source map
        for source in sources
            get(source,"scope",nothing)=="transformer:$id" && return deepcopy(source)
        end
    end
    nothing
end

function _phase_source_note(ev)
    sp=get(ev,"source_preservation",nothing)
    sp isa AbstractDict || return ""
    ll=get(sp,"leadlag","?"); status=get(sp,"status","indeterminate")
    status=="verified" && return "; source leadlag=$ll verified"
    status=="not_applicable" && return ""
    status=="known_mismatch" &&
        return "; SOURCE MISMATCH: leadlag=$ll implies clock $(sp["source_clock"]), converted clock $(sp["target_clock"])"
    "; converted-model relation only; source leadlag=$ll unverified"
end

function _phase_windings(net, subtype, xf)
    r=(;kind="transformer",id="",subtype,component=xf)
    roles=_index_roles(net)
    out=Dict{String,Any}[]
    for (k,e) in enumerate(_connection_endpoints(r))
        cfg = subtype=="n_winding" && e.raw isa AbstractDict ? get(e.raw,"configuration","WYE") :
            subtype=="delta_wye" ? (k==1 ? "DELTA" : "WYE") :
            subtype=="wye_delta" ? (k==1 ? "WYE" : "DELTA") : "WYE"
        roll = subtype=="n_winding" && e.raw isa AbstractDict ? get(e.raw,"delta_roll",1) :
            subtype=="delta_wye" ? -1 : 1
        d=_connection_evidence(net,r,e;roles)
        d["configuration"]=deepcopy(cfg)
        d["delta_roll"]=deepcopy(roll)
        d["v_nom"]=deepcopy(subtype=="n_winding" && e.raw isa AbstractDict ? get(e.raw,"v_nom",nothing) :
            get(xf,k==1 ? "v_nom_from" : "v_nom_to",nothing))
        d["winding"]=k
        push!(out,deepcopy(d))
    end
    out
end

function _phase_order_for(w, phase_order)
    tm=w["terminal_map"]; rs=w["resolved_roles"]
    phases=[t for (t,r) in zip(tm,rs) if r=="phase"]
    supplied=phase_order isa AbstractDict && haskey(phase_order,w["bus"])
    order = supplied ? phase_order[w["bus"]] :
        Set(phases)==Set(["1","2","3"]) ? ["1","2","3"] :
        Set(phases)==Set(["a","b","c"]) ? ["a","b","c"] :
        Set(phases)==Set(["A","B","C"]) ? ["A","B","C"] : nothing
    order===nothing && return (nothing,"unavailable","phase_correspondence_missing")
    (_index_strings(order) && length(order)==3 && length(unique(order))==3 && Set(order)==Set(phases)) ||
        return (nothing,"explicit","invalid_phase_correspondence")
    (collect(order),supplied ? "explicit" : "conventional_labels",nothing)
end

function _phase_connection_letter(w; reference=false)
    cfg=uppercase(string(w["configuration"]))
    base=cfg=="WYE" ? "y" : cfg=="DELTA" ? "d" : "?"
    reference && (base=uppercase(base))
    # Accessibility is evidence about a represented terminal, not a ground bond.
    if cfg=="WYE" && "neutral" in w["resolved_roles"]
        base*=reference ? "N" : "n"
    end
    base
end

function _phase_coils!(w, order)
    tm=w["terminal_map"]; rs=w["resolved_roles"]
    pos=findall(==("phase"),rs); neutral=findfirst(==("neutral"),rs)
    cfg=uppercase(string(w["configuration"]))
    roll=w["delta_roll"]
    v=Dict(order[k]=>cis(-2π*(k-1)/3) for k in 1:3)
    coils=ComplexF64[]; incidence=Dict{String,Any}[]
    for (j,p) in enumerate(pos)
        q=cfg=="WYE" ? neutral : pos[mod1(j+roll,3)]
        push!(coils,v[tm[p]]-(q===nothing || rs[q]=="neutral" ? 0 : v[tm[q]]))
        push!(incidence,Dict{String,Any}("positive_position"=>p,"negative_position"=>q,
            "positive_terminal"=>tm[p],"negative_terminal"=>q===nothing ? nothing : tm[q],
            "reference"=>q===nothing ? "implicit_zero_reference" : "terminal_difference"))
    end
    w["coil_incidence"]=incidence
    coils
end

"""
    transformer_phase_relation(net, subtype, xfmr;
        phase_order=Dict(), from_winding=1, to_winding=2, declared_vector_group=nothing)

Describe the ideal effective phase relation from one authored winding to another.
Returns JSON-compatible connection/provenance evidence, a string `display_label`,
and `status` (`known`, `partial`, `unknown`, or `unsupported`). A clock is present
only for a uniform balanced three-phase displacement; failed inference is never 0.

`phase_order` maps bus IDs to three explicitly corresponding phase labels in
0°, −120°, +120° order. Absent an explicit map, only complete `1/2/3`, `a/b/c`
or `A/B/C` conventions supply angles. Role membership alone supplies no angle.
Indices refer to original windings (1=from, 2=to for two-bus subtypes); uppercase
connection letters denote the reference winding, not necessarily HV. The
optional declared nameplate string is preserved separately and never used to
infer a transfer. No input is modified. See the transformer phase reporting guide.
"""
function transformer_phase_relation(net::Dict{String,Any}, subtype::String, xfmr::Dict{String,Any};
        phase_order=Dict(), from_winding::Int=1, to_winding::Int=2,
        declared_vector_group=get(xfmr,"vector_group",nothing))
    ws=_phase_windings(net,subtype,xfmr)
    result=Dict{String,Any}("schema_version"=>"1.0", "subtype"=>subtype,
        "knowledge_ids"=>["PSK-000006"],"status"=>"unknown","reason"=>nothing,
        "clock"=>nothing,"displacement_degrees"=>nothing,"display_label"=>"?",
        "declared_vector_group"=>deepcopy(declared_vector_group),
        "declared_provenance"=>declared_vector_group===nothing ? "absent" : "authored_unverified",
        "from_winding"=>from_winding,"to_winding"=>to_winding,"windings"=>ws,
        "orientation"=>"ordered_reference_to_target_not_HV_LV",
        "voltage_reference"=>"balanced_phase_to_neutral_or_delta_virtual_neutral",
        "angle_convention"=>"target minus reference; clock = -displacement/30 mod 12",
        "derivation"=>"positive_ratio_ideal_coil_equations",
        "unassessed"=>["loaded_voltage_drop","nameplate_equivalence","network_loop_compatibility",
            "grounding","solver_label_support","tap_feasibility"])
    result["source_preservation"]=_source_phase_preservation(net,subtype,xfmr)
    finish(status,reason)=begin result["status"]=status;result["reason"]=reason;result end
    (1<=from_winding<=length(ws) && 1<=to_winding<=length(ws) && from_winding!=to_winding) ||
        return finish("unknown","winding_reference_unavailable")
    a,b=ws[from_winding],ws[to_winding]
    prefix=_phase_connection_letter(a;reference=true)*_phase_connection_letter(b)
    subtype=="single_phase" && all(w -> count(==("phase"),w["resolved_roles"])<3,(a,b)) && (prefix="Ii")
    subtype=="center_tap" && (prefix="Ii")
    subtype=="single_phase_autotransformer" && (prefix="Ia")
    subtype=="open_delta_regulator" && (prefix="OD")
    result["connection_label"]=prefix
    result["display_label"]=prefix*"?"
    for w in (a,b)
        w["reason"]===nothing || return finish("unknown",w["reason"])
        tm=w["terminal_map"]; rs=w["resolved_roles"]
        length(unique(tm))==length(tm) || return finish("unknown","duplicate_terminal")
        count(==("neutral"),rs)<=1 || return finish("unknown","multiple_winding_neutrals")
    end
    subtype in ("single_phase","wye_delta","delta_wye","n_winding") ||
        return finish("unsupported","subtype_has_no_supported_three_phase_clock")
    for w in (a,b)
        cfg=uppercase(string(w["configuration"]))
        cfg in ("WYE","DELTA") || return finish("unsupported","winding_configuration")
        rs=w["resolved_roles"]
        cfg=="DELTA" && "neutral" in rs && return finish("unknown","delta_contains_neutral")
        count(==("phase"),rs)==3 || return finish("partial","not_three_phase")
        if cfg=="DELTA"
            roll=w["delta_roll"]
            roll isa Integer && !(roll isa Bool) && roll in (-1,1) ||
                return finish("unsupported","delta_roll_domain")
        end
    end
    # Positive real ratios/taps change magnitude only. Reject authored sign or
    # complex ambiguity rather than silently treating a phase reversal as zero.
    for field in ("tap","tap_ratio","v_nom_from","v_nom_to")
        v=get(xfmr,field,nothing); v===nothing && continue
        _index_number(v) && isfinite(v) && v>0 || return finish("unknown","nonpositive_or_nonscalar_ratio")
    end
    for w in (a,b)
        vn=w["v_nom"]
        vn===nothing || (_index_number(vn) && isfinite(vn) && vn>0) ||
            return finish("unknown","invalid_nominal_winding_voltage")
        order,source,reason=_phase_order_for(w,phase_order)
        w["phase_order"]=order;w["phase_order_source"]=source
        w["phase_angles_degrees"]=order===nothing ? nothing : [0,-120,120]
        reason===nothing || return finish(reason=="phase_correspondence_missing" ? "partial" : "unknown",reason)
    end
    ua=_phase_coils!(a,a["phase_order"]); ub=_phase_coils!(b,b["phase_order"])
    rot=[(ua[k]/ub[k])/abs(ua[k]/ub[k]) for k in 1:3]
    result["coil_displacements_degrees"]=[rad2deg(angle(z)) for z in rot]
    residual=maximum(abs(z-rot[1]) for z in rot)
    result["uniform_rotation_residual"]=residual
    residual<=1e-10 || return finish("unsupported","nonuniform_phase_relation")
    displacement=rad2deg(angle(rot[1]))
    clock=mod(round(Int,-displacement/30),12)
    abs(rot[1]-cis(-clock*π/6))<=1e-10 || return finish("unsupported","nonclock_displacement")
    result["clock"]=clock
    result["displacement_degrees"]=clock<=6 ? -30*clock : 360-30*clock
    result["display_label"]=prefix*string(clock)
    finish("known",nothing)
end

function _transformer_phase_summary(net,subtype,xf;phase_order=Dict())
    ws=_phase_windings(net,subtype,xf)
    relations=[transformer_phase_relation(net,subtype,xf;phase_order,to_winding=k) for k in 2:length(ws)]
    isempty(relations) && return Dict{String,Any}("status"=>"unknown","display_label"=>"?","relations"=>relations)
    length(relations)==1 && return merge(relations[1],Dict{String,Any}("relations"=>relations))
    letters=join(_phase_connection_letter(w;reference=k==1) for (k,w) in enumerate(ws))
    Dict{String,Any}("status"=>"partial","reason"=>"multiwinding_has_pairwise_relations",
        "display_label"=>letters*"?","clock"=>nothing,"relations"=>relations,
        "declared_vector_group"=>deepcopy(get(xf,"vector_group",nothing)))
end

# String consumers stay string-valued. Context-free legacy calls are explicitly
# incomplete; they cannot recover network roles or phase correspondence.
_derive_vector_group(net::Dict{String,Any},subtype::String,xf::Dict{String,Any};kwargs...) =
    transformer_phase_relation(net,subtype,xf;kwargs...)["display_label"]
_derive_vector_group(subtype::String,xf::Dict{String,Any}) =
    _derive_vector_group(Dict{String,Any}(),subtype,xf)
