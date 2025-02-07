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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
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
    // Check if REPO or file run
    if (args.len == 1) {
        try repl(global_allocator, setup_allocator);
    } else if (args.len == 2) {
        try runFile(global_allocator, setup_allocator, args[1]);
    } else {
        _ = try stdout.write("Usage: Zave [path]\n");
    }
}

/// Execute code source
fn run(global_allocator: std.mem.Allocator, setup_allocator: std.mem.Allocator, source: []const u8) !void {
    // Make local arena for compiler
    var local_arena = std.heap.ArenaAllocator.init(global_allocator);
    defer local_arena.deinit();

    // Make compiler
    var compiler = Compiler.init(setup_allocator, &local_arena);
    defer compiler.reset();

    // Compile source code
    compiler.compile(source, true);
}

/// Read from a source file and execute it
fn runFile(global_allocator: std.mem.Allocator, setup_allocator: std.mem.Allocator, path: []const u8) !void {
    const stdout = std.io.getStdOut().writer();

    // Try to open file
    const file = std.fs.cwd().openFile(path, .{}) catch {
        try stdout.print("Could not open file at \"{s}\"", .{path});
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
    try run(global_allocator, setup_allocator, source);
}

/// Run an interactive REPL
fn repl(global_allocator: std.mem.Allocator, setup_allocator: std.mem.Allocator) !void {
    // Std printer
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

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
        try run(global_allocator, setup_allocator, source);
    }
}
