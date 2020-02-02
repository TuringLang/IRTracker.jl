using LightGraphs
using MetaGraphs
import Base: convert

include("graphviz.jl")
using .GraphViz



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




function remember_node!(node, node_indices)
    ix = length(node_indices) + 1
    node_indices[node] = GraphViz.NodeID(string(ix))
    return ix
end

function push_datarefs!(stmts, node_indices, node)
    node_id = node_indices[node]

    for (arg, referenced) in referenced(node, Union{Preceding, Parent}; numbered = true)
        referenced_id = node_indices[referenced]
        referenced_link = GraphViz.Edge([node_id, referenced_id],
                                        style = "solid", label = string(arg),
                                        constrained = "false")
        push!(stmts, referenced_link)
    end
    
    return stmts
end

function push_parentref!(stmts, node_indices, node, parent)
    node_id = node_indices[node]
    parent_id = node_indices[parent]
    parent_link = GraphViz.Edge([node_id, parent_id],
                       style = "dotted")
    return push!(stmts, parent_link)
end

push_children!(stmts, node_indices, ::AbstractNode) = stmts

function push_children!(stmts, node_indices, node::NestedCallNode)
    child_stmts = Vector{GraphViz.Statement}()
    for child in getchildren(node)
        push_node!(child_stmts, node_indices, child)
        push_datarefs!(child_stmts, node_indices, child)
        push_parentref!(child_stmts, node_indices, child, node)
        push_children!(child_stmts, node_indices, child)
    end
    cluster = GraphViz.Cluster(node_indices[node].name, child_stmts)
    return push!(stmts, cluster)
end

function push_node!(stmts, node_indices, node::AbstractNode)
    node_vertex = remember_node!(node, node_indices)
    expr = escape_string(split(string(node), " =")[1])
    stmt = GraphViz.Node(string(node_vertex),
                         label = expr,
                         shape = "plaintext")
    return push!(stmts, stmt)
end

function convert(::Type{GraphViz.Graph}, root::NestedCallNode)
    stmts = Vector{GraphViz.Statement}()
    node_indices = Dict{AbstractNode, GraphViz.NodeID}()

    push_node!(stmts, node_indices, root)
    push_children!(stmts, node_indices, root)
    
    graph_attrs = Dict(:ordering => "in",    # edges sorted by incoming
                       :rankdir => "BT",     # order nodes from right to left
                       :compound => "true",  # allow edges between clusters
                       )
    
    return GraphViz.DiGraph(stmts, graph_attrs = graph_attrs)
end
