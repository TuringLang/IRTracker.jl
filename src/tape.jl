import Base: push!


export GraphTape

"""Record of data and control flow of evaluating IR."""
struct GraphTape <: AbstractGraphTape
    nodes::Vector{<:Node}
end

GraphTape() = GraphTape(Node[])

push!(tape::GraphTape, node::Node) = push!(tape.nodes, node)
