value(node::StatementNode) = node.value
value(node::BranchNode) = nothing

# assumes `expr` is flat, i.e., not containing sub-expressions
parentindices(expr::Expr) = TapeIndex[e for e in expr.args if e isa TapeIndex]
parentindices(expr::TapeIndex) = [expr]
parentindices(expr) = TapeIndex[]



struct Argument <: StatementNode
    value::Any
    index::VarIndex
    info::StatementInfo
end

Argument(value, index) = Argument(value, index, StatementInfo())

parents(tape::GraphTape, ::Argument) = Node[]
children(::Argument) = Node[]


struct Constant <: StatementNode
    value::Any
    index::VarIndex
    info::StatementInfo
end

Constant(value, index) = Constant(value, index, StatementInfo())

parents(tape::GraphTape, ::Constant) = Node[]
children(::Constant) = Node[]


struct PrimitiveCall <: StatementNode
    expr::Any
    value::Any
    index::VarIndex
    info::StatementInfo
end

PrimitiveCall(expr, value, index) = PrimitiveCall(expr, value, index, StatementInfo())

parents(tape::GraphTape, node::PrimitiveCall) = [tape[ix] for ix in parentindices(node.expr)]
children(::PrimitiveCall) = Node[]


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
parents(tape::GraphTape, node::NestedCall) = [tape[ix] for ix in parentindices(node.expr)]
children(node::NestedCall) = node.subtape.nodes


struct SpecialStatement <: StatementNode
    expr::Any
    value::Any
    index::VarIndex
    info::StatementInfo
end

SpecialStatement(expr, value, index) = SpecialStatement(expr, value, index, StatementInfo())

parents(tape::GraphTape, node::SpecialStatement) = [tape[ix] for ix in parentindices(node.expr)]
children(::SpecialStatement) = Node[]


struct Return <: BranchNode
    expr::Any
    value::Any
    index::BranchIndex
    info::StatementInfo
end

Return(expr, value, index) = Return(expr, value, index, StatementInfo())

parents(tape::GraphTape, node::Return) = [tape[ix] for ix in parentindices(node.expr)]
children(::Return) = Node[]


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

parents(tape::GraphTape, node::Branch) = getindex.(Ref(tape),
                                                   reduce(vcat, parentindices.(node.arg_exprs),
                                                          init = parentindices(node.condition_expr)))
children(::Branch) = Node[]
