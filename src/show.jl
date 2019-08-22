function show(io::IO, tape::GraphTape, level = 0)
    for (i, node) in enumerate(tape.nodes)
        print(io, " " ^ 2level, "@", i, ": ")
        show(io, node)
        print(io, "\n")
    end
end

function show(io::IO, node::Constant, level = 0)
    print(io, " " ^ 2level)
    print(io, "Constant ", repr(node.value))
end

function show(io::IO, node::PrimitiveCall, level = 0)
    print(io, " " ^ 2level)
    print(io, "(", node.index, ") ")
    print(io, node.expr, " = ", repr(node.value))
end

function show(io::IO, node::NestedCall, level = 0)
    print(io, " " ^ 2level)
    print(io, "(", node.index, ") ")
    print(io, node.expr, " = ", repr(node.value), "\n")
    show(io, node.subtape, level + 1)
end

function show(io::IO, node::SpecialStatement, level = 0)
    print(io, " " ^ 2level)
    print(io, "(", node.index, ") ")
    print(io, node.expr, " = ", repr(node.value))
end

function show(io::IO, node::Argument, level = 0)
    print(io, " " ^ 2level)
    print(io, "Argument ", node.index, " = ", repr(node.value))
end

function show(io::IO, node::Return, level = 0)
    print(io, " " ^ 2level)
    # print(io, "(", node.index, ") ")
    print(io, "return ", node.expr, " = ", repr(node.value))
end

function show(io::IO, node::Branch, level = 0)
    print(io, " " ^ 2level)
    # print(io, "(", node.index, ") ")
    print(io, "br ", node.target)
end

show(io::IO, index::StmtIndex) = print(io, "%", index.varid)
show(io::IO, index::BranchIndex) = print(io, index.block, "-", index.position)

show(io::IO, index::TapeIndex) = print(io, "@", index.id)


# function show(io::IO, node::UnconditionalBranch, level = 0)
#     print(io, " " ^ 2level)
#     print(io, "br ", node.target, " (", join(node.args, ", "), ")")
# end

# function show(io::IO, node::UnconditionalBranch, level = 0)
#     print(io, " " ^ 2level)
#     print(io, "br ", node.target, " (", join(node.args, ", "), ") unless ", node.condition)
# end
