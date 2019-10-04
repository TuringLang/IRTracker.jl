abstract type Node end
abstract type StatementNode <: Node end
abstract type BranchNode <: Node end

include("graphtape.jl")

include("tapeexpr.jl")

include("nodes.jl")
