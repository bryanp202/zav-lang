const std = @import("std");
const Compiler = @import("compiler.zig");
// Global const
const REPL_BUFF_LEN = 1001;

pub fn main() !void {
    // Stdio
    const stdout = std.io.getStdOut().writer();
    // Alloc
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        // Check for memory leaks at end of execution
        const maybeLeak = gpa.deinit();
        std.debug.print("Memory Status: {}\n", .{maybeLeak});
    }

    // Start of execution time marker
    const start = std.time.nanoTimestamp();

    // Get args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    // Check if REPO or file run
    if (args.len == 1) {
        try repl(allocator);
    } else if (args.len == 2) {
        try runFile(allocator, args[1]);
    } else {
        _ = try stdout.write("Usage: Zave [path]\n");
    }

    const total_time = std.time.nanoTimestamp() - start;
    std.debug.print("Time to run: {d} s\n", .{@as(f64, @floatFromInt(total_time)) / 1000000000.0});
}

/// Execute code source
fn run(allocator: std.mem.Allocator, source: []const u8) !void {
    var compiler = Compiler.init(allocator);
    defer compiler.deinit();

    compiler.compile(source);
}

/// Read from a source file and execute it
fn runFile(allocator: std.mem.Allocator, path: []const u8) !void {
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
    const buffer = try allocator.alloc(u8, file_stats.size + 1);
    defer allocator.free(buffer);
    // Read file
    const contents = try file.reader().read(buffer);
    // Add null at end
    buffer[contents] = '\x00';

    // Slice source
    const source = buffer[0..];
    try run(allocator, source);
}

/// Run an interactive REPL
fn repl(allocator: std.mem.Allocator) !void {
    // Std printer
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    // Run loop
    while (true) {
        _ = try stdout.write("> ");
        // Make input buffer
        const buffer = try allocator.alloc(u8, REPL_BUFF_LEN);
        defer allocator.free(buffer);

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
        try run(allocator, source);
    }
}
