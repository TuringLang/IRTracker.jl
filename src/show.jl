function show(io::IO, tape::GraphTape, level = 0)
    for (i, node) in enumerate(tape.nodes)
        print(io, " " ^ 2level, "@", i, ": ")
        show(io, node, level + 1)
        i < length(tape.nodes) && print(io, "\n")
    end
end

function show(io::IO, node::Constant, level = 0)
    print(io, "[Constant ", node.index, "] = ", repr(node.value))
end

function show(io::IO, node::PrimitiveCall, level = 0)
    print(io, "[", node.index, "] ")
    print(io, node.expr, " = ", repr(node.value))
end

function show(io::IO, node::NestedCall, level = 0)
    print(io, "[", node.index, "] ")
    print(io, node.expr, " = ", repr(node.value), "\n")
    show(io, node.subtape, level + 1)
end

function show(io::IO, node::SpecialStatement, level = 0)
    print(io, "[", node.index, "] ")
    print(io, node.expr, " = ", repr(node.value))
end

function show(io::IO, node::Argument, level = 0)
    print(io, "[Argument ", node.index, "] = ", repr(node.value))
end

function show(io::IO, node::Return, level = 0)
    print(io, "[", node.index, "] ")
    print(io, "return ", node.expr, " = ", repr(node.value))
end

function show(io::IO, node::Branch, level = 0)
    print(io, "[", node.index, "] ")
    print(io, "goto §", node.target)

    if length(node.arg_exprs) > 0
        arguments = map(node.arg_exprs, node.arg_values) do e, v
            (e isa IRTools.Variable) ?  "$e = $v" : repr(v)
        end
        print(io, " (")
        join(io, arguments, ", ")
        print(io, ")")
    end

    if !isnothing(node.condition_expr)
        print(io, " since ", node.condition_expr)
    end
end

show(io::IO, index::VarIndex) = print(io, "§", index.block, ":%", index.id, "")
show(io::IO, index::BranchIndex) = print(io, "§", index.block, ":", index.id,)

show(io::IO, index::TapeIndex) = print(io, "@", index.id)


# function show(io::IO, node::UnconditionalBranch, level = 0)
#     print(io, " " ^ 2level)
#     print(io, "br ", node.target, " (", join(node.args, ", "), ")")
# end

# function show(io::IO, node::UnconditionalBranch, level = 0)
#     print(io, " " ^ 2level)
#     print(io, "br ", node.target, " (", join(node.args, ", "), ") unless ", node.condition)
# end
