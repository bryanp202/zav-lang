const std = @import("std");
// Stmt import
const Stmt = @import("stmt.zig");
const StmtNode = Stmt.StmtNode;

/// Used to store a program/script
/// Program -> Declarations*
const Module = @This();

/// Stores the name of this module
name: []const u8,
/// Stores all declarations in this module
declarations: std.ArrayList(StmtNode),

/// Init a new program stmt
pub fn init(name: []const u8, allocator: std.mem.Allocator) Module {
    return Module{
        .name = name,
        .declarations = std.ArrayList(StmtNode).init(allocator),
    };
}

/// Print out this module
pub fn display(self: Module) void {
    std.debug.print("\n--- Module <{s}> ---\n", .{self.name});
    for (self.stmts()) |stmt| {
        stmt.display();
    }
    std.debug.print("--- End of <{s}> ---\n\n", .{self.name});
}

/// Return a slice of all stmts in this module
pub fn stmts(self: Module) []StmtNode {
    return self.declarations.items;
}

/// Add a new stmt node to the program
pub fn addStmt(self: *Module, stmt_node: StmtNode) !void {
    try self.declarations.append(stmt_node);
}
