import Base: print, show


printlevels(tape::GraphTape, levels) = show(stdout, tape, maxlevel = levels - 1)

function show(io::IO, tape::GraphTape, level = 0; maxlevel = typemax(level))
    level > maxlevel && return
    for (i, node) in enumerate(tape.nodes)
        print(io, " " ^ 2level, "@", i, ": ")
        show(io, node, level; maxlevel = maxlevel)
        i < length(tape.nodes) && print(io, "\n")
    end
end

function show(io::IO, node::Constant, level = 0; maxlevel = typemax(level))
    print(io, "[Constant ", node.index, "] = ", repr(node.value))
end

function show(io::IO, node::PrimitiveCall, level = 0; maxlevel = typemax(level))
    print(io, "[", node.index, "] ")
    print(io, node.expr, " = ", repr(node.value))
end

function show(io::IO, node::NestedCall, level = 0; maxlevel = typemax(level))
    print(io, "[", node.index, "] ")
    print(io, node.expr, " = ", repr(node.value))
    level < maxlevel && print(io, "\n") # prevent double newlines in limited printing
    show(io, node.subtape, level + 1; maxlevel = maxlevel)
end

function show(io::IO, node::SpecialStatement, level = 0; maxlevel = typemax(level))
    print(io, "[", node.index, "] ")
    print(io, node.expr, " = ", repr(node.value))
end

function show(io::IO, node::Argument, level = 0; maxlevel = typemax(level))
    print(io, "[Argument ", node.index, "] = ", repr(node.value))
end

function show(io::IO, node::Return, level = 0; maxlevel = typemax(level))
    print(io, "[", node.index, "] ")
    print(io, "return ", node.expr, " = ", repr(node.value))
end

function show(io::IO, node::Branch, level = 0; maxlevel = typemax(level))
    print(io, "[", node.index, "] ")
    print(io, "goto §", node.target)

    if length(node.arg_exprs) > 0
        print(io, " (")
        for (expr, value) in zip(node.arg_exprs, node.arg_values) 
           (expr isa IRTools.Variable) && print(io, expr, " = ")
            print(io, repr(value))
        end
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
