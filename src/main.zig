const std = @import("std");
const Compiler = @import("compiler.zig");
// Global const
const REPL_BUFF_LEN = 1001;

pub fn main() !void {
    // Start of execution time marker
    const start = std.time.nanoTimestamp();
    // Defer message about length
    defer {
        const total_time = std.time.nanoTimestamp() - start;
        std.debug.print("Time to run: {d} s\n", .{@as(f64, @floatFromInt(total_time)) / 1000000000.0});
    }

    // Stdio
    const stdout = std.io.getStdOut().writer();
    // Alloc
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const global_allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(global_allocator);
    const setup_allocator = arena.allocator();
    defer {
        arena.deinit();
        const maybeLeak = gpa.deinit();
        std.debug.print("Memory status: {any}\n", .{maybeLeak});
    }

    // Get args
    const args = try std.process.argsAlloc(setup_allocator);
    // Get parced args
    const parsed_args = parseArgs(args);

    // Check if REPO or file run
    if (parsed_args.help) {
        _ = try stdout.write("Usage: Zav [options] <source_file>\n\n");
        _ = try stdout.write(
            \\Options: 
            \\  -s, --emit-asm          Emit assembly files for each module
            \\  -d, --show-ast          Display Abstract Syntax Tree (AST) during compilation
            \\  -o <file>               Specify output file name (default is 'out.exe')
            \\  -h, --help              Display this help message
            \\
            \\Example:
            \\  Zav -s -o splicer.exe ./src/main.zav    # Output assembly and specify output file 'splicer.exe'
            \\  Zav -d splicer.zav                      # Display the AST for each module and compile to default 'out.exe'
            \\
            \\
        );
    } else if (parsed_args.path == null) {
        try repl(
            global_allocator,
            setup_allocator,
            parsed_args.output_name,
            parsed_args.show_ast,
            parsed_args.emit_asm,
        );
    } else {
        try runFile(
            global_allocator,
            setup_allocator,
            parsed_args.path.?,
            parsed_args.output_name,
            parsed_args.show_ast,
            parsed_args.emit_asm,
        );
    }
}

/// Used to store compiler flags
const ParsedArgs = struct {
    help: bool = false,
    path: ?[]u8 = null,
    output_name: ?[]u8 = null,
    show_ast: bool = false,
    emit_asm: bool = false,
};

/// Parses user args into a struct with flags, path, and name
fn parseArgs(args: [][:0]u8) ParsedArgs {
    // Set up variables for compile flags
    var parsed_args: ParsedArgs = .{};

    // Check if only one arg
    if (args.len == 1) {
        return parsed_args;
    }

    // Next arg will be path
    var next_is_name = false;
    // Check for flags
    for (args[1..args.len]) |arg| {
        // Check if next arg should be output path
        if (next_is_name) {
            // Check if already path
            if (parsed_args.output_name != null) {
                parsed_args.help = true;
                break;
            }
            // store name
            parsed_args.output_name = arg;
            next_is_name = false;
            continue;
        }
        // Check if flag setter
        if (arg[0] == '-') {
            if (std.mem.eql(u8, arg, "-o")) {
                // Check if this flag was already used
                if (parsed_args.output_name == null) {
                    next_is_name = true;
                } else {
                    parsed_args.help = true;
                    break;
                }
            } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                parsed_args.help = true;
                break;
            } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--emit-asm")) {
                if (!parsed_args.emit_asm) {
                    // Check if this flag was already used
                    parsed_args.emit_asm = true;
                } else {
                    parsed_args.help = true;
                    break;
                }
            } else if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--show-ast")) {
                // Check if this flag was already used
                if (!parsed_args.show_ast) {
                    parsed_args.show_ast = true;
                } else {
                    parsed_args.help = true;
                    break;
                }
            } else {
                parsed_args.help = true;
            }
            continue;
        }
        // Else check if path already exists
        if (parsed_args.path == null) {
            parsed_args.path = arg;
        } else {
            parsed_args.help = true;
            break;
        }
    }
    // Check if -o was last arg
    if (next_is_name) {
        parsed_args.help = true;
    }
    // Return
    return parsed_args;
}

/// Execute code source
fn run(
    global_allocator: std.mem.Allocator,
    setup_allocator: std.mem.Allocator,
    source: []const u8,
    main_path: []const u8,
    output_name: ?[]const u8,
    show_ast: bool,
    emit_asm: bool,
) !void {
    // Make local arena for compiler
    var local_arena = std.heap.ArenaAllocator.init(global_allocator);
    defer local_arena.deinit();

    // Check if name
    const name = output_name orelse "out.exe";
    // Make compiler
    var compiler = Compiler.init(setup_allocator, &local_arena, main_path, name, show_ast, emit_asm);
    defer compiler.reset();

    // Compile source code
    compiler.compile(source);
}

/// Read from a source file and execute it
fn runFile(
    global_allocator: std.mem.Allocator,
    setup_allocator: std.mem.Allocator,
    path: []const u8,
    output_name: ?[]const u8,
    show_ast: bool,
    emit_asm: bool,
) !void {
    const stdout = std.io.getStdOut().writer();

    // Try to open file
    const file = std.fs.cwd().openFile(path, .{}) catch {
        try stdout.print("Could not open file at \"{s}\"\n", .{path});
        return;
    };
    defer file.close();

    // Read file stats
    const file_stats = try file.stat();
    // Make input buffer
    const buffer = try setup_allocator.alloc(u8, file_stats.size + 1);
    // Read file
    const contents = try file.reader().read(buffer);
    // Add null at end
    buffer[contents] = '\x00';
    // Slice source
    const source = buffer[0..];

    const main_path = try std.fs.cwd().realpathAlloc(setup_allocator, path);
    try run(global_allocator, setup_allocator, source, main_path, output_name, show_ast, emit_asm);
}

/// Run an interactive REPL
fn repl(
    global_allocator: std.mem.Allocator,
    setup_allocator: std.mem.Allocator,
    output_name: ?[]const u8,
    show_ast: bool,
    emit_asm: bool,
) !void {
    // Std printer
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const main_path = try std.fs.cwd().realpathAlloc(setup_allocator, ".");

    // Run loop
    while (true) {
        _ = try stdout.write("> ");
        // Make input buffer
        var buffer = [_]u8{undefined} ** REPL_BUFF_LEN;

        // Get input
        const input = try stdin.readUntilDelimiterOrEof(buffer[0 .. REPL_BUFF_LEN - 1], '\n') orelse "";

        // Strip \r and add \0
        var end_index: usize = undefined;
        if (buffer[input.len - 1] == '\r') {
            buffer[input.len - 1] = '\x00';
            end_index = input.len;
        } else {
            buffer[input.len] = '\x00';
            end_index = input.len + 1;
        }
        // Slice source
        const source = buffer[0..end_index];
        try run(global_allocator, setup_allocator, source, main_path, output_name, show_ast, emit_asm);
    }
}
