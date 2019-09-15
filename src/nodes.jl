struct Argument <: StatementNode
    value::Any
    index::VarIndex
    info::StatementInfo
end

Argument(value, index) = Argument(value, index, StatementInfo())


struct Constant <: StatementNode
    value::Any
    index::VarIndex
    info::StatementInfo
end

Constant(value, index) = Constant(value, index, StatementInfo())


struct PrimitiveCall <: StatementNode
    expr::Any
    value::Any
    index::VarIndex
    info::StatementInfo
end

PrimitiveCall(expr, value, index) = PrimitiveCall(expr, value, index, StatementInfo())


struct NestedCall <: StatementNode
    expr::Any
    value::Any
    index::VarIndex
    subtape::GraphTape
    info::StatementInfo
end

NestedCall(expr, value, index, subtape = GraphTape()) =
    NestedCall(expr, value, index, subtape, StatementInfo())

push!(node::NestedCall, child::Node) = (push!(node.subtape, child); node)


struct SpecialStatement <: StatementNode
    expr::Any
    value::Any
    index::VarIndex
    info::StatementInfo
end

SpecialStatement(expr, value, index) = SpecialStatement(expr, value, index, StatementInfo())


struct Return <: BranchNode
    expr::Any
    value::Any
    index::BranchIndex
    info::StatementInfo
end

Return(expr, value, index) = Return(expr, value, index, StatementInfo())

struct Branch <: BranchNode
    target::Int
    arg_exprs::Vector{Any}
    arg_values::Vector{Any}
    condition_expr::Any
    index::BranchIndex
    info::StatementInfo
end

Branch(target, arg_exprs, arg_values, condition_expr, index) =
    Branch(target, arg_exprs, arg_values, condition_expr, index, StatementInfo())
