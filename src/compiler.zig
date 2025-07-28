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
asm_names: std.ArrayList([]const u8),
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

    const root_path = std.fs.path.dirname(main_path) orelse "";

    return .{
        .arena = local_arena,
        .allocator = local_arena.*.allocator(),
        .root_path = root_path,
        .root_name = root_name,
        .output_name = trimmed_name,
        .show_ast = show_ast,
        .emit_asm = emit_asm,
        .asm_names = std.ArrayList([]const u8).init(setup_allocator),
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
        var obj_names = std.ArrayList([]const u8).init(self.allocator);
        // Assemble
        for (self.asm_names.items) |module| {
            std.debug.print("[File: \'{s}\'] Assembling...\n", .{module});

            var filename_iter = std.mem.splitScalar(u8, module, '.');
            const filename_no_ext = filename_iter.next() orelse "";
            const new_obj_name = std.fmt.allocPrint(
                self.allocator,
                "{s}\\{s}.obj",
                .{ self.root_path, filename_no_ext },
            ) catch unreachable;

            obj_names.append(new_obj_name) catch unreachable;

            const abs_asm_path = std.fmt.allocPrint(self.allocator, "{s}\\{s}", .{ self.root_path, module }) catch unreachable;

            const as_args = [_][]const u8{ "nasm", "-f", "win64", abs_asm_path, "-o", new_obj_name };
            const asm_result = std.process.Child.run(.{ .allocator = self.allocator, .argv = &as_args }) catch {
                std.debug.print("[File: \'{s}\'] Failed to assemble file\n", .{module});
                return;
            };

            // Check if asm was successful
            if (asm_result.term != .Exited or asm_result.term.Exited != 0) {
                std.debug.print("[File: \'{s}\'] Failed to assemble file\n", .{module});
                return;
            }
        }
        std.debug.print("Successfully assembled\n", .{});

        // Link
        std.debug.print("Linking...\n", .{});
        const output_path = std.fmt.allocPrint(self.allocator, "{s}\\{s}", .{
            self.root_path,
            self.output_name,
        }) catch unreachable;
        std.debug.print("Outputting to: \"{s}\"\n", .{output_path});
        var base_link_args = [_][]const u8{ "gcc", "-nostartfiles", "-o", output_path, "-Wl,-e_start" };

        // Concat with obj file args
        const link_args = std.mem.concat(self.allocator, []const u8, &[_][][]const u8{
            &base_link_args,
            obj_names.items,
        }) catch unreachable;

        const link_result = std.process.Child.run(.{ .allocator = self.allocator, .argv = link_args }) catch {
            std.debug.print("Failed to link file\n", .{});

            // Delete obj files
            deleteObjFiles(obj_names);
            return;
        };

        // Check if link was successful
        if (link_result.term != .Exited or link_result.term.Exited != 0) {
            std.debug.print("Failed to link file\n", .{});
            std.debug.print("{s}\n", .{link_result.stderr});
            // Delete obj file
            deleteObjFiles(obj_names);
            return;
        }
        std.debug.print("Successfully linked\n", .{});

        // Delete obj file
        deleteObjFiles(obj_names);
        // If keep assembly flag not used, delete .asm file
        if (!self.emit_asm) {
            self.deleteAsmFiles();
        }
    }
}

fn deleteAsmFiles(self: Compiler) void {
    for (self.asm_names.items) |asm_file| {
        const dir = std.fs.openDirAbsolute(self.root_path, .{}) catch unreachable;
        dir.deleteFile(asm_file) catch unreachable;
    }
}

fn deleteObjFiles(obj_names: std.ArrayList([]const u8)) void {
    for (obj_names.items) |obj_file| {
        _ = std.fs.deleteFileAbsolute(obj_file) catch {};
    }
}

/// Compile source code
pub fn compileToAsm(self: *Compiler, source: []const u8) bool {
    // Make a scanner
    var scanner = Scanner.init(self.allocator, source);
    // Make a parser
    var parser = Parser.init(self.allocator, &scanner, "");
    // Make TypeChecker
    var type_checker = TypeChecker.init(self.allocator);
    // Make modules list and root module
    var modules = std.StringHashMap(*Module).init(self.allocator);
    var root_module: Module = undefined;
    root_module = Module.init(self.allocator, "", Module.ModuleKind.ROOT, &root_module, null);
    root_module.stm.setParentModule(&root_module);
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
                "{s}__{s}",
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
            parser.reset(dependency_source, module_path);
            const new_module = self.allocator.create(Module) catch unreachable;
            new_module.* = Module.init(self.allocator, module_path, Module.ModuleKind.DEPENDENCY, &root_module, requesting_module);
            new_module.stm.setParentModule(new_module);
            getOrPut.value_ptr.* = new_module;
            const sub_dependencies = parser.parse(new_module);

            if (parser.hadError()) {
                std.debug.print("Had Syntax Error\n", .{});
                return false;
            }

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
        var module_iter = modules.iterator();
        while (module_iter.next()) |entry| {
            const module = entry.value_ptr.*;
            module.display();
        }
    }

    // Generation
    var module_iter = modules.iterator();
    while (module_iter.next()) |entry| {
        const module = entry.value_ptr.*;
        const module_asm_path = std.fmt.allocPrint(self.allocator, "{s}{s}.asm", .{ self.root_name, module.path }) catch unreachable;
        _ = std.mem.replace(u8, module_asm_path, "::", "__", module_asm_path);
        self.asm_names.append(module_asm_path) catch unreachable;
        const module_path = std.fmt.allocPrint(self.allocator, "{s}", .{module.path}) catch unreachable;
        _ = std.mem.replace(u8, module_path, "::", "__", module_path);

        var generator = Generator.open(
            self.allocator,
            &module.stm,
            self.root_path,
            module_asm_path,
            module_path,
            module.kind,
            module.stm.extern_dependencies,
        ) catch {
            std.debug.print("[Module <root{s}>] Failed to write file\n", .{module.path});
            return false;
        };

        std.debug.print("[Module <root{s}>] Generating assembly...\n", .{module.path});
        // Generate asm
        _ = generator.genModule(module.*) catch {
            std.debug.print("[Module <root{s}>] Failed to write file\n", .{module.path});
            return false;
        };

        // Close file
        generator.close() catch {
            std.debug.print("[Module <root{s}>] Failed to close file\n", .{module.path});
            return false;
        };
    }

    // Success
    return true;
}

fn openSourceFile(allocator: std.mem.Allocator, root_path: []const u8, module_name: []const u8) ![]const u8 {
    var path_buffer: [1024]u8 = undefined;
    path_buffer[0] = '.';
    const replacement_size = std.mem.replacementSize(u8, module_name, "__", "/");

    const new_len = replacement_size + 5;
    if (new_len > path_buffer.len) {
        return Error.CompilerError.AllocationFailed;
    }
    _ = std.mem.replace(u8, module_name, "__", "/", path_buffer[1..]);
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
