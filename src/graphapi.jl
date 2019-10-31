using IRTools
import Base: collect, eltype, iterate, length, size
import Base: firstindex, getindex, lastindex
import Base: push!



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

function backward(f!, node::NestedCallNode)
    for node in Iterators.reverse(node)
        f!(node, parents(node))
    end
end


# Graph API for general nodes
parents(node::JumpNode) = getindex.(reduce(vcat, references.(node.arguments),
                                           init = references(node.condition)))
parents(node::ReturnNode) = getindex.(references(node.argument))
parents(node::SpecialCallNode) = getindex.(references(node.form))
parents(node::NestedCallNode) = getindex.(references(node.call))
parents(node::PrimitiveCallNode) = getindex.(references(node.call))
parents(::ConstantNode) = AbstractNode[]
parents(::ArgumentNode) = AbstractNode[]

children(::JumpNode) = AbstractNode[]
children(::ReturnNode) = AbstractNode[]
children(::SpecialCallNode) = AbstractNode[]
children(node::NestedCallNode) = node.children
children(::PrimitiveCallNode) = AbstractNode[]
children(::ConstantNode) = AbstractNode[]
children(::ArgumentNode) = AbstractNode[]

value(::JumpNode) = nothing
value(::ReturnNode) = nothing
value(node::SpecialCallNode) = value(node.form)
value(node::NestedCallNode) = value(node.call)
value(node::PrimitiveCallNode) = value(node.call)
value(node::ConstantNode) = value(node.value)
value(node::ArgumentNode) = value(node.value)
