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
export BranchIndex, IRIndex, NoIndex, NO_INDEX, VarIndex
export NodeInfo, ArgumentTuple
export AbstractNode, ControlFlowNode, DataFlowNode, RecursiveNode
export ArgumentNode, ConstantNode, JumpNode, NestedCallNode, PrimitiveCallNode,
    ReturnNode, SpecialCallNode
export TapeCall, TapeConstant, TapeExpr, TapeReference, TapeSpecialForm, TapeValue

# graphapi.jl
export getmetadata, getmetadata!, metadata, location, setmetadata!, value
export ancestors, children, parent, descendants, query
export Ancestor, Child, Descendant, Following, Parent, Preceding
export backward, dependents, forward, referenced

# trackingcontext.jl
export AbstractTrackingContext, DefaultTrackingContext, DepthLimitContext

# show.jl
export printlevels

# tracker.jl
export track, trackcall, tracknested, trackprimitive
export canrecur, recordnested, recordprimitive
export @code_tracked

# runtime_functions.jl
export isbuiltin


end # module
