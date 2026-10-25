unit DelphiFormatter.Syntax.Kinds;

interface

type
  TSyntaxKind = (skCompilationUnit, skExpressionRoot, skStatementRoot,
    skUnitDeclaration, skUsesClause, skBlockStatement, skIfStatement,
    skAssignmentStatement, skCallStatement, skEmptyStatement,
    skIdentifierExpression, skLiteralExpression, skParenthesizedExpression,
    skUnaryExpression, skBinaryExpression, skCallExpression,
    skError, skOpaqueRegion, skToken, skMissingToken);

implementation

end.
