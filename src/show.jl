import Base: show


printlevels(io::IO, value, levels::Integer) = print(IOContext(io, :maxlevel => levels - 1), value)
printlevels(value, levels::Integer) = printlevels(stdout::IO, value, levels)

printlimited(io::IO, value) = print(IOContext(io, :limit => true), value)
printlimited(io::IO, value::Nothing) = print(io, repr(value))


function joinlimited(io::IO, values, delim)
    L = length(values)

    if L > 0
        for (i, value) in enumerate(values)
            printlimited(io, value)
            i != L && print(io, delim)
        end
    end
end


function show(io::IO, tape::GraphTape, level = 0)
    maxlevel = get(io, :maxlevel, typemax(level))
    level > maxlevel && return
    
    for (i, node) in enumerate(tape.nodes)
        print(io, " " ^ 2level, "@", i, ": ")
        show(io, node, level)
        i < length(tape.nodes) && print(io, "\n")
    end
end

function show(io::IO, node::ConstantNode, level = 0)
    print(io, "[Constant ", node.location, "] = ")
    printlimited(io, value(node))
end

function show(io::IO, node::PrimitiveCallNode, level = 0)
    print(io, "[", node.location, "] ")
    print(io, node.call, " = ")
    printlimited(io, value(node))
end

function show(io::IO, node::NestedCallNode, level = 0)
    maxlevel = get(io, :maxlevel, typemax(level))
    print(io, "[", node.location, "] ")
    print(io, node.call, " = ")
    printlimited(io, value(node))
    level < maxlevel && print(io, "\n") # prevent double newlines in limited printing
    show(io, node.subtape, level + 1)
end

function show(io::IO, node::SpecialCallNode, level = 0)
    print(io, "[", node.location, "] ")
    print(io, node.form, " = ")
    printlimited(io, value(node))
end

function show(io::IO, node::ArgumentNode, level = 0)
    print(io, "[Argument ", node.location, "] = ")
    printlimited(io, value(node))
end

function show(io::IO, node::ReturnNode, level = 0)
    print(io, "[", node.location, "] ")
    print(io, "return ", node.argument, " = ")
    printlimited(io, value(node.argument))
end

function show(io::IO, node::JumpNode, level = 0)
    print(io, "[", node.location, "] ")
    print(io, "goto §", node.target)
    L = length(node.arguments)

    if L > 0
        print(io, " (")
        for (i, argument) in enumerate(node.arguments)
            (argument isa TapeReference) && print(io, argument, " = ")
            printlimited(io, value(argument))
            i != L && print(io, ", ")
        end
        print(io, ")")
    end

    reason = value(node.condition)
    if !isnothing(reason)
        print(io, " since ", reason)
    end
end

show(io::IO, index::VarIndex) = print(io, "§", index.block, ":%", index.line, "")
show(io::IO, index::BranchIndex) = print(io, "§", index.block, ":", index.line,)

show(io::IO, expr::TapeReference) = print(io, "@", expr.index)
show(io::IO, expr::TapeConstant) = printlimited(io, expr.value)

function show(io::IO, expr::TapeCall)
    print(io, expr.f, "(")
    joinlimited(io, expr.arguments, ", ")
    print(io, ")")
end

function show(io::IO, expr::TapeSpecialForm)
    print(io, expr.head, "(")
    joinlimited(io, expr.arguments, ", ")
    print(io, ")")
end

show(io::IO, info::StatementInfo)= 
    print(io, "StatementInfo(", something(info.metadata, ""), ")")
