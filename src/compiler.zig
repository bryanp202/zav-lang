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
/// ModStmt import
const Stmt = @import("stmt.zig");

// Compiler fields
const Compiler = @This();
arena: *std.heap.ArenaAllocator,
allocator: std.mem.Allocator,
// Fields for compiler flags
root_path: []const u8,
root_name: []const u8,
output_name: []const u8,
asm_name: []const u8,
show_ast: bool,
emit_asm: bool,

/// Initialize a managed compiler
pub fn init(
    setup_allocator: std.mem.Allocator,
    local_arena: *std.heap.ArenaAllocator,
    main_path: []const u8,
    output_name: []const u8,
    show_ast: bool,
    emit_asm: bool,
) Compiler {
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

    const root_path = std.fs.path.dirname(main_path) orelse "";

    return .{
        .arena = local_arena,
        .allocator = local_arena.*.allocator(),
        .root_path = root_path,
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
    var type_checker = TypeChecker.init(self.allocator);
    // Make modules list and root module
    var modules = std.StringHashMap(*Module).init(self.allocator);
    var root_module: Module = undefined;
    root_module = Module.init(self.allocator, "", Module.ModuleKind.ROOT, &root_module);
    modules.put(root_module.path, &root_module) catch unreachable;

    // Parse
    std.debug.print("Parsing...\n", .{});
    // Parse into it
    const root_dependencies = parser.parse(&root_module);

    // Output
    if (parser.hadError()) {
        std.debug.print("Had Syntax Error\n", .{});
        return false;
    }

    const Request = struct {
        requester: *Module,
        requests: []Stmt.ModStmt,
    };

    var requested_dependencies = std.ArrayList(Request).init(self.allocator);
    requested_dependencies.append(Request{ .requester = &root_module, .requests = root_dependencies }) catch unreachable;

    while (requested_dependencies.pop()) |request| {
        const requesting_module = request.requester;
        const request_slice = request.requests;

        for (request_slice) |mod_stmt| {
            const module_name = mod_stmt.module_name;

            const module_path = std.fmt.allocPrint(
                self.allocator,
                "{s}::{s}",
                .{ request.requester.path, module_name.lexeme },
            ) catch unreachable;

            const getOrPut = modules.getOrPut(module_path) catch unreachable;
            if (getOrPut.found_existing) {
                std.debug.print("Duplicate module: {s}\n", .{module_path});
                return false;
            }

            const dependency_source = openSourceFile(self.allocator, self.root_path, module_path) catch {
                std.debug.print("Could not open file at \'{s}\'\n", .{module_path});
                return false;
            };
            parser.reset(dependency_source);
            const new_module = self.allocator.create(Module) catch unreachable;
            new_module.* = Module.init(self.allocator, module_path, Module.ModuleKind.DEPENDENCY, &root_module);
            getOrPut.value_ptr.* = new_module;
            const sub_dependencies = parser.parse(new_module);

            requesting_module.add_dependency(
                new_module,
                module_name.lexeme,
                module_name.line,
                module_name.column,
                mod_stmt.public,
            );
            requested_dependencies.append(Request{ .requester = new_module, .requests = sub_dependencies }) catch unreachable;
        }
    }

    std.debug.print("Checking types...\n", .{});
    // Check types
    type_checker.check(&modules);

    if (type_checker.hadError()) {
        std.debug.print("Had Semantic Error\n", .{});
        return false;
    }
    std.debug.print("Types all good\n", .{});

    // Check if display ast is on
    if (self.show_ast) {
        // Print root module post type checking
        std.debug.print("Post type checking program:\n", .{});
        root_module.display();
    }

    // Generation
    var generator = Generator.open(self.allocator, &root_module.stm, self.asm_name) catch {
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

fn openSourceFile(allocator: std.mem.Allocator, root_path: []const u8, module_name: []const u8) ![]const u8 {
    var path_buffer: [1024]u8 = undefined;
    path_buffer[0] = '.';
    const replacement_size = std.mem.replacementSize(u8, module_name, "::", "/");

    const new_len = replacement_size + 5;
    if (new_len > path_buffer.len) {
        return Error.CompilerError.AllocationFailed;
    }
    _ = std.mem.replace(u8, module_name, "::", "/", path_buffer[1..]);
    std.mem.copyForwards(u8, path_buffer[new_len - 4 ..], ".zav");

    const path = path_buffer[0..new_len];

    //std.debug.print("Dependency path: {s}, module name {s}\n", .{ path, module_name });

    // Try to open file
    const directory = std.fs.openDirAbsolute(root_path, .{}) catch return Error.CompilerError.FileNotFound;
    const file = directory.openFile(path, .{}) catch return Error.CompilerError.FileNotFound;
    defer file.close();

    // Read file stats
    const file_stats = try file.stat();
    // Make input buffer
    const buffer = try allocator.alloc(u8, file_stats.size + 1);
    // Read file
    const contents = try file.reader().read(buffer);
    // Add null at end
    buffer[contents] = '\x00';
    return buffer;
}
