const std = @import("std");
// Stmt import
const Stmt = @import("stmt.zig");
const StmtNode = Stmt.StmtNode;

/// Used to store a program/script
/// Program -> Declarations*
const Module = @This();

/// Stores the name of this module
name: []const u8,
/// Stores all global variables and functions in this module
globals: std.ArrayList(StmtNode),
functions: std.ArrayList(StmtNode),

/// Init a new program stmt
pub fn init(name: []const u8, allocator: std.mem.Allocator) Module {
    return Module{
        .name = name,
        .globals = std.ArrayList(StmtNode).init(allocator),
        .functions = std.ArrayList(StmtNode).init(allocator),
    };
}

/// Print out this module
pub fn display(self: Module) void {
    std.debug.print("\n--- Module <{s}> ---\n", .{self.name});
    for (self.globalSlice()) |global| {
        global.display();
    }
    for (self.functionSlice()) |function| {
        function.display();
    }
    std.debug.print("--- End of <{s}> ---\n\n", .{self.name});
}

/// Return a slice of all globals in this module
pub fn globalSlice(self: Module) []StmtNode {
    return self.globals.items;
}

/// Return a slice of all functions in this module
pub fn functionSlice(self: Module) []StmtNode {
    return self.functions.items;
}

/// Add a new stmt node to the program
pub fn addStmt(self: *Module, stmt_node: StmtNode) !void {
    switch (stmt_node) {
        .GLOBAL => try self.globals.append(stmt_node),
        .FUNCTION => try self.functions.append(stmt_node),
        else => unreachable,
    }
}
