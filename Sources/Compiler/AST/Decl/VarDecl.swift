/// A variable declaration associated with a name in a binding declaration.
public struct VarDecl: Decl, SourceRepresentable {

  public var range: SourceRange?

  /// The identifier of the declared variable.
  public var identifier: Identifier

}