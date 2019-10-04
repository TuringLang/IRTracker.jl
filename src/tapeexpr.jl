import Base: getindex

"""Reference to a node of a `GraphTape`s node list; like the indices of a Wengert list."""
struct TapeReference
    tape::GraphTape
    index::Int
end

getindex(ref::TapeReference) = ref.tape[ref.index]


const TapeExpr = Any

# assumes `expr` is flat, i.e., not containing sub-expressions
references(expr::Expr) = TapeReference[e for e in expr.args if e isa TapeReference]
references(expr::TapeReference) = [expr]
references(expr) = TapeReference[]


