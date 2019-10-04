"""Extra data and metadata associated with an SSA statement"""
struct StatementInfo
    # line::LineInfoNode
    metadata::Any
end

StatementInfo() = StatementInfo(nothing)



value(node::StatementNode) = node.value
value(node::BranchNode) = nothing

struct Argument <: StatementNode
    value::Any
    index::VarIndex
    info::StatementInfo
end

Argument(value, index) = Argument(value, index, StatementInfo())

parents(::Argument) = Node[]
children(::Argument) = Node[]


struct Constant <: StatementNode
    value::Any
    index::VarIndex
    info::StatementInfo
end

Constant(value, index) = Constant(value, index, StatementInfo())

parents(::Constant) = Node[]
children(::Constant) = Node[]


struct PrimitiveCall <: StatementNode
    expr::TapeExpr
    value::Any
    index::VarIndex
    info::StatementInfo
end

PrimitiveCall(expr, value, index) = PrimitiveCall(expr, value, index, StatementInfo())

parents(node::PrimitiveCall) = getindex.(references(node.expr))
children(::PrimitiveCall) = Node[]


struct NestedCall <: StatementNode
    expr::TapeExpr
    value::Any
    index::VarIndex
    subtape::GraphTape
    info::StatementInfo
end

NestedCall(expr, value, index, subtape = GraphTape()) =
    NestedCall(expr, value, index, subtape, StatementInfo())

push!(node::NestedCall, child::Node) = (push!(node.subtape, child); node)
parents(node::NestedCall) = getindex.(references(node.expr))
children(node::NestedCall) = node.subtape.nodes


struct SpecialStatement <: StatementNode
    expr::TapeExpr
    value::Any
    index::VarIndex
    info::StatementInfo
end

SpecialStatement(expr, value, index) = SpecialStatement(expr, value, index, StatementInfo())

parents(node::SpecialStatement) = getindex.(references(node.expr))
children(::SpecialStatement) = Node[]


struct Return <: BranchNode
    expr::TapeExpr
    value::Any
    index::BranchIndex
    info::StatementInfo
end

Return(expr, value, index) = Return(expr, value, index, StatementInfo())

parents(node::Return) = getindex.(references(node.expr))
children(::Return) = Node[]


struct Branch <: BranchNode
    target::Int
    arg_exprs::Vector{TapeExpr}
    arg_values::Vector{Any}
    condition_expr::TapeExpr
    index::BranchIndex
    info::StatementInfo
end

Branch(target, arg_exprs, arg_values, condition_expr, index) =
    Branch(target, arg_exprs, arg_values, condition_expr, index, StatementInfo())

parents(node::Branch) = getindex.(reduce(vcat, references.(node.arg_exprs),
                                         init = references(node.condition_expr)))
children(::Branch) = Node[]
