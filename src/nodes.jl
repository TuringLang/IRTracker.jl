"""Extra data and metadata associated with an SSA statement"""
struct StatementInfo
    # line::LineInfoNode
    metadata::Any
end

StatementInfo() = StatementInfo(nothing)


struct ArgumentNode <: DataflowNode
    value::TapeConstant
    location::VarIndex
    info::StatementInfo
end

ArgumentNode(value, location) = ArgumentNode(value, location, StatementInfo())


struct ConstantNode <: DataflowNode
    value::TapeConstant
    location::VarIndex
    info::StatementInfo
end

ConstantNode(value, location) = ConstantNode(value, location, StatementInfo())


struct PrimitiveCallNode <: DataflowNode
    call::TapeCall
    location::VarIndex
    info::StatementInfo
end

PrimitiveCallNode(call, location) = PrimitiveCallNode(call, location, StatementInfo())


mutable struct NestedCallNode <: RecursiveNode
    call::TapeCall
    children::Vector{<:AbstractNode}
    original_ir::IRTools.IR
    location::VarIndex
    info::StatementInfo

    NestedCallNode() = new()
end

NestedCallNode(call, children, location, ir) = NestedCallNode(call, children, location, StatementInfo())


struct SpecialCallNode <: DataflowNode
    form::TapeSpecialForm
    location::VarIndex
    info::StatementInfo
end

SpecialCallNode(form, location) = SpecialCallNode(form, location, StatementInfo())


struct ReturnNode <: ControlflowNode
    argument::TapeValue
    location::BranchIndex
    info::StatementInfo
end

ReturnNode(argument, location) = ReturnNode(argument, location, StatementInfo())


struct JumpNode <: ControlflowNode
    target::Int
    arguments::Vector{<:TapeValue}
    condition::TapeValue
    location::BranchIndex
    info::StatementInfo
end

JumpNode(target, arguments, condition, location) =
    JumpNode(target, arguments, condition, location, StatementInfo())
