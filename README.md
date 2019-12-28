# DynamicComputationGraphs.jl

[![Build Status](https://travis-ci.org/phipsgabler/DynamicComputationGraphs.jl.svg?branch=master)](https://travis-ci.org/phipsgabler/DynamicComputationGraphs.jl)

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
⟨geom⟩(⟨1⟩, ⟨0.5⟩) = 3
  @1: [Argument §1:%1] = geom
  @2: [Argument §1:%2] = 1
  @3: [Argument §1:%3] = 0.5
  @4: [§1:%4] ⟨rand⟩() = 0.5649805445318339
    @1: [Argument §1:%1] = rand
    @2: [§1:%2] @1(⟨some huge Mersenne twister constant⟩, ⟨Float64⟩) = 0.5649805445318339
    @3: [§1:&1] return @2 = 0.5649805445318339
  @5: [§1:%5] ⟨<⟩(@4, @3) = false
    @1: [Argument §1:%1] = <
    @2: [Argument §1:%2] = 0.5649805445318339
    @3: [Argument §1:%3] = 0.5
    @4: [§1:%4] ⟨lt_float⟩(@2, @3) = false
    @5: [§1:&1] return @4 = false
  @6: [§1:&1] goto §2 since @5 == false
  @7: [§2:%6] ⟨+⟩(@2, ⟨1⟩) = 2
    @1: [Argument §1:%1] = +
    @2: [Argument §1:%2] = 1
    @3: [Argument §1:%3] = 1
    @4: [§1:%4] ⟨add_int⟩(@2, @3) = 2
    @5: [§1:&1] return @4 = 2
  @8: [§2:%7] ⟨geom⟩(@7, @3) = 3
    @1: [Argument §1:%1] = geom
    @2: [Argument §1:%2] = 2
    @3: [Argument §1:%3] = 0.5
    @4: [§1:%4] ⟨rand⟩() = 0.9938271839338844
    @5: [§1:%5] ⟨<⟩(@4, @3) = false
    @6: [§1:&1] goto §2 since @5 == false
    @7: [§2:%6] ⟨+⟩(@2, ⟨1⟩) = 3
    @8: [§2:%7] ⟨geom⟩(@7, @3) = 3
    @9: [§2:&1] return @8 = 3
  @9: [§2:&1] return @8 = 3
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
  and the position among all branch statements within that block: `[§b:&position]`.
- Nested function calls and their arguments (note that the argument `%1` stands for the function itself and
  is not used most of the time).
- Constants (literals in the expressions) are written in ⟨angle brackets⟩ (this makes debugging the
  transformed code easier).

In this form, a backward pass is as trivial as following back the references from the last `return` and adding 
adjoint values in the metadata.

The data structure used for this is an abstract `AbstractNode` type, with subtypes for:

- Arguments and constants;
- Special calls (such as `:inbounds`) and primitive calls (by default, everything which is builtin
  or intrinsic, but this can be changed by using a context – see below);
- Nested calls, containing recursively the nodes from a non-primitive call; and
- Return and jump nodes, being recorded when a branch is taken.
  

## Implementation

Constructing this kind of trace should be possible by extending the original IR by inserting a
constant number of statements before or after each original statement (and some at the beginning of
each block), somehow like this:

```
julia> transform_ir(@code_ir geom(1, 0.5))
1: (%4, %1, %2, %3)
  %5 = GraphRecorder(1: (%1, %2, %3)
  %4 = rand()
  %5 = %4 < %3
  br 2 unless %5
  return %2
2:
  %6 = %2 + 1
  %7 = geom(%6, %3)
  return %7, %4)
  %6 = getfield(%5, :incomplete_node)
  %7 = TapeConstant(%1)
  %8 = NodeInfo($(QuoteNode(§1:%1)), %6)
  %9 = ArgumentNode(%7, $(QuoteNode(1)), %8)
  %10 = record!(%5, %9)
  %11 = TapeConstant(%2)
  %12 = NodeInfo($(QuoteNode(§1:%2)), %6)
  %13 = ArgumentNode(%11, $(QuoteNode(2)), %12)
  %14 = record!(%5, %13)
  %15 = TapeConstant(%3)
  %16 = NodeInfo($(QuoteNode(§1:%3)), %6)
  %17 = ArgumentNode(%15, $(QuoteNode(3)), %16)
  %18 = record!(%5, %17)
  %19 = TapeConstant(rand)
  %20 = tuple()
  %21 = tuple()
  %22 = NodeInfo($(QuoteNode(§1:%4)), %6)
  %23 = trackcall(%4, rand, %19, %20, %21, %22)
  %24 = record!(%5, %23)
  %25 = TapeConstant(:<)
  %26 = tuple(%24, %3)
  %27 = tapeify(%5, $(QuoteNode(%4)))
  %28 = tapeify(%5, $(QuoteNode(%3)))
  %29 = tuple(%27, %28)
  %30 = NodeInfo($(QuoteNode(§1:%5)), %6)
  %31 = trackcall(%4, <, %25, %26, %29, %30)
  %32 = record!(%5, %31)
  %33 = tuple()
  %34 = tapeify(%5, $(QuoteNode(%5)))
  %35 = NodeInfo($(QuoteNode(§1:&1)), %6)
  %36 = JumpNode(2, %33, %34, %35)
  %37 = tapeify(%5, $(QuoteNode(%2)))
  %38 = NodeInfo($(QuoteNode(§1:&2)), %6)
  %39 = ReturnNode(%37, %38)
  br 2 (%36) unless %32
  br 3 (%2, %39)
2: (%40)
  %41 = record!(%5, %40)
  %42 = TapeConstant(+)
  %43 = tuple(%2, 1)
  %44 = tapeify(%5, $(QuoteNode(%2)))
  %45 = tuple(%44, $(QuoteNode(⟨1⟩)))
  %46 = NodeInfo($(QuoteNode(§2:%6)), %6)
  %47 = trackcall(%4, +, %42, %43, %45, %46)
  %48 = record!(%5, %47)
  %49 = TapeConstant(geom)
  %50 = tuple(%48, %3)
  %51 = tapeify(%5, $(QuoteNode(%6)))
  %52 = tapeify(%5, $(QuoteNode(%3)))
  %53 = tuple(%51, %52)
  %54 = NodeInfo($(QuoteNode(§2:%7)), %6)
  %55 = trackcall(%4, geom, %49, %50, %53, %54)
  %56 = record!(%5, %55)
  %57 = tapeify(%5, $(QuoteNode(%7)))
  %58 = NodeInfo($(QuoteNode(§2:&1)), %6)
  %59 = ReturnNode(%57, %58)
  br 3 (%56, %59)
3: (%60, %61)
  %62 = record!(%5, %61)
  %63 = tuple(%60, %5)
  return %63
```

The function `trackcall` then recursively does the same kind of thing to the nested calls.

This can be achieved by using an `IRTools` dynamo, which in essence is just a fancier generated
function, allowing one to operate with `IRTools.IR` instead of "raw" `CodeInfo`s.  In this dynamo,
the original IR is completely rebuilt to insert all necessary tracking statements.

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
- There are some splice-in `QuoteNode`s.  These result from inlined literal values known at the time
  of the transformation (either because they are statically determined, such as IR
  indices/locations, or because they result from literals in the original code).
  

## Contexts

You may have noticed that there is an additional, fourth argument occuring in the transformed IR
shown above.  This is the additional context that gets passed down the transformed functions, and is
used for dispatch in in the internal functions (mostly `trackcall`).  These context arguments work
similar to the contexts in Cassette.jl, and let you overload the behaviour of how tracking works.

The main parts of customizable behaviour are 1) to change what is considered a primitive (e.g., a
“primitively” differentiable function is primitive in an AD application – no need to recurse
further), and 2) to record custom metadata.

