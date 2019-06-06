# DynamicComputationGraphs.jl

## Plan

My basic idea is to use a tape consisting of the IR instructions of the executed code, including control flow.
These should be possible to extract using a Cassette pass inserting a "recording statement" after each instruction
of a given function.

If we look at a simple function with stochastic control flow, 

    geom(n, β) = rand() < β ? n : geom(n + 1, β)
    
with IR code

```
1:
  <1>  %1 = (Main.rand)()
  <2>  %2 = %1 < _3
  <3>  br 3 unless %2
2:
  <4>  return _2
3:
  <5>  %3 = _2 + 1
  <6>  %4 = (Main.geom)(%3, _3)
  <7>  return %4
```

(using [IRTools](https://github.com/MikeInnes/IRTools.jl) format with statement numbers inserted in angle brackets),
we would record a trace like the following,
under the assumption that `rand()` returns a value greater than β the first time and less the second time:
    
```
<5> %3 = _2 + 1
<6> %4 = (Main.geom)(%3, _3)
    <4>  return _2
<7> return %4
```

Here, the indented `return _2` indicates the "inner code" recorded in the recursive call of `geom`.  This is
essentially the recorded "data flow slice" of the expansion of the above IR, going back from the last `return`.  
If we record intermediate values as well, and track data dependencies by pointers, this is equivalent to a 
traditional tape used for backward mode AD.

But we can see that at least half the "information" from the original IR is missing; first and foremost, everthing 
that determines control flow.  In our use case, 
we need a couple of other information as well -- e.g., metadata about certain function calls (e.g. 
for differenetiation, or to analyze the relationships between random variables).

For this purpose, I propose a form like the following for a trace of `geom(1, 0.5)`:

```
[1]     _2 => 1    # first argument
[2]     _3 => 0.5  # second argument
[3] <1> (Main.rand)() => 0.87
[4] <2> [3] < [2] => false
[5] <3> br 3
[6] <5> [1] + 1 => 2
[7] <6> (Main.geom)([6], [2]) => 2   # recursive call, containing subtape
    [1]     _2 => 1    # first argument
    [2]     _3 => 0.5  # second argument
    [3] <1> (Main.rand)() => 0.32
    [4] <2> [3] < [2] => true
    [5] <3> br 2
    [6] <4> return [1] => 2
[8] <7> return [7] => 2
```

This, together with the original IR, contains the following information:

- Every executed statement, linked by line number `<l>` to the original
- All intermediate values, indicated by `=> value` at the right
- The branching instructions actually taken, written in literal form `br label`
- All data dependencies as references to previous instructions in the trace, indicated
  in `[brackets]`.
- Nested function calls and their arguments (note that the argument `_1` stands for the function itself and
  is not used most of the time).
  
Additionally, adding arbitrary other metadata to the intermediate values should be easily possible as well.

In this form, a backward pass is as trivial as following back the references from the last `return` and adding 
adjoint values in the metadata.

The data structure used for this would mostly be a `Vector` of instruction records, of which there are five types:

- "Primitive calls", which are not traced recursively, and contain the calling function, result value, argument 
  references, and metadata
- "Nested calls", which are the same as primitive calls, but with an additional tape for the recursive trace
- "Input declarations", giving a reference to the arguments, which are internally treated as constants
- Branches and returns; the former recording the label actually jumped to, the latter just referencing
  the value to be returned.
  
Constructing this kind of trace should be possible by extending the original IR by inserting a constant number of 
statements before or after each original statement, somehow like this:

```
1:
       %11 = push!(trace, Input(:_2 => _2))
       %12 = push!(%11, Input(:_3 => _3))
  <1>  %1 = (Main.rand)()
       %13 = push!(%12, PCall(:%1 => %1, :(Main.rand))
  <2>  %2 = %1 < _3
       %14 = push!(%13, PCall(:%2 => %2, :<, :%1, :_3))
       %15 = %2 ? 2 : 3   # remember where to we will have branched; simplified
  <3>  br 3 unless %2
2:
       %20 = phi(%14)  # determine control-flow dependent data; here trivial
       %21 = phi(%15)  # determine from where we came
       %22 = push!(%20, Branch(%21))
       %23 = push!(%22, Return(:_2))
  <4>  return (_2, %23)
3:
       %30 = phi(%14)   # determine control-flow dependent data; here trivial
       %31 = phi(%15)   # determine from where we came
       %32 = push!(%30, Branch(%31))
  <5>  %3 = _2 + 1
       %33 = push!(%32, PCall(:%3 => %3, :+, :_2, 1))
  <6>  (%4, %34) = (Main.geom)(%3, _3)
       %35 = push!(%34, NCall(:%4 => %4, :(Main.geom), :%3, :_3))
  <7>  return (%4, %35)
```

### Things I still have to think about

- How to handle phi-nodes, or: how to insert branch recording statements correctly, whithout much overhead
- How to decide when to recurse, or what to consider as "primitive"
- The trace should also indicate the original variable names of values -- is this possible by some
  reflection, or contained in the CodeInfo?
- Handle or ignore "transparent" calls, such as automatically inserted conversions?
- A proper name for this; "control flow tape" is misleading...


