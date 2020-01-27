using LightGraphs
using MetaGraphs
import Base: convert


const DOTFormat = MetaGraphs.DOTFormat
export DOTFormat


function convert(::Type{MetaDiGraph}, root::NestedCallNode)
    mg = MetaDiGraph(SimpleDiGraph(), 0)
    last_vertex = 0

    function add_node!(node::AbstractNode)
        add_vertex!(mg)
        last_vertex += 1
        set_indexing_prop!(mg, last_vertex, :node, node)
        return last_vertex
    end

    add_node!(root)
    
    for node in query(root, Descendant)
        node_vertex = add_node!(node)

        rs = referenced(node, Union{Preceding, Parent}; numbered = true)
        for (arg, referenced) in rs
            referenced_vertex = mg[referenced, :node]
            add_edge!(mg, node_vertex, referenced_vertex,
                      Dict(:type => :reference, :arg => arg))
        end

        parent = getparent(node)
        if !isnothing(parent)
            parent_vertex = mg[parent, :node]
            add_edge!(mg, node_vertex, parent_vertex, Dict(:type => :parent))
        end
        
    end

    return mg
end

# MetaGraphs.savegraph("/tmp/graph.dot", graph, MetaGraphs.DOTFormat())
# dot /tmp/graph.dot -Tpdf -Nfontname="DejaVu Sans Mono" -Efontname="DejaVu Sans Mono" > /tmp/graph.pdf

function convert(::Type{MetaDiGraph}, root::NestedCallNode, ::DOTFormat)
    mg = MetaDiGraph(SimpleDiGraph(), 0)
    last_vertex = 0
    node_indices = Dict{AbstractNode, Int}()

    function add_node!(node::AbstractNode)
        add_vertex!(mg)
        last_vertex += 1
        node_indices[node] = last_vertex
        set_prop!(mg, last_vertex, :shape, :plaintext)
        label = escape_string(string(node))
        # truncation = collect(Iterators.take(eachindex(label), 20))
        set_prop!(mg, last_vertex, :label, split(label, " =")[1])
        return last_vertex
    end

    root_vertex = add_node!(root)
    
    for node in query(root, Descendant)
        node_vertex = add_node!(node)

        rs = referenced(node, Union{Preceding, Parent}; numbered = true)
        for (arg, referenced) in rs
            referenced_vertex = node_indices[referenced]

            add_edge!(mg, node_vertex, referenced_vertex,
                      Dict(:style => :solid, :label => arg,
                           :constraint => false))
        end

        parent = getparent(node)
        if !isnothing(parent)
            parent_vertex = node_indices[parent]
            add_edge!(mg, node_vertex, parent_vertex,
                      Dict(:style => :dotted))
        end
        
    end

    set_prop!(mg, :ordering, :in)
    set_prop!(mg, :rankdir, :RL)

    return mg
end
