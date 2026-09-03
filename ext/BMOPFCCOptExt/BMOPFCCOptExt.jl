module BMOPFCCOptExt

using BMOPFTools
using JuMP
using Ipopt
using CCOpt
using MPCCModels
using NLPModelsJuMP

function _opf_extension()
    ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
    ext === nothing && throw(ArgumentError(
        "BMOPFOpfExt must be loaded before using the CCOpt adapter"))
    return ext
end

include("../BMOPFOpfExt/ccopt.jl")

end # module BMOPFCCOptExt
