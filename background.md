# Automatic Differentiation & Related Graphs


## General Introduction

- P. Ruffwind, [“Reverse-mode automatic differentiation: a tutorial,”](https://rufflewind.com/2016-12-30/reverse-mode-automatic-differentiation) Rufflewind’s Scratchpad.

Best general introductory overview I found of what happens in the details of forward and reverse mode, compared, and with 
good graphics.  Also explains tapes (and provides Rust code to look at).

- A. Radul, “Introduction to Automatic Differentiation,” Conversations.

Very high-level introduction of AD terms and concepts.


## General Papers

- A. G. Baydin, B. A. Pearlmutter, A. A. Radul, and J. M. Siskind, “Automatic Diﬀerentiation in Machine Learning: a Survey,” p. 43.

Survey paper with a lot of examples, graphics, and comparison of state of the art implementations.

- M. Bartholomew-Biggs, S. Brown, B. Christianson, and L. Dixon, “Automatic differentiation of algorithms,” Journal of Computational and Applied Mathematics, vol. 124, no. 1, pp. 171–190, Dec. 2000.

Survey paper from 2000, introducing mostly source-to-source AD in a quite technical context.

- B. van Merriënboer, O. Breuleux, A. Bergeron, and P. Lamblin, “Automatic differentiation in ML: Where we are and where we should be going,” Oct. 2018.

Gives a concise overview over state of the art methods, and introduces Myia, an AD framework based on python and functional principles.


## Zygote

IR-based source-to-source backward mode AD in Julia.  Contains very good explanations of basic AD and good ideas how
to design a more general system.

- M. Innes, “Don’t Unroll Adjoint: Differentiating SSA-Form Programs,” arXiv:1810.07951 [cs], Oct. 2018.

The paper behind Zygote, explaining SSA-based source-to-source AD, in general and applied to some specific language
features such as data types.

- “Zygote.” [Online]. Available: http://fluxml.ai/Zygote.jl/latest/. [Accessed: 30-Apr-2019].

The [glossary](http://fluxml.ai/Zygote.jl/latest/glossary/) of Zygotes docs contain a good overview of common AD terms
and their confusions.


## Cassette

There are two existing sketches of forward and backward AD using Cassette's tagging system (in an older version, though):

- https://gist.github.com/jrevels/4b75ce24d8563888e54a89f6fdf2ff97

- https://gist.github.com/willtebbutt/39205ab845b22e6452a42705eac8d254


## Related approaches/ideas

- T. Rompf and M. Odersky, “Lightweight Modular Staging: A Pragmatic Approach to Runtime Code Generation and Compiled DSLs,” p. 10.

An alternative to overloading and source-to-source approaces in AD, with relations to the tracing JIT approach for graph
extraction in Julia, and generated functions.  Could provide some insights to dynamic graph tracing.

- “The Tapenade A.D. engine.” [Online]. Available: https://www-sop.inria.fr/tropics/tapenade.html. [Accessed: 30-Apr-2019].

Tapenade is an older source-to-source system, but it's docs try to explain the concepts well.  Especially they distinguish
between gradients, tangents, derivatives, JVPs, VJPs, etc.  in mathematical form.

- A. Paszke et al., “Automatic differentiation in PyTorch,” p. 4.

PyTorch uses dynamic graphs as well, so this is something to compare to.  Although the interface is rather different, since
Torch uses API-based graph definition.


### Swift for TensorFlow

There's currently many efforts put into a fork of Swift to equip the language with two compiler features needed for 
"nice" modern machine learning: built-in AD, and extraction of program graphs.  These efforts focus on making everything
fit to TensorFlow, but can be reused in other graph-based frameworks as well, of course.  

They have and still to put a lot of thought into the design of all parts of that, and produced some very good design 
documents explaining all of their choices and the ideas behind them:

- [Graph program extraction](https://github.com/tensorflow/swift/blob/master/docs/GraphProgramExtraction.md)

Their motivation and ideas about how to get a graph representation of tensor computations from static analysis of Swift code.

- M. Hong and C. Lattner, “Graph Program Extraction and Device Partitioning in Swift for TensorFLow,” presented at the 2018 LLVM Developers’ Meeting.

A takl which describes Swift's Graph Program Extraction from a compiler perspective, especially the control flow 
analysis and program slicing parts operating on the Swift IR.

- [Automatic differentiation in Swift](https://github.com/tensorflow/swift/blob/master/docs/AutomaticDifferentiation.md)
- [First-Class Automatic Differentiation in Swift: A Manifesto](https://gist.github.com/rxwei/30ba75ce092ab3b0dce4bde1fc2c9f1d)
- [Differentiable functions and differentiation APIs](https://github.com/tensorflow/swift/blob/master/docs/DifferentiableFunctions.md)

The design of the AD compiler interface at different stages -- an extremely useful resource for a general compositional 
interface.  Especially, it provides code snippets and types (!) for everything.


## Ideas from (pure) FP

- S. Peyton Jones, “Automatic differentiation for dummies,” presented at the IC Colloquium, EPFL, 22-Jan-2019.
- C. Elliott, “The simple essence of automatic differentiation,” arXiv:1804.00746 [cs], Apr. 2018.
- B. A. Pearlmutter, “Reverse-Mode AD in a Functional Framework: Lambda the Ultimate Backpropagator,” ACM Transactions on Programming Languages and Systems, p. 35.
