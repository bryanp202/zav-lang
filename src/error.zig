/// Scope searching error type
pub const ScopeError = error{
    DuplicateDeclaration,
    UndeclaredSymbol,
};

/// Parsing Errors
pub const SyntaxError = error{
    UnexpectedSymbol,
    InvalidExpression,
};
