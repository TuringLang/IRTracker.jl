import Base: parent

"""Extra (optional) data and metadata associated with every node (mostly locations & parent node)."""
mutable struct NodeInfo
    location::IRIndex
    # slot::Core.Slot
    parent_ref::ParentRef  # because we can only set this from the parent!
    position::Union{Int, Nothing}
    metadata::Dict{Symbol, Any}
end

NodeInfo() = NodeInfo(NO_INDEX, no_parent, nothing, Dict{Symbol, Any}())
NodeInfo(location) = NodeInfo(location, no_parent, nothing, Dict{Symbol, Any}())
NodeInfo(location, parent) = NodeInfo(location, parent, nothing, Dict{Symbol, Any}())

location(info::NodeInfo) = info.location
parent(info::NodeInfo) = info.parent_ref[]
position(info::NodeInfo) = info.position
metadata(info::NodeInfo) = info.metadata
function reference(info::NodeInfo)
    if !(isnothing(info.position))
        return TapeReference(info.parent_ref, info.position)
    else
        return nothing
    end
end
