"""Extra data and metadata associated with an SSA statement"""
struct NodeInfo
    location::IRIndex
    parent::Union{RecursiveNode, Nothing}
    # slot::Core.Slot
    descendants::Cached{Vector{AbstractNode}}
    metadata::Dict{Symbol, Any}
end

NodeInfo() = NodeInfo(NO_INDEX, nothing, Cached{Vector{AbstractNode}}(), Dict{Symbol, Any}())
NodeInfo(location) = NodeInfo(
    location, nothing, Cached{Vector{AbstractNode}}(), Dict{Symbol, Any}())
NodeInfo(location, parent) = NodeInfo(
    location, parent, Cached{Vector{AbstractNode}}(), Dict{Symbol, Any}())


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


mutable struct NestedCallNode <: RecursiveNode
    call::TapeCall
    children::Vector{AbstractNode}
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
    arguments::ArgumentTuple
    condition::TapeValue
    info::NodeInfo
end
