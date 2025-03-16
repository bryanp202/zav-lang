const std = @import("std");

// Import symbols
const Symbols = @import("symbols.zig");
const Value = Symbols.Value;
const KindId = Symbols.KindId;
// Import Generator
const Generator = @import("back_end/generator.zig");
// Import Errors
const Error = @import("error.zig");
const GenerationError = Error.GenerationError;

/// Manager for all native functions
pub const NativesTable = @This();

// Used for inline generation
const InlineGenType = fn (writer: *Generator, args: []KindId) GenerationError!void;

/// Used to store the source code of a native function and its kindid
const Native = struct {
    kind: KindId,
    source: []const u8,
    data: ?[]const u8,
    inline_gen: ?*const InlineGenType,
    comptime_args_count: usize,
    used: bool,

    pub fn newNative(kind: KindId, source: []const u8, data: ?[]const u8, inline_gen: ?*const InlineGenType, ct_arg_count: usize) Native {
        return Native{
            .kind = kind,
            .source = source,
            .data = data,
            .inline_gen = inline_gen,
            .comptime_args_count = ct_arg_count,
            .used = false,
        };
    }
};

/// Hash map that contains all native function names and KindId
natives_table: std.StringHashMapUnmanaged(Native),

/// Used to store all non-floating point number types
const nonFloatingNumbersNames = .{ "u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64" };
const nonFloatingNumbersKind = .{
    KindId.newUInt(8), KindId.newUInt(16), KindId.newUInt(32), KindId.newUInt(64), KindId.newInt(8), KindId.newInt(16), KindId.newInt(32), KindId.newInt(64),
};
// Used to store all primative types
const primativeTypePtrNames = .{
    "u8ptr",
    "u16ptr",
    "u32ptr",
    "u64ptr",
    "i8ptr",
    "i16ptr",
    "i32ptr",
    "i64ptr",
    "f32ptr",
    "f64ptr",
    "boolptr",
    "voidptr",
};
const primativeTypes = .{
    KindId.newUInt(8),
    KindId.newUInt(16),
    KindId.newUInt(32),
    KindId.newUInt(64),
    KindId.newInt(8),
    KindId.newInt(16),
    KindId.newInt(32),
    KindId.newInt(64),
    KindId.FLOAT32,
    KindId.FLOAT64,
    KindId.BOOL,
    KindId.VOID,
};

/// Init a natives table
pub fn init(allocator: std.mem.Allocator) NativesTable {
    var new_table = NativesTable{
        .natives_table = std.StringHashMapUnmanaged(Native){},
    };

    // Add all natives to the table
    new_table.natives_table.put(allocator, "printf", printf_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "sizeof", sizeof_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "len", len_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "nanoTimestamp", nanoTimestamp_native(allocator)) catch unreachable;

    // All primative pointer conversions
    inline for (nonFloatingNumbersKind, nonFloatingNumbersNames) |kind, name| {
        new_table.natives_table.put(
            allocator,
            name,
            cvt2Nonfloating_native(allocator, kind),
        ) catch unreachable;
    }
    // All non floating point conversions
    inline for (primativeTypes, primativeTypePtrNames) |kind, name| {
        new_table.natives_table.put(
            allocator,
            name,
            cvt2pointer_native(allocator, kind),
        ) catch unreachable;
    }
    // Floating point conversions
    new_table.natives_table.put(allocator, "f32", cvt2f32_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "f64", cvt2f64_native(allocator)) catch unreachable;
    // Bool conversion
    new_table.natives_table.put(allocator, "bool", cvt2bool_native(allocator)) catch unreachable;

    // Math natives
    new_table.natives_table.put(allocator, "sqrtf32", sqrtf32_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "sqrtf64", sqrtf64_native(allocator)) catch unreachable;

    // Allocation natives
    new_table.natives_table.put(allocator, "malloc", malloc_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "calloc", calloc_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "realloc", realloc_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "free", free_native(allocator)) catch unreachable;

    // I/O
    new_table.natives_table.put(allocator, "input", input_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "open", open_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "write", write_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "read", read_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "close", close_native(allocator)) catch unreachable;

    // return it
    return new_table;
}

/// Look for a native function and return its kind
pub fn getNativeKind(self: *NativesTable, name: []const u8) ?KindId {
    const maybe_native = self.natives_table.getPtr(name);
    // If it exists mark it as used
    if (maybe_native) |native| {
        // Update used
        native.used = true;
        // Return by value
        return native.kind;
    }
    // Not found, null
    return null;
}

/// Get the amount of comptime args
pub fn getComptimeArgCount(self: *NativesTable, name: []const u8) usize {
    const maybe_native = self.natives_table.getPtr(name);
    // If it exists, get the amount of comptime args
    if (maybe_native) |native| {
        // Return by value
        return native.comptime_args_count;
    }
    // Not found, null
    return 0;
}

