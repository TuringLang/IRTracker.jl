import Base: convert, getindex

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

convert(::Type{TapeReference}, node::AbstractNode) =
    TapeReference(node.info.parent_ref[], node.info.position)


"""
    references(expr::TapeExpr; numbered = false) -> Vector{TapeReference}

Get the list of tape references in a `TapeExpr`, i.e., the parents in the call graph.

If `numbered` is `true`, will return `Pair{Int, TapeReference}` for each reference with its
position within the expression.
"""
function references end


_contents(expr::TapeCall) = append!(TapeValue[expr.f], expr.arguments)
_contents(expr::TapeSpecialForm) = collect(expr.arguments)
_contents(expr::TapeConstant) = TapeValue[expr]
_contents(expr::TapeReference) = TapeValue[expr]

unnumbered_references(expr::TapeExpr) =
    TapeReference[e for e in _contents(expr) if e isa TapeReference]
numbered_references(expr::TapeExpr) =
    Pair{Int, TapeReference}[i => e for (i, e) in enumerate(_contents(expr)) if e isa TapeReference]
function references(expr::TapeExpr; numbered::Bool = false)
    if numbered
        return numbered_references(expr)
    else
        return unnumbered_references(expr)
    end
end


# references(expr::TapeCall) = append!(expr.f isa TapeReference ? [expr.f] : TapeReference[],
                                     # (e for e in expr.arguments if e isa TapeReference))
# references(expr::TapeSpecialForm) = TapeReference[e for e in expr.arguments if e isa TapeReference]
# references(expr::TapeConstant) = TapeReference[]
# references(expr::TapeReference) = TapeReference[expr]


getvalue(expr::TapeCall) = expr.value[]
getvalue(expr::TapeSpecialForm) = expr.value
getvalue(expr::TapeConstant) = expr.value
getvalue(expr::TapeReference) = getvalue(expr[])



