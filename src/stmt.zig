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

pub const StmtNode = union(enum) {
    MUTATE: *MutStmt,
    DECLARE: *DeclareStmt,
    EXPRESSION: *ExprStmt,

    /// Display a stmt
    pub fn display(self: StmtNode) void {
        // Display based off of self
        switch (self) {
            .MUTATE => |mutStmt| {
                std.debug.print("mut ", .{});
                mutStmt.id_expr.display();
                std.debug.print("{s} ", .{mutStmt.op.lexeme});
                mutStmt.assign_expr.display();
                std.debug.print(";\n", .{});
            },
            .DECLARE => |declareStmt| {
                if (declareStmt.mutable) {
                    std.debug.print("var {s}", .{declareStmt.id.lexeme});
                } else {
                    std.debug.print("const {s}", .{declareStmt.id.lexeme});
                }
                // Check if type is given
                if (declareStmt.kind) |kind| {
                    std.debug.print(": {any}", .{kind});
                }
                std.debug.print(" = ", .{});
                declareStmt.expr.display();
                std.debug.print(";\n", .{});
            },
            .EXPRESSION => |exprStmt| {
                exprStmt.expr.display();
                std.debug.print(";\n", .{});
            },
        }
    }
};

// ************** //
//   Stmt Structs //
// ************** //
/// Used to store an MutExpr
/// MutStmt -> identifier "=" expression ";"
pub const MutStmt = struct {
    id_expr: ExprNode,
    op: Token,
    assign_expr: ExprNode,

    /// Initialize an AssignStmt with an exprnode
    pub fn init(id_expr: ExprNode, op: Token, assign_expr: ExprNode) MutStmt {
        return MutStmt{
            .id_expr = id_expr,
            .op = op,
            .assign_expr = assign_expr,
        };
    }
};

/// Used to store an DeclareStmt
/// DeclareStmt -> ("const"|"var") identifier (":" type)? "=" expression ";"
pub const DeclareStmt = struct {
    mutable: bool,
    id: Token,
    kind: ?KindId,
    op: Token,
    expr: ExprNode,

    /// Initialize a DeclareStmt with an mutablity, identifier token, optional kind, and expr
    pub fn init(mutable: bool, id: Token, kind: ?KindId, op: Token, expr: ExprNode) DeclareStmt {
        return DeclareStmt{
            .mutable = mutable,
            .id = id,
            .kind = kind,
            .op = op,
            .expr = expr,
        };
    }
};

/// Used to store an ExprStmt
/// exprstmt -> expression ";"
pub const ExprStmt = struct {
    expr: ExprNode,

    /// Initialize an expr stmt with an exprnode
    pub fn init(expr: ExprNode) ExprStmt {
        return ExprStmt{ .expr = expr };
    }
};