/// Return a native function's source if it is inline
pub fn writeNativeInline(self: *NativesTable, generator: *Generator, name: []const u8, args: []KindId) GenerationError!bool {
    const maybe_native = self.natives_table.get(name);
    // If it exists mark it as used
    if (maybe_native) |native| {
        // Check if inline
        if (native.inline_gen) |gen| {
            try gen(generator, args);
            return true;
        }
    }
    return false;
}

/// Wrapper for stdlib printf
/// Ex => @printf("Hello: %d\n", 100);
fn printf_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.newPtr(allocator, KindId.newUInt(8), true);
    // Make return kind
    const ret_kind = KindId.newUInt(32);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, true, ret_kind);
    const source = undefined;
    const data = "    extern printf";

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write(
                \\    sub rsp, 32 ; Inline printf call
                \\    call printf
                \\    add rsp, 32
                \\
            );
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Size of data type inline
/// Ex => @sizeof(100) -> u64 (8 because it is i64)
fn sizeof_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.ANY;
    // Make return kind
    const ret_kind = KindId.newUInt(64);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = null;

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            // Get size
            const size = args[0].size();
            // Extract first args size
            try generator.print("    mov rax, {d} ; Inline sizeof\n", .{size});
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 1);
    return native;
}

/// Size of data type inline
/// Ex => @len("cool") -> u64 (4)
fn len_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.ANY;
    // Make return kind
    const ret_kind = KindId.newUInt(32);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = null;

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            // Get length if array
            const len = if (args[0] == .ARRAY) args[0].ARRAY.length else 0;
            // Extract first args length
            try generator.print("    mov rax, {d} ; Inline len\n", .{len});
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 1);
    return native;
}

/// Used to get the current time in ns
/// Ex => @time() -> u32
fn nanoTimestamp_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    var arg_kinds: []KindId = undefined;
    arg_kinds.len = 0;
    // Make return kind
    const ret_kind = KindId.newUInt(64);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source =
        \\@nanoTimestamp:
        \\    push rbp
        \\    mov rbp, rsp
        \\    push rax
        \\    mov rcx, rsp
        \\    sub rsp, 32
        \\    call QueryPerformanceCounter
        \\    add rsp, 32
        \\    pop rax
        \\    sub rax, [@CLOCK_START]
        \\    imul rax, 100
        \\    pop rbp
        \\    ret
        \\
    ;
    const data = null;
    const native = Native.newNative(kind, source, data, null, 0);
    return native;
}

