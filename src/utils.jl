using IRTools
import Base: getproperty, getindex

struct _DCGCall end

const DCGCall = _DCGCall()
getproperty(::_DCGCall, name::Symbol) =
    (args...) -> IRTools.xcall(DynamicComputationGraphs, name, args...)


# Unique indexing into IR

abstract type IRIndex end

struct StmtIndex <: IRIndex
    varid::Int
end

struct BranchIndex <: IRIndex
    block::Int
    position::Int
end

getindex(ir::IRTools.IR, ix::StmtIndex) = ir[IRTools.var(ix.varid)]
getindex(ir::IRTools.IR, ix::BranchIndex) = IRTools.branches(ir, ix.block)[ix.position]



function print_intrinsic_error(f::Core.IntrinsicFunction, args...)
    # from https://github.com/JuliaLang/julia/blob/c6da87ff4bc7a855e217856757ad3413cf6d1f79/base/show.jl#L398
    name = unsafe_string(ccall(:jl_intrinsic_name, Cstring, (Core.IntrinsicFunction,), f))
    error("Can't track the intrinsic function ", name, " with arguments ",
          join(args, ", "))
end



struct TapeIndex
    id::Int
end


const VarOrNewVar = Union{IRTools.Variable, IRTools.NewVariable}

struct VarToRecordDict
    old_variables::Dict{IRTools.Variable, TapeIndex}
    new_variables::Dict{VarOrNewVar, IRTools.Variable}
end

VarToRecordDict() = VarToRecordDict(Dict{IRTools.Variable, TapeIndex}(),
                                    Dict{VarOrNewVar, IRTools.Variable}())

record_old_variable!(d::VarToRecordDict, v::IRTools.Variable) =
    (push!(d.old_variables, v => TapeIndex(length(d.old_variables) + 1)); d)
record_new_variable!(d::VarToRecordDict, new_var::VarOrNewVar, old_var::IRTools.Variable) =
    (push!(d.new_variables, new_var => old_var); d)


reify_quote(expr) = Expr(:copyast, QuoteNode(expr))

translate_old_variable(d::VarToRecordDict, var::IRTools.Variable) = d.old_variables[var]
translate_old_variable(d::VarToRecordDict, expr::Expr) =
    Expr(expr.head, map(expr -> translate_old_variable(d, expr), expr.args)...)
translate_old_variable(::VarToRecordDict, expr) = expr

translate_new_variable(d::VarToRecordDict, var::VarOrNewVar) = d.new_variables[var]
translate_new_variable(d::VarToRecordDict, expr::Expr) =
    Expr(expr.head, map(expr -> translate_new_variable(d, expr), expr.args)...)
translate_new_variable(::VarToRecordDict, expr) = expr
