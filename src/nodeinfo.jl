import IRTools
import Base: parent

"""Extra (optional) data and metadata associated with every node (mostly locations & parent node)."""
mutable struct NodeInfo
    original_ir::Union{IRTools.IR, Nothing}
    location::IRIndex
    parent_ref::NullableRef{RecursiveNode}  # because we can only set this from the parent!
    position::Union{Int, Nothing}
    metadata::Dict{Symbol, Any}
end

# NodeInfo(ir, ) = NodeInfo(ir, NO_INDEX, NullableRef{RecursiveNode}(), nothing, Dict{Symbol, Any}())
# NodeInfo(ir, location) = NodeInfo(ir, location, NullableRef{RecursiveNode}(), nothing, Dict{Symbol, Any}())
NodeInfo(ir, location, parent) = NodeInfo(ir, location, parent, nothing, Dict{Symbol, Any}())

original_ir(info::NodeInfo) = info.original_ir
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
