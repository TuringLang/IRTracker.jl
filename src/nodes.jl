import Base: firstindex, getindex, lastindex, push!


struct ArgumentNode <: DataFlowNode
    value::TapeConstant
    number::Int
    info::NodeInfo
end

struct ConstantNode <: DataFlowNode
    value::TapeConstant
    info::NodeInfo
end

struct PrimitiveCallNode <: DataFlowNode
    call::TapeCall
    info::NodeInfo
end

struct NestedCallNode <: RecursiveNode
    call::TapeCall
    children::Vector{AbstractNode}
    original_ir::NullableRef{IRTools.IR}
    info::NodeInfo
end

struct SpecialCallNode <: DataFlowNode
    form::TapeSpecialForm
    info::NodeInfo
end

struct ReturnNode <: ControlFlowNode
    argument::TapeValue
    info::NodeInfo
end

struct JumpNode <: ControlFlowNode
    target::Int
    arguments::ArgumentTuple{TapeValue}
    condition::TapeValue
    info::NodeInfo
end




####################################################################################################
# Node property and metadata accessors

# function push!(node::NestedCallNode, child::AbstractNode)
#     push!(node.children, child)
#     child.info.position = length(node.children)
#     return node
# end


getindex(node::NestedCallNode, i) = node.children[i]
firstindex(node::NestedCallNode) = firstindex(node.children)
lastindex(node::NestedCallNode) = lastindex(node.children)


"""Return the IR index into the original IR statement, which `node` was recorded from."""
location(node::AbstractNode) = location(node.info)

"""Return the index of `node` in its parent node."""
position(node::AbstractNode) = position(node.info)

value(::JumpNode) = nothing
value(::ReturnNode) = nothing
value(node::SpecialCallNode) = value(node.form)
value(node::NestedCallNode) = value(node.call)
value(node::PrimitiveCallNode) = value(node.call)
value(node::ConstantNode) = value(node.value)
value(node::ArgumentNode) = value(node.value)

metadata(node::AbstractNode) = metadata(node.info)

getmetadata(node::AbstractNode, key::Symbol) = metadata(node)[key]
getmetadata(node::AbstractNode, key::Symbol, default) = get(metadata(node), key, default)
getmetadata!(node::AbstractNode, key::Symbol, default) = get!(metadata(node), key, default)
getmetadata!(f, node::AbstractNode, key::Symbol) = get!(f, metadata(node), key)
setmetadata!(node::AbstractNode, key::Symbol, value) = metadata(node)[key] = value

