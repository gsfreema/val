/// An error encountered during type checking.
struct TypeError {

  /// The kind of a type error.
  enum Kind {

    /// The type does not conform to `traits` in `scope`.
    case doesNotConform(Type, traits: Set<TraitType>, scope: AnyNodeID)

    /// The associated constraint went stale.
    case staleConstaint

  }

  /// The kind of the error.
  var kind: Kind

  /// The constraint that cause the type error.
  var cause: LocatableConstraint

}