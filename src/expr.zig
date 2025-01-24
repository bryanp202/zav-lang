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
    IDENTIFIER: *IdentifierExpr,
    LITERAL: *LiteralExpr,
    NATIVE: *NativeExpr,
    CONVERSION: *ConversionExpr,
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
            .result_kind = KindId.newVoid(),
            .expr = expr,
        };
    }

    pub fn initWithKind(expr: ExprUnion, kind: KindId) ExprNode {
        return ExprNode{
            .result_kind = kind,
            .expr = expr,
        };
    }

    pub fn deinit(self: ExprNode, allocator: std.mem.Allocator) void {
        // Deinit kindid
        self.result_kind.deinit(allocator);
        // Check type and call next level of deinit
        switch (self.expr) {
            .IDENTIFIER => |idExpr| allocator.destroy(idExpr),
            .LITERAL => |litExpr| allocator.destroy(litExpr),
            .CONVERSION => |convExpr| convExpr.deinit(allocator),
            .NATIVE => |nativeExpr| nativeExpr.deinit(allocator),
            .UNARY => |unaryExpr| unaryExpr.deinit(allocator),
            .ARITH => |arithExpr| arithExpr.deinit(allocator),
            .COMPARE => |compareExpr| compareExpr.deinit(allocator),
            .AND => |andExpr| andExpr.deinit(allocator),
            .OR => |orExpr| orExpr.deinit(allocator),
            .IF => |ifExpr| ifExpr.deinit(allocator),
        }
    }

    /// Used to display an AST in polish notation
    pub fn debugDisplay(self: ExprNode) void {
        switch (self.expr) {
            .IDENTIFIER => |idExpr| std.debug.print("{s}", .{idExpr.id.lexeme}),
            .LITERAL => |litExpr| std.debug.print("{s}", .{litExpr.literal.lexeme}),
            .CONVERSION => |convExpr| {
                std.debug.print("(", .{});
                convExpr.operand.debugDisplay();
                std.debug.print("->{any})", .{self.result_kind});
            },
            .NATIVE => |nativeExpr| {
                std.debug.print("{s}(", .{nativeExpr.name.lexeme});
                // Check if any args
                if (nativeExpr.args) |args| {
                    // Print each arg, seperated by ','
                    for (args) |arg| {
                        arg.debugDisplay();
                        std.debug.print(",", .{});
                    }
                }
                std.debug.print(")->{any}", .{self.result_kind});
            },
            .UNARY => |unaryExpr| {
                std.debug.print("(", .{});
                std.debug.print("{s}", .{unaryExpr.op.lexeme});
                unaryExpr.operand.debugDisplay();
                std.debug.print(")", .{});
            },
            .ARITH => |arithExpr| {
                std.debug.print("(", .{});
                arithExpr.lhs.debugDisplay();
                std.debug.print("{s}", .{arithExpr.op.lexeme});
                arithExpr.rhs.debugDisplay();
                std.debug.print(")", .{});
            },
            .COMPARE => |compareExpr| {
                std.debug.print("(", .{});
                compareExpr.lhs.debugDisplay();
                std.debug.print("{s}", .{compareExpr.op.lexeme});
                compareExpr.rhs.debugDisplay();
                std.debug.print(")", .{});
            },
            .AND => |andExpr| {
                std.debug.print("(", .{});
                andExpr.lhs.debugDisplay();
                std.debug.print(" and ", .{});
                andExpr.rhs.debugDisplay();
                std.debug.print(")", .{});
            },
            .OR => |orExpr| {
                std.debug.print("(", .{});
                orExpr.lhs.debugDisplay();
                std.debug.print(" or ", .{});
                orExpr.rhs.debugDisplay();
                std.debug.print(")", .{});
            },
            .IF => |ifExpr| {
                std.debug.print("(if(", .{});
                ifExpr.conditional.debugDisplay();
                std.debug.print(")", .{});
                ifExpr.then_branch.debugDisplay();
                std.debug.print(" else ", .{});
                ifExpr.else_branch.debugDisplay();
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
    operand: ExprNode,

    pub fn init(operand: ExprNode) ConversionExpr {
        return ConversionExpr{
            .operand = operand,
        };
    }

    pub fn deinit(self: *ConversionExpr, allocator: std.mem.Allocator) void {
        self.operand.deinit(allocator);
        allocator.destroy(self);
    }
};

//**********************************************//
//          Call nodes
//**********************************************//
/// Used to call a native function
pub const NativeExpr = struct {
    name: Token,
    args: ?[]ExprNode,

    pub fn init(name: Token, args: ?[]ExprNode) NativeExpr {
        return NativeExpr{
            .name = name,
            .args = args,
        };
    }

    pub fn deinit(self: *NativeExpr, allocator: std.mem.Allocator) void {
        // Check if any args
        if (self.args) |args| {
            // Destroy each argument
            for (args) |arg| {
                arg.deinit(allocator);
            }
            // Destory argument list
            allocator.free(args);
        }
        // Destry self
        allocator.destroy(self);
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

    fn deinit(self: *UnaryExpr, allocator: std.mem.Allocator) void {
        self.operand.deinit(allocator);
        allocator.destroy(self);
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

    /// Make a new Arithmatic Expr with a void return type
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token) ArithExpr {
        return ArithExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
        };
    }

    fn deinit(self: *ArithExpr, allocator: std.mem.Allocator) void {
        // Deinit subnodes
        self.lhs.deinit(allocator);
        self.rhs.deinit(allocator);
        // Destory self
        allocator.destroy(self);
    }
};

/// Compare operation on two operands and one operator.
/// ==,!=,>,>=,<,<=
pub const CompareExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,

    /// Make a new compare Expr with a void return type
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token) CompareExpr {
        return CompareExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
        };
    }

    fn deinit(self: *CompareExpr, allocator: std.mem.Allocator) void {
        // Deinit subnodes
        self.lhs.deinit(allocator);
        self.rhs.deinit(allocator);
        // Destory self
        allocator.destroy(self);
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

    fn deinit(self: *AndExpr, allocator: std.mem.Allocator) void {
        // Deinit subnodes
        self.lhs.deinit(allocator);
        self.rhs.deinit(allocator);
        // Destory self
        allocator.destroy(self);
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

    fn deinit(self: *OrExpr, allocator: std.mem.Allocator) void {
        // Deinit subnodes
        self.lhs.deinit(allocator);
        self.rhs.deinit(allocator);
        // Destory self
        allocator.destroy(self);
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

    fn deinit(self: *IfExpr, allocator: std.mem.Allocator) void {
        // Deinit subnodes
        self.conditional.deinit(allocator);
        self.then_branch.deinit(allocator);
        self.else_branch.deinit(allocator);
        // Destory self
        allocator.destroy(self);
    }
};
