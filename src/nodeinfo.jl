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

getparent(info::NodeInfo) = info.parent_ref[]
getir(info::NodeInfo) = info.original_ir
getlocation(info::NodeInfo) = info.location
getposition(info::NodeInfo) = info.position
getmetadata(info::NodeInfo) = info.metadata

setir!(info::NodeInfo, value::IRTools.IR) = (info.original_ir = value)
setlocation!(info::NodeInfo, value::IRIndex) = (info.location = value)
setposition!(info::NodeInfo, value::Int) = (info.position = value)
