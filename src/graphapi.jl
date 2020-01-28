using IRTools
import Base: firstindex, getindex, lastindex


####################################################################################################
# General graph query API, modelled after XPath axes, see:
# https://developer.mozilla.org/en-US/docs/Web/XPath/Axes

abstract type Axis end

abstract type Forward <: Axis end
abstract type Reverse <: Axis end

struct Parent <: Reverse end
struct Child <: Forward end
struct Preceding <: Reverse end # corresponding to preceding-sibling
struct Following <: Forward end # corresponding to following-sibling
struct Ancestor <: Reverse end
struct Descendant <: Forward end


query(node::AbstractNode, ::Type{Parent}) = getparent(node)

query(node::AbstractNode, ::Type{Child}) = Vector{AbstractNode}()
query(node::NestedCallNode, ::Type{Child}) = getchildren(node)

function query(node::AbstractNode, ::Type{Following})
    parent = query(node, Parent)
    if isnothing(parent)
        return Vector{AbstractNode}()
    else
        return @view parent.children[(getposition(node) + 1):end]
    end
end

function query(node::AbstractNode, ::Type{Preceding})
    parent = query(node, Parent)
    if isnothing(parent)
        return Vector{AbstractNode}()
    else
        return @view parent.children[1:(getposition(node) - 1)]
    end
end

function query(node::AbstractNode, ::Type{Ancestor})
    ancestors = Vector{AbstractNode}()
    current = query(node, Parent)
    while !isnothing(current)
        push!(ancestors, current)
        current = query(current, Parent)
    end

    return ancestors
end

function query(node::AbstractNode, ::Type{Descendant})
    descendants = copy(query(node, Child))
    first_unhandled = 1

    while first_unhandled ≤ length(descendants)
        for descendant in @view descendants[first_unhandled:end]
            append!(descendants, query(descendant, Child))
            first_unhandled += 1
        end
    end
    
    return descendants
end


####################################################################################################
# Accessor functions based on Query API, and specialized queries; node properties and metadata

"""
    getchildren(node) -> Vector{<:AbstractNode}

Return all sub-nodes of this node (only none-empty if `node` is a `NestedCallNode`).
"""
getchildren(node::NestedCallNode) = node.children
getchildren(node::AbstractNode) = Vector{AbstractNode}()

"""
    getparent(node) -> Union{Nothing, NestedCallNode}

Return the `NestedNode` `node` is a child of (the root call has no parent).
"""
getparent(node::AbstractNode) = getparent(node.info)


"""
    getarguments(node) -> Vector{ArgumentNode}

Return the sub-nodes representing the arguments of a nested call.
"""
getarguments(node::AbstractNode) =
    [child for child in node.children if child isa ArgumentNode && isnothing(child.branch_node)]


# Make child nodes accessible by indexing
getindex(node::NestedCallNode, i) = node.children[i]
firstindex(node::NestedCallNode) = firstindex(node.children)
lastindex(node::NestedCallNode) = lastindex(node.children)


"""Return the IR index into the original IR statement, which `node` was recorded from."""
getlocation(node::AbstractNode) = getlocation(node.info)

"""Return the index of `node` in its parent node."""
getposition(node::AbstractNode) = getposition(node.info)

"""
Return the original IR this node was recorded from.  `original_ir(node)[location(node)]` will
return the precise statement.
"""
getir(node::AbstractNode) = getir(node.info)

getvalue(::JumpNode) = nothing
getvalue(::ReturnNode) = nothing
getvalue(node::SpecialCallNode) = getvalue(node.form)
getvalue(node::NestedCallNode) = getvalue(node.call)
getvalue(node::PrimitiveCallNode) = getvalue(node.call)
getvalue(node::ConstantNode) = getvalue(node.value)
getvalue(node::ArgumentNode) = getvalue(node.value)

getmetadata(node::AbstractNode) = getmetadata(node.info)

getmetadata(node::AbstractNode, key::Symbol) = getmetadata(node)[key]
getmetadata(node::AbstractNode, key::Symbol, default) = get(getmetadata(node), key, default)
getmetadata(f, node::AbstractNode, key::Symbol) = get(f, getmetadata(node), key)

getmetadata!(node::AbstractNode, key::Symbol, default) = get!(getmetadata(node), key, default)
getmetadata!(f, node::AbstractNode, key::Symbol) = get!(f, getmetadata(node), key)

setmetadata!(node::AbstractNode, key::Symbol, value) = getmetadata(node)[key] = value


parentbranch(node::ArgumentNode) = isnothing(node.branch_node) ? getparent(node) : node.branch_node

####################################################################################################
# Data dependency analysis

_contents(node::JumpNode) = push!(collect(node.arguments), node.condition)
_contents(node::ReturnNode) = TapeValue[node.argument]
_contents(node::SpecialCallNode) = _contents(node.form)
_contents(node::NestedCallNode) = _contents(node.call)
_contents(node::PrimitiveCallNode) = _contents(node.call)
_contents(node::ConstantNode) = _contents(node.value)
_contents(node::ArgumentNode) = TapeValue[]


function _branchargument(branch::JumpNode, argument_number::Int)
    return branch.arguments[argument_number]
end

function _parentarguments(parent::NestedCallNode, argument_number::Int)
    # 1 -- function, 2..(N+1) -- normal arguments, (N+2) -- varargs
    if argument_number == 1
        return TapeValue[parent.call.f]
    elseif 2 ≤ argument_number ≤ length(parent.call.arguments) + 1
        return TapeValue[parent.call.arguments[argument_number - 1]]
    elseif argument_number == length(parent.call.arguments) + 2
        return collect(parent.call.varargs::ArgumentTuple{TapeValue})
    else
        error(parent, "has not argument with number ", argument_number)
    end
