const std = @import("std");

// Constants, types, and Symbol import
const Symbol = @import("symbols.zig");
const Value = Symbol.Value;
const KindId = Symbol.KindId;
// Token
const Token = @import("front_end/scanner.zig").Token;

//**********************************************//
//          Expression Node
//**********************************************//

pub const ExprUnion = union(enum) {
    SCOPE: *ScopeExpr,
    IDENTIFIER: *IdentifierExpr,
    LITERAL: *LiteralExpr,
    NATIVE: *NativeExpr,
    CONVERSION: *ConversionExpr,
    DEREFERENCE: *DereferenceExpr,
    FIELD: *FieldExpr,
    CALL: *CallExpr,
    INDEX: *IndexExpr,
    UNARY: *UnaryExpr,
    ARITH: *ArithExpr,
    COMPARE: *CompareExpr,
    AND: *AndExpr,
    OR: *OrExpr,
    IF: *IfExpr,
};

/// Generic node for all expression types
pub const ExprNode = struct {
    result_kind: KindId,
    expr: ExprUnion,

    pub fn init(expr: ExprUnion) ExprNode {
        return ExprNode{
            .result_kind = KindId.VOID,
            .expr = expr,
        };
    }

    pub fn initWithKind(expr: ExprUnion, kind: KindId) ExprNode {
        return ExprNode{
            .result_kind = kind,
            .expr = expr,
        };
    }

    /// Used to display an AST in polish notation
    pub fn display(self: ExprNode) void {
        switch (self.expr) {
            .SCOPE => |scopeExpr| {
                std.debug.print("{s}::", .{scopeExpr.scope.lexeme});
                scopeExpr.operand.display();
            },
            .IDENTIFIER => |idExpr| {
                std.debug.print("{s}", .{idExpr.id.lexeme});
                if (idExpr.scope_kind == .ARG or idExpr.scope_kind == .LOCAL) {
                    std.debug.print("(at [rbp+{d}])", .{idExpr.stack_offset});
                }
            },
            .LITERAL => |litExpr| std.debug.print("{s}", .{litExpr.literal.lexeme}),
            .CONVERSION => |convExpr| {
                //std.debug.print("(", .{});
                convExpr.operand.display();
                //std.debug.print("->{any})", .{self.result_kind});
            },
            .NATIVE => |nativeExpr| {
                std.debug.print("{s}(", .{nativeExpr.name.lexeme});
                // Check if any args
                // Print each arg, seperated by ','
                for (nativeExpr.args) |arg| {
                    arg.display();
                    std.debug.print(",", .{});
                }
                std.debug.print(")", .{});
                //std.debug.print(")->{any}", .{self.result_kind});
            },
            .DEREFERENCE => |derefExpr| {
                derefExpr.operand.display();
                std.debug.print(".*", .{});
            },
            .FIELD => |fieldExpr| {
                fieldExpr.operand.display();
                std.debug.print(".{s}", .{fieldExpr.field_name.lexeme});
                if (fieldExpr.method_name == null) {
                    std.debug.print("(at [base+{d}])", .{fieldExpr.stack_offset});
                }
            },
            .CALL => |callExpr| {
                // Print caller expr
                callExpr.caller_expr.display();
                std.debug.print("(", .{});
                // Check if any args
                // Print each arg, seperated by ','
                for (callExpr.args) |arg| {
                    arg.display();
                    std.debug.print(",", .{});
                }
                std.debug.print(")", .{});
                //std.debug.print(")->{any}", .{self.result_kind});
            },
            .INDEX => |indexExpr| {
                std.debug.print("(", .{});
                indexExpr.lhs.display();
                std.debug.print("[", .{});
                indexExpr.rhs.display();
                std.debug.print("])", .{});
            },
            .UNARY => |unaryExpr| {
                std.debug.print("(", .{});
                std.debug.print("{s}", .{unaryExpr.op.lexeme});
                unaryExpr.operand.display();
                std.debug.print(")", .{});
            },
            .ARITH => |arithExpr| {
                std.debug.print("(", .{});
                arithExpr.lhs.display();
                std.debug.print("{s}", .{arithExpr.op.lexeme});
                arithExpr.rhs.display();
                std.debug.print(")", .{});
            },
            .COMPARE => |compareExpr| {
                std.debug.print("(", .{});
                compareExpr.lhs.display();
                std.debug.print("{s}", .{compareExpr.op.lexeme});
                compareExpr.rhs.display();
                std.debug.print(")", .{});
            },
            .AND => |andExpr| {
                std.debug.print("(", .{});
                andExpr.lhs.display();
                std.debug.print(" and ", .{});
                andExpr.rhs.display();
                std.debug.print(")", .{});
            },
            .OR => |orExpr| {
                std.debug.print("(", .{});
                orExpr.lhs.display();
                std.debug.print(" or ", .{});
                orExpr.rhs.display();
                std.debug.print(")", .{});
            },
            .IF => |ifExpr| {
                std.debug.print("(", .{});
                ifExpr.conditional.display();
                std.debug.print("?", .{});
                ifExpr.then_branch.display();
                std.debug.print(":", .{});
                ifExpr.else_branch.display();
                std.debug.print(")", .{});
            },
        }
    }
};

