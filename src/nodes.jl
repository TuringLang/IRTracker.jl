"""Extra data and metadata associated with an SSA statement"""
struct StatementInfo
    # line::LineInfoNode
    metadata::Any
end

StatementInfo() = StatementInfo(nothing)


struct Argument <: StatementNode
    value::TapeConstant
    location::VarIndex
    info::StatementInfo
end

Argument(value, location) = Argument(value, location, StatementInfo())


struct Constant <: StatementNode
    value::TapeConstant
    location::VarIndex
    info::StatementInfo
end

Constant(value, location) = Constant(value, location, StatementInfo())


struct PrimitiveCall <: StatementNode
    call::TapeCall
    location::VarIndex
    info::StatementInfo
end

PrimitiveCall(call, location) = PrimitiveCall(call, location, StatementInfo())


struct NestedCall <: StatementNode
    call::TapeCall
    subtape::GraphTape
    location::VarIndex
    info::StatementInfo
end

NestedCall(call, subtape, location) = NestedCall(call, subtape, location, StatementInfo())


struct SpecialStatement <: StatementNode
    form::TapeSpecialForm
    location::VarIndex
    info::StatementInfo
end

SpecialStatement(form, location) = SpecialStatement(form, location, StatementInfo())


struct Return <: BranchNode
    argument::TapeValue
    location::BranchIndex
    info::StatementInfo
end

Return(argument, location) = Return(argument, location, StatementInfo())


struct Branch <: BranchNode
    target::Int
    arguments::Vector{<:TapeValue}
    condition::TapeValue
    location::BranchIndex
    info::StatementInfo
end

Branch(target, arguments, condition, location) =
    Branch(target, arguments, condition, location, StatementInfo())



push!(node::NestedCall, child::Node) = (push!(node.subtape, child); node)

parents(node::Branch) = getindex.(reduce(vcat, references.(node.arguments),
                                         init = references(node.condition)))
parents(node::Return) = getindex.(references(node.argument))
parents(node::SpecialStatement) = getindex.(references(node.form))
parents(node::NestedCall) = getindex.(references(node.call))
parents(node::PrimitiveCall) = getindex.(references(node.call))
parents(::Constant) = Node[]
parents(::Argument) = Node[]

children(::Branch) = Node[]
children(::Return) = Node[]
children(::SpecialStatement) = Node[]
children(node::NestedCall) = node.subtape.nodes
children(::PrimitiveCall) = Node[]
children(::Constant) = Node[]
children(::Argument) = Node[]

value(::Branch) = nothing
value(::Return) = nothing
value(node::SpecialStatement) = value(node.form)
value(node::NestedCall) = value(node.call)
value(node::PrimitiveCall) = value(node.call)
value(node::Constant) = value(node.value)
value(node::Argument) = value(node.value)
