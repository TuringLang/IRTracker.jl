"""
    ArgumentNode{T} <: DataFlowNode{T}

Representation of a block (or, as a special case, function) argument in tracked IR.  `T` is the type
of the recorded value.
"""
struct ArgumentNode{T} <: DataFlowNode{T}
    "Value of the argument at the time it is encountered during recording"
    value::TapeConstant{T}

    "Branch node the argument has been assigned in for block arguments, or nothing for function arguments."
    branch_node::Union{ControlFlowNode, Nothing}

    "Number of the argument within the block arguments of the block it belongs to."
    number::Int
    
    info::NodeInfo
end


"""
    ConstantNode{T} <: DataFlowNode{T}

Representation of a constant SSA statement in tracked IR.  `T` is the type of the recorded value.
"""
struct ConstantNode{T} <: DataFlowNode{T}
    value::TapeConstant{T}
    info::NodeInfo
end


"""
    PrimitiveCallNode{T} <: DataFlowNode{T}

Representation of an SSA statement with a primitive call in tracked IR (what is primitive depends on
the tracking context used).  `T` is the type of the recorded value.
"""
struct PrimitiveCallNode{T} <: DataFlowNode{T}
    "Expression corresponding to the primitive call."
    call::TapeCall{T}
    
    info::NodeInfo
end


"""
    NestedCallNode{T} <: RecursiveNode{T}

Representation of an SSA statement consisting of a nested (non-primitive) call in tracked IR.  `T`
is the type of the recorded value.
"""
struct NestedCallNode{T} <: RecursiveNode{T}
    "Expression corresponding to the nested call."
    call::TapeCall{T}

    "Child nodes of the nested call."
    children::Vector{<:AbstractNode}
    
    info::NodeInfo
end


"""
    SpecialCallNode <: DataFlowNode

Representation of an SSA statement consisting of a special call in tracked IR.  `T` is the type of
the recorded value.
"""
struct SpecialCallNode{T} <: DataFlowNode{T}
    "Expression corresponding to the special call."
    form::TapeSpecialForm{T}
    
    info::NodeInfo
end


"""
    ReturnNode <: ControlFlowNode

Representation of a return branch in tracked IR.  
"""
struct ReturnNode <: ControlFlowNode
    "Returned value."
    argument::TapeValue
    
    info::NodeInfo
end


"""
    JumpNode <: ControlFlowNode

Representation of a conditional or unconditional jump in tracked IR.
"""
struct JumpNode <: ControlFlowNode
    "Block number of the target of the jump."
    target::Int

    "Arguments of the branch the jump corresponds to."
    arguments::ArgumentTuple{TapeValue}

    "Condition of an conditional jump, or `true` in case of an unconditional one."
    condition::TapeValue
    
    info::NodeInfo
end
