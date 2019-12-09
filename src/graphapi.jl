using IRTools
import Base: collect, eltype, iterate, length, size
import Base: firstindex, getindex, lastindex
import Base: parent, push!



# Graph API for NestedCallNode
push!(node::NestedCallNode, child::AbstractNode) = (push!(node.children, child); node)

iterate(node::NestedCallNode) = iterate(node.children)
iterate(node::NestedCallNode, state) = iterate(node.children, state)
eltype(node::NestedCallNode) = AbstractNode
length(node::NestedCallNode) = length(node.children)
size(node::NestedCallNode) = size(node.children)
collect(node::NestedCallNode) = collect(node.children)
iterate(rNode::Iterators.Reverse{NestedCallNode}) = iterate(Iterators.reverse(rNode.itr.children))
iterate(rNode::Iterators.Reverse{NestedCallNode}, state) = iterate(Iterators.reverse(rNode.itr.children), state)

getindex(node::NestedCallNode, i) = node.children[i]
firstindex(node::NestedCallNode) = firstindex(node.children)
lastindex(node::NestedCallNode) = lastindex(node.children)


function backward!(f!, node::NestedCallNode)
    kernel!(::ControlFlowNode) = nothing
    kernel!(node::DataFlowNode) = f!(node, ancestors(node))

    for node in Iterators.reverse(node)
        kernel!(node)
    end
end


# Graph API for general nodes
"""
    ancestors(node) -> Vector{<:AbstractNode}

Return all nodes that `node` references; i.e., all data it depends on.
"""
ancestors(node::JumpNode) = getindex.(reduce(vcat, references.(node.arguments),
                                           init = references(node.condition)))
ancestors(node::ReturnNode) = getindex.(references(node.argument))
ancestors(node::SpecialCallNode) = getindex.(references(node.form))
ancestors(node::NestedCallNode) = getindex.(references(node.call))
ancestors(node::PrimitiveCallNode) = getindex.(references(node.call))
ancestors(::ConstantNode) = AbstractNode[]
ancestors(::ArgumentNode) = AbstractNode[]

#TODO: descendants


"""
    children(node) -> Vector{<:AbstractNode}

Return all sub-nodes of this node (only none-empty if `node` is a `NestedCallNode`).
"""
children(node::NestedCallNode) = node.children
children(node::AbstractNode) = AbstractNode[]


"""
    arguments(node) -> Vector{ArgumentNode}

Return the sub-nodes representing the arguments of a nested call.
"""
arguments(node::NestedCallNode) = filter(child -> child isa ArgumentNode, children(node))
arguments(node::AbstractNode) = ArgumentNode[]


"""Return the `NestedNode` `node` is a child of."""
parent(node::AbstractNode) = node.info.parent


"""Return the of the original IR statement `node` was recorded from."""
location(node::AbstractNode) = node.info.location


metadata(node::AbstractNode) = node.info.metadata

value(::JumpNode) = nothing
value(::ReturnNode) = nothing
value(node::SpecialCallNode) = value(node.form)
value(node::NestedCallNode) = value(node.call)
value(node::PrimitiveCallNode) = value(node.call)
value(node::ConstantNode) = value(node.value)
value(node::ArgumentNode) = value(node.value)


