# Reviewed finite-fixture correspondences. These are regression oracles, not a
# general reduction API. PSK-000002/PSK-000007: electrical agreement does not
# establish neutral-role or rating preservation.
using LinearAlgebra

const RT_REVIEW = BMOPFTools.JSON3.read(
    read(joinpath(@__DIR__, "data", "roundtrip_review.json"), String), Dict{String,Any})

_rt_mapped(node, mapping) = Tuple(split(get(mapping, join(node,"."), join(node,".")), "."; limit=2))

function _rt_stamp!(entries, nodes, Y; mapping=Dict())
    for i in eachindex(nodes), j in eachindex(nodes)
        key = (_rt_mapped(nodes[i],mapping), _rt_mapped(nodes[j],mapping))
        entries[key] = get(entries,key,0.0+0im) + Y[i,j]
    end
    entries
end

function _rt_shunts(net; lines=String[], mapping=Dict())
    entries = Dict{Any,ComplexF64}()
    for shunt in values(get(net,"shunt",Dict()))
        nodes,Y = BMOPFTools._shunt_yprim(shunt)
        _rt_stamp!(entries,nodes,Y;mapping)
    end
    for id in lines
        nodes,Y = line_yprim(net["line"][id],net["linecode"])
        _rt_stamp!(entries,nodes,Y;mapping)
    end
    entries
end

# Exact +R/-R series source realization, checked independently of a solved PF.
function _rt_source_pairs(a,b,pairs)
    isempty(pairs) && return
    old = a["voltage_source"]["source"]
    @test length(pairs) == length(old["terminal_map"])
    for (phase,(sid,pos,neg)) in enumerate(pairs)
        s=b["voltage_source"][sid]; p=b["line"][pos]; n=b["line"][neg]
        @test b["bus"][s["bus"]]["perfectly_grounded_terminals"] == ["n_ref"]
        @test b["bus"][s["bus"]]["terminal_names"] == ["a","n_ref"]
        @test p["bus_from"] == s["bus"]
        @test p["terminal_map_from"] == s["terminal_map"] == ["a"]
        @test (p["bus_to"],p["terminal_map_to"]) == (n["bus_from"],n["terminal_map_from"])
        @test (n["bus_to"],n["terminal_map_to"]) == (old["bus"],[old["terminal_map"][phase]])
        zp,_=BMOPFTools._line_z_complex(p,b["linecode"])
        zn,_=BMOPFTools._line_z_complex(n,b["linecode"])
        @test size(zp)==size(zn)==(1,1)
        @test zp[1,1] == 1.0+0im
        @test zn[1,1] == -1.0+0im
        @test zp+zn == zeros(ComplexF64,1,1)
        for line in (p,n), (key,value) in b["linecode"][line["linecode"]]
            (startswith(key,"G_") || startswith(key,"B_")) && @test iszero(value)
        end
        @test only(s["v_magnitude"]) * cis(only(s["v_angle"])) ≈
              old["v_magnitude"][phase] * cis(old["v_angle"][phase]) rtol=1e-12
    end
end

# Tiny series impedance is represented by a three-node current circuit. Eliminate
# ONLY the declared auxiliary node and compare the two-port primitive, including
# its three constant-Z shunts. This never ignores changes to physical feeders.
function _rt_tiny_impedance(a,b,id)
    old=a["line"][id]; oldnodes,Yold=line_yprim(old,a["linecode"])
    aux="_pio_current_"*id
    nodes=vcat(oldnodes,[(aux,"a")]); Y=zeros(ComplexF64,3,3)
    function stamp(ns,block)
        for (i,ni) in enumerate(ns), (j,nj) in enumerate(ns)
            ii=findfirst(==(ni),nodes); jj=findfirst(==(nj),nodes)
            if ii!==nothing && jj!==nothing
                Y[ii,jj]+=block[i,j]
            else
                for node in (ni,nj)
                    node in nodes && continue
                    @test node[2] in get(b["bus"][node[1]],"perfectly_grounded_terminals",[])
                end
            end
        end
    end
    for lid in (id,aux*"_to")
        ns,block=line_yprim(b["line"][lid],b["linecode"]); stamp(ns,block)
    end
    for suffix in ("_from_shunt","_to_shunt","_aux_shunt")
        load=b["load"][aux*suffix]
        @test load["model"]=="constant_impedance"
        @test length(load["terminal_map"])==2
        y=complex(only(load["p_nom"]),-only(load["q_nom"]))/only(load["v_nom"])^2
        ns=[(load["bus"],t) for t in load["terminal_map"]]
        stamp(ns,y*[1 -1;-1 1])
    end
    reduced=Y[1:2,1:2]-Y[1:2,3:3]*(Y[3:3,3:3]\Y[3:3,1:2])
    @test reduced ≈ Yold rtol=1e-12 atol=1e-12