end


"""
    referenced(node[, axis]; numbered = false) -> Vector{<:AbstractNode}

Return all nodes that `node` references; i.e., all data it immediately depends on.
"""
function referenced(node::AbstractNode, ::Type{T} = Preceding;
                    numbered::Bool = false) where {T<:Reverse}
    if numbered
        return numbered_referenced(node, T)
    else
        return unnumbered_referenced(node, T)
    end
end

for variant in (:numbered, :unnumbered)
    referenced_variant = Symbol(variant, "_referenced")
    references_variant = Symbol(variant, "_references")

    # deref is a hack to get type inference right here -- if we factor it out into a function
    # and broadcast it, the result is Vector{Union{}}.
    
    local Result_variant, deref
    if variant == :numbered
        Result_variant = :(Pair{Int, AbstractNode})
        deref = :(ref.first => ref.second[])
    else
        Result_variant = :(AbstractNode)
        deref = :(ref[])
    end

    
    @eval begin
        # PRECEDING
        function $referenced_variant(node::JumpNode, ::Type{Preceding})
            refs = mapfoldl($references_variant, append!, node.arguments,
                            init = $references_variant(node.condition))
            return $Result_variant[$deref for ref in refs]
        end
        $referenced_variant(node::ReturnNode, ::Type{Preceding}) =
            $Result_variant[$deref for ref in $references_variant(node.argument)]
        $referenced_variant(node::SpecialCallNode, ::Type{Preceding}) =
            $Result_variant[$deref for ref in $references_variant(node.form)]
        $referenced_variant(node::NestedCallNode, ::Type{Preceding}) =
            $Result_variant[$deref for ref in $references_variant(node.call)]
        $referenced_variant(node::PrimitiveCallNode, ::Type{Preceding}) =
            $Result_variant[$deref for ref in $references_variant(node.call)]
        $referenced_variant(::ConstantNode, ::Type{Preceding}) = Vector{$Result_variant}()
        function $referenced_variant(node::ArgumentNode, ::Type{Preceding})
            parent_branch = parentbranch(node)
            if parent_branch isa NestedCallNode
                # non-branch arguments have no preceding nodes
                return Vector{$Result_variant}()
            else
                branch_argument = _branchargument(node.branch_node, node.number)
                refs = $references_variant(branch_argument)
                return $Result_variant[$deref for ref in refs]
            end
        end

        # PARENT
        $referenced_variant(node::AbstractNode, ::Type{Parent}) = Vector{$Result_variant}()
        function $referenced_variant(node::ArgumentNode, ::Type{Parent}; numbered::Bool = false)
            parent_branch = parentbranch(node)
            if parent_branch isa NestedCallNode
                parent_arguments = _parentarguments(parent_branch, node.number)
                refs = mapfoldl($references_variant, append!, parent_arguments)
                return $Result_variant[$deref for ref in refs]
            else
                # branch arguments have no parent references
                return Vector{$Result_variant}()
            end
        end

        # UNION{PRECEDING, PARENT}}
        $referenced_variant(node::AbstractNode, ::Type{Union{Preceding, Parent}}) =
            $referenced_variant(node, Preceding)
        $referenced_variant(node::ArgumentNode, ::Type{Union{Preceding, Parent}}) =
            $referenced_variant(node, Parent)
    end
end



"""
    backward(node[, axis]) -> Vector{AbstractNode}
    backward(f, node[, axis])

Traverse references backward in `axis` order (default: `Preceding`).  By default, `union` all nodes
onto an array.  If `f` is given, the current node and its references are passed in for every node of
which `node` is a data dependecy, and you can do arbitrary things to it.
"""
function backward(node::AbstractNode, axis::Type{<:Reverse} = Preceding)
    result = Vector{AbstractNode}()
    return backward(node, axis) do node, refs
        union!(result, refs)
    end
end

function backward(f, node::AbstractNode, axis::Type{<:Reverse} = Preceding)
    current_refs = Vector{AbstractNode}(referenced(node, axis))
    result = f(node, current_refs)
    
    while !isempty(current_refs)
        node = pop!(current_refs)
        new_refs = referenced(node, axis)
        result = f(node, new_refs)
        union!(current_refs, new_refs)
    end

    return result
end


"""
    dependents(node) -> Vector{<:AbstractNode}

Return all nodes that reference `node`; i.e., all data that immediately depends on it.
"""
function dependents(node::AbstractNode)
    return [f for f in query(node, Following) if node in referenced(f, Preceding)]
    # or: filter(f -> (node in references(f, Preceding))::Bool, query(node, Following))
    # an instance of https://github.com/JuliaLang/julia/issues/28889
end



"""
    forward(node) -> Vector{AbstractNode}
    forward(f, node)

Traverse dependencies forward.  By default, `union` all nodes onto an array.  If `f` is given, the
current node and its dependents are passed in for every node is a data dependecy of `node`, and you
can do arbitrary things to it.
"""
function forward(node::AbstractNode)
    result = Vector{AbstractNode}()
    return forward(node) do node, deps
        union!(result, deps)
    end
end

function forward(f, node::AbstractNode)
    current_deps = Vector{AbstractNode}(dependents(node))
    result = f(node, current_deps)
    
    while !isempty(current_deps)
        node = pop!(current_deps)
        new_deps = dependents(node)
        result = f(node, new_deps)
        union!(current_deps, new_deps)
    end

    return result
end








