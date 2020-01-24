
struct ArgumentNode{T} <: DataFlowNode{T}
    value::TapeConstant{T}
    call_source::Union{ControlFlowNode, Nothing}
    number::Int
    info::NodeInfo
end

struct ConstantNode{T} <: DataFlowNode{T}
    value::TapeConstant{T}
    info::NodeInfo
end

struct PrimitiveCallNode{T} <: DataFlowNode{T}
    call::TapeCall{T}
    info::NodeInfo
end

struct NestedCallNode{T} <: RecursiveNode{T}
    call::TapeCall{T}
    children::Vector{<:AbstractNode}
    info::NodeInfo
end

struct SpecialCallNode{T} <: DataFlowNode{T}
    form::TapeSpecialForm{T}
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
