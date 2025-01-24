const std = @import("std");

// Constants, types, and Symbol import
const Symbol = @import("symbols.zig");
const Value = Symbol.Value;
const KindId = Symbol.KindId;
// Token
const Token = @import("front_end/scanner.zig").Token;
// Expr
const Expr = @import("expr.zig");
const ExprNode = Expr.ExprNode;

pub const StmtUnion = union(enum) {
    EXPRESSION: ExprNode,
};
