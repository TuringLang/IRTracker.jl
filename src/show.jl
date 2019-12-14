import Base: show


printlevels(io::IO, mime::MIME, value, levels::Integer) = show(IOContext(io, :maxlevel => levels),
                                                              mime, value)
printlevels(io::IO, value, levels::Integer) = show(IOContext(io, :maxlevel => levels),
                                                   MIME"text/plain"(), value)
printlevels(value, levels::Integer) = printlevels(stdout, value, levels)


# INTERNAL STUFF
showvalue(io::IO, value) = show(IOContext(io, :limit => true), value)
showvalue(io::IO, value::Nothing) = show(io, value)
# showvalue(io::IO, value) = repr(value, context = IOContext(io, :limit => true, :compact => true))

function joinlimited(io::IO, values, delim)
    L = length(values)
    if L > 0
        for (i, value) in enumerate(values)
            showvalue(io, value)
            i != L && print(io, delim)
        end
    end
end

maybespace(str) = isempty(str) ? "" : " "
printlocation(io::IO, ix::IRIndex, postfixes...) = printlocation(io, "", ix, postfixes...)
printlocation(io::IO, prefix, ix::IRIndex, postfixes...) =
    print(io, "[", prefix, maybespace(prefix), ix, "]", maybespace(postfixes), postfixes...)
printlocation(io::IO, prefix, ::NoIndex, postfixes...) = 
    print(io, postfixes...)

function printmetadata(io::IO, metadata::Dict{Symbol, <:Any})
    !isempty(metadata) && print(io, "\t", "[")
    for (i, (k, v)) in enumerate(metadata)
        print(io, k, " = ")
        showvalue(io, v)
        i < length(metadata) && print(io, ", ")
    end
    !isempty(metadata) && print(io, "]")
    return nothing
end


# ACTUAL SHOW IMPLEMENTATIONS
function show(io::IO, node::ConstantNode, level = 1)
    printlocation(io, "Constant", location(node), " = ")
    showvalue(io, value(node))
    printmetadata(io, metadata(node))
end

function show(io::IO, node::PrimitiveCallNode, level = 1)
    printlocation(io, location(node), node.call, " = ")
    showvalue(io, value(node))
    printmetadata(io, metadata(node))
end

function show(io::IO, node::NestedCallNode, level = 1)
    maxlevel = get(io, :maxlevel, typemax(level))
    printlocation(io, location(node), node.call, " = ")
    showvalue(io, value(node))
    printmetadata(io, metadata(node))
end

function show(io::IO, node::SpecialCallNode, level = 1)
    printlocation(io, location(node), node.form, " = ")
    showvalue(io, value(node))
    printmetadata(io, metadata(node))
end

function show(io::IO, node::ArgumentNode, level = 1)
    printlocation(io, "Argument", location(node), "= ")
    showvalue(io, value(node))
    printmetadata(io, metadata(node))
end

function show(io::IO, node::ReturnNode, level = 1)
    printlocation(io, location(node), "return ", node.argument, " = ")
    showvalue(io, value(node.argument))
    printmetadata(io, metadata(node))
end

function show(io::IO, node::JumpNode, level = 1)
    printlocation(io, location(node), "goto §", node.target)
    L = length(node.arguments)

    if L > 0
        print(io, " (")
        for (i, argument) in enumerate(node.arguments)
            print(io, argument)
            i != L && print(io, ", ")
        end
        print(io, ")")
    end

    reason = node.condition
    if !isnothing(value(reason))
        print(io, " since ", reason)
        (reason isa TapeReference) && print(io, " == ", value(reason))
    end

    printmetadata(io, metadata(node))
end


# Recursive printing for display purposes:
function show(io::IO, mime::MIME"text/plain", node::NestedCallNode, level = 1)
    maxlevel = get(io, :maxlevel, typemax(level))
    printlocation(io, location(node), node.call, " = ")
    showvalue(io, value(node))
    printmetadata(io, metadata(node))

    if level < maxlevel
        print(io, "\n") # prevent double newlines
        for (i, child) in enumerate(node)
            print(io, "  " ^ level, "@", i, ": ")
            show(io, mime, child, level + 1)
            i < length(node) && print(io, "\n")
        end
    end
end

show(io::IO, ::MIME"text/plain", node::AbstractNode, level = 1) = show(io, node, level)


show(io::IO, index::VarIndex) = print(io, "§", index.block, ":%", index.line, "")
show(io::IO, index::BranchIndex) = print(io, "§", index.block, ":&", index.line)


show(io::IO, expr::TapeReference) = print(io, "@", expr.index)
show(io::IO, expr::TapeConstant) = (print(io, "⟨"); showvalue(io, expr.value); print(io, "⟩"))

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

# show(io::IO, info::StatementInfo)= 
    # print(io, "StatementInfo(", something(info.metadata, ""), ")")