end

function check_reviewed_roundtrip(a,b,stem)
    review=RT_REVIEW[stem]; mapping=review["terminal_map"]
    # No original line is dropped, even when its code id changes. Match every
    # physical terminal and the complete primitive, including charging/mutuals.
    for (id,line) in get(a,"line",Dict())
        @test haskey(b["line"],id)
        if id == review["tiny_impedance_equivalent"]
            _rt_tiny_impedance(a,b,id)
        else
            na,ya=line_yprim(line,a["linecode"])
            nb,yb=line_yprim(b["line"][id],b["linecode"])
            @test _rt_mapped.(na,Ref(mapping)) == nb
            @test ya ≈ yb rtol=1e-12 atol=1e-12
        end
        for field in ("i_max","s_max")
            limit(net,l)=get(l,field,get(net["linecode"][l["linecode"]],field,nothing))
            before=limit(a,line); after=limit(b,b["line"][id])
            if id=="_pio_vsource_source_impedance" && before===nothing && field=="i_max" && !isempty(review["ideal_source_pairs"])
                # Evidence inventory only; the normative missing-rating check is
                # isolated in the minimized upstream #762 expected failure.
                @test after == fill(600,length(line["terminal_map_from"]))
            else
                @test before == after
            end
        end
    end
    _rt_source_pairs(a,b,review["ideal_source_pairs"])
    replacements=review["shunt_replacements"]
    @test Set(replacements["source_ids"]) == setdiff(keys(get(a,"shunt",Dict())),keys(get(b,"shunt",Dict())))
    sa=_rt_shunts(a;mapping)
    sb=_rt_shunts(b;lines=replacements["target_lines"])
    for key in union(keys(sa),keys(sb))
        @test get(sa,key,0im) ≈ get(sb,key,0im) rtol=1e-12 atol=1e-12
    end
    # Every retained ground relation survives the declared coordinate map. A
    # removed n_ref may be ignored only if no original element uses that node.
    function used(node,net)
        for kind in COMPONENT_TYPES
            kind in (:bus,:linecode) && continue
            bank=get(net,string(kind),Dict())
            components=kind==:transformer ? [c for sub in values(bank) for c in values(sub)] : values(bank)
            for c in components, (bk,tk) in (("bus","terminal_map"),("bus_from","terminal_map_from"),("bus_to","terminal_map_to"))
                get(c,bk,nothing)==node[1] && node[2] in get(c,tk,[]) && return true
            end
            if kind==:transformer
                for c in components, w in get(c,"windings",[])
                    get(w,"bus",nothing)==node[1] && node[2] in get(w,"terminal_map",[]) && return true
                end
            end
        end
        false
    end
    for (id,bus) in a["bus"], t in get(bus,"perfectly_grounded_terminals",[])
        node=(id,t); dest=_rt_mapped(node,mapping)
        if t=="n_ref" && !(dest[2] in get(b["bus"][dest[1]],"terminal_names",[]))
            @test !used(node,a)
        else
            @test dest[2] in get(b["bus"][dest[1]],"perfectly_grounded_terminals",[])
        end
    end
end
