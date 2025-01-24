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

    // return it
    return new_table;
}

/// Deinit the natives table
pub fn deinit(self: *NativesTable, allocator: std.mem.Allocator) void {
    // Deinit all functions in the table
    var natives = self.natives_table.iterator();
    while (natives.next()) |nativeEntry| {
        nativeEntry.value_ptr.kind.deinit(allocator);
    }
    // Dealloc table
    self.natives_table.deinit(allocator);
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
    const ret_kind = KindId.newInt(64);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, ret_kind);
    const source =
        \\@print_i:
        \\    mov rdx, rcx
        \\    lea rcx, [rel I_FMT]
        \\    sub rsp, 40 ; shadow space
        \\    call printf
        \\    add rsp, 40
        \\    ret
        \\
    ;
    const data =
        \\    I_FMT: db "%d", 0
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
    arg_kinds[0] = KindId.newFloat(64);
    // Make return kind
    const ret_kind = KindId.newInt(64);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, ret_kind);
    const source =
        \\@print_f:
        \\    mov rdx, rcx
        \\    lea rcx, [rel F_FMT]
        \\    sub rsp, 40 ; shadow space
        \\    call printf
        \\    add rsp, 40
        \\    ret
        \\
    ;
    const data =
        \\    F_FMT: db "%f", 0
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
    arg_kinds[0] = KindId.newPtr(allocator, KindId.newUInt(8), 1);
    // Make return kind
    const ret_kind = KindId.newInt(64);
    // Make the function kindid
    const kind = KindId.newFunc(allocator, arg_kinds, ret_kind);
    const source =
        \\@print_s:
        \\    ; rcx already inputted
        \\    ; no rdx needed
        \\    sub rsp, 40 ; shadow space
        \\    call printf
        \\    add rsp, 40
        \\    ret
        \\
    ;
    const native = Native.newNative(kind, source, null);
    return native;
}
