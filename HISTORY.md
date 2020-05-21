# Release 0.5

- Better printing (constants, unicode, special forms, types of results…)
- Some interface changes:
  - `getarguments` is renamed to `getcallarguments` (returning function argument nodes of a `NestedCallNode`)
  - New functions `getargument`, `getarguments`, `getfunction` return the respective parts of a call expression
    in call nodes
- Tracked values are snapshotted – i.e., values that are mutated during execution are recorded as
  they were at that point (that means `deepcopy`ing, where possible).  `getvalue` now returns the
  snapshotted value, while `getvalue_ref` returns the original, but should only be necessary for
  internal purposes.
- All `TapeExpr`s and `AbstractNode`s are now parametrized by the types of their children, improving
  type stability and allowing to dispatch on them
- `cglobal` calls are correctly treated as special forms, like `ccalls`
