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

/// Type Checking Errors
pub const SemanticError = error{
    TypeMismatch,
    UnsafeCoercion,
    UnresolvableIdentifier,
};

/// Asm Generation Errors
pub const GenerationError = error{
    FailedToWrite,
};

/// General Compiler Errors
pub const CompilerError = error{
    AllocationFailed,
};
