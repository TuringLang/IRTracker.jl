using LightGraphs
using MetaGraphs
import Base: convert


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

        @show node
        rs = referenced(node, Union{Preceding, Parent}; numbered = true)
        @show rs
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