// ******************** //
//     TYPE CASTING     //
// ******************** //
/// Convert any pointer into a primative pointer type
/// Ex => @i8ptr(100) -> *i8
fn cvt2pointer_native(allocator: std.mem.Allocator, convert_kind: KindId) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.ANY;
    // Make return kind
    const ret_kind = KindId.newPtr(allocator, convert_kind, false);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = null;

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write("    mov rax, rcx\n");
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Convert to non-floating point data type inline
/// Ex => @i8(100) -> i8
fn cvt2Nonfloating_native(allocator: std.mem.Allocator, convert_kind: KindId) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.ANY;
    // Make return kind
    const ret_kind = convert_kind;
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = null;

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            // Determine source kind
            const arg = args[0];
            switch (arg) {
                .FLOAT32, .FLOAT64 => {
                    // Determine type char
                    const type_char: u8 = if (arg == .FLOAT32) 's' else 'd';

                    // Write conversion
                    try generator.print("    cvts{c}2si rax, xmm0\n", .{type_char});
                },
                else => {
                    // Move rax to dest
                    try generator.write("    mov rax, rcx\n");
                },
            }
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Convert data to f32 type inline
/// Ex => @f32(100) -> 100.0 f32
fn cvt2f32_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.ANY;
    // Make return kind
    const ret_kind = KindId.FLOAT32;
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = null;

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            // Determine source kind
            const arg = args[0];
            switch (arg) {
                .FLOAT32 => {
                    // Move ecx to dest
                    try generator.write("    mov rax, rcx\n");
                },
                .FLOAT64 => {
                    // Write conversion
                    try generator.write("    cvtsd2ss xmm0, xmm0\n    movq rax, xmm0\n");
                },
                else => {
                    // Write conversion
                    try generator.write("    cvtsi2ss xmm0, rcx\n    movq rax, xmm0\n");
                },
            }
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Convert data to f64 type inline
/// Ex => @f64(100) -> 100.0 f64
fn cvt2f64_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.ANY;
    // Make return kind
    const ret_kind = KindId.FLOAT64;
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = null;

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            // Determine source kind
            const arg = args[0];
            switch (arg) {
                .FLOAT32 => {
                    // Write conversion
                    try generator.write("    cvtss2sd xmm0, xmm0\n    movq rax, xmm0\n");
                },
                .FLOAT64 => {
                    // Move rcx to dest
                    try generator.write("    mov rax, rcx\n");
                },
                else => {
                    // Write conversion
                    try generator.write("    cvtsi2sd xmm0, rcx\n    movq rax, xmm0\n");
                },
            }
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Convert data to a bool
/// Ex => @bool(100) -> true bool
fn cvt2bool_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.ANY;
    // Make return kind
    const ret_kind = KindId.BOOL;
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = null;

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;

            // Test and see if not zero
            try generator.write("    test rcx, rcx\n    setnz al\n");
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Square root of a float
fn sqrtf32_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.FLOAT32;
    // Make return kind
    const ret_kind = KindId.FLOAT32;
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = null;

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            // Test and see if not zero
            try generator.write("    sqrtss xmm0, xmm0\n    movd rax, xmm0\n");
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Square root of a float
fn sqrtf64_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.FLOAT64;
    // Make return kind
    const ret_kind = KindId.FLOAT64;
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = null;

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            // Test and see if not zero
            try generator.write("    sqrtsd xmm0, xmm0\n    movq rax, xmm0\n");
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// C malloc
fn malloc_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.newInt(64);
    // Make return kind
    const ret_kind = KindId.newPtr(allocator, KindId.VOID, false);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = "    extern malloc";

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write(
                \\    sub rsp, 32 ; Inline malloc call
                \\    call malloc
                \\    add rsp, 32
                \\
            );
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// C calloc
fn calloc_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 2) catch unreachable;
    arg_kinds[0] = KindId.newInt(64);
    arg_kinds[1] = KindId.newInt(64);
    // Make return kind
    const ret_kind = KindId.newPtr(allocator, KindId.VOID, false);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = "    extern calloc";

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write(
                \\    sub rsp, 32 ; Inline calloc call
                \\    call calloc
                \\    add rsp, 32
                \\
            );
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// C realloc
fn realloc_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 2) catch unreachable;
    arg_kinds[0] = KindId.newPtr(allocator, KindId.ANY, false);
    arg_kinds[1] = KindId.newInt(64);
    // Make return kind
    const ret_kind = KindId.newPtr(allocator, KindId.VOID, false);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = "    extern realloc";

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write(
                \\    sub rsp, 32 ; Inline realloc call
                \\    call realloc
                \\    add rsp, 32
                \\
            );
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// C free
fn free_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.newPtr(allocator, KindId.ANY, false);
    // Make return kind
    const ret_kind = KindId.VOID;
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = "    extern free";

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write(
                \\    sub rsp, 32 ; Inline free call
                \\    call free
                \\    add rsp, 32
                \\
            );
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Get user input
fn input_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 2) catch unreachable;
    arg_kinds[0] = KindId.newPtr(allocator, KindId.newUInt(8), false);
    arg_kinds[1] = KindId.newUInt(64);
    // Make return kind
    const ret_kind = KindId.newInt(64);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = "    extern _read";

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write(
                \\    mov r8, rdx
                \\    mov rdx, rcx
                \\    mov rcx, 0
                \\    sub rsp, 32 ; Input call
                \\    call _read
                \\    add rsp, 32
                \\
            );
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Open file
fn open_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.newPtr(allocator, KindId.newUInt(8), true);
    // Make return kind
    const ret_kind = KindId.newInt(64);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = "    extern CreateFileA";

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write(
                \\    mov rdx, 0xC0000000
                \\    mov r8, 3
                \\    mov r9, 0
                \\    push 0
                \\    push 0x80
                \\    push 4
                \\    sub rsp, 32 ; Open file call
                \\    call CreateFileA
                \\    add rsp, 56
                \\
            );
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Read file
fn read_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 4) catch unreachable;
    arg_kinds[0] = KindId.newInt(64);
    arg_kinds[1] = KindId.newPtr(allocator, KindId.newUInt(8), false);
    arg_kinds[2] = KindId.newUInt(64);
    arg_kinds[3] = KindId.newPtr(allocator, KindId.newInt(64), false);
    // Make return kind
    const ret_kind = KindId.BOOL;
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = "    extern ReadFile";

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write(
                \\    push 0
                \\    sub rsp, 32 ; Read call
                \\    call ReadFile
                \\    add rsp, 40
                \\
            );
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Write file
fn write_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 4) catch unreachable;
    arg_kinds[0] = KindId.newInt(64);
    arg_kinds[1] = KindId.newPtr(allocator, KindId.newUInt(8), true);
    arg_kinds[2] = KindId.newUInt(64);
    arg_kinds[3] = KindId.newPtr(allocator, KindId.newInt(64), false);
    // Make return kind
    const ret_kind = KindId.BOOL;
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = "    extern WriteFile";

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write(
                \\    push 0
                \\    sub rsp, 32 ; Write call
                \\    call WriteFile
                \\    add rsp, 40
                \\
            );
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}

/// Close file
fn close_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.newInt(64);
    // Make return kind
    const ret_kind = KindId.BOOL;
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, false, ret_kind);
    const source = undefined;
    const data = "    extern CloseHandle";

    // Define static inline generator
    const inline_gen: InlineGenType = struct {
        fn gen(generator: *Generator, args: []KindId) GenerationError!void {
            _ = args;
            try generator.write(
                \\    sub rsp, 32 ; Close handle call
                \\    call CloseHandle
                \\    add rsp, 32
                \\
            );
        }
    }.gen;

    const native = Native.newNative(kind, source, data, &inline_gen, 0);
    return native;
}
