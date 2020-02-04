using LightGraphs
using MetaGraphs

import Base: convert
import MetaGraphs: savedot

include("graphviz.jl")
using .GraphViz


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


function convert(::Type{GraphViz.Graph}, root::NestedCallNode)
    stmts = Vector{GraphViz.Statement}()
    node_indices = Dict{AbstractNode, GraphViz.NodeID}()

    push_node!(stmts, node_indices, root)
    push_children!(stmts, node_indices, root)
    
    graph_attrs = Dict(:ordering => "in",    # edges sorted by incoming
                       :rankdir => "BT",     # order nodes from right to left
                       :compound => "true",  # allow edges between clusters
                       )
    edge_attrs = Dict(:style => "invis")
    node_attrs = Dict(:shape => "plaintext")
    
    return GraphViz.DiGraph(stmts, graph_attrs = graph_attrs, edge_attrs = edge_attrs,
                            node_attrs = node_attrs)
end


# dot /tmp/graph.dot -Tpdf -Nfontname="DejaVu Sans Mono" -Efontname="DejaVu Sans Mono" > /tmp/graph.pdf

"""
    savedot(fn, node)

Save a textual representation of `node` in file named `fn`, using the GraphViz format.  Optimized
to result in a somewhat readable representation of nested calls.
"""
function savedot(fn::AbstractString, node::NestedCallNode)
    open(fn, "w") do fp
        GraphViz.pprint(fp, convert(GraphViz.Graph, node))
    end
end

######### Details for GraphViz conversion #########################

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
                                        style = "solid", label = "#" * string(arg),
                                        constraint = "false")
        push!(stmts, referenced_link)
    end
    
    return stmts
end

push_children!(stmts, node_indices, ::AbstractNode) = stmts

function push_children!(stmts, node_indices, parent::NestedCallNode)
    child_stmts = Vector{GraphViz.Statement}()
    dataref_stmts = Vector{GraphViz.Statement}()
    for child in getchildren(parent)
        push_node!(child_stmts, node_indices, child)
        push_children!(child_stmts, node_indices, child)
        push_datarefs!(dataref_stmts, node_indices, child)
    end

    parent_id = node_indices[parent]
    cluster_name = "cluster_" * parent_id.name

    # cluster of child nodes
    push!(stmts, GraphViz.Subgraph(cluster_name, child_stmts,
                                   graph_attrs = Dict(:label => string(parent.call.f))))

    # invisible nodes to ensure top-down ordering of child nodes
    children_ids = [node_indices[c] for c in reverse(getchildren(parent))]
    push!(stmts, GraphViz.Edge(children_ids, group = parent_id.name))

    # edge from cluster to parent node
    push!(stmts, GraphViz.Edge([children_ids[end], parent_id],
                               ltail = cluster_name,
                               style = "dotted"))
    # finally, append actual data references
    return append!(stmts, dataref_stmts)
end

function push_node!(stmts, node_indices, node::AbstractNode)
    node_vertex = remember_node!(node, node_indices)
    expr = escape_string(split(string(node), " =")[1])
    stmt = GraphViz.Node(string(node_vertex),
                         label = expr)
    return push!(stmts, stmt)
end



