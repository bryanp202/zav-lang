const std = @import("std");

// Scanning and token import
const Scan = @import("front_end/scanner.zig");
const Scanner = Scan.Scanner;
const TokenKind = Scan.TokenKind;
const Token = Scan.Token;
// Module import
const Module = @import("module.zig");
// Parser and AST import
const Parser = @import("front_end/parser.zig");
// Type checking
const TypeChecker = @import("front_end/type_checker.zig");
// Values, constant, and symbols import
const Symbols = @import("symbols.zig");
const STM = Symbols.SymbolTableManager;
// Code generation import
const Generator = @import("back_end/generator.zig");
// Error Import
const Error = @import("error.zig");
const ScopeError = Error.ScopeError;
const GenerationError = Error.GenerationError;

// Compiler fields
const Compiler = @This();
arena: *std.heap.ArenaAllocator,
allocator: std.mem.Allocator,
stm: STM,

/// Initialize a managed compiler
pub fn init(setup_allocator: std.mem.Allocator, local_arena: *std.heap.ArenaAllocator) Compiler {
    const symbol_table = STM.init(setup_allocator);
    return .{
        .arena = local_arena,
        .allocator = local_arena.*.allocator(),
        .stm = symbol_table,
    };
}

/// Deinit a managed compiler
pub fn reset(self: *Compiler) void {
    _ = self.arena.*.reset(.free_all);
}

/// Compile source text into assembly
pub fn compile(self: *Compiler, source: []const u8, keep_asm: bool) void {
    // Make assembly
    const asm_okay = self.compileToAsm(source);

    // If successfully made asm, assemble and link
    if (asm_okay) {
        // Assemble
        const as_args = [_][]const u8{ "nasm", "-f", "win64", ".\\out.asm" };
        const asm_result = std.process.Child.run(.{ .allocator = self.allocator, .argv = &as_args }) catch {
            std.debug.print("Failed to assemble file\n", .{});
            return;
        };

        // Check if asm was successful
        if (asm_result.term != .Exited or asm_result.term.Exited != 0) {
            std.debug.print("Failed to assemble file\n", .{});
            return;
        }
        std.debug.print("Successfully assembled\n", .{});

        // Link
        const link_args = [_][]const u8{ "gcc", ".\\out.obj", "-o", ".\\out.exe" }; // "-nostdlib", "-static" };
        const link_result = std.process.Child.run(.{ .allocator = self.allocator, .argv = &link_args }) catch {
            std.debug.print("Failed to link file\n", .{});
            return;
        };

        // Check if link was successful
        if (link_result.term != .Exited or asm_result.term.Exited != 0) {
            std.debug.print("Failed to assemble file\n", .{});
            return;
        }
        std.debug.print("Successfully linked\n", .{});

        // Delete obj file
        var cwd = std.fs.cwd();
        // Delete obj file
        cwd.deleteFile("out.obj") catch unreachable;
        // If keep assembly flag not used, delete .asm file
        if (!keep_asm) {
            cwd.deleteFile("out.asm") catch unreachable;
        }
    }
}

/// Compile source code
pub fn compileToAsm(self: *Compiler, source: []const u8) bool {
    // Make a scanner
    var scanner = Scanner.init(self.allocator, source);
    // Make a parser
    var parser = Parser.init(self.allocator, &scanner);
    // Make TypeChecker
    var type_checker = TypeChecker.init(self.allocator, &self.stm);

    // Make a new root module
    var root_module = Module.init("out", self.allocator);
    // Parse into it
    parser.parse(&root_module);

    // Output
    if (!parser.hadError()) {
        // Print program
        root_module.display();

        // Check types
        type_checker.check(&root_module);
        if (!type_checker.hadError()) {
            std.debug.print("Types all good\n", .{});
        } else {
            std.debug.print("Had Semantic Error\n", .{});
            return false;
        }
    } else {
        std.debug.print("Had Syntax Error\n", .{});
        return false;
    }

    // Print root module post type checking
    std.debug.print("Post type checking program:\n", .{});
    root_module.display();

    // Generation
    var generator = Generator.open(self.allocator, &self.stm, root_module.name) catch |err| {
        // switch (err) {
        //     error.FailedToWrite => std.debug.print("Failed to make file\n", .{}),
        //     error.OutOfCPURegisters => std.debug.print("Ran out of CPU registers\n", .{}),
        //     error.OutOfSSERegisters => std.debug.print("Ran out of SSE registers\n", .{}),
        // }
        std.debug.print("{any}\n", .{err});
        return false;
    };

    // Generate asm
    _ = generator.gen(root_module) catch {
        std.debug.print("Failed to write file\n", .{});
        return false;
    };

    // Close file
    generator.close(self.allocator) catch {
        std.debug.print("Failed to close file\n", .{});
        return false;
    };

    // Success
    return true;
}
