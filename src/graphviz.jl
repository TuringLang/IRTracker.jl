# Small GraphViz all of this stolen from catlab:
# https://github.com/epatters/Catlab.jl/blob/master/src/graphics/Graphviz.jl
# but simplified and stripped of dependencies

module GraphViz

export Expression, Statement, Attributes, Graph, DiGraph, Subgraph, Node, NodeID, Edge, pprint

# AST
#####

abstract type Expression end
abstract type Statement <: Expression end

const Attributes = Dict{Symbol, String}


struct Graph <: Expression
  name::String
  directed::Bool
  stmts::Vector{Statement}
  graph_attrs::Attributes
  node_attrs::Attributes
  edge_attrs::Attributes
end

Graph(stmts::Vector{Statement} = Statement[]; kw...) = Graph("", stmts; kw...)
Graph(name::String, stmts::Vector{Statement} = Statement[];
      graph_attrs::Attributes = Attributes(), node_attrs::Attributes = Attributes(),
      edge_attrs::Attributes = Attributes()) =
          Graph(name, false, stmts, graph_attrs, node_attrs, edge_attrs)
DiGraph(stmts::Vector{Statement} = Statement[]; kw...) = DiGraph("", stmts; kw...)
DiGraph(name::String, stmts::Vector{Statement} = Statement[];
      graph_attrs::Attributes = Attributes(), node_attrs::Attributes = Attributes(),
      edge_attrs::Attributes = Attributes()) =
    Graph(name, true, stmts, graph_attrs, node_attrs, edge_attrs)


struct Subgraph <: Statement
  name::String     # Subgraphs can be anonymous
  stmts::Vector{Statement}
  graph_attrs::Attributes
  node_attrs::Attributes
  edge_attrs::Attributes
end

Subgraph(stmts::Vector{Statement} = Statement[]; kw...) = Subgraph("", stmts; kw...)
Subgraph(name::String, stmts::Vector{Statement} = Statement[];
         graph_attrs::Attributes = Attributes(), node_attrs::Attributes = Attributes(),
         edge_attrs::Attributes = Attributes()) =
             Subgraph(name, stmts, graph_attrs, node_attrs, edge_attrs)
Cluster(name::String, stmts::Vector{Statement} = Statement[];
        graph_attrs::Attributes = Attributes(), node_attrs::Attributes = Attributes(),
        edge_attrs::Attributes = Attributes()) =
            Subgraph("cluster_" * name, stmts, graph_attrs, node_attrs, edge_attrs)


struct Node <: Statement
  name::String
  attrs::Attributes
end
Node(name::String, attrs::AbstractDict) = Node(name, Attributes(attrs))
Node(name::String; attrs...) = Node(name, attrs)

struct NodeID <: Expression
  name::String
  port::String
  anchor::String
  NodeID(name::String, port::String="", anchor::String="") = new(name, port, anchor)
end

struct Edge <: Statement
  path::Vector{NodeID}
  attrs::Attributes
end
Edge(path::Vector{NodeID}, attrs::AbstractDict) = Edge(path, Attributes(attrs))
Edge(path::Vector{NodeID}; attrs...) = Edge(path, attrs)



# Pretty-print
##############

""" 
Pretty-print the Graphviz expression
"""
pprint(expr::Expression) = pprint(stdout, expr)
pprint(io::IO, expr::Expression) = pprint(io, expr, 0)

function pprint(io::IO, graph::Graph, n::Int)
  indent(io, n)
  print(io, graph.directed ? "digraph " : "graph ")
  print(io, graph.name)
  println(io, " {")
  pprint_attrs(io, graph.graph_attrs, n+2; pre="graph", post=";\n")
  pprint_attrs(io, graph.node_attrs, n+2; pre="node", post=";\n")
  pprint_attrs(io, graph.edge_attrs, n+2; pre="edge", post=";\n")
  for stmt in graph.stmts
    pprint(io, stmt, n+2, directed=graph.directed)
    println(io)
  end
  indent(io, n)
  println(io, "}")
end

function pprint(io::IO, subgraph::Subgraph, n::Int; directed::Bool=false)
  indent(io, n)
  if isempty(subgraph.name)
    println(io, "{")
  else
    print(io, "subgraph ")
    print(io, subgraph.name)
    println(io, " {")
  end
  pprint_attrs(io, subgraph.graph_attrs, n+2; pre="graph", post=";\n")
  pprint_attrs(io, subgraph.node_attrs, n+2; pre="node", post=";\n")
  pprint_attrs(io, subgraph.edge_attrs, n+2; pre="edge", post=";\n")
  for stmt in subgraph.stmts
    pprint(io, stmt, n+2, directed=directed)
    println(io)
  end
  indent(io, n)
  print(io, "}")
end

function pprint(io::IO, node::Node, n::Int; directed::Bool=false)
  indent(io, n)
  print(io, node.name)
  pprint_attrs(io, node.attrs)
  print(io, ";")
end

function pprint(io::IO, node::NodeID, n::Int)
  print(io, node.name)
  if !isempty(node.port)
    print(io, ":")
    print(io, node.port)
  end
  if !isempty(node.anchor)
    print(io, ":")
    print(io, node.anchor)
  end
end

function pprint(io::IO, edge::Edge, n::Int; directed::Bool=false)
  indent(io, n)
  for (i, node) in enumerate(edge.path)
    if i > 1
      print(io, directed ? " -> " : " -- ")
    end
    pprint(io, node, n)
  end
  pprint_attrs(io, edge.attrs)
  print(io, ";")
end

function pprint_attrs(io::IO, attrs::Attributes, n::Int=0;
                      pre::String="", post::String="")
  if !isempty(attrs)
    indent(io, n)
    print(io, pre)
    print(io, " [")
    for (i, (key, value)) in enumerate(attrs)
      if (i > 1) print(io, ",") end
      print(io, key)
      print(io, "=")
      print(io, value)
    end
    print(io, "]")
    print(io, post)
  end
end

indent(io::IO, n::Int) = print(io, " "^n)

end #module
