module DynamicComputationGraphs


include("utils.jl")
include("graph.jl")
include("show.jl")
include("graphrecorder.jl")
include("trackbuilder.jl")
include("tracker.jl")
include("runtime_functions.jl")


# graph.jl
export BranchIndex, IRIndex, VarIndex
export GraphTape, StatementInfo
export TapeCall, TapeConstant, TapeExpr, TapeReference, TapeSpecialForm, TapeValue

export references, value
export backward, children, parents

# show.jl
export printlevels

# tracker.jl
export track


end # module
