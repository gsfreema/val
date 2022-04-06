/// A map literal expression.
public struct MapLiteralExpr: Expr {

  public var range: SourceRange?

  /// The key-value pairs of the literal.
  public var elements: [(key: Expr, value: Expr)]

}