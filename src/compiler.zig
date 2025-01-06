const std = @import("std");

const Parse = @import("front_end/parser.zig");
const Scan = @import("front_end/scanner.zig");
const Symbols = @import("symbols.zig");

const Compiler = @This();
allocator: std.mem.Allocator,
stm: Symbols.SymbolTableManager,

/// Initialize a managed compiler
pub fn init(allocator: std.mem.Allocator) Compiler {
    const symbol_table = Symbols.SymbolTableManager.init(allocator);
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
    var scanner = Scan.Scanner.init(self.allocator, source);
    defer scanner.deinit();

    var token = scanner.nextToken();
    var previous: Scan.Token = undefined;
    while (token.kind != Scan.TokenKind.EOF) {
        // std.debug.print("Token: {any}\n", .{token});
        if (token.kind == Scan.TokenKind.IDENTIFIER) {
            if (previous.kind == Scan.TokenKind.CONST) {
                // Make new KindId and stuff to declare
                const child_child_child = Symbols.KindId.newInt(64, false);
                const child_child = Symbols.KindId.newArr(self.allocator, child_child_child, 13);
                const child = Symbols.KindId.newPtr(self.allocator, child_child, 97);
                const kind = Symbols.KindId.newArr(self.allocator, child, 913);
                const is_mut = false;
                const scope = Symbols.ScopeKind.GLOBAL;

                // Declare it
                self.stm.declareSymbol(token.lexeme, kind, scope, token.line, is_mut) catch |err| {
                    std.debug.print("{any}\n", .{err});
                    previous = token;
                    token = scanner.nextToken();
                    continue;
                };
                std.debug.print("Declared name: {s}\n", .{token.lexeme});
            }

            const symbol = self.stm.getSymbol(token.lexeme) catch |err| {
                std.debug.print("{any}\n", .{err});
                previous = token;
                token = scanner.nextToken();
                continue;
            };
            std.debug.print("Symbol: {}\n", .{symbol});
        } else if (token.kind == Scan.TokenKind.LEFT_BRACE) {
            // Enter new scope
            self.stm.addScope();
        } else if (token.kind == Scan.TokenKind.RIGHT_BRACE) {
            // Exit scope
            self.stm.popScope();
        }
        previous = token;
        token = scanner.nextToken();
    }
}
