import IRTools


"""
    NodeInfo

Extra (optional) data and metadata associated with every node (mostly locations & parent node).
"""
mutable struct NodeInfo
    "Original IR a node was recorded from."
    original_ir::Union{IRTools.IR, Nothing}

    "Corresponding IR location of the node."
    location::IRIndex

    "Parent of this node (i.e., the `NestedCallNode` it is stored within)."
    parent_ref::NullableRef{RecursiveNode}  # because we can only set this from the parent!

    "Position of the node within the parent node."
    position::Union{Int, Nothing}

    "Arbitrary metadata that can be used by contexts."
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
