/// A data structure representing a typed Val program ready to be lowered.
public struct TypedProgram: Program {

  public let ast: AST

  public let scopeToParent: ASTProperty<AnyScopeID>

  public let scopeToDecls: ASTProperty<[AnyDeclID]>

  public let declToScope: DeclProperty<AnyScopeID>

  public let exprToScope: [NameExpr.ID: AnyScopeID]

  public let varToBinding: [VarDecl.ID: BindingDecl.ID]

  /// A map from translation unit to its imports.
  public let imports: [TranslationUnit.ID: Set<ModuleDecl.ID>]

  /// The overarching type of each declaration.
  public let declTypes: DeclProperty<AnyType>

  /// The type of each expression.
  public let exprTypes: ExprProperty<AnyType>

  /// A map from function and subscript declarations to their implicit captures.
  public let implicitCaptures: DeclProperty<[ImplicitCapture]>

  /// A map from generic declarations to their environment.
  public let environments: DeclProperty<GenericEnvironment>

  /// A map from module to its synthesized declarations.
  public let synthesizedDecls: [ModuleDecl.ID: [SynthesizedDecl]]

  /// A map from name expression to its referred declaration.
  public let referredDecls: [NameExpr.ID: DeclReference]

  /// A map from sequence expressions to their evaluation order.
  public let foldedSequenceExprs: [SequenceExpr.ID: FoldedSequenceExpr]

  /// The type relations of the program.
  public let relations: TypeRelations

  /// Val's core library.
  public var coreLibrary: ModuleDecl.Typed? {
    ast.coreLibrary.map({ self[$0] })
  }

  /// Creates a typed program from a scoped program and property maps describing type annotations.
  ///
  /// - Requires: All modules in `program` have been sucessfully typed checked.
  public init(
    annotating program: ScopedProgram,
    imports: [TranslationUnit.ID: Set<ModuleDecl.ID>],
    declTypes: DeclProperty<AnyType>,
    exprTypes: ExprProperty<AnyType>,
    implicitCaptures: DeclProperty<[ImplicitCapture]>,
    environments: DeclProperty<GenericEnvironment>,
    synthesizedDecls: [ModuleDecl.ID: [SynthesizedDecl]],
    referredDecls: [NameExpr.ID: DeclReference],
    foldedSequenceExprs: [SequenceExpr.ID: FoldedSequenceExpr],
    relations: TypeRelations
  ) {
    precondition(program.ast.modules.allSatisfy({ declTypes[$0]?.base is ModuleType }))

    self.ast = program.ast
    self.scopeToParent = program.scopeToParent
    self.scopeToDecls = program.scopeToDecls
    self.declToScope = program.declToScope
    self.exprToScope = program.exprToScope
    self.varToBinding = program.varToBinding
    self.imports = imports
    self.declTypes = declTypes
    self.exprTypes = exprTypes
    self.implicitCaptures = implicitCaptures
    self.environments = environments
    self.synthesizedDecls = synthesizedDecls
    self.referredDecls = referredDecls
    self.foldedSequenceExprs = foldedSequenceExprs
    self.relations = relations
  }

  /// Returns the declarations of `d`' captures.
  ///
  /// If `d` is a member function, its receiver is its only capture. Otherwise, its explicit
  /// captures come first, in the order they appear in its capture list, from left to right.
  /// Implicit captures come next, in the order they were found during type checking.
  public func captures(of d: FunctionDecl.ID) -> [AnyDeclID] {
    var result: [AnyDeclID] = []
    if let r = ast[d].receiver {
      result.append(AnyDeclID(r))
    } else {
      result.append(contentsOf: ast[d].explicitCaptures.map(AnyDeclID.init(_:)))
      result.append(contentsOf: implicitCaptures[d]!.map(\.decl))
    }
    return result
  }

  /// Returns the declarations of `d`' captures.
  ///
  /// If `d` is a member subscript, its receiver is its only capture. Otherwise, its explicit
  /// captures come first, in the order they appear in its capture list, from left to right.
  /// Implicit captures come next, in the order they were found during type checking.
  public func captures(of d: SubscriptImpl.ID) -> [AnyDeclID] {
    var result: [AnyDeclID] = []
    if let r = ast[d].receiver {
      result.append(AnyDeclID(r))
    } else {
      let bundle = SubscriptDecl.ID(declToScope[d]!)!
      result.append(contentsOf: ast[bundle].explicitCaptures.map(AnyDeclID.init(_:)))
      result.append(contentsOf: implicitCaptures[bundle]!.map(\.decl))
    }
    return result
  }

}
