# DynamicComputationGraphs.jl

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
- All intermediate valuest
- The branching instructions actually taken, written in literal form `br label`
- All data dependencies as references to previous instructions in the trace, indicated by `@x` line references.
- Nested function calls and their arguments (note that the argument `%1` stands for the function itself and
  is not used most of the time).

In our use case, 
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
statements before or after each original statement, somehow like this:

```
1: (%1, %2, %3)
  %4 = GraphTape()
  %5 = StmtIndex(1)
  %6 = Argument(%1, %5)
  %7 = record!(%4, %6)
  %8 = StmtIndex(2)
  %9 = Argument(%2, %8)
  %10 = record!(%4, %9)
  %11 = StmtIndex(3)
  %12 = Argument(%3, %11)
  %13 = record!(%4, %12)
  %14 = StmtIndex(4)
  %15 = $(Expr(:copyast, :($(QuoteNode(:(rand()))))))
  %16 = record!(%4, %14, %15, rand)
  %17 = StmtIndex(5)
  %18 = $(Expr(:copyast, :($(QuoteNode(:(%4 < %3))))))
  %19 = record!(%4, %17, %18, :<, %16, %3)
  %20 = $(Expr(:copyast, :($(QuoteNode(%2)))))
  %21 = BranchIndex(1, 2)
  %22 = Return(%20, %2, %21)
  %23 = record!(%4, %22)
  %24 = Base.tuple(%2, %4)
  return %24
2:
  %25 = StmtIndex(6)
  %26 = $(Expr(:copyast, :($(QuoteNode(:(%2 + 1))))))
  %27 = record!(%4, %25, %26, :+, %2, 1)
  %28 = StmtIndex(7)
  %29 = $(Expr(:copyast, :($(QuoteNode(:(geom(%6, %3)))))))
  %30 = record!(%4, %28, %29, geom, %27, %3)
  %31 = $(Expr(:copyast, :($(QuoteNode(%7)))))
  %32 = BranchIndex(2, 1)
  %33 = Return(%31, %30, %32)
  %34 = record!(%4, %33)
  %35 = Base.tuple(%30, %4)
  return %35
```

This is just the current form, and not yet handling branching correctly.  It uses an `IRTools` dynamo, which in
essence is just a fancier generated function allowing one to operate with `IRTools.IR` instead of "raw" `CodeInfo`s.

### Things I still have to think about

- How to handle phi-nodes, or: how to insert branch recording statements correctly, whithout much overhead
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