//**********************************************//
//          Literal/Identifier nodes
//**********************************************//

/// Used to access a variable or a constant
pub const IdentifierExpr = struct {
    id: Token,
    scope_kind: Symbol.ScopeKind = undefined,
    stack_offset: u64 = undefined,
    lexical_scope: []const u8,
};

/// Used to access a variable or a constant
pub const LiteralExpr = struct {
    value: Value,
    literal: Token,
};

//**********************************************//
//          Type conversion nodes
//**********************************************//
/// Used to convert between types
pub const ConversionExpr = struct {
    op: Token,
    operand: ExprNode,

    pub fn init(op: Token, operand: ExprNode) ConversionExpr {
        return ConversionExpr{
            .op = op,
            .operand = operand,
        };
    }
};

//**********************************************//
//          Call nodes
//**********************************************//
/// Used to call a native function
pub const NativeExpr = struct {
    name: Token,
    args: []ExprNode,
    arg_kinds: []KindId,

    pub fn init(name: Token, args: []ExprNode) NativeExpr {
        return NativeExpr{
            .name = name,
            .args = args,
            .arg_kinds = null,
        };
    }
};

/// Used to call a user defined function
pub const CallExpr = struct {
    caller_expr: ExprNode,
    op: Token,
    args: []ExprNode,

    pub fn init(caller_expr: ExprNode, op: Token, args: []ExprNode) CallExpr {
        return CallExpr{
            .caller_expr = caller_expr,
            .op = op,
            .args = args,
        };
    }
};

//**********************************************//
//          Access nodes
//**********************************************//

/// Scope through the stm
pub const ScopeExpr = struct {
    scope: Token,
    op: Token,
    operand: ExprNode,

    pub fn init(scope: Token, op: Token, operand: ExprNode) ScopeExpr {
        return ScopeExpr{
            .scope = scope,
            .op = op,
            .operand = operand,
        };
    }
};

/// Operation for accessing a struct field
pub const FieldExpr = struct {
    operand: ExprNode,
    field_name: Token,
    op: Token,
    stack_offset: u64 = undefined,
    method_name: ?[]const u8 = null,

    /// Make a new FieldExpr
    pub fn init(operand: ExprNode, field_name: Token, op: Token) FieldExpr {
        return FieldExpr{
            .operand = operand,
            .field_name = field_name,
            .op = op,
        };
    }
};

/// Operation for dereferencing a pointer
pub const DereferenceExpr = struct {
    operand: ExprNode,
    op: Token,

    /// Make a new Dereference Expr
    pub fn init(operand: ExprNode, op: Token) DereferenceExpr {
        return DereferenceExpr{
            .operand = operand,
            .op = op,
        };
    }
};

/// Operation for accessing an index
pub const IndexExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,
    // Marked true if evaluation order was swapped
    reversed: bool,

    /// Make a new Index Expression
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token, reversed: bool) IndexExpr {
        return IndexExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
            .reversed = reversed,
        };
    }
};

//**********************************************//
//          Unary node
//**********************************************//

/// Operation on one operand and one operator
pub const UnaryExpr = struct {
    operand: ExprNode,
    op: Token,

    pub fn init(operand: ExprNode, op: Token) UnaryExpr {
        return UnaryExpr{
            .operand = operand,
            .op = op,
        };
    }
};

//**********************************************//
//          Binary nodes
//**********************************************//

/// Arithmatic operation on two operands and one operator.
/// +-*/%
pub const ArithExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,
    // Marked true if evaluation order was swapped
    reversed: bool,

    /// Make a new Arithmatic Expr with a void return type
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token, reversed: bool) ArithExpr {
        return ArithExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
            .reversed = reversed,
        };
    }
};

/// Compare operation on two operands and one operator.
/// ==,!=,>,>=,<,<=
pub const CompareExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,
    // Marked true if evaluation order was swapped
    reversed: bool,

    /// Make a new compare Expr with a void return type
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token, reversed: bool) CompareExpr {
        return CompareExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
            .reversed = reversed,
        };
    }
};

//**********************************************//
//          Logical nodes
//**********************************************//

/// Logic operation on two operands and one operator.
/// and or
pub const AndExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,

    /// Make a new Logic Expr with a void return type
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token) AndExpr {
        return AndExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
        };
    }
};

pub const OrExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,

    /// Make a new Logic Expr with a void return type
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token) OrExpr {
        return OrExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
        };
    }
};

//**********************************************//
//          Ternary node
//**********************************************//

/// Operation on three operands and two operators
pub const IfExpr = struct {
    conditional: ExprNode,
    then_branch: ExprNode,
    else_branch: ExprNode,
    if_token: Token,

    /// Make a new If Expr with a void return type
    pub fn init(if_token: Token, conditional: ExprNode, then_branch: ExprNode, else_branch: ExprNode) IfExpr {
        return IfExpr{
            .if_token = if_token,
            .conditional = conditional,
            .then_branch = then_branch,
            .else_branch = else_branch,
        };
    }
};
