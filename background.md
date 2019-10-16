# Automatic differentiation

## Easy introductions

- Ruffwind, P. Reverse-mode automatic differentiation: a tutorial. Rufflewind’s Scratchpad
    https://rufflewind.com/2016-12-30/reverse-mode-automatic-differentiation (2016).
    
    Best general introductory overview I found of what happens in the details of forward and reverse
    mode, compared, and with good graphics. Also explains tapes (and provides Rust code to look at).
- Radul, A. Introduction to Automatic Differentiation. Conversations
    https://alexey.radul.name/ideas/2013/introduction-to-automatic-differentiation/ (2013).
    
    Very high-level introduction of AD terms and concepts.
    
    
## Standard and general works

- Griewank, A. & Walther, A. Evaluating derivatives: principles and techniques of algorithmic
   differentiation. (Society for Industrial and Applied Mathematics, 2008).
   
   Standard reference.  Extremely in-depth book about automatic differentiation; deals with all the
   details of math and implementation.
- Bartholomew-Biggs, M., Brown, S., Christianson, B. & Dixon, L. Automatic differentiation of
   algorithms. Journal of Computational and Applied Mathematics 124, 171–190 (2000).
   
   Survey paper from 2000, introducing mostly source-to-source AD in a quite technical context.
- Baydin, A. G., Pearlmutter, B. A., Radul, A. A. & Siskind, J. M. Automatic differentiation in
   machine learning: a survey. Journal of Machine Learning Research 18, 1–43 (2018).
   
   Survey paper with a lot of examples, graphics, and comparison of state of the art
   implementations.
- Revels, J., Besard, T., Churavy, V., De Sutter, B. & Vielma, J. P. Dynamic Automatic
    Differentiation of GPU Broadcast Kernels. arXiv:1810.08297 [cs] (2018).
    
    Analyses the `broadcast` operation in forward and reverse mode. Relevant because it uses Julia
    notions, and introduces mixed mode, which is a topic in all newer Julia AD packages.
- Innes, M. et al. A Differentiable Programming System to Bridge Machine Learning and Scientific
   Computing. arXiv:1907.07587 [cs] (2019).
   
   Explaining Zygote in a large context; general requirements for a differentiable programming system.
- Cohen, W. W. Automatic Reverse-Mode Differentiation: Lecture Notes. 12 (2016).


## Implementations

- van Merriënboer, B., Breuleux, O., Bergeron, A. & Lamblin, P. Automatic differentiation in ML:
    Where we are and where we should be going. arXiv:1810.11530 [cs, stat] (2018).
    
    Gives a concise overview over state of the art methods, and introduces Myia, an AD framework
    based on Python and functional principles.
- Tapenade developers. The Tapenade A.D. engine. https://www-sop.inria.fr/tropics/tapenade.html
    (2019).
    
    Tapenade is an older source-to-source system, but it's docs try to explain the concepts
    well. Especially they distinguish between gradients, tangents, derivatives, JVPs, VJPs, etc. in
    mathematical form.
- Paszke, A. et al. Automatic differentiation in PyTorch. in (2017).

   PyTorch uses dynamic graphs as well, so this is something to compare to. Although the interface
   is rather different, since Torch uses API-based graph definition.
   
   
## Zygote, SSA-based source-to-source

Zygote is an SSA-based source-to-source backward mode AD framework in Julia. Contains very good
explanations of basic AD and good ideas how to design a more general system.

- Zygote. http://fluxml.ai/Zygote.jl/latest/.
- Innes, M. J. Don’t Unroll Adjoint: Differentiating SSA-Form Programs. arXiv:1810.07951 [cs]
   (2018).
   
   The paper behind Zygote, explaining SSA-based source-to-source AD, in general and applied to some
   specific language features such as data types.
   
   
## Cassette
   
There are two existing sketches of forward and backward AD using Cassette's tagging system (in an
older version, though):

- https://gist.github.com/jrevels/4b75ce24d8563888e54a89f6fdf2ff97
- https://gist.github.com/willtebbutt/39205ab845b22e6452a42705eac8d254


### Swift for TensorFlow

There's currently many efforts put into a fork of Swift to equip the language with two compiler
features needed for "nice" modern machine learning: built-in AD, and extraction of program graphs.
These efforts focus on making everything
fit to TensorFlow, but can be reused in other graph-based frameworks as well, of course.  

They have and still to put a lot of thought into the design of all parts of that, and produced some
very good design documents explaining all of their choices and the ideas behind them:

