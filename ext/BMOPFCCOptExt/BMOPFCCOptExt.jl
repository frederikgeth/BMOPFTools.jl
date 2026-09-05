module BMOPFCCOptExt

using BMOPFTools
using JuMP
# Not called here. It is in this extension's trigger list because BMOPFOpfExt —
# whose staged builder and result extraction this adapter reuses — is itself
# triggered by [JuMP, Ipopt], and `_opf_extension()` below requires it loaded.
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

include("ccopt.jl")

end # module BMOPFCCOptExt
