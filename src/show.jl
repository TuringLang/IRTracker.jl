import Base: show

printlevels(io::IO, mime::MIME, value, levels::Integer) =
    show(IOContext(io, :maxlevel => levels), mime, value)
printlevels(io::IO, value, levels::Integer) =
    show(IOContext(io, :maxlevel => levels), MIME"text/plain"(), value)
printlevels(value, levels::Integer) = printlevels(stdout, value, levels)


# INTERNAL STUFF
showvalue(io::IO, value) = show(IOContext(io, :limit => true), value)
showvalue(io::IO, value::Nothing) = show(io, value)

function joindelimited(io::IO, values, delim)
    L = length(values)
    if L > 0
        for (i, value) in enumerate(values)
            showvalue(io, value)
            i != L && print(io, delim)
        end
    end
end


# DISPATCH ON PARTS OF DIFFERENT NODES
annotation(::AbstractNode) = ""
annotation(::ConstantNode) = "Const"
annotation(node::ArgumentNode) = "Arg"


function showpretext(io::IO, node::AbstractNode, postfix...)
    position = getposition(node)
    !isnothing(position) && print(io, "@", position, ":", postfix...)
end

function showpretext(io::IO, ::MIME"text/plain", node::AbstractNode, postfix...)
    position = getposition(node)
    location = getlocation(node)
    !isnothing(position) && print(io, "@", position, ":", postfix...)
    
    if !isempty(annotation(node))
        if location !== NO_INDEX
            print(io, "[", annotation(node), ":", location, "]", postfix...)
        else
            print(io, "[", annotation(node), "]", postfix...)
        end
    else
        if location !== NO_INDEX
            print(io, "[", location, "]", postfix...)
        end
    end
end



showcall(io::IO, node::ConstantNode) = nothing
showcall(io::IO, node::PrimitiveCallNode) =
    (print(io, node.call, " = "); showvalue(io, getvalue(node)))
showcall(io::IO, node::NestedCallNode) =
    (print(io, node.call, " = "); showvalue(io, getvalue(node)))
showcall(io::IO, node::SpecialCallNode) =
    (print(io, node.form, " = "); showvalue(io, getvalue(node)))

function showcall(io::IO, node::ArgumentNode)
    call_source = node.call_source
    if !isnothing(call_source)
        print(io, "@", call_source.info.position, "#", node.number, " = ")
    end
    showvalue(io, getvalue(node))
end

function showcall(io::IO, node::ReturnNode)
    if node.argument isa TapeReference
        print(io, "return ", node.argument, " = ")
        showvalue(io, getvalue(node.argument))
    else
        print(io, "return ", node.argument)
    end
end

function showcall(io::IO, node::JumpNode)
    print(io, "goto §", node.target)
    
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
    if !isnothing(getvalue(reason))
        print(io, " since ", reason)
        if reason isa TapeReference
            print(io, " == ")
            showvalue(io, getvalue(reason))
        end
    end
end


showmetadata(io::IO, prefix, node::AbstractNode) = nothing

function showmetadata(io::IO, ::MIME"text/plain", prefix, node::AbstractNode)
    metadata = getmetadata(node)
    isempty(metadata) && return nothing

    print(io, prefix, "[")
    for (i, (k, v)) in enumerate(metadata)
        print(io, k, " = ")
        showvalue(io, v)
        i < length(metadata) && print(io, ", ")
    end
    !isempty(metadata) && print(io, "]")
    return nothing
end


# ACTUAL SHOW METHODS
function show(io::IO, node::AbstractNode, level = 1)
    showpretext(io, node, " ")
    showcall(io, node)
    showmetadata(io, "\t", node)
end

function show(io::IO, mime::MIME"text/plain", node::AbstractNode, level = 1)
    showpretext(io, mime, node, " ")
    showcall(io, node)
    showmetadata(io, mime, "\t", node)
end

function show(io::IO, mime::MIME"text/plain", node::NestedCallNode, level = 1)
    # Special case: recursive printing for display purposes
    showpretext(io, mime, node, " ")
    showcall(io, node)
    showmetadata(io, mime, "\t", node)

    maxlevel = get(io, :maxlevel, typemax(level))
    if level < maxlevel
        print(io, "\n") # prevent double newlines
        children = getchildren(node)
        for (i, child) in enumerate(children)
            print(io, "  " ^ level)
            show(io, mime, child, level + 1)
            i < length(children) && print(io, "\n")
        end
    end

end


# OTHER TYPES
show(io::IO, index::VarIndex) = print(io, "§", index.block, ":%", index.line, "")
show(io::IO, index::BranchIndex) = print(io, "§", index.block, ":&", index.line)


show(io::IO, expr::TapeReference) = print(io, "@", expr.index)
show(io::IO, expr::TapeConstant) = (print(io, "⟨"); showvalue(io, expr.value); print(io, "⟩"))

function show(io::IO, expr::TapeCall)
    print(io, expr.f, "(")
    joindelimited(io, expr.arguments, ", ")

    if !isnothing(expr.varargs)
        print(io, ", (")
        joindelimited(io, expr.varargs, ", ")
        print(io, ")...")
    end
    
    print(io, ")")
end

function show(io::IO, expr::TapeSpecialForm)
    print(io, expr.head, "(")
    joindelimited(io, expr.arguments, ", ")
    print(io, ")")
end

# show(io::IO, info::StatementInfo)= 
    # print(io, "StatementInfo(", something(info.metadata, ""), ")")
