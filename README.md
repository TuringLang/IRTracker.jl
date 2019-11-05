# DynamicComputationGraphs.jl

> ATTENTION: THE EXAMPLES ARE A BIT OUTDATED SINCE THE LAST REFACTORINGS, TAKE WITH CARE!

## Plan

My basic idea is to use a tape consisting of the IR instructions of the executed code, including control flow.
This type should be similar to a Wengert list, in that it records linearly the statements executed during the 
execution of a function, but contain information about function calls (so, more like nested Wengert lists) and
metadata.

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

(using [IRTools](https://github.com/MikeInnes/IRTools.jl) format ),
we would record a trace like the following,
under the assumption that `rand()` returns a value greater than β the first time and less the second time:
    
```
@1: Argument %1 = geom
@2: Argument %2 = 2
@3: Argument %3 = 0.5
@4: (%4) rand() = 0.6778
  @1 <... implementation of rand ...>
@5  br 2
@6: (%6) @2 + 1 = 3
  @1 <... implementation of + ...>
@7  (%7) geom(@6, @3) = 3
  @1: Argument %1 = geom
  @2: Argument %2 = 3
  @3: Argument %3 = 0.5
  @4: (%4) rand() = 0.1234
    @1 <... implementation of rand ...>
  @5  return @2
@8: return @7 = 3

```

Here, the indented lines indicate the "inner code" recorded in the recursive calls.  This is
essentially the recorded "data flow slice" of the expansion of the above IR, going back from the last `return`.
Since we record intermediate values as well, and track data dependencies by pointers, this is equivalent to a 
traditional tape used for backward mode AD.

This, together with the original IR, contains the following information:

- Every executed statement, linked to the original (indicated sometimes by `(%x)` in parentheses)
- All intermediate values
- The branching instructions actually taken, written in literal form `goto label`
- All data dependencies as references to previous instructions in the trace, indicated by `@x` line references.
- Nested function calls and their arguments (note that the argument `%1` stands for the function itself and
  is not used most of the time).

In our use case (analysis of Turing.jl), 
we need a couple of other information as well -- e.g., metadata about certain function calls (e.g. 
for differentiation, or to analyze the relationships between random variables).

In this form, a backward pass is as trivial as following back the references from the last `return` and adding 
adjoint values in the metadata.

The data structure used for this would mostly be a `Vector` of instruction records, of which there are several:

- "Primitive calls", which are not traced recursively, and contain the calling function, result value, argument 
  references, and metadata
- "Nested calls", which are the same as primitive calls, but with an additional tape for the recursive trace
- "Argument declarations", giving a reference to the arguments, which are internally treated as constants
- Branches and returns; the former recording the label actually jumped to, the latter just referencing
  the value to be returned.
- Some special statements, like constants or `:boundscheck` expressions
  
## Implementation

Constructing this kind of trace should be possible by extending the original IR by inserting a constant number of 
statements before or after each original statement (and some at the beginning of each block), somehow like this:

```
1: (%1, %2, %3)
  %4 = GraphTape(…)
  %5 = VarIndex(1, 1)
  %6 = Argument(%1, %5)
  %7 = record!(%4, %6)
  %8 = VarIndex(1, 2)
  %9 = Argument(%2, %8)
  %10 = record!(%4, %9)
  %11 = VarIndex(1, 3)
  %12 = Argument(%3, %11)
  %13 = record!(%4, %12)
  %14 = VarIndex(1, 4)
  %15 = $(Expr(:copyast, :($(QuoteNode(:(rand()))))))
  %16 = record!(%4, %14, %15, rand)
  %17 = VarIndex(1, 5)
  %18 = $(Expr(:copyast, :($(QuoteNode(:(%4 < %3))))))
  %19 = record!(%4, %17, %18, :<, %16, %3)
  %20 = Base.vect()
  %21 = Base.vect()
  %22 = $(Expr(:copyast, :($(QuoteNode(%5)))))
  %23 = BranchIndex(1, 1)
  %24 = Branch(2, %20, %21, %22, %23)
  %25 = $(Expr(:copyast, :($(QuoteNode(%2)))))
  %26 = BranchIndex(1, 2)
  %27 = Return(%25, %2, %26)
  %28 = record!(%4, %27)
  %29 = Base.tuple(%2, %4)
  br 2 (%24) unless %19
  return %29
2: (%30)
  %31 = record!(%4, %30)
  %32 = VarIndex(2, 6)
  %33 = $(Expr(:copyast, :($(QuoteNode(:(%2 + 1))))))
  %34 = record!(%4, %32, %33, :+, %2, 1)
  %35 = VarIndex(2, 7)
  %36 = $(Expr(:copyast, :($(QuoteNode(:(geom(%6, %3)))))))
  %37 = record!(%4, %35, %36, geom, %34, %3)
  %38 = $(Expr(:copyast, :($(QuoteNode(%7)))))
  %39 = BranchIndex(2, 1)
  %40 = Return(%38, %37, %39)
  %41 = record!(%4, %40)
  %42 = Base.tuple(%37, %4)
  return %42
```

This can be achieved by using an `IRTools` dynamo, which in essence is just a fancier generated 
function, allowing one to operate with `IRTools.IR` instead of "raw" `CodeInfo`s.  In this dynamo,
the original IR is completely rebuilt to insert all necessary tracking statements. 

Additionally, there’s some logic in the `record!` function, which determines how to differentiate
between “primitive” and “non-primitive” calls (serving as the stopping case for the recursive
tracking), and keeps track renaming SSA variables to tape indices.


### Examples

For the simple function 

```julia
function test3(x)
    y = 0 #zero(x)
    while x > 0
        y += 1
        x -= 1
    end

    return y
end
```

with original IR

```julia
1: (%1, %2)
  br 2 (:(%2), 0)
2: (%3, %4)
  %5 = %3 > 0
  br 4 unless %5
  br 3
3:
  %6 = %4 + 1
  %7 = %3 - 1
  br 2 (:(%7), :(%6))
4:
  return :(%4)
```

we get the following new IR (at the top level):

```
1: (%1, %2)
  %3 = Main.DynamicComputationGraphs.GraphTape(…)
  %4 = Main.DynamicComputationGraphs.VarIndex(1, 1)
  %5 = Main.DynamicComputationGraphs.Argument(%1, %4)
  %6 = Main.DynamicComputationGraphs.record!(%3, %5)
  %7 = Main.DynamicComputationGraphs.VarIndex(1, 2)
  %8 = Main.DynamicComputationGraphs.Argument(%2, %7)
  %9 = Main.DynamicComputationGraphs.record!(%3, %8)
  %10 = $(Expr(:copyast, :($(QuoteNode(%2)))))
  %11 = $(Expr(:copyast, :($(QuoteNode(0)))))
  %12 = Base.vect(%10, %11)
  %13 = Base.vect(%2, 0)
  %14 = $(Expr(:copyast, :($(QuoteNode(nothing)))))
  %15 = Main.DynamicComputationGraphs.BranchIndex(1, 1)
  %16 = Main.DynamicComputationGraphs.Branch(2, %12, %13, %14, %15)
  %17 = 0
  br 2 (%2, %17, %16)
2: (%18, %19, %20)
  %21 = Main.DynamicComputationGraphs.record!(%3, %20)
  %22 = Main.DynamicComputationGraphs.VarIndex(2, 3)
  %23 = Main.DynamicComputationGraphs.Argument(%18, %22)
  %24 = Main.DynamicComputationGraphs.record!(%3, %23)
  %25 = Main.DynamicComputationGraphs.VarIndex(2, 4)
  %26 = Main.DynamicComputationGraphs.Argument(%19, %25)
  %27 = Main.DynamicComputationGraphs.record!(%3, %26)
  %28 = Main.DynamicComputationGraphs.VarIndex(2, 5)
  %29 = $(Expr(:copyast, :($(QuoteNode(:(%3 > 0))))))
  %30 = Main.DynamicComputationGraphs.record!(%3, %28, %29, Main.DynamicComputationGraphs.:>, %18, 0)
  %31 = Base.vect()
  %32 = Base.vect()
  %33 = $(Expr(:copyast, :($(QuoteNode(%5)))))
  %34 = Main.DynamicComputationGraphs.BranchIndex(2, 1)
  %35 = Main.DynamicComputationGraphs.Branch(4, %31, %32, %33, %34)
  %36 = Base.vect()
  %37 = Base.vect()
  %38 = $(Expr(:copyast, :($(QuoteNode(nothing)))))
  %39 = Main.DynamicComputationGraphs.BranchIndex(2, 2)
  %40 = Main.DynamicComputationGraphs.Branch(3, %36, %37, %38, %39)
  br 4 (%35) unless %30
  br 3 (%40)
3: (%41)
  %42 = Main.DynamicComputationGraphs.record!(%3, %41)
  %43 = Main.DynamicComputationGraphs.VarIndex(3, 6)
  %44 = $(Expr(:copyast, :($(QuoteNode(:(%4 + 1))))))
  %45 = Main.DynamicComputationGraphs.record!(%3, %43, %44, Main.DynamicComputationGraphs.:+, %19, 1)
  %46 = Main.DynamicComputationGraphs.VarIndex(3, 7)
  %47 = $(Expr(:copyast, :($(QuoteNode(:(%3 - 1))))))
  %48 = Main.DynamicComputationGraphs.record!(%3, %46, %47, Main.DynamicComputationGraphs.:-, %18, 1)
  %49 = $(Expr(:copyast, :($(QuoteNode(%7)))))
  %50 = $(Expr(:copyast, :($(QuoteNode(%6)))))
  %51 = Base.vect(%49, %50)
  %52 = Base.vect(%48, %45)
  %53 = $(Expr(:copyast, :($(QuoteNode(nothing)))))
  %54 = Main.DynamicComputationGraphs.BranchIndex(3, 1)
  %55 = Main.DynamicComputationGraphs.Branch(2, %51, %52, %53, %54)
  br 2 (%48, %45, %55)
4: (%56)
  %57 = Main.DynamicComputationGraphs.record!(%3, %56)
  %58 = $(Expr(:copyast, :($(QuoteNode(%4)))))
  %59 = Main.DynamicComputationGraphs.BranchIndex(4, 1)
  %60 = Main.DynamicComputationGraphs.Return(%58, %19, %59)
  %61 = Main.DynamicComputationGraphs.record!(%3, %60)
  %62 = Base.tuple(%19, %3)
  return %62
```

Calling this function with the argument `2` gives the following trace:

```
@1: [Argument §1:%1] = Main.DynamicComputationGraphs.test3
@2: [Argument §1:%2] = 2
@3: [§1:1] goto §2 (2, 0)
@4: [Argument §2:%3] = 2
@5: [Argument §2:%4] = 0
@6: [§2:%5] @4 > 0 = true
    @1: [Argument §1:%1] = >
    @2: [Argument §1:%2] = 2
    @3: [Argument §1:%3] = 0
    @4: [§1:%4] @3 < @2 = true
        @1: [Argument §1:%1] = <
        @2: [Argument §1:%2] = 0
        @3: [Argument §1:%3] = 2
        @4: [§1:%4] Base.slt_int(@2, @3) = true
        @5: [§1:1] return @4 = true
    @5: [§1:1] return @4 = true
@7: [§2:2] goto §3
@8: [§3:%6] @5 + 1 = 1
    @1: [Argument §1:%1] = +
    @2: [Argument §1:%2] = 0
    @3: [Argument §1:%3] = 1
    @4: [§1:%4] Base.add_int(@2, @3) = 1
    @5: [§1:1] return @4 = 1
@9: [§3:%7] @4 - 1 = 1
    @1: [Argument §1:%1] = -
    @2: [Argument §1:%2] = 2
    @3: [Argument §1:%3] = 1
    @4: [§1:%4] Base.sub_int(@2, @3) = 1
    @5: [§1:1] return @4 = 1
@10: [§3:1] goto §2 (1, 1)
@11: [Argument §2:%3] = 1
@12: [Argument §2:%4] = 1
@13: [§2:%5] @11 > 0 = true
    @1: [Argument §1:%1] = >
    @2: [Argument §1:%2] = 1
    @3: [Argument §1:%3] = 0
    @4: [§1:%4] @3 < @2 = true
        @1: [Argument §1:%1] = <
        @2: [Argument §1:%2] = 0
        @3: [Argument §1:%3] = 1
        @4: [§1:%4] Base.slt_int(@2, @3) = true
        @5: [§1:1] return @4 = true
    @5: [§1:1] return @4 = true
@14: [§2:2] goto §3
@15: [§3:%6] @12 + 1 = 2
    @1: [Argument §1:%1] = +
    @2: [Argument §1:%2] = 1
    @3: [Argument §1:%3] = 1
    @4: [§1:%4] Base.add_int(@2, @3) = 2
    @5: [§1:1] return @4 = 2
@16: [§3:%7] @11 - 1 = 0
    @1: [Argument §1:%1] = -
    @2: [Argument §1:%2] = 1
    @3: [Argument §1:%3] = 1
    @4: [§1:%4] Base.sub_int(@2, @3) = 0
    @5: [§1:1] return @4 = 0
@17: [§3:1] goto §2 (0, 2)
@18: [Argument §2:%3] = 0
@19: [Argument §2:%4] = 2
@20: [§2:%5] @18 > 0 = false
    @1: [Argument §1:%1] = >
    @2: [Argument §1:%2] = 0
    @3: [Argument §1:%3] = 0
    @4: [§1:%4] @3 < @2 = false
        @1: [Argument §1:%1] = <
        @2: [Argument §1:%2] = 0
        @3: [Argument §1:%3] = 0
        @4: [§1:%4] Base.slt_int(@2, @3) = false
        @5: [§1:1] return @4 = false
    @5: [§1:1] return @4 = false
@21: [§2:1] goto §4 since @20
@22: [§4:1] return @19 = 2
```

This is admittedly a bit cryptic, so here’s a legend:

- The entries of the tape are numbered as `@i`. These are referred to in expressions
  recorded, to that a backward pass is trivial.
- Indentation matters: indented blocks are sub-traces of non-primitive function calls
- Blocks are referred to by paragraph signs: `§b`.
- Corresponding SSA values in the original code are annotated in [brackets], by their 
  block and variable id (`§s:%i`).  Arguments, having no associated expressions, are 
  prefixed with `Argument`.
- Branch statements taken are reformatted a bit, and annotated as well with the block
  they come from, and the position among all branch statements within that block: `[§b:position]`.
- Return statements are basically handled like branches.



### Things I still have to think about

- How to decide when to recurse, or what to consider as "primitive" -- there should be some kind of 
  context for that, deciding this and metadata recording on a per-use basis.
- The trace should also indicate the original variable names of values -- is this possible by some
  reflection, or contained in the CodeInfo?
- Handle or ignore "transparent" calls, such as automatically inserted conversions?
- A proper name for this; "control flow tape" is misleading...


## Trying it out

Currently, there are no test or good examples, but the interface is simple:

    result, graph = track(f, args...)
    
To run the small debug examples, I use

    julia --project=. src/DynamicComputationGraphs.jl


# Project Goals

With this graph tracker, one should be able to perform the following basic tasks

- Perform the usual forward computation (without performance overhead by interpretation)
- Record expression nodes representing the calculation (raw `Expr` or something equivalent, allowing to convert back)
- Record meta-information from the original code, such as information about random variable types, conditions, etc.
- Record, if applicable, information needed for backward calculation
- The backward information in the graph should be mutable, so that one can update subgraphs without full re-evaluation when changing parts of a model.

Here are a few corner cases which we should support, specifically relating to tracking Turing models:

- [ ] stochastic and deterministic `For` loops i.e., `K ~ ...; for k in 1:K`
- [ ] stochastic and deterministic While loops
- [ ] stochastic and deterministic `If-Else` conditions 
- [ ] stochastic and deterministic statements / assignments
- [ ] model recursions / compositional models
- [ ] recursions in general
