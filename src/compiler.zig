const std = @import("std");

const Parse = @import("front_end/parser.zig");
const Scan = @import("front_end/scanner.zig");
const Symbols = @import("symbols.zig");
// Error Import
const Error = @import("error.zig");
const ScopeError = Error.ScopeError;

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

    // Add some constants
    const array = self.allocator.alloc(Symbols.Value, 2) catch unreachable;
    array[0] = Symbols.Value.newInt(-1, true, 32);
    array[1] = Symbols.Value.newInt(1002, true, 32);
    const dim = self.allocator.alloc(usize, 1) catch unreachable;
    dim[0] = 2;
    const cnst = Symbols.Value.newArr(Symbols.ValueKind.INT, dim, array);
    const cnst2 = Symbols.Value.newInt(21, true, 9);
    const cnst3 = Symbols.Value.newInt(21, false, 9);
    const cnst4 = Symbols.Value.newInt(21, false, 16);
    self.stm.addConstant(cnst);
    self.stm.addConstant(cnst);
    self.stm.addConstant(cnst);
    self.stm.addConstant(cnst2);
    self.stm.addConstant(cnst);
    self.stm.addConstant(cnst);
    self.stm.addConstant(cnst4);
    self.stm.addConstant(cnst3);
    self.stm.addConstant(cnst);
    self.stm.addConstant(cnst2);
    std.debug.print("Const: {s}\n", .{self.stm.getConstantId(cnst)});
    std.debug.print("Const: {s}\n", .{self.stm.getConstantId(cnst2)});
    std.debug.print("Const: {s}\n", .{self.stm.getConstantId(cnst4)});
    std.debug.print("Const: {s}\n", .{self.stm.getConstantId(cnst3)});

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
                const is_mut = true;
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