This system is basically working, but still a bit under construction (mostly in that there will be
more points provided that can be overloaded, and documentation given).


## Trying it out

Currently, there are only a couple of very primitive examples in `runtests.jl`, but the interface is
simple:

    node = track(f, args...)
    
`node` will be a `NestedCallNode` (unless `f` is primitive), with `value(node)` being the result of
`f(args...)`.

Since tracked graphs are recursive, they can become very large.  To inspect only the “top level” of
them, you can use `printlevels`:

```
julia> f(x) = sin(x) + x

julia> node = track(f, 1.0);

julia> printlevels(node, 2)
⟨f⟩(⟨1.0⟩) = 1.8414709848078965
  @1: [Argument §1:%1] = f
  @2: [Argument §1:%2] = 1.0
  @3: [§1:%3] ⟨sin⟩(@2) = 0.8414709848078965
  @4: [§1:%4] ⟨+⟩(@3, @2) = 1.8414709848078965
  @5: [§1:&1] return @4 = 1.8414709848078965
```

Nodes in general may have `children` and a `parent`:

```
julia> children(node)
5-element Array{AbstractNode,1}:
 [Argument §1:%1] = f                    
 [Argument §1:%2] = 1.0                  
 [§1:%3] ⟨sin⟩(@2) = 0.8414709848078965  
 [§1:%4] ⟨+⟩(@3, @2) = 1.8414709848078965
 [§1:&1] return @4 = 1.8414709848078965 
 
julia> parent(node[4]) === node
true
```

