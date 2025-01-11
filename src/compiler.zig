const std = @import("std");

// Scanning and token import
const Scan = @import("front_end/scanner.zig");
const Scanner = Scan.Scanner;
const TokenKind = Scan.TokenKind;
const Token = Scan.Token;
// Parser and AST import
const Parser = @import("front_end/parser.zig");
// Values, constant, and symbols import
const Symbols = @import("symbols.zig");
const STM = Symbols.SymbolTableManager;
// Error Import
const Error = @import("error.zig");
const ScopeError = Error.ScopeError;

// Compiler fields
const Compiler = @This();
allocator: std.mem.Allocator,
stm: STM,

/// Initialize a managed compiler
pub fn init(allocator: std.mem.Allocator) Compiler {
    const symbol_table = STM.init(allocator);
    return .{
        .allocator = allocator,
        .stm = symbol_table,
    };
}
/// Deinitialize a managed compiler
pub fn deinit(self: *Compiler) void {
    self.stm.deinit();
}

/// Compile source code
pub fn compile(self: *Compiler, source: []const u8) void {
    // Make a scanner
    var scanner = Scanner.init(self.allocator, source);
    defer scanner.deinit();
    // Make a parser
    var parser = Parser.init(self.allocator, &scanner);

    // Parser into stage 1 AST
    const root = parser.parse();
    defer if (root) |rt| rt.deinit(self.allocator);

    // Output
    if (!parser.hadError() and root != null) {
        std.debug.print("AST: {any}\n", .{root.?});
    } else {
        std.debug.print("Had Error\n", .{});
    }
}
