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


function datapath(node::NestedCallNode)
    current_front = Set{AbstractNode}(ancestors(node[end]))
    datanodes = Set{AbstractNode}(current_front)

    while !isempty(current_front)
        current_node = pop!(current_front)
        new_front = ancestors(current_node)
        union!(current_front, new_front)
        union!(datanodes, new_front)
    end

    return filter(in(datanodes), children(node))
end


# Graph API for general nodes
"""
    ancestors(node) -> Vector{<:AbstractNode}

Return all nodes that `node` references; i.e., all data it depends on.  Argument nodes link back to
the parent block.
"""
ancestors(node::JumpNode) = getindex.(reduce(append!, references.(node.arguments),
                                             init = references(node.condition)))
ancestors(node::ReturnNode) = getindex.(references(node.argument))
ancestors(node::SpecialCallNode) = getindex.(references(node.form))
ancestors(node::NestedCallNode) = getindex.(references(node.call))
ancestors(node::PrimitiveCallNode) = getindex.(references(node.call))
ancestors(::ConstantNode) = AbstractNode[]
ancestors(::ArgumentNode) = AbstractNode[]
# function ancestors(node::ArgumentNode)
    # first argument is always the function itself -- need to treat this separately
    # if node.number == 1
        # return getindex.(references(parent(node).call.f))
    # else
        # return getindex.(references(parent(node).call.arguments[node.number - 1]))
    # end
# end


"""
    descendants(node) -> Vector{AbstractNode}

Return all nodes that reference `node`; i.e., all data that depends on it.
"""
function descendants(node::AbstractNode)
    isnothing(parent(node)) && return Vector{AbstractNode}()
    !hasvalue(node.info.descendants) && calculate_descendants!(parent(node))
    return getvalue(node.info.descendants)
end


function calculate_descendants!(node::AbstractNode)
    for child in children(node)
        # make sure all nodes have at least an empty descendants list
        setvalue!(child.info.descendants, Vector{AbstractNode}())
        
        for ancestor in ancestors(child)
            descendants = getvalue(ancestor.info.descendants)
            child ∉ descendants && push!(descendants, child)
        end
    end
    
    return node
end


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
arguments(node::NestedCallNode) = [child for child in node if child isa ArgumentNode]
arguments(node::AbstractNode) = ArgumentNode[]


"""Return the `NestedNode` `node` is a child of."""
parent(node::AbstractNode) = node.info.parent


"""Return the of the original IR statement `node` was recorded from."""
location(node::AbstractNode) = node.info.location


value(::JumpNode) = nothing
value(::ReturnNode) = nothing
value(node::SpecialCallNode) = value(node.form)
value(node::NestedCallNode) = value(node.call)
value(node::PrimitiveCallNode) = value(node.call)
value(node::ConstantNode) = value(node.value)
value(node::ArgumentNode) = value(node.value)


metadata(node::AbstractNode) = node.info.metadata


getmetadata(node::AbstractNode, key::Symbol) = metadata(node)[key]
getmetadata(node::AbstractNode, key::Symbol, default) = get(metadata(node), key, default)
getmetadata!(node::AbstractNode, key::Symbol, default) = get!(metadata(node), key, default)
getmetadata!(f, node::AbstractNode, key::Symbol) = get!(f, metadata(node), key)
setmetadata!(node::AbstractNode, key::Symbol, value) = metadata(node)[key] = value
