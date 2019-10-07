using IRTools
import Base: collect, eltype, iterate, length, size
import Base: firstindex, getindex, lastindex
import Base: push!


"""
Tape of data and control flow of evaluated IR.  Essentially, a list of 
(potentially nested) `Node`s, like a recursive Wengert list
"""
struct GraphTape
    """The methods original IR, to which the `IRIndex`es in `nodes` refer to."""
    original_ir::IRTools.IR
    """Vector of recorded IR statements, as nodes in the computation graph (like in a Wengert list)"""
    nodes::Vector{<:Node}
end

GraphTape(ir::IRTools.IR) = GraphTape(ir, Node[])


iterate(tape::GraphTape) = iterate(tape.nodes)
iterate(tape::GraphTape, state) = iterate(tape.nodes, state)
eltype(tape::GraphTape) = Node
length(tape::GraphTape) = length(tape.nodes)
size(tape::GraphTape) = size(tape.nodes)
collect(tape::GraphTape) = collect(tape.nodes)
iterate(rTape::Iterators.Reverse{GraphTape}) = iterate(Iterators.reverse(rTape.itr.nodes))
iterate(rTape::Iterators.Reverse{GraphTape}, state) = iterate(Iterators.reverse(rTape.itr.nodes), state)

getindex(tape::GraphTape, i) = tape.nodes[i]
firstindex(tape::GraphTape) = firstindex(tape.nodes)
lastindex(tape::GraphTape) = lastindex(tape.nodes)

push!(tape::GraphTape, node::Node) = (push!(tape.nodes, node); tape)

function backward(f!, tape::GraphTape)
    for node in Iterators.reverse(tape)
        f!(node, parents(node))
    end
end
