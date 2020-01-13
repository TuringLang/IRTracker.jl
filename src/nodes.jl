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
