unit DelphiFormatter.Syntax.Kinds;

interface

type
  TSyntaxKind = (skCompilationUnit, skExpressionRoot, skStatementRoot,
    skUnitDeclaration, skUsesClause, skBlockStatement, skIfStatement,
    skAssignmentStatement, skCallStatement, skEmptyStatement,
    skIdentifierExpression, skLiteralExpression, skParenthesizedExpression,
    skUnaryExpression, skBinaryExpression, skCallExpression,
    skError, skOpaqueRegion, skToken, skMissingToken,
    skConstSection, skConstDeclaration, skVarSection, skVarDeclaration,
    skTypeReference, skRoutineDeclaration, skRoutineHeader, skParameterList,
    skParameterDeclaration, skReturnType, skDirective,
    skMemberAccessExpression, skIndexExpression, skDereferenceExpression,
    skTypeSection, skTypeDeclaration, skClassDeclaration, skRecordDeclaration,
    skVisibilitySection, skFieldDeclaration, skMethodDeclaration, skAncestorList);

implementation

end.
