/// Scope searching error type
pub const ScopeError = error{
    DuplicateDeclaration,
    UndeclaredSymbol,
    InvalidScope,
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
    DuplicateDeclaration,
    InvalidControlFlow,
    UnmutatedVarIdentifier,
    FoundMainFunction,
    InvalidMainFunction,
};

/// Asm Generation Errors
pub const GenerationError = error{
    FailedToWrite,
    OutOfRegisters,
};

/// General Compiler Errors
pub const CompilerError = error{
    AllocationFailed,
    FileNotFound,
};
