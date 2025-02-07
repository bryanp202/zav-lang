const std = @import("std");

// Import symbols
const Symbols = @import("symbols.zig");
const KindId = Symbols.KindId;

/// Manager for all native functions
pub const NativesTable = @This();

/// Used to store the source code of a native function and its kindid
const Native = struct {
    kind: KindId,
    source: []const u8,
    data: ?[]const u8,
    used: bool,

    pub fn newNative(kind: KindId, source: []const u8, data: ?[]const u8) Native {
        return Native{
            .kind = kind,
            .source = source,
            .data = data,
            .used = false,
        };
    }
};

/// Hash map that contains all native function names and KindId
natives_table: std.StringHashMapUnmanaged(Native),

/// Init a natives table
pub fn init(allocator: std.mem.Allocator) NativesTable {
    var new_table = NativesTable{
        .natives_table = std.StringHashMapUnmanaged(Native){},
    };

    // Add all natives to the table
    new_table.natives_table.put(allocator, "print_i", print_i_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "print_f", print_f_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "print_s", print_s_native(allocator)) catch unreachable;
    new_table.natives_table.put(allocator, "print_ss", print_ss_native(allocator)) catch unreachable;

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

/// Used to print a signed integer of any size
/// Ex => @print_i(integer)
fn print_i_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.newInt(64);
    // Make return kind
    const ret_kind = KindId.newUInt(32);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, ret_kind);
    const source =
        \\@print_i:
        \\    push rbp
        \\    mov rbp, rsp
        \\    lea rcx, [@I_FMT]
        \\    mov rdx, [rbp + 16]
        \\    sub rsp, 40 ; shadow space
        \\    call printf
        \\    add rsp, 40
        \\    pop rbp
        \\    ret
        \\
    ;
    const data =
        \\    @I_FMT: db "%d", 0
        \\
    ;
    const native = Native.newNative(kind, source, data);
    return native;
}

/// Used to print a float of any size
/// Ex => @print_f(float)
fn print_f_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.FLOAT64;
    // Make return kind
    const ret_kind = KindId.newUInt(32);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, ret_kind);
    const source =
        \\@print_f:
        \\    push rbp
        \\    mov rbp, rsp
        \\    lea rcx, [@F_FMT]
        \\    mov rdx, [rbp + 16]
        \\    sub rsp, 40 ; shadow space
        \\    call printf
        \\    add rsp, 40
        \\    pop rbp
        \\    ret
        \\
    ;
    const data =
        \\    @F_FMT: db "%f", 0
        \\
    ;
    const native = Native.newNative(kind, source, data);
    return native;
}

/// Used to print an integer of any size
/// Ex => @print_s(char array) null terminated
fn print_s_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 1) catch unreachable;
    arg_kinds[0] = KindId.newPtr(allocator, KindId.newUInt(8), true);
    // Make return kind
    const ret_kind = KindId.newUInt(32);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, ret_kind);
    const source =
        \\@print_s:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rcx, [rbp + 16]
        \\    sub rsp, 40 ; shadow space
        \\    call printf
        \\    add rsp, 40
        \\    pop rbp
        \\    ret
        \\
    ;
    const native = Native.newNative(kind, source, null);
    return native;
}

/// Used to print count chars from a char array
/// Ex => @print_ss(char array, int count) null termination optional
fn print_ss_native(allocator: std.mem.Allocator) Native {
    // Make the Arg Kind Ids
    const arg_kinds = allocator.alloc(KindId, 2) catch unreachable;
    arg_kinds[0] = KindId.newPtr(allocator, KindId.newUInt(8), true);
    arg_kinds[1] = KindId.newInt(64);
    // Make return kind
    const ret_kind = KindId.newUInt(32);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, ret_kind);
    const source =
        \\@print_ss:
        \\    push rbp
        \\    mov rbp, rsp
        \\    lea rcx, [@SS_FMT]
        \\    mov rdx, [rbp + 16]
        \\    mov r8, [rbp + 24]
        \\    sub rsp, 40 ; shadow space
        \\    call printf
        \\    add rsp, 40
        \\    pop rbp
        \\    ret
        \\
    ;
    const data =
        \\    @SS_FMT db "%.*s", 0
        \\
    ;
    const native = Native.newNative(kind, source, data);
    return native;
}
