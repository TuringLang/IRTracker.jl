import Base: firstindex, getindex, lastindex, push!


struct ConstantNode{T} <: DataFlowNode
    value::TapeConstant{T}
    info::NodeInfo
end

struct PrimitiveCallNode{T} <: DataFlowNode
    call::TapeCall{T}
    info::NodeInfo
end

struct NestedCallNode{T} <: RecursiveNode
    call::TapeCall{T}
    children::Vector{<:AbstractNode}
    info::NodeInfo
end

struct SpecialCallNode{T} <: DataFlowNode
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

struct ArgumentNode{T} <: DataFlowNode
    value::TapeConstant{T}
    call_source::Union{TapeReference, Nothing}
    number::Int
    info::NodeInfo
end
