module DynamicComputationGraphs


include("utils.jl")
include("graph.jl")
include("show.jl")
include("trackingcontext.jl")
include("graphrecorder.jl")
include("trackbuilder.jl")
include("tracker.jl")
include("runtime_functions.jl")


# graph.jl
export BranchIndex, IRIndex, VarIndex
export StatementInfo
export AbstractNode, BranchNode, StatementNode
export ArgumentNode, ConstantNode, JumpNode, NestedCallNode, PrimitiveCallNode,
     ReturnNode, SpecialCallNode
export TapeCall, TapeConstant, TapeExpr, TapeReference, TapeSpecialForm, TapeValue

export references, value
export backward, children, parents

# trackingcontext.jl
export AbstractTrackingContext, DefaultTrackingContext

# show.jl
export printlevels

# tracker.jl
export track


end # module
