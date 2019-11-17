# DynamicComputationGraphs.jl

The aim of this project is to provide a graph representation suitable for dynamic models, as they
occur in probabilistic programming languages (e.g. with stochastic control flow, or model
recursion).  To implement this, I use an approach between the two traditional ideas: operator
overloading and source transformations.  The resulting data structure is an “extended Wengert list”
– a generalization of traditional Wengert lists used for backward mode AD, which 1) also records
control flow operations, 2) preserves the hierarchy of function calls by being nested, instead of
fully linearized, and 3) can carry arbitrary metadata, which is customizable by a context system
(similar to what you can do in Cassette.jl).

The representation should be able to:

- Perform the usual forward computation (without performance overhead by interpretation)
- Record expression nodes representing the calculation (raw `Expr` or something equivalent, allowing
  to convert back)
- Record meta-information from the original code, such as information about random variable types,
  conditions, etc.
- Record, if applicable, information needed for backward calculation
- The backward information in the graph should be mutable, so that one can update subgraphs without
  full re-evaluation when changing parts of a model.


## Design

My basic idea is to use a nested tape, consisting of the IR instructions of the executed code,
including control flow.  This type should be similar to a Wengert list, in that it records linearly
the statements executed during the execution of a function, but contain information about function
calls (so, more like nested Wengert lists) and metadata.

These should be possible to extract by inserting a "recording statement" after each instruction
of a given function.

If we look at a simple function with stochastic control flow, 

    geom(n, β) = rand() < β ? n : geom(n + 1, β)
    
with IR code

```
1: (%1, %2, %3)
  %4 = Main.rand()
  %5 = %4 < %3
  br 2 unless %5
  return %2
2:
  %6 = %2 + 1
  %7 = Main.geom(%6, %3)
  return %7
```