As you can see, normal indexing can also be used to access the children of a nested node.  Each node
also has a `location`, which can be used to as an index into the original IR:

```
julia> printlevels(node[4], 1)   # this node is huge…
[§1:%4] ⟨+⟩(@3, @2) = 1.8414709848078965

julia> location(node[4])
§1:%4

julia> node.original_ir[location(node[4])]
IRTools.Inner.Statement(:(%1 + %3), Any, 1)
```

To inspect the dependencies in the code, we can use `ancestors`:

```
julia> ancestors(node[4])
2-element Array{DataFlowNode,1}:
 [§1:%3] ⟨sin⟩(@2) = 0.8414709848078965
 [Argument §1:%2] = 1.0 
```

We can also inspect the various contents of each node:

```
julia> typeof(node[3])
NestedCallNode

julia> value(node[3])
0.8414709848078965

julia> node[3].call.f
⟨sin⟩

julia> value(node[3].call.f)
sin (generic function with 12 methods)

julia> node[3].call.arguments
(@2,)

julia> value.(node[3].call.arguments)
(1.0,)
```

See `graphapi.jl`, `nodes.jl`, and `tapeexpr.jl` for more functionality.


### Contexts

If we want to use contexts, we have to create a new subtype of `AbstractTrackingContext`.  Say we
want to limit the recursive tracking to a maximum level (to avoid having to call `printlevels` every
time), then we could start with the following:

```
struct DepthLimitContext <: AbstractTrackingContext
    level::Int
    maxlevel::Int
end

DepthLimitContext(maxlevel) = DepthLimitContext(1, maxlevel)

# a little helper:
increase_level(ctx::DepthLimitContext) = DepthLimitContext(ctx.level + 1, ctx.maxlevel)
```

Then, we can overload some functions for things we want to change:

```
import DynamicComputationGraphs: canrecur, tracknested

# this is the main thing to make this work: 
canrecur(ctx::DepthLimitContext, f, args...) = ctx.level < ctx.maxlevel

# and if we recur into a nested function, we need to update the level in the context:
function tracknested(ctx::DepthLimitContext, f, f_repr, args, args_repr, info)
    new_ctx = increase_level(ctx)
    return recordnested(new_ctx, f, f_repr, args, args_repr, info)
end
```

`recordnested` is the fallback implementation, like `recurse` in Cassette.jl.

Once we have a custom context, we can just pass it as the first argument to `track`:

```
julia> call = track(DepthLimitContext(2), geom, 1, 0.5)
⟨geom⟩(⟨1⟩, ⟨0.5⟩) = 2
  @1: [Argument §1:%1] = geom
  @2: [Argument §1:%2] = 1
  @3: [Argument §1:%3] = 0.5
  @4: [§1:%4] ⟨rand⟩() = 0.7382990026907705
  @5: [§1:%5] ⟨<⟩(@4, @3) = false
  @6: [§1:&1] goto §2 since @5 == false
  @7: [§2:%6] ⟨+⟩(@2, ⟨1⟩) = 2
  @8: [§2:%7] ⟨geom⟩(@7, @3) = 2
  @9: [§2:&1] return @8 = 2
```

Note that here, all the nodes at level 2 are `PrimitiveNode`s!

If no context is provided, the constant `DEFAULT_CTX::DefaultTrackingContext` will be used, which
tracks everything down to primitive/intrinsic functions (see `isbuiltin`), and records no additional
metadata.  `DepthLimitContext` is also provided by the library, in case you need it.

At the moment, the overloadable methods are `canrecur`, `trackprimitive`, `tracknested`, and
`trackcall`.  Their fallbacks are `recordnested`, `recordprimitive`, and `isbuiltin` (you are not
forced to use these, but otherwise, you’d have to manually construct the node structures to return.)




