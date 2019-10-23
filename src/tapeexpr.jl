import Base: getindex

abstract type TapeExpr end
abstract type TapeValue <: TapeExpr end
abstract type TapeForm <: TapeExpr end


"""Reference to a node of a `GraphTape`s node list; like the indices of a Wengert list."""
struct TapeReference <: TapeValue
    tape::GraphTape
    index::Int
end


struct TapeConstant <: TapeValue
    value::Any
end


struct TapeCall <: TapeExpr
    value::Any
    f::TapeValue
    arguments::Vector{<:TapeValue}
end


struct TapeSpecialForm <: TapeExpr
    value::Any
    head::Symbol
    arguments::Vector{<:TapeValue}
end



getindex(ref::TapeReference) = ref.tape[ref.index]

references(expr::TapeCall) = TapeReference[e for e in expr.arguments if e isa TapeReference]
references(expr::TapeSpecialForm) = TapeReference[e for e in expr.arguments if e isa TapeReference]
references(expr::TapeConstant) = TapeReference[]
references(expr::TapeReference) = TapeReference[expr]

value(expr::TapeCall) = expr.value
value(expr::TapeSpecialForm) = expr.value
value(expr::TapeConstant) = expr.value
value(expr::TapeReference) = value(expr[])
