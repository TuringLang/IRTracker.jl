module IRTracker

include("utils.jl")
include("graph.jl")
include("show.jl")
include("io.jl")
include("trackingcontext.jl")
include("graphrecorder.jl")
include("trackbuilder.jl")
include("tracker.jl")



# graph.jl
export BranchIndex, IRIndex, NoIndex, NO_INDEX, VarIndex
export NodeInfo, ArgumentTuple
export AbstractNode, ControlFlowNode, DataFlowNode, RecursiveNode
export ArgumentNode, ConstantNode, JumpNode, NestedCallNode, PrimitiveCallNode,
    ReturnNode, SpecialCallNode
export TapeCall, TapeConstant, TapeExpr, TapeReference, TapeSpecialForm, TapeValue

# graphapi.jl
export getargument, getarguments, getcallarguments, getchildren, getfunction, getmetadata,
    getmetadata!, getir, getlocation, getparent, getposition, getvalue, setmetadata!
export Ancestor, Child, Descendant, Following, Parent, Preceding
export backward, dependents, forward, query, referenced

# trackingcontext.jl
export AbstractTrackingContext, DefaultTrackingContext, DepthLimitContext

# show.jl
export printlevels

# tracker.jl
export track, recordnestedcall
export canrecur, isbuiltin, trackedargument, trackedcall, trackedconstant, trackederror, trackedjump,
    trackednested, trackedprimitive, trackedreturn, trackedspecial
export @code_tracked

end # module
