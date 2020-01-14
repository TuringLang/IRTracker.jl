import Base: getindex

"""
Representation of an expression in an IR statement when tracked in a node.  Contains a 
reified form of the original and the value obtained during execution (i.e., forward mode).
"""
abstract type TapeExpr end

abstract type TapeValue <: TapeExpr end
abstract type TapeForm <: TapeExpr end


"""
Representation of an SSA variable.  References a child node of a `NestedCallNode`; like the indices
of a Wengert list.  Behaves like `Ref` (i.e., you can get the referenced node of `r` by `r[]`).
"""
struct TapeReference <: TapeValue
    parent::RecursiveNode
    index::Int
end


"""Representation of a constant value."""
struct TapeConstant <: TapeValue
    value::Any
end


"""Representation of a normal function call."""
struct TapeCall <: TapeExpr
    value::NullableRef{Any}
    f::TapeValue
    arguments::ArgumentTuple{TapeValue}

    TapeCall(value, f::TapeValue, arguments::ArgumentTuple{TapeValue}) =
        new(NullableRef{Any}(value), f, arguments)
    TapeCall(f::TapeValue, arguments::ArgumentTuple{TapeValue}) =
        new(NullableRef{Any}(), f, arguments)
end


"""Representation of special expression (i.e., anything other than `Expr(:call, ...)`)."""
struct TapeSpecialForm <: TapeExpr
    value::Any
    head::Symbol
    arguments::ArgumentTuple{TapeValue}
end



getindex(expr::TapeReference) = expr.parent.children[expr.index]


"""
    references(expr::TapeExpr) -> Vector{TapeReference}

Get the list of tape references in a `TapeExpr`, i.e., the parents in the call graph.
"""
function references end

references(expr::TapeCall) = append!(expr.f isa TapeReference ? [expr.f] : TapeReference[],
                                     (e for e in expr.arguments if e isa TapeReference))
references(expr::TapeSpecialForm) = TapeReference[e for e in expr.arguments if e isa TapeReference]
references(expr::TapeConstant) = TapeReference[]
references(expr::TapeReference) = TapeReference[expr]


getvalue(expr::TapeCall) = expr.value[]
getvalue(expr::TapeSpecialForm) = expr.value
getvalue(expr::TapeConstant) = expr.value
getvalue(expr::TapeReference) = getvalue(expr[])