(using [IRTools](https://github.com/MikeInnes/IRTools.jl) format ), we would record a trace of
`geom(1, 0.5)` as follows, under the assumption that `rand()` returns a value greater than β the
first time and less the second time:
    
```
julia> printlevels(track(geom, 1, 0.5), 3)
geom(1, 0.5) = 2
  @1: [Argument §1:%1]  = geom
  @2: [Argument §1:%2]  = 1
  @3: [Argument §1:%3]  = 0.5
  @4: [§1:%4] rand() = 0.5800257791874384
    @1: [Argument §1:%1]  = rand
    @2: [§1:%2] @1(<some huge MersenneTwister>), Float64) = 0.5800257791874384
    @3: [§1:1] return @2 = 0.5800257791874384
  @5: [§1:%5] <(@4, @3) = false
    @1: [Argument §1:%1]  = <
    @2: [Argument §1:%2]  = 0.5800257791874384
    @3: [Argument §1:%3]  = 0.5
    @4: [§1:%4] lt_float(@2, @3) = false
    @5: [§1:1] return @4 = false
  @6: [§1:1] goto §2 since false
  @7: [§2:%6] +(@2, 1) = 2
    @1: [Argument §1:%1]  = +
    @2: [Argument §1:%2]  = 1
    @3: [Argument §1:%3]  = 1
    @4: [§1:%4] add_int(@2, @3) = 2
    @5: [§1:1] return @4 = 2
  @8: [§2:%7] geom(@7, @3) = 2
    @1: [Argument §1:%1]  = geom
    @2: [Argument §1:%2]  = 2
    @3: [Argument §1:%3]  = 0.5
    @4: [§1:%4] rand() = 0.439123904036538
    @5: [§1:%5] <(@4, @3) = true
    @6: [§1:2] return @2 = 2
  @9: [§2:1] return @8 = 2
```

(This result is expanded to only three levels, since the full output would be huge.)

Here, the indented lines indicate the "inner code" recorded in the recursive calls.  Since we record
intermediate values as well, and track data dependencies by pointers, this is equivalent to a
traditional tape used for backward mode AD, just with the control flow nodes between.

This, together with the original IR, while being a bit cryptic, contains the following information:

- Every executed statement, linked to the original.  Corresponding SSA values in the original code
  are annotated in [brackets], by their block and variable id (`§s:%i`).  Arguments, having no
  associated expressions, are prefixed with `Argument`.
- All intermediate values on the data path. They are, as all nodes, numbered as `@i`. These are
  referred to in expressions recorded, to that a backward pass is trivial.
- The branching instructions actually taken, written in literal form `goto label`.  Blocks are
  referred to by paragraph signs: `§b`.  They are annotated as well with the block they come from,
  and the position among all branch statements within that block: `[§b:position]`.
- Nested function calls and their arguments (note that the argument `%1` stands for the function itself and
  is not used most of the time).

In this form, a backward pass is as trivial as following back the references from the last `return` and adding 
adjoint values in the metadata.

The data structure used for this is an abstract `AbstractNode` type, with subtypes for:

- Arguments and constants;
- Special calls (such as `:inbounds`) and primitive calls (by default, everything which is builtin;
  or intrinsic, but this can be changed by using a context – see below);
- Nested calls, containing recursively the nodes from a non-primitive call; and
- Return and jump nodes, occuring when a branch is taken.
  

## Implementation

Constructing this kind of trace should be possible by extending the original IR by inserting a
constant number of statements before or after each original statement (and some at the beginning of
each block), somehow like this:

```
transform_ir(@code_ir geom(1, 0.5))
1: (%4, %1, %2, %3)
  %5 = GraphRecorder(1: (%1, %2, %3)
  %4 = Main.rand()
  %5 = %4 < %3
  br 2 unless %5
  return %2
2:
  %6 = %2 + 1
  %7 = Main.geom(%6, %3)
  return %7, %4)
  %6 = TapeConstant(%1)
  %7 = VarIndex(1, 1)
  %8 = Base.getfield(%5, :incomplete_node)
  %9 = NodeInfo(%7, %8)
  %10 = ArgumentNode(%6, %9)
  %11 = record!(%5, %10)
  %12 = TapeConstant(%2)
  %13 = VarIndex(1, 2)
  %14 = Base.getfield(%5, :incomplete_node)
  %15 = NodeInfo(%13, %14)
  %16 = ArgumentNode(%12, %15)
  %17 = record!(%5, %16)
  %18 = TapeConstant(%3)
  %19 = VarIndex(1, 3)
  %20 = Base.getfield(%5, :incomplete_node)
  %21 = NodeInfo(%19, %20)
  %22 = ArgumentNode(%18, %21)
  %23 = record!(%5, %22)
  %24 = Base.getfield(%5, :context)
  %25 = TapeConstant(Main.rand)
  %26 = Base.tuple()
  %27 = Base.getindex(TapeValue)
  %28 = VarIndex(1, 4)
  %29 = Base.getfield(%5, :incomplete_node)
  %30 = NodeInfo(%28, %29)
  %31 = trackcall(%24, Main.rand, %25, %26, %27, %30)
  %32 = record!(%5, %31)
  %33 = Base.getfield(%5, :context)
  %34 = TapeConstant(Main.:<)
  %35 = Base.tuple(%32, %3)
  %36 = tapeify(%5, $(QuoteNode(%4)))
  %37 = tapeify(%5, $(QuoteNode(%3)))
  %38 = Base.getindex(TapeValue, %36, %37)
  %39 = VarIndex(1, 5)
  %40 = Base.getfield(%5, :incomplete_node)
  %41 = NodeInfo(%39, %40)
  %42 = trackcall(%33, Main.:<, %34, %35, %38, %41)
  %43 = record!(%5, %42)
  %44 = Base.getindex(TapeValue)
  %45 = tapeify(%5, $(QuoteNode(%5)))
  %46 = BranchIndex(1, 1)
  %47 = Base.getfield(%5, :incomplete_node)
  %48 = NodeInfo(%46, %47)
  %49 = JumpNode(2, %44, %45, %48)
  %50 = tapeify(%5, $(QuoteNode(%2)))
  %51 = BranchIndex(1, 2)
  %52 = Base.getfield(%5, :incomplete_node)
  %53 = NodeInfo(%51, %52)
  %54 = ReturnNode(%50, %53)
  br 2 (%49) unless %43
  br 3 (%2, %54)
2: (%55)
  %56 = record!(%5, %55)
  %57 = Base.getfield(%5, :context)
  %58 = TapeConstant(Main.:+)
  %59 = Base.tuple(%2, 1)
  %60 = tapeify(%5, $(QuoteNode(%2)))
  %61 = TapeConstant(1)
  %62 = Base.getindex(TapeValue, %60, %61)
  %63 = VarIndex(2, 6)
  %64 = Base.getfield(%5, :incomplete_node)
  %65 = NodeInfo(%63, %64)
  %66 = trackcall(%57, Main.:+, %58, %59, %62, %65)
  %67 = record!(%5, %66)
  %68 = Base.getfield(%5, :context)
  %69 = TapeConstant(Main.geom)
  %70 = Base.tuple(%67, %3)
  %71 = tapeify(%5, $(QuoteNode(%6)))
  %72 = tapeify(%5, $(QuoteNode(%3)))
  %73 = Base.getindex(TapeValue, %71, %72)
  %74 = VarIndex(2, 7)
  %75 = Base.getfield(%5, :incomplete_node)
  %76 = NodeInfo(%74, %75)
  %77 = trackcall(%68, Main.geom, %69, %70, %73, %76)
  %78 = record!(%5, %77)
  %79 = tapeify(%5, $(QuoteNode(%7)))
  %80 = BranchIndex(2, 1)
  %81 = Base.getfield(%5, :incomplete_node)
  %82 = NodeInfo(%80, %81)
  %83 = ReturnNode(%79, %82)
  br 3 (%78, %83)
3: (%84, %85)
  %86 = record!(%5, %85)
  %87 = Base.tuple(%84, %5)
  return %87

```

The function `trackcall` then recursively does the same kind of thing to the nested calls.

This can be achieved by using an `IRTools` dynamo, which in essence is just a fancier generated
function, allowing one to operate with `IRTools.IR` instead of "raw" `CodeInfo`s.  In this dynamo,
the original IR is completely rebuilt to insert all necessary tracking statements.

Additionally, 

There’s some things to note:

- Branches are recorded by first creating a node for each branch in a block, then passing this as an
  extra argument to the actual branch.  The actual recording is done in the target block.  For this
  reason, all return branches are replaced by jumps to an extra “return block” at the end. 
- `trackcall`’s many arguments are just all the information needed to construct a full call node out
  of the list of recursively called nodes: the called function as value and in reified form, the
  arguments as values and in reified form, and the `NodeInfo` containing the original location and
  the parent node.
- There’s some additional runtime logic in the `trackcall` function, which determines how to
  differentiate between “primitive” and “non-primitive” calls (serving as the stopping case for the
  recursive tracking).
- The purpose of `tapeify` is to make tape references (`@i` in the output) that actually point to
  the last usage of a SSA variable (since that can happen multiple times in a loop).
  

## Contexts

Are implemented; documentation coming soon (until then, see `runtests.jl`).


## Trying it out

Currently, there are only a couple of very primitive examples in `runtests.jl`, but the interface is
simple:

    node = track(f, args...)