- [Graph program extraction](https://github.com/tensorflow/swift/blob/master/docs/GraphProgramExtraction.md)

Their motivation and ideas about how to get a graph representation of tensor computations from
static analysis of Swift code.

- Hong, M. & Lattner, C. Graph Program Extraction and Device Partitioning in Swift for
  TensorFLow. (2018).

A takl which describes Swift's Graph Program Extraction from a compiler perspective, especially the
control flow analysis and program slicing parts operating on the Swift IR.

- [Automatic differentiation in Swift](https://github.com/tensorflow/swift/blob/master/docs/AutomaticDifferentiation.md)
- [First-Class Automatic Differentiation in Swift: A Manifesto](https://gist.github.com/rxwei/30ba75ce092ab3b0dce4bde1fc2c9f1d)
- [Differentiable functions and differentiation APIs](https://github.com/tensorflow/swift/blob/master/docs/DifferentiableFunctions.md)

The design of the AD compiler interface at different stages -- an extremely useful resource for a
general compositional interface.  Especially, it provides code snippets and types (!) for
everything.


## Ideas from (pure) FP

- Peyton Jones, S. Automatic differentiation for dummies. (2019), presented at the IC Colloquium, EPFL, 22-Jan-2019.
- Elliott, C. The simple essence of automatic differentiation. arXiv:1804.00746 [cs] (2018).

The talk and the paper present AD in a purely functional, strongly typed concept with a category
theoretic background (to show, as usual, that the trivial is trivially trivial :))

- Pearlmutter, B. A. & Siskind, J. M. Reverse-Mode AD in a Functional Framework: Lambda the Ultimate
Backpropagator. ACM Trans. Program. Lang. Syst. 30, 7:1-7:36 (2008).

Quite mathematical presentation of AD and description of the source-to-source transformations used
in VLAD/Stalin∇.


# Message passing algorithms

- Minka, T. From automatic differentiation to message
  passing. https://www.microsoft.com/en-us/research/video/from-automatic-differentiation-to-message-passing/
  (2019).
  
  Talk describing the basic ideas of message passing, and how it can serve to implement general
  algorithms on graphs.
- Minka, T. Divergence Measures and Message
  Passing. https://www.microsoft.com/en-us/research/publication/divergence-measures-and-message-passing/
  (2005).
  
  Theory behind message passing generalizing variational methods.
- Ruozzi, N. R. Message Passing Algorithms for Optimization. (Yale University, 2011).
- Dauwels, J., Korl, S. & Loeliger, H.-A. Steepest descent as message passing. in
  (2005). doi:10.1109/ITW.2005.1531853.


# Probabilistic programming and theory

- Vihola, M. Lectures on stochastic simulation. http://users.jyu.fi/~mvihola/stochsim/ (2018).

  General intro to sampling, MC, MCMC, etc. 
- van de Meent, J.-W., Paige, B., Yang, H. & Wood, F. An Introduction to Probabilistic
  Programming. arXiv:1809.10756 [cs, stat] (2018).
  
  Book-like overview over probabilistic programming approaches and inference.
- Koller, D. & Friedman, N. Probabilistic graphical models: principles and techniques. (MIT Press,
  2009).
  
  Standard reference for graphical models.
- Goodman, N. D. & Stuhlmüller, A. The Design and Implementation of Probabilistic Programming
  Languages. http://dippl.org (2014).
  
  Tutorial-like work, implementing a PPL in JavaScript using CPS.
- Andrieu, C., Doucet, A. & Holenstein, R. Particle Markov chain Monte Carlo methods. Journal of the
  Royal Statistical Society: Series B (Statistical Methodology) 72, 269–342 (2010).
- Dahlin, J. & Schön, T. B. Getting Started with Particle Metropolis-Hastings for Inference in
  Nonlinear Dynamical Models. arXiv:1511.01707 [q-fin, stat] (2015).


## Special topics, optimizations

- Hoffman, M. D., Johnson, M. J. & Tran, D. Autoconj: Recognizing and Exploiting Conjugacy Without a
  Domain-Specific Language. arXiv:1811.11926 [cs, stat] (2018).
- Murray, L. M., Lundén, D., Kudlicka, J., Broman, D. & Schön, T. B. Delayed Sampling and Automatic
  Rao-Blackwellization of Probabilistic Programs. arXiv:1708.07787 [stat] (2017).
- Wigren, A., Risuleo, R. S., Murray, L. & Lindsten, F. Parameter elimination in particle Gibbs
  sampling. in Advances in Neural Information Processing Systems (2019).


## Purely functional approaches, types, and categories

- Bhat, S., Agarwal, A., Vuduc, R. & Gray, A. A type theory for probability density functions. ACM
  SIGPLAN Notices 47, 545–556 (2012).
- Heunen, C., Kammar, O., Staton, S. & Yang, H. A Convenient Category for Higher-Order Probability
  Theory. arXiv:1701.02547 [cs, math] (2017).
- Ramsey, N. & Pfeffer, A. Stochastic Lambda Calculus and Monads of Probability
  Distributions. SIGPLAN Not. 37, 154–165 (2002).


## Variational methods

- Jordan, M. I., Ghahramani, Z., Jaakkola, T. S. & Saul, L. K. An introduction to variational
  methods for graphical models. Machine learning 37, 183–233 (1999).
- Minka, T. P. Expectation Propagation for Approximate Bayesian Inference. in UAI’01: Proceedings of
  the Seventeenth conference on Uncertainty in artificial intelligence (2001).
- Wainwright, M. J. & Jordan, M. I. Graphical Models, Exponential Families, and Variational
  Inference. Foundations and Trends in Machine Learning 1, 1–305 (2007).
- Winn, J., Bishop, C. M., Diethe, T., Guiver, J. & Zaykov, Y. Model-Based Machine Learning (Early
  Access). http://mbmlbook.com/index.html (2019).
  
  
## Bayesian Nonparametrics

- Ghahramani, Z. Non-parametric Bayesian Methods. (2005).
- Hjort, N. L., Holmes, C., Müller, P. & Walker, S. G. Bayesian nonparametrics. (Cambridge
  University Press, 2010).
- Orbanz, P. Lecture Notes on Bayesian Nonparametrics. 108 (2014).


## Frameworks and Implementations

### Probabilistic Programming 

- Bingham, E. et al. Pyro: Deep Universal Probabilistic Programming. arXiv:1810.09538 [cs, stat]
  (2018).
  
  Trace constructed by messages during runtime
- Ge, H., Xu, K. & Ghahramani, Z. Turing: A Language for Flexible Probabilistic Inference. in
  International Conference on Artificial Intelligence and Statistics 1682–1690 (2018).
- Goodman, N. D., Mansinghka, V., Roy, D. M., Bonawitz, K. & Tenenbaum, J. B. Church: a language for
  generative models. arXiv:1206.3255 [cs] (2012).
  
  LISP-based; computation trace, similar to a LISP/R environment structure.
- Goodman, N. D. & Stuhlmüller, A. The Design and Implementation of Probabilistic Programming
  Languages. http://dippl.org (2014).
  
  WebPPL.  Implemented in JavaScript, using ideas from LISP, uses CPS transformations to intercept
  code.
- Kulkarni, T. D., Kohli, P., Tenenbaum, J. B. & Mansinghka, V. Picture: A Probabilistic Programming
  Language for Scene Perception. in 4390–4399 (2015).
- Lunn, D. J., Thomas, A., Best, N. & Spiegelhalter, D. WinBUGS - A Bayesian modelling framework:
  Concepts, structure, and extensibility. Statistics and Computing 10, 325–337 (2000).
- Mansinghka, V., Selsam, D. & Perov, Y. Venture: a higher-order probabilistic programming platform
  with programmable inference. arXiv:1404.0099 [cs, stat] (2014).
  
  Probabilistic execution traces, closest to DynamicComputationGraphs.jl.
- Minka, T. et al. Infer.NET 0.3. http://dotnet.github.io/infer (2018).

  Defines static factor graphs, which are then compiled together with an inference engine.
- Wood, F., van de Meent, J. W. & Mansinghka, V. A New Approach to Probabilistic Programming
  Inference. arXiv:1507.00996 [cs, stat] (2015).
  
  Anglican; uses a CPS transformation in Clojure.
- Plummer, M. JAGS: A Program for Analysis of Bayesian Graphical Models Using Gibbs Sampling. in
  Proceedings of the 3rd International Workshop on Distributed Statistical Computing (DSC 2003)
  (2003).
  

### General ML
- Innes, M. Flux: Elegant machine learning with Julia. Journal of Open Source Software (2018)
  doi:10.21105/joss.00602.
  
  Flux.Tracker uses OO with tapes to do backward-mode AD.
- Looks, M., Herreshoff, M., Hutchins, D. & Norvig, P. Deep Learning with Dynamic Computation
  Graphs. arXiv:1702.02181 [cs, stat] (2017).
  
  TensorFlow Fold; uses static graphs with dynamic batching.
- Neubig, G. et al. DyNet: The Dynamic Neural Network Toolkit. arXiv:1701.03980 [cs, stat] (2017).

  OO based dynamic compuation graph, with extra lightweight data structure and runtime
  optimizations.
- Tokui, S., Oono, K., Hido, S. & Clayton, J. Chainer: a Next-Generation Open Source Framework for
  Deep Learning. in Proceedings of workshop on machine learning systems (LearningSys) in the
  twenty-ninth annual conference on neural information processing systems (NIPS) (2015).
  
  OO based dynamic compuation graph (define-by-run), with some special runtime optimizations.
- Yuret, D. Knet: beginning deep learning with 100 lines of Julia. in Machine learning systems
  workshop at NIPS (2016).











