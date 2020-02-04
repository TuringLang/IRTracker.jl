import Base: convert, getindex


"""
    TapeExpr{T}

Abstract supertype of representations of an expression in an IR statement when tracked in a node.
Contains a reified form of the original and the value obtained during execution (i.e., forward
mode).  `T` is the type of the value of the statement.
"""
abstract type TapeExpr{T} end


"""
    TapeValue{T}

Abstract supertype of [`TapeExpr`](@ref)s that represents a simple value (i.e., constants or
references).
"""
abstract type TapeValue{T} <: TapeExpr{T} end


"""
    TapeExpr{T}

Abstract supertype of [`TapeExpr`](@ref)s that contain a non-simple value (i.e., calls or special 
calls).
"""
abstract type TapeForm{T} <: TapeExpr{T} end


"""
    TapeReference{T} <: TapeValue{T}

Tape representation of an SSA variable reference of type `T`.  References a child node of a
`NestedCallNode`; like the indices of a Wengert list.  Behaves like `Ref` (i.e., you can get the
referenced node of `r` by `r[]`).
"""
struct TapeReference{T} <: TapeValue{T}
    referenced::DataFlowNode{T}
    index::Int
end

getindex(expr::TapeReference{T}) where {T} = expr.referenced


"""
    TapeConstant{T} <: TapeValue{T}

Tape representation of a constant value of type `T`
"""
struct TapeConstant{T} <: TapeValue{T}
    value::T
end


"""
    TapeCall{T} <: TapeExpr{T}

Tape representation of a normal function call with result type `T`.

The arguments of the function call are split into normal `arguments` and `varargs`, since varargs
calls need to be handled specially in the graph API.
"""
struct TapeCall{T} <: TapeExpr{T}
    value::T
    f::TapeValue
    arguments::ArgumentTuple{TapeValue}
    varargs::Union{ArgumentTuple{TapeValue}, Nothing}
end

TapeCall(value::T, f::TapeValue, arguments::ArgumentTuple{TapeValue}) where {T} =
    TapeCall{T}(value, f, arguments, nothing)


"""
    TapeCall{T} <: TapeExpr{T}

Tape representation of special expression (i.e., anything other than `Expr(:call, ...)`) with
result type `T`.
"""
struct TapeSpecialForm{T} <: TapeExpr{T}
    value::T
    head::Symbol
    arguments::ArgumentTuple{TapeValue}
end




"""
    references(expr::TapeExpr; numbered = false) -> Vector{TapeReference}

Get the list of tape references in a `TapeExpr`, i.e., the parents in the call graph.

If `numbered` is `true`, will return `Pair{Int, TapeReference}` for each reference with its
position within the expression.
"""
function references end


_contents(expr::TapeCall) = append!(append!(TapeValue[expr.f], expr.arguments),
                                    something(expr.varargs, TapeValue[]))
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


getvalue(expr::TapeCall) = expr.value
getvalue(expr::TapeSpecialForm) = expr.value
getvalue(expr::TapeConstant) = expr.value
getvalue(expr::TapeReference) = getvalue(expr[])



