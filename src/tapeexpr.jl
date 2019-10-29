import Base: getindex

"""
Representation of an expression in an IR statement when tracked on a `GraphTape`.  Contains a 
reified form of the original and the value obtained during execution (i.e., forward mode).
"""
abstract type TapeExpr end


abstract type TapeValue <: TapeExpr end
abstract type TapeForm <: TapeExpr end


"""
Representation of an SSA variable.  References a node of a `GraphTape`s node list; like the indices
of a Wengert list.  Behaves like `Ref` (i.e., you can get the referenced node of `r` by `r[]`).
"""
struct TapeReference <: TapeValue
    tape::GraphTape
    index::Int
end


"""Representation of a constant value."""
struct TapeConstant <: TapeValue
    value::Any
end


"""Representation of a normal function call."""
struct TapeCall <: TapeExpr
    value::Any
    f::TapeValue
    arguments::Vector{<:TapeValue}
end


"""Representation of special expression (i.e., anything other than `Expr(:call, ...)`)."""
struct TapeSpecialForm <: TapeExpr
    value::Any
    head::Symbol
    arguments::Vector{<:TapeValue}

    # TapeSpecialForm(value, head::Symbol, arguments::Vector{<:TapeValue}) = new{head}(value, head, arguments)
end



getindex(ref::TapeReference) = ref.tape[ref.index]


"""
    references(expr::TapeExpr) -> Vector{TapeReference}

Get the list of tape references in a `TapeExpr`, i.e., the parents in the call graph.
"""
function references end

references(expr::TapeCall) = TapeReference[e for e in expr.arguments if e isa TapeReference]
references(expr::TapeSpecialForm) = TapeReference[e for e in expr.arguments if e isa TapeReference]
references(expr::TapeConstant) = TapeReference[]
references(expr::TapeReference) = TapeReference[expr]


value(expr::TapeCall) = expr.value
value(expr::TapeSpecialForm) = expr.value
value(expr::TapeConstant) = expr.value
value(expr::TapeReference) = value(expr[])
