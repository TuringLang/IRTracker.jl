import Base: show


printlevels(tape::GraphTape, levels) = show(IOContext(stdout, :maxlevel => levels - 1), tape)
printlevels(node::Node, levels) = show(IOContext(stdout, :maxlevel => levels - 1), node)

printvalue(io, value) = print(IOContext(io, :limit => true), value)
printvalue(io, n::Nothing) = print(io, repr(n))

function show(io::IO, tape::GraphTape, level = 0)
    maxlevel = get(io, :maxlevel, typemax(level))
    level > maxlevel && return
    
    for (i, node) in enumerate(tape.nodes)
        print(io, " " ^ 2level, "@", i, ": ")
        show(io, node, level)
        i < length(tape.nodes) && print(io, "\n")
    end
end

function show(io::IO, node::Constant, level = 0)
    print(io, "[Constant ", node.index, "] = ")
    printvalue(io, node.value)
end

function show(io::IO, node::PrimitiveCall, level = 0)
    print(io, "[", node.index, "] ")
    print(io, node.expr, " = ")
    printvalue(io, node.value)
end

function show(io::IO, node::NestedCall, level = 0)
    maxlevel = get(io, :maxlevel, typemax(level))
    print(io, "[", node.index, "] ")
    print(io, node.expr, " = ")
    printvalue(io, node.value)
    level < maxlevel && print(io, "\n") # prevent double newlines in limited printing
    show(io, node.subtape, level + 1)
end

function show(io::IO, node::SpecialStatement, level = 0)
    print(io, "[", node.index, "] ")
    print(io, node.expr, " = ")
    printvalue(io, node.value)
end

function show(io::IO, node::Argument, level = 0)
    print(io, "[Argument ", node.index, "] = ")
    printvalue(io, node.value)
end

function show(io::IO, node::Return, level = 0)
    print(io, "[", node.index, "] ")
    print(io, "return ", node.expr, " = ")
    printvalue(io, node.value)
end

function show(io::IO, node::Branch, level = 0)
    print(io, "[", node.index, "] ")
    print(io, "goto §", node.target)
    L = length(node.arg_exprs) 

    if L > 0
        print(io, " (")
        for (expr, value, i) in zip(node.arg_exprs, node.arg_values, 1:L)
            (expr isa TapeReference) && print(io, expr, " = ")
            printvalue(io, value)
            i != L && print(io, ", ")
        end
        print(io, ")")
    end

    if !isnothing(node.condition_expr)
        print(io, " since ", node.condition_expr)
    end
end

show(io::IO, index::VarIndex) = print(io, "§", index.block, ":%", index.id, "")
show(io::IO, index::BranchIndex) = print(io, "§", index.block, ":", index.id,)

show(io::IO, ref::TapeReference) = print(io, "@", ref.index)

show(io::IO, info::StatementInfo)= 
    print(io, "StatementInfo(", something(info.metadata, ""), ")")
