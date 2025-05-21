const std = @import("std");
// Stmt import
const Stmt = @import("stmt.zig");
const StmtNode = Stmt.StmtNode;
const Symbols = @import("symbols.zig");
const STM = Symbols.SymbolTableManager;

/// Used to store a program/script
/// Program -> Declarations*
const Module = @This();

/// Stores the name of this module
path: []const u8,
kind: ModuleKind,
/// Stores all global variables and functions in this module
uses: std.ArrayList(StmtNode),
globals: std.ArrayList(StmtNode),
functions: std.ArrayList(StmtNode),
structs: std.ArrayList(StmtNode),
enums: std.ArrayList(StmtNode),
/// Scope handlers
stm: STM,

pub const ModuleKind = enum {
    ROOT,
    DEPENDENCY,
};

/// Init a new program stmt
pub fn init(allocator: std.mem.Allocator, path: []const u8, module_kind: ModuleKind, global_module: *Module) Module {
    return Module{
        .path = path,
        .kind = module_kind,
        .uses = std.ArrayList(StmtNode).init(allocator),
        .globals = std.ArrayList(StmtNode).init(allocator),
        .functions = std.ArrayList(StmtNode).init(allocator),
        .structs = std.ArrayList(StmtNode).init(allocator),
        .enums = std.ArrayList(StmtNode).init(allocator),
        .stm = STM.init(allocator, global_module),
    };
}

pub fn add_dependency(self: *Module, dependency: *Module, name: []const u8, dcl_line: usize, dcl_column: usize, public: bool) void {
    self.stm.addDependency(dependency, name, dcl_line, dcl_column, public) catch unreachable;
}

/// Print out this module
pub fn display(self: Module) void {
    std.debug.print("\n--- Module <root{s}> ---\n", .{self.path});
    for (self.useSlice()) |use| {
        use.display();
    }
    for (self.enumSlice()) |enm| {
        enm.display();
    }
    for (self.structSlice()) |strct| {
        strct.display();
    }
    for (self.globalSlice()) |global| {
        global.display();
    }
    for (self.functionSlice()) |function| {
        function.display();
    }
    std.debug.print("--- End of <root{s}> ---\n\n", .{self.path});
}

/// Return a slice of all globals in this module
pub fn globalSlice(self: Module) []StmtNode {
    return self.globals.items;
}

/// Return a slice of all functions in this module
pub fn functionSlice(self: Module) []StmtNode {
    return self.functions.items;
}

/// Retern a slice of all struct definitions in this module
pub fn structSlice(self: Module) []StmtNode {
    return self.structs.items;
}

pub fn enumSlice(self: Module) []StmtNode {
    return self.enums.items;
}

pub fn useSlice(self: Module) []StmtNode {
    return self.uses.items;
}

/// Add a new stmt node to the program
pub fn addStmt(self: *Module, stmt_node: StmtNode) !void {
    switch (stmt_node) {
        .GLOBAL => try self.globals.append(stmt_node),
        .FUNCTION => try self.functions.append(stmt_node),
        .STRUCT => try self.structs.append(stmt_node),
        .ENUM => try self.enums.append(stmt_node),
        .MOD => {},
        .USE => try self.uses.append(stmt_node),
        else => unreachable,
    }
}
