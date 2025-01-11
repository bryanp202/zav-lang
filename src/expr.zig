const std = @import("std");

// Constants, types, and Symbol import
const Symbol = @import("symbols.zig");
const Value = Symbol.Value;

//**********************************************//
//          Expression nodes
//**********************************************//

/// Generic node for all expression types
pub const ExprNode = union(enum) {
    LITERAL: *LiteralExpr,
    NEGATE: *NegateExpr,
    NOT: *NotExpr,
    ADD: *AddExpr,
    SUB: *SubExpr,
    DIV: *DivExpr,
    MULTI: *MultiExpr,
    MOD: *ModExpr,
    ERROR: void,

    pub fn deinit(self: ExprNode, allocator: std.mem.Allocator) void {
        // Check type and call next level of deinit
        switch (self) {
            .LITERAL => |expr| allocator.destroy(expr),
            .NEGATE => |expr| expr.deinit(allocator),
            .NOT => |expr| expr.deinit(allocator),
            .ADD => |expr| expr.deinit(allocator),
            .SUB => |expr| expr.deinit(allocator),
            .DIV => |expr| expr.deinit(allocator),
            .MULTI => |expr| expr.deinit(allocator),
            else => return,
        }
    }
};

//**********************************************//
//          Literal node
//**********************************************//

/// Used to access a variable or a constant
pub const LiteralExpr = union(enum) {
    IDENTIFIER: []const u8,
    CONSTANT: Value,
};

//**********************************************//
//          Unary nodes
//**********************************************//

/// Negate a value
pub const NegateExpr = struct {
    rhs: ExprNode,

    fn deinit(self: *NegateExpr, allocator: std.mem.Allocator) void {
        self.rhs.deinit(allocator);
        allocator.destroy(self);
    }
};

/// Not a value
pub const NotExpr = struct {
    rhs: ExprNode,

    fn deinit(self: *NotExpr, allocator: std.mem.Allocator) void {
        self.rhs.deinit(allocator);
        allocator.destroy(self);
    }
};

//**********************************************//
//          Binary nodes
//**********************************************//

/// Add two values together
pub const AddExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,

    fn deinit(self: *AddExpr, allocator: std.mem.Allocator) void {
        // Deinit subnodes
        self.lhs.deinit(allocator);
        self.rhs.deinit(allocator);
        // Destory self
        allocator.destroy(self);
    }
};

/// Subtract two values
pub const SubExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,

    fn deinit(self: *SubExpr, allocator: std.mem.Allocator) void {
        // Deinit subnodes
        self.lhs.deinit(allocator);
        self.rhs.deinit(allocator);
        // Destory self
        allocator.destroy(self);
    }
};

/// Divide two values
pub const DivExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,

    fn deinit(self: *DivExpr, allocator: std.mem.Allocator) void {
        // Deinit subnodes
        self.lhs.deinit(allocator);
        self.rhs.deinit(allocator);
        // Destory self
        allocator.destroy(self);
    }
};

/// Multiply two values together
pub const MultiExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,

    fn deinit(self: *MultiExpr, allocator: std.mem.Allocator) void {
        // Deinit subnodes
        self.lhs.deinit(allocator);
        self.rhs.deinit(allocator);
        // Destory self
        allocator.destroy(self);
    }
};

/// Modulus two values together
pub const ModExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,

    fn deinit(self: *ModExpr, allocator: std.mem.Allocator) void {
        // Deinit subnodes
        self.lhs.deinit(allocator);
        self.rhs.deinit(allocator);
        // Destory self
        allocator.destroy(self);
    }
};
