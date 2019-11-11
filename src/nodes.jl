"""Extra data and metadata associated with an SSA statement"""
Base.@kwdef struct NodeInfo
    location::IRIndex = NO_INDEX
    parent::Union{RecursiveNode, Nothing} = nothing
    # slot::Core.Slot
    metadata::Any = nothing
end



struct ArgumentNode <: DataFlowNode
    value::TapeConstant
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


mutable struct NestedCallNode <: RecursiveNode
    call::TapeCall
    children::Vector{<:AbstractNode}
    original_ir::IRTools.IR
    info::NodeInfo

    NestedCallNode() = new()
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
    arguments::Vector{<:TapeValue}
    condition::TapeValue
    info::NodeInfo
end
