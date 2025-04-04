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
// Fields for compiler flags
root_name: []const u8,
output_name: []const u8,
asm_name: []const u8,
show_ast: bool,
emit_asm: bool,

/// Initialize a managed compiler
pub fn init(
    setup_allocator: std.mem.Allocator,
    local_arena: *std.heap.ArenaAllocator,
    output_name: []const u8,
    show_ast: bool,
    emit_asm: bool,
) Compiler {
    // Set up stm
    const symbol_table = STM.init(setup_allocator);

    // Get assembly path name
    var output_no_dot = std.mem.splitSequence(u8, output_name, "./");
    var trimmed_name = output_no_dot.next().?;
    // Check if empty or not
    if (trimmed_name.len == 0) {
        // Try to get what is after "./" else use "out"
        trimmed_name = output_no_dot.next() orelse "out";
    }

    // Split based on '.'
    var output_name_iter = std.mem.splitScalar(u8, trimmed_name, '.');
    const root_name = output_name_iter.next().?;
    // Get asm name
    const asm_name = std.fmt.allocPrint(setup_allocator, "{s}.asm", .{root_name}) catch unreachable;

    return .{
        .arena = local_arena,
        .allocator = local_arena.*.allocator(),
        .stm = symbol_table,
        .root_name = root_name,
        .output_name = trimmed_name,
        .asm_name = asm_name,
        .show_ast = show_ast,
        .emit_asm = emit_asm,
    };
}

/// Deinit a managed compiler
pub fn reset(self: *Compiler) void {
    _ = self.arena.*.reset(.free_all);
}

/// Compile source text into assembly
pub fn compile(self: *Compiler, source: []const u8) void {
    // Make assembly
    const asm_okay = self.compileToAsm(source);

    // If successfully made asm, assemble and link
    if (asm_okay) {
        // Assemble
        std.debug.print("Assembling...\n", .{});
        const as_args = [_][]const u8{ "nasm", "-f", "win64", self.asm_name, "-o", "zav_temp.obj" };
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

        // Get cwd to delete obj file
        var cwd = std.fs.cwd();
        // Link
        std.debug.print("Linking...\n", .{});
        const link_args = [_][]const u8{ "gcc", "-s", "-nostartfiles", "-static", "zav_temp.obj", "-o", self.output_name };
        const link_result = std.process.Child.run(.{ .allocator = self.allocator, .argv = &link_args }) catch {
            std.debug.print("Failed to link file\n", .{});

            // Delete obj file
            cwd.deleteFile("zav_temp.obj") catch unreachable;
            return;
        };

        // Check if link was successful
        if (link_result.term != .Exited or link_result.term.Exited != 0) {
            std.debug.print("Failed to link file\n", .{});
            // Delete obj file
            cwd.deleteFile("zav_temp.obj") catch unreachable;
            return;
        }
        std.debug.print("Successfully linked\n", .{});

        // Delete obj file
        cwd.deleteFile("zav_temp.obj") catch unreachable;
        // If keep assembly flag not used, delete .asm file
        if (!self.emit_asm) {
            cwd.deleteFile(self.asm_name) catch unreachable;
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
    var root_module = Module.init(self.root_name, self.allocator);

    // Parse
    std.debug.print("Parsing...\n", .{});
    // Parse into it
    parser.parse(&root_module);

    // Output
    if (!parser.hadError()) {
        // Print program
        //if (self.show_ast) {
        //    root_module.display();
        //}

        std.debug.print("Checking types...\n", .{});
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

    // Check if display ast is on
    if (self.show_ast) {
        // Print root module post type checking
        std.debug.print("Post type checking program:\n", .{});
        root_module.display();
    }

    // Generation
    var generator = Generator.open(self.allocator, &self.stm, self.asm_name) catch {
        std.debug.print("Failed to write file\n", .{});
        return false;
    };

    std.debug.print("Generating assembly...\n", .{});
    // Generate asm
    _ = generator.genModule(root_module) catch {
        std.debug.print("Failed to write file\n", .{});
        return false;
    };

    // Close file
    generator.close() catch {
        std.debug.print("Failed to close file\n", .{});
        return false;
    };

    // Success
    return true;
}
