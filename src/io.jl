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
        
        for (arg, dependency) in referenced(node; numbered = true)
            @show dependency
            parent_vertex = mg[dependency, :node]
            add_edge!(mg, node_vertex, parent_vertex, :arg, arg)
        end
    end

    return mg
end
