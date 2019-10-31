"""Extra data and metadata associated with an SSA statement"""
struct StatementInfo
    # line::LineInfoNode
    metadata::Any
end

StatementInfo() = StatementInfo(nothing)


struct ArgumentNode <: StatementNode
    value::TapeConstant
    location::VarIndex
    info::StatementInfo
end

ArgumentNode(value, location) = ArgumentNode(value, location, StatementInfo())


struct ConstantNode <: StatementNode
    value::TapeConstant
    location::VarIndex
    info::StatementInfo
end

ConstantNode(value, location) = ConstantNode(value, location, StatementInfo())


struct PrimitiveCallNode <: StatementNode
    call::TapeCall
    location::VarIndex
    info::StatementInfo
end

PrimitiveCallNode(call, location) = PrimitiveCallNode(call, location, StatementInfo())


struct NestedCallNode <: StatementNode
    call::TapeCall
    subtape::GraphTape
    location::VarIndex
    info::StatementInfo
end

NestedCallNode(call, subtape, location) = NestedCallNode(call, subtape, location, StatementInfo())


struct SpecialCallNode <: StatementNode
    form::TapeSpecialForm
    location::VarIndex
    info::StatementInfo
end

SpecialCallNode(form, location) = SpecialCallNode(form, location, StatementInfo())


struct ReturnNode <: BranchNode
    argument::TapeValue
    location::BranchIndex
    info::StatementInfo
end

ReturnNode(argument, location) = ReturnNode(argument, location, StatementInfo())


struct JumpNode <: BranchNode
    target::Int
    arguments::Vector{<:TapeValue}
    condition::TapeValue
    location::BranchIndex
    info::StatementInfo
end

JumpNode(target, arguments, condition, location) =
    JumpNode(target, arguments, condition, location, StatementInfo())



push!(node::NestedCallNode, child::AbstractNode) = (push!(node.subtape, child); node)

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
children(node::NestedCallNode) = node.subtape.nodes
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
