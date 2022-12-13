// Renaming dance

public typealias ValNode = Node

extension AST {

  public typealias Node = ValNode
  
}

/// A projection from a `TypedProgram` of an AST node along with all the non-syntax information
/// related to that node.
@dynamicMemberLookup
public struct TypedNode<ID: NodeIDProtocol> : Hashable {

  /// The program program of which this node is a notional part.
  fileprivate let program: TypedProgram

  /// The node's identity in `program.ast`.
  let id: ID

  /// Equality comparison; only check the node ID.
  public static func == (lhs: TypedNode<ID>, rhs: TypedNode<ID>) -> Bool {
      lhs.id == rhs.id
  }

  /// Hashes the value of `id` into `hasher`.
  public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
  }

}

/// An AST node with type information.
public typealias Typed<T: AST.Node> = TypedNode<NodeID<T>>

extension TypedProgram {
  /// Bundles `id` together with `self`.
  public subscript<TargetID: NodeIDProtocol>(_ id: TargetID) -> TypedNode<TargetID>
  {
    TypedNode(program: self, id: id)
  }
}

extension TypedNode where ID: ConcreteNodeID {
  
  /// The corresponding AST node.
  private var syntax: ID.Subject {
    program.ast[NodeID(id)!]
  }
  
  /// Accesses the given member of the corresponding AST node.
  subscript<Target>(dynamicMember m: KeyPath<ID.Subject, Target>) -> Target
  {
    syntax[keyPath: m]
  }
  
  /// Accesses the given member of the corresponding AST node as a corresponding
  /// `TypedNode`
  subscript<TargetID: NodeIDProtocol>(
    dynamicMember m: KeyPath<ID.Subject, TargetID>
  ) -> TypedNode<TargetID>
  {
    .init(program: program, id: syntax[keyPath: m])
  }
  
  /// Accesses the given member of the corresponding AST node as a corresponding lazy collection
  /// of `TypedNode`s.
  subscript<TargetID: NodeIDProtocol>(
    dynamicMember m: KeyPath<ID.Subject, [TargetID]>
  ) -> LazyMapCollection<[TargetID], TypedNode<TargetID>>
  {
    syntax[keyPath: m].lazy.map { .init(program: program, id: $0) }
  }
  
  /// Accesses the given member of the corresponding AST node as a corresponding `TypedNode?`
  subscript<TargetID: NodeIDProtocol>(
    dynamicMember m: KeyPath<ID.Subject, TargetID?>
  ) -> TypedNode<TargetID>?
  {
    syntax[keyPath: m].map { .init(program: program, id: $0) }
  }
  
  /// Creates an instance denoting the same node as `s`, or fails if `s` does not refer to a
  /// `Target` node.
  init?<SourceID, Target>(_ s: TypedNode<SourceID>)
     where ID == NodeID<Target>
  {
    guard let myID = NodeID<ID.Subject>(s.id) else { return nil }
    program = s.program
    id = .init(myID)
  }
}

extension TypedNode {
  
  /// The corresponding node kind.
  var kind: NodeKind { id.kind }

}

extension TypedNode where ID: ScopeID {
  /// The parent scope, if any
  var parent: TypedNode<AnyScopeID>? {
    program.scopeToParent[id].map { .init(program: program, id: $0) }
  }

  /// The declarations in this immediate scope.
  var decls: LazyMapCollection<[AnyDeclID], TypedNode<AnyDeclID>> {
    program.scopeToDecls[id, default: []].lazy.map { .init(program: program, id: $0) }
  }
}

extension TypedNode where ID: DeclID {
  /// The scope in which this declaration resides.
  var scope: TypedNode<AnyScopeID> {
    .init(program: program, id: program.declToScope[id]!)
  }

  /// The type of the declared entity.
  var type: AnyType {
    program.declTypes[id]!
  }

  /// The implicit captures for the declared entity.
  var implicitCaptures: [ImplicitCapture]? {
    program.implicitCaptures[id]
  }
}

extension TypedNode where ID == NodeID<VarDecl> {
  /// The binding decl containing this var.
  var binding: Typed<BindingDecl> {
    .init(program: program, id: program.varToBinding[id]!)
  }
}

extension TypedNode where ID: ExprID {
  /// The type of this expression
  var type: AnyType {
    program.exprTypes[id]!
  }
}

extension TypedNode where ID == NodeID<NameExpr> {
  enum Domain: Equatable {

    /// No domain.
    case none

    /// Domain is implicit; the expression denotes a type member.
    case implicit

    /// Domain is a value expression or a type identifier.
    case expr(TypedNode<AnyExprID>)

  }

  /// The domain of the name, if it is qualified.
  var domain: Domain {
    switch syntax.domain {
    case .none:
      return .none
    case .implicit:
      return .implicit
    case .expr(let expr):
      return .expr(program[expr])
    }
  }

  /// A reference to a declaration.
  enum DeclRef: Hashable {
    /// A direct reference.
    case direct(TypedNode<AnyDeclID>)

    /// A reference to a member declaration bound to `self`.
    case member(TypedNode<AnyDeclID>)

    /// Accesses the referred declaration.
    public var decl: TypedNode<AnyDeclID> {
      switch self {
      case .direct(let d): return d
      case .member(let d): return d
      }
    }
  }


  /// The declaration of this name.
  var decl: DeclRef {
    switch program.referredDecls[id]! {
      case .direct(let decl):
        return .direct(program[decl])
      case .member(let decl):
        return .member(program[decl])
    }
  }
}

extension TypedNode where ID: PatternID {
  /// The names associated with this pattern.
  var names: [(path: [Int], pattern: Typed<NamePattern>)] {
    program.ast.names(in: id).map({ (path: $0.path, pattern: program[$0.pattern]) })
  }
}

extension TypedNode where ID == NodeID<ModuleDecl> {
  /// Collection of (typed) top-level declarations of the module.
  typealias TopLevelDecls = LazyMapSequence<
        FlattenSequence<
            LazyMapSequence<
                [NodeID<TopLevelDeclSet>],
                [AnyDeclID]>>,
        TypedNode<AnyDeclID>>

  /// The top-level declarations in the module.
  var topLevelDecls: TopLevelDecls {
    program.ast.topLevelDecls(id).map({ program[$0] })
  }
}

extension TypedNode where ID == NodeID<FunctionDecl> {
  /// The body of the function, containing typed information
  enum Body {

    /// An expression body.
    case expr(TypedNode<AnyExprID>)

    /// A block body.
    case block(Typed<BraceStmt>)

  }

  /// The body of the declaration, if any (in typed formed).
  var body: Body? {
    switch syntax.body {
    case .expr(let expr):
      return .expr(program[expr])

    case .block(let stmt):
      return .block(program[stmt])

    case .none:
      return .none
    }
  }
}

extension TypedNode where ID == NodeID<SequenceExpr> {

  /// A map from (typed) sequence expressions to their evaluation order.
  var foldedSequenceExprs: FoldedSequenceExpr? {
    program.foldedSequenceExprs[id]
  }

}