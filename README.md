# IRTracker.jl

[![Build Status](https://travis-ci.org/TuringLang/IRTracker.jl.svg?branch=master)](https://travis-ci.org/TuringLang/IRTracker.jl)

**Previously known as _DynamicComputationGraphs_**

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
    
![Extended Wengert list of geom with annotations](/figures/extended-wengert-list.png)

(This result is expanded to only three levels, since the full output would be huge.)

Here, the indented lines indicate the "inner code" recorded in the recursive calls.  Since we record
intermediate values as well, and track data dependencies by pointers, this is equivalent to a
traditional tape used for backward mode AD, just with the control flow nodes between.

This, together with the original IR, while being a bit cryptic, contains the following information:

- Every executed statement, linked to the original.  Corresponding SSA values in the original code
  are annotated in [brackets], by their block and variable id (`§s:%i`).  Arguments, having no
  associated expressions, are prefixed with `Arg:`.
- All intermediate values on the data path. They are, as all nodes, numbered as `@i`. These are
  referred to in expressions recorded, to that a backward pass is trivial.
- The branching instructions actually taken, written in literal form `goto label`.  Blocks are
  referred to by paragraph signs: `§b`.  They are annotated as well with the block they come from,
  and the position among all branch statements within that block: `[§b:&position]`.
- Nested function calls and their arguments (note that the argument `%1` stands for the function
  itself and is not used most of the time).
- Constants (literals in the expressions) are written in ⟨angle brackets⟩ (this makes debugging the
  transformed code easier).
- Not shown here, but “special expression”, such as `Expr(:foreigncall, …)`, are written as `$(foreigncall)(…)`.

Furthermore, argument assignments in blocks jumped to by branches are linked back to the respective
arguments by using the notation `@i#j = value`:

```
julia> function h(x, n)
           r = zero(x)
           i = 0
           while i < n
               r += x^i
               i += 1
           end
           return r
       end
h (generic function with 1 method)

julia> printlevels(track(h, 2.0, 2), 2)
⟨h⟩(⟨2.0⟩, ⟨2⟩, ()...) → 3.0::Float64
  @1: [Arg:§1:%1] h::typeof(h)
  @2: [Arg:§1:%2] 2.0::Float64
  @3: [Arg:§1:%3] 2::Int64
  @4: [§1:%4] ⟨zero⟩(@2, ()...) → 0.0::Float64
  @5: [§1:&1] goto §2 (⟨0⟩, @4)
  @6: [Arg:§2:%5] @5#1 → 0::Int64
  @7: [Arg:§2:%6] @5#2 → 0.0::Float64
  @8: [§2:%7] ⟨<⟩(@6, @3, ()...) → true::Bool
  @9: [§2:&2] goto §3
  @10: [§3:%8] ⟨^⟩(@2, @6, ()...) → 1.0::Float64
  @11: [§3:%9] ⟨+⟩(@7, @10, ()...) → 1.0::Float64
  @12: [§3:%10] ⟨+⟩(@6, ⟨1⟩, ()...) → 1::Int64
  @13: [§3:&1] goto §2 (@12, @11)
  @14: [Arg:§2:%5] @13#1 → 1::Int64
  @15: [Arg:§2:%6] @13#2 → 1.0::Float64
  @16: [§2:%7] ⟨<⟩(@14, @3, ()...) → true::Bool
  @17: [§2:&2] goto §3
  @18: [§3:%8] ⟨^⟩(@2, @14, ()...) → 2.0::Float64
  @19: [§3:%9] ⟨+⟩(@15, @18, ()...) → 3.0::Float64
  @20: [§3:%10] ⟨+⟩(@14, ⟨1⟩, ()...) → 2::Int64
  @21: [§3:&1] goto §2 (@20, @19)
  @22: [Arg:§2:%5] @21#1 → 2::Int64
  @23: [Arg:§2:%6] @21#2 → 3.0::Float64
  @24: [§2:%7] ⟨<⟩(@22, @3, ()...) → false::Bool
  @25: [§2:&1] goto §4 since @24 == false
  @26: [§4:&1] return @23 → 3.0::Float64
```

The spurious `()...` arguments represent the empty varargs part.

In this form, a backward pass is as trivial as following back the references from the last `return`
and adding adjoint values in the metadata.

The data structure used for this is an abstract `AbstractNode` type, with subtypes for:

- Arguments and constants;
- Special calls (such as `:inbounds`) and primitive calls (by default, everything which is builtin
  or intrinsic, but this can be changed by using a context – see below);
- Nested calls, containing recursively the nodes from a non-primitive call; and
- Return and jump nodes, being recorded when a branch is taken.
  

## Implementation

Constructing this kind of trace should be possible by extending the original IR by inserting a
constant number of statements before and after each original statement (and some at the beginning of
each block), somehow like this:

![Annotated transformed code of geom](/figures/translation.png)

The extra argument, `%5`, is a `GraphRecorder` object where all statements are recorded onto using
`record!`.  Each kind of statement is reified by a call to `tracked<whatever>` (plus some
preparations), and finally replaced by `record!`, which returns its original value. The function
`trackcall` recursively does the same kind of thing to the nested calls (depending the current
notion of “primitive” calls, that is – see below under “Contexts” for more about this).

This transformation is implemented using an `IRTools`
[dynamo](https://mikeinnes.github.io/IRTools.jl/latest/dynamo/), which in essence is just a fancier
generated function, allowing one to operate with `IRTools.IR` instead of "raw" `CodeInfo`s.  In this
dynamo, the original IR is completely rebuilt to insert all necessary tracking statements.

There’s some things to note:

- Branches are recorded by first creating a node for each branch in a block, then passing this as an
  extra argument to the actual branch.  The actual recording is done in the target block.  For this
  reason, all return branches are replaced by jumps to an extra “return block” at the end. 
- There’s some additional runtime logic in the `trackcall` function, which determines how to
  differentiate between “primitive” and “non-primitive” calls (serving as the stopping case for the
  recursive tracking).
- The purpose of `trackedvariable` is to make sure that tape references (`@i` in the output)
  actually point to the last usage of a SSA variable (since that can happen multiple times in a
  loop).
- There are some spliced-in `QuoteNode`s.  These result from inlined literal values known at the time
  of the transformation (either because they are statically determined, such as IR
  indices/locations, or because they result from literals in the original code).
  

### Contexts

You may have noticed that all `tracked<whatever>` functions above take the `GraphRecorder` as their first 
argument.  Through this, a context object gets passed down the transformed functions, and is
used for dispatch in in the internal functions (mostly `trackcall`).  These context arguments work
similar to the contexts in Cassette.jl, and let you overload the behaviour of how tracking works by providing
custom implementations of a method of the tracker functions.

The main parts of customizable behaviour are 1) to change what is considered a primitive (e.g., a
“primitively” differentiable function is primitive in an AD application – no need to recurse
further), and 2) to record custom metadata.

For examples, see the end of the readme or the context test cases.


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
f (generic function with 1 method)

julia> node = track(f, 1.0);

julia> printlevels(node, 2)
⟨f⟩(⟨1.0⟩, ()...) → 1.8414709848078965::Float64
  @1: [Arg:§1:%1] f::typeof(f)
  @2: [Arg:§1:%2] 1.0::Float64
  @3: [§1:%3] ⟨sin⟩(@2, ()...) → 0.8414709848078965::Float64
  @4: [§1:%4] ⟨+⟩(@3, @2, ()...) → 1.8414709848078965::Float64
  @5: [§1:&1] return @4 → 1.8414709848078965::Float64
```

Nodes in general may have children and a parent:

```
julia> getchildren(node)
5-element Array{AbstractNode,1}:
 @1: f::typeof(f)
 @2: 1.0::Float64
 @3: ⟨sin⟩(@2, ()...) → 0.8414709848078965::Float64
 @4: ⟨+⟩(@3, @2, ()...) → 1.8414709848078965::Float64
 @5: return @4 → 1.8414709848078965::Float64 
 
julia> getparent(node[4]) === node
true
```

As you can see, normal indexing can also be used to access the children of a nested node.

There are provided several functions to inspect the dependencies in the code.  `referenced` results
in the parent nodes which a node directly references, and `backwards` follows back these references
transitively (within the current `NestedCallNode`):

```
julia> printlevels(node, 2)
⟨f⟩(⟨1.0⟩, ()...) → 1.8414709848078965::Float64
  @1: [Arg:§1:%1] f::typeof(f)
  @2: [Arg:§1:%2] 1.0::Float64
  @3: [§1:%3] ⟨sin⟩(@2, ()...) → 0.8414709848078965::Float64
  @4: [§1:%4] ⟨+⟩(@3, @2, ()...) → 1.8414709848078965::Float64
  @5: [§1:&1] return @4 → 1.8414709848078965::Float64
  
julia> referenced(node[5])
1-element Array{AbstractNode,1}:
 @4: ⟨+⟩(@3, @2, ()...) → 1.8414709848078965::Float64
 
julia> backward(node[5])
3-element Array{AbstractNode,1}:
 @4: ⟨+⟩(@3, @2, ()...) → 1.8414709848078965::Float64
 @3: ⟨sin⟩(@2, ()...) → 0.8414709848078965::Float64
 @2: 1.0::Float64
```

For special cases, such as when implementing AD, we can also require the references to be numbered
according to their position in calls:

```
julia> referenced(node[5], numbered = true)
1-element Array{Pair{Int64,AbstractNode},1}:
 1 => @4: ⟨+⟩(@3, @2, ()...) → 1.8414709848078965::Float64


julia> referenced(node[4], numbered = true)
2-element Array{Pair{Int64,AbstractNode},1}:
 2 => @3: ⟨sin⟩(@2, ()...) → 0.8414709848078965::Float64
 3 => @2: 1.0::Float64
```

Constant arguments are left out.  For function calls, `1` corresponds to the function itself.

`dependents` and `forward` are the corresponding query functions in the other direction:

```
julia> dependents(node[2])
2-element Array{AbstractNode,1}:
 @3: ⟨sin⟩(@2, ()...) → 0.8414709848078965::Float64
 @4: ⟨+⟩(@3, @2, ()...) → 1.8414709848078965::Float64	

julia> forward(node[2])
3-element Array{AbstractNode,1}:
 @3: ⟨sin⟩(@2, ()...) → 0.8414709848078965::Float64
 @4: ⟨+⟩(@3, @2, ()...) → 1.8414709848078965::Float64
 @5: return @4 → 1.8414709848078965::Float64
```

See also the `query` function for a more detailed, internal iterface to the node hierarchy.

Finally, we can also inspect various properties of each node:

```
julia> typeof(node[3])
NestedCallNode{Float64,typeof(sin),Tuple{Float64},TapeCall{Float64,typeof(sin),Tuple{Float64},TapeConstant{typeof(sin)},Tuple{TapeReference{Float64,ArgumentNode{Float64}}},Tuple{}}}

julia> getvalue(node[3])
0.8414709848078965

julia> getfunction(node[3])
⟨sin⟩

julia> getvalue(getfunction(node[3]))
sin (generic function with 12 methods))

julia> getarguments(node[3])
(@2,)

julia> getvalue.(getarguments(node[3]))
(1.0,)
```

Each node also has a location in the original IR:

```
julia> printlevels(node[4], 1)  # this node is huge...
@4: [§1:%4] ⟨+⟩(@3, @2, ()...) → 1.8414709848078965::Float64

julia> getlocation(node[4])
§1:%4
```

The original IR from which a node was recorded is available, and can be indexed by the location:

```
julia> getir(node[4])
1: (%1, %2)
  %3 = Main.sin(%2)
  %4 = %3 + %2
  return %4

julia> getir(node[4])[getlocation(node[4])]
IRTools.Inner.Statement(:(%3 + %2), Any, 1)
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
import IRTracker: canrecur, trackednested

# this is the main thing to make this work: 
canrecur(ctx::DepthLimitContext, f, args...) = ctx.level < ctx.maxlevel

# and if we recur into a nested function, we need to update the level in the context:
function trackednested(ctx::DepthLimitContext, f_repr::TapeExpr,
                       args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
    new_ctx = increase_level(ctx)
    return recordnestedcall(new_ctx, f_repr, args_repr, info)
end
```

`recordnestedcall` is the fallback implementation, like `recurse` in Cassette.jl, and
returns a `NestedCallNode` with the recorded children.

Once we have a custom context, we can just pass it as the first argument to `track`:

```
julia> call = track(DepthLimitContext(2), geom, 1, 0.5)
⟨geom⟩(⟨1⟩, ⟨0.5⟩, ()...) → 4::Int64
  @1: [Arg:§1:%1] geom::typeof(geom)
  @2: [Arg:§1:%2] 1::Int64
  @3: [Arg:§1:%3] 0.5::Float64
  @4: [§1:%4] ⟨rand⟩() → 0.933407016129252::Float64
  @5: [§1:%5] ⟨<⟩(@4, @3) → false::Bool
  @6: [§1:&1] goto §2 since @5 == false
  @7: [§2:%6] ⟨+⟩(@2, ⟨1⟩) → 2::Int64
  @8: [§2:%7] ⟨geom⟩(@7, @3) → 4::Int64
  @9: [§2:&1] return @8 → 4::Int64
```

Note that here, all the nodes at level 2 are `PrimitiveNode`s!

If no context is provided, the constant `DEFAULT_CTX::DefaultTrackingContext` will be used, which
tracks everything down to primitive/intrinsic functions (see `isbuiltin`), and records no additional
metadata.  `DepthLimitContext` is also provided by the library, in case you need it.

At the moment, the overloadable methods are `canrecur`, `trackedargument`, `trackedcall`,
`trackedconstant`, `trackedjump`, `trackednested`, `trackedprimitive`, `trackedreturn`, and
`trackedspecial`.  Provided fallbacks are `recordnestedcall`, as explained, and `isbuiltin` for
`canrecur` (you are not forced to use these, but otherwise, you’d have to manually construct the
node structures to return.)

For something more complex, you can have a look at the AD implementation in the test folder.




