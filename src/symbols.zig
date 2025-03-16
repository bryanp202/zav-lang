const std = @import("std");

// Error import
const Error = @import("error.zig");
const ScopeError = Error.ScopeError;
// Natives Table
const NativesTable = @import("natives.zig");

// *********************** //
//*** STM type Classes  ***//
// *********************** //

/// Used to store the scoping and naming information of a source program
pub const SymbolTableManager = struct {
    allocator: std.mem.Allocator,
    // Symbol Resolution
    scopes: std.ArrayList(*Scope),
    next_scope: u16,
    active_scope: *Scope,
    /// Constant Resolution
    constants: std.AutoHashMap([48]u8, ConstantData),
    /// Stores memory offset for next global
    next_address: u64,
    /// Stores the count of constants, used for name generation
    constant_count: u64,
    /// Used to resolve native functions
    natives_table: NativesTable,

    /// Init a STM
    pub fn init(allocator: std.mem.Allocator) SymbolTableManager {
        // Make global scope
        const global = allocator.create(Scope) catch unreachable;
        global.* = Scope.init(allocator, null);

        // Make scopes stack
        var scopes = std.ArrayList(*Scope).init(allocator);
        scopes.append(global) catch unreachable;

        // Make constants map
        const const_map = std.AutoHashMap([48]u8, ConstantData).init(allocator);

        // Make a natives table
        const natives_table = NativesTable.init(allocator);

        // Return a new STM
        return SymbolTableManager{
            .allocator = allocator,
            .scopes = scopes,
            .next_scope = 1,
            .active_scope = global,
            .next_address = 0,
            .constants = const_map,
            .constant_count = 0,
            .natives_table = natives_table,
        };
    }

    /// Reset the active scope stack and scope counter
    pub fn resetStack(self: *SymbolTableManager) void {
        // Set bottom scope to active_scope
        self.active_scope = self.scopes.items[0];
        // Reset counter
        self.next_scope = 1;
    }

    /// Create a new scope, add it to scopes stack,
    /// and then push it to the top of the active scopes stack
    pub fn addScope(self: *SymbolTableManager) void {
        // Get next address
        const next_address = self.active_scope.next_address;

        // Make new scope
        const new_scope = self.allocator.create(Scope) catch unreachable;
        new_scope.* = Scope.init(self.allocator, self.active_scope);
        // Set to active scope
        self.active_scope = new_scope;
        // Transfer next address
        self.active_scope.next_address = next_address;

        // Insert new scope into stack
        self.scopes.insert(self.next_scope, new_scope) catch unreachable;

        // Increment current scope counter
        self.next_scope += 1;
    }

    /// Push the next scope onto the active scope stack
    pub fn pushScope(self: *SymbolTableManager) void {
        // Put next scope as active scope
        self.active_scope = self.scopes.items[self.next_scope];

        // Increment counter
        self.next_scope += 1;
    }

    /// Pop the current active scope from the active scope stack
    pub fn popScope(self: *SymbolTableManager) void {
        // Get old scope size
        const next_address = self.active_scope.next_address;
        // Pop scope
        self.active_scope = self.active_scope.enclosing.?;

        // Add size if not global
        if (self.active_scope != self.scopes.items[0]) {
            self.active_scope.next_address = next_address;
        }
    }

    /// Add a new symbol, with all of its attributes, and assign it with a null memory location
    pub fn declareSymbol(
        self: *SymbolTableManager,
        name: []const u8,
        kind: KindId,
        scope: ScopeKind,
        dcl_line: u64,
        dcl_column: u64,
        is_mutable: bool,
    ) !u64 {
        // Calculate the size of the kind
        const size = kind.size();

        // Else let the local scope calculate the local scope
        const mem_loc = try self.active_scope.declareSymbol(
            name,
            kind,
            scope,
            dcl_line,
            dcl_column,
            is_mutable,
            &self.next_address,
            size,
        );

        // Return the memory location
        return mem_loc;
    }

    /// Add a new symbol to the top scope on the stack, assign it a memory location
    /// if it has not been assigned one. Global scope variables will use a static memory location
    /// and Local scope variables use a relative stack location
    pub fn getSymbol(self: *SymbolTableManager, name: []const u8) !*Symbol {
        // Get symbol, starting at active_scope
        return self.active_scope.getSymbol(name);
    }

    /// Peak if a symbol is in the table, but do not mark as used
    pub fn peakSymbol(self: *SymbolTableManager, name: []const u8) !*Symbol {
        return self.active_scope.peakSymbol(name);
    }
    /// Try to put a new Value in the constants table marked as not used,
    /// but if there is a pre-existing constant mark it as used
    pub fn addConstant(self: *SymbolTableManager, constant: Value) void {
        // Convert to a string
        const val_as_str = ValueAndStr{ .value = constant };

        // Attempt to add the value into the constant table
        const getOrPut = self.constants.getOrPut(val_as_str.str) catch unreachable;
        // Check if not found
        if (!getOrPut.found_existing) {
            // Pre-calculate the size of this value
            const size = switch (constant.kind) {
                .NULLPTR => 8,
                .UINT => constant.as.uint.size(),
                .INT => constant.as.int.size(),
                .FLOAT32 => 4,
                .FLOAT64 => 8,
                .STRING => constant.as.string.data.len,
                .BOOL => 1,
                .ARRAY => constant.as.array.size(),
            };
            // Add the constant marked as unused
            getOrPut.value_ptr.* = ConstantData.init(constant, size);
        }
    }

    /// Get the name of a constant, assigning it one if it is not already named
    pub fn getConstantId(self: *SymbolTableManager, constant: Value) []const u8 {
        const val_as_str = ValueAndStr{ .value = constant };
        // Get the constant, returning null if it was not found
        const constPtr = self.constants.getPtr(val_as_str.str).?;

        // Check if constant has been assigned a number
        if (constPtr.name == null) {
            // Alloc new name string
            const new_name = std.fmt.allocPrint(self.allocator, "C{d}", .{self.constant_count}) catch unreachable;
            // Mark constant with new name
            constPtr.name = new_name;
            // Increment constant_count
            self.constant_count += 1;
        }
        // Return the const id
        return constPtr.name.?;
    }

    const ValueAndStr = extern union { value: Value, str: [48]u8 };

    // Helper Methods //
};

// *********************** //
//** Scope type Classes ***//
// *********************** //

/// Used to store a lexical scope, such as a function or global scope
pub const Scope = struct {
    enclosing: ?*Scope,
    symbols: std.StringHashMap(Symbol),
    next_address: u64,

    /// Initialize a Scope
    pub fn init(allocator: std.mem.Allocator, enclosing: ?*Scope) Scope {
        const table = std.StringHashMap(Symbol).init(allocator);
        return Scope{
            .enclosing = enclosing,
            .symbols = table,
            .next_address = 0,
        };
    }

    /// Add a new symbol, providing all of its attributes and a null address
    pub fn declareSymbol(
        self: *Scope,
        name: []const u8,
        kind: KindId,
        scope: ScopeKind,
        dcl_line: u64,
        dcl_column: u64,
        is_mutable: bool,
        global_next_address: *u64,
        size: u64,
    ) ScopeError!u64 {
        // Check if in table
        const getOrPut = self.symbols.getOrPut(name) catch unreachable;
        // Check if it is already in table
        if (getOrPut.found_existing) {
            // Throw error
            return ScopeError.DuplicateDeclaration;
        }

        // Calculate address location
        var mem_loc: u64 = undefined;
        // Get allignment of data size
        const alignment: u64 = if (size > 4) 8 else if (size > 2) 4 else if (size > 1) 2 else 1;
        const offset = self.next_address & (alignment - 1);

        // If arg or local
        if (scope == ScopeKind.LOCAL or scope == ScopeKind.ARG) {
            // Check if address is aligned
            if (offset != 0) {
                // Increment next address
                self.next_address += alignment - offset;
            }
            // Set location
            mem_loc = self.next_address;
            // Increment next addres
            self.next_address += size;
        } else if (scope == ScopeKind.GLOBAL) {
            // Add to global address
            // Check if global address is aligned
            if (offset != 0) {
                global_next_address.* += alignment - offset;
            }
            // Use global address and increment it
            mem_loc = global_next_address.*;
            global_next_address.* += size;
        }

        // Add symbol to the table
        const new_symbol = Symbol.init(
            name,
            kind,
            scope,
            dcl_line,
            dcl_column,
            is_mutable,
            mem_loc,
            size,
        );
        getOrPut.value_ptr.* = new_symbol;
        // Return mem location
        return mem_loc;
    }

    /// Try to get a symbol based off of a name
    /// Mark as used
    pub fn getSymbol(self: *Scope, name: []const u8) ScopeError!*Symbol {
        // Check this and all enclosing scopes for a declared symbol as name
        var curr: ?*Scope = self;
        while (curr) |enclosing| : (curr = enclosing.enclosing) {
            const maybeSymbol = enclosing.symbols.getPtr(name);
            // Check if found symbol
            if (maybeSymbol) |sym| {
                // Mark as used
                sym.used = true;
                // Return the symbol
                return sym;
            }
        }
        return ScopeError.UndeclaredSymbol;
    }

    /// Try to get a symbol based off of a name
    /// Do not mark as used
    pub fn peakSymbol(self: *Scope, name: []const u8) ScopeError!*Symbol {
        // Check this and all enclosing scopes for a declared symbol as name
        var curr: ?*Scope = self;
        while (curr) |enclosing| : (curr = enclosing.enclosing) {
            const maybeSymbol = enclosing.symbols.getPtr(name);
            // Check if found symbol
            if (maybeSymbol) |sym| {
                // Return the symbol
                return sym;
            }
        }
        return ScopeError.UndeclaredSymbol;
    }
};

pub const StructScope = struct {
    fields: std.StringHashMap(Field),
    next_address: u64,

    /// Make a new struct scope, used to store the names, relative location, and types of a struct's fields
    pub fn init(allocator: std.mem.Allocator) StructScope {
        return StructScope{
            .fields = std.StringHashMap(Field).init(allocator),
            .next_address = 0,
        };
    }

    /// Add a new field to this scope
    pub fn addField(self: *StructScope, scope: ScopeKind, name: []const u8, dcl_line: u64, dcl_column: u64, kind: KindId) ScopeError!void {
        // Check if already in scope
        const getOrPut = self.fields.getOrPut(name) catch unreachable;
        if (getOrPut.found_existing) {
            return ScopeError.DuplicateDeclaration;
        }

        // Check if adding a "local"
        if (scope == .LOCAL) {
            // Calculate address location
            var mem_loc: u64 = undefined;
            // Get size of field
            const kind_size = kind.size();
            // Get allignment of data size
            const alignment: u64 = if (kind_size > 4) 8 else if (kind_size > 2) 4 else if (kind_size > 1) 2 else 1;
            const offset = self.next_address & (alignment - 1);

            // Check if address is aligned
            if (offset != 0) {
                // Increment next address
                self.next_address += alignment - offset;
            }
            // Set location
            mem_loc = self.next_address;
            // Increment next addres
            self.next_address += kind_size;
            const field = Field.init(scope, name, kind, dcl_line, dcl_column, mem_loc);
            getOrPut.value_ptr.* = field;
        } else {
            const field = Field.init(scope, name, kind, dcl_line, dcl_column, undefined);
            getOrPut.value_ptr.* = field;
        }
    }

    /// Get a field by name from this scope
    pub fn getField(self: *StructScope, name: []const u8) ScopeError!Field {
        const field = self.fields.getPtr(name) orelse {
            return ScopeError.UndeclaredSymbol;
        };
        field.used = true;
        return field.*;
    }

    /// Calculate the size of this scope
    pub fn size(self: StructScope) u64 {
        const alignment = 8 - self.next_address % 8;
        if (alignment == 8) {
            return self.next_address;
        }
        return self.next_address + alignment;
    }
};

// ******************************* //
//***   Symbol / Field Struct   ***//
// ******************************* //

/// Used to store information about a variable/symbol
pub const Symbol = struct {
    name: []const u8,
    kind: KindId,
    scope: ScopeKind,
    dcl_line: u64,
    dcl_column: u64,
    is_mutable: bool,
    has_mutated: bool,
    mem_loc: u64,
    size: u64,
    used: bool,

    /// Make a new symbol
    pub fn init(name: []const u8, kind: KindId, scope: ScopeKind, dcl_line: u64, dcl_column: u64, is_mutable: bool, mem_loc: u64, size: u64) Symbol {
        return Symbol{
            .name = name,
            .kind = kind,
            .scope = scope,
            .dcl_line = dcl_line,
            .dcl_column = dcl_column,
            .is_mutable = is_mutable,
            .has_mutated = false,
            .mem_loc = mem_loc,
            .size = size,
            .used = false,
        };
    }
};

/// Used to store information about a structs field
pub const Field = struct {
    scope: ScopeKind,
    name: []const u8,
    kind: KindId,
    dcl_line: u64,
    dcl_column: u64,
    relative_loc: u64,
    used: bool,

    /// Init a new field, used to store information about a structs field
    pub fn init(scope: ScopeKind, name: []const u8, kind: KindId, dcl_line: u64, dcl_column: u64, relative_loc: u64) Field {
        return Field{
            .scope = scope,
            .name = name,
            .kind = kind,
            .dcl_line = dcl_line,
            .dcl_column = dcl_column,
            .relative_loc = relative_loc,
            .used = false,
        };
    }
};

// *********************** //
//***  Data type Stuff  ***//
// *********************** //

// Enum for the types available in Zav
pub const Kinds = enum { ANY, VOID, BOOL, UINT, INT, FLOAT32, FLOAT64, PTR, ARRAY, FUNC, STRUCT };

/// Used to mark what type a variable is
pub const KindId = union(Kinds) {
    ANY: void,
    VOID: void,
    BOOL: void,
    UINT: UInteger,
    INT: Integer,
    FLOAT32: void,
    FLOAT64: void,
    PTR: Pointer,
    ARRAY: Array,
    FUNC: Function,
    STRUCT: Struct,

    /// Init a new unsigned integer
    pub fn newUInt(bits: u16) KindId {
        const uint = UInteger{
            .bits = bits,
        };
        return KindId{ .UINT = uint };
    }
    /// Init a new integer
    pub fn newInt(bits: u16) KindId {
        const int = Integer{
            .bits = bits,
        };
        return KindId{ .INT = int };
    }
    /// Init a new pointer
    pub fn newPtr(allocator: std.mem.Allocator, child_kind: KindId, const_child: bool) KindId {
        // Dynamically allocate the child KindId tag
        const child_ptr = allocator.create(KindId) catch unreachable;
        child_ptr.* = child_kind;
        // Make new pointer
        const ptr = Pointer{
            .child = child_ptr,
            .const_child = const_child,
        };
        return KindId{ .PTR = ptr };
    }
    /// Init a new pointer with no allocation
    pub fn newPtrFromArray(source: KindId, const_items: bool) KindId {
        const array = source.ARRAY;
        // Make new ptr
        const ptr = Pointer{
            .child = array.child,
            .const_child = const_items,
        };
        return KindId{ .PTR = ptr };
    }
    /// Init a new array kindid
    pub fn newArr(allocator: std.mem.Allocator, child_kind: KindId, length: u64, const_items: bool, static: bool) KindId {
        // Dynamically allocate the child KindId tag
        const child_ptr = allocator.create(KindId) catch unreachable;
        child_ptr.* = child_kind;
        // Make new array
        const arr = Array{
            .child = child_ptr,
            .length = length,
            .const_items = const_items,
            .static = static,
        };
        return KindId{ .ARRAY = arr };
    }
    /// Init a new Function kindid
    pub fn newFunc(allocator: std.mem.Allocator, arg_kinds: []KindId, variadic: bool, ret_kind: KindId) KindId {
        // Dynamically allocate the child KindId tag
        const ret_ptr = allocator.create(KindId) catch unreachable;
        ret_ptr.* = ret_kind;
        // Make new array
        const func = Function{
            .arg_kinds = arg_kinds,
            .variadic = variadic,
            .ret_kind = ret_ptr,
            .args_size = undefined,
        };
        return KindId{ .FUNC = func };
    }
    /// Init a new Struct kindid with a defined scope
    pub fn newStructWithIndex(allocator: std.mem.Allocator, name: []const u8, index: u64) KindId {
        const new_scope = allocator.create(StructScope) catch unreachable;
        new_scope.* = StructScope.init(allocator);
        const new_struct = Struct{ .name = name, .fields = new_scope, .index = index };
        return KindId{ .STRUCT = new_struct };
    }
    /// Init a new Struct kindid with no scope
    pub fn newStruct(name: []const u8) KindId {
        const new_struct = Struct{ .name = name, .fields = undefined };
        return KindId{ .STRUCT = new_struct };
    }

    /// Return if this kindid is the same as another
    pub fn equal(self: KindId, other: KindId) bool {
        // Check if other is any
        if (other == .ANY) {
            return true;
        }
        // Else check for compatible matches
        return switch (self) {
            .ANY => return true,
            .VOID => return other == .VOID,
            .BOOL => return other == .BOOL,
            .UINT => return other == .UINT and self.UINT.bits == other.UINT.bits,
            .INT => return other == .INT and self.INT.bits == other.INT.bits,
            .FLOAT32 => return other == .FLOAT32,
            .FLOAT64 => return other == .FLOAT64,
            .PTR => |ptr| return other == .PTR and ptr.equal(other.PTR),
            .ARRAY => |arr| return other == .ARRAY and arr.equal(other.ARRAY),
            .FUNC => |func| return other == .FUNC and func.equal(other.FUNC),
            .STRUCT => |srct| return other == .STRUCT and srct.equal(other.STRUCT),
        };
    }

    /// Return the size of the Kind
    pub fn size(self: KindId) u64 {
        return switch (self) {
            .VOID => 0,
            .BOOL => 1,
            .UINT => |uint| uint.size(),
            .INT => |int| int.size(),
            .FLOAT32 => 4,
            .ANY, .FLOAT64, .PTR, .FUNC => 8,
            .ARRAY => |arr| arr.size(),
            .STRUCT => |stct| stct.fields.size(),
        };
    }

    /// Return the size of the Kind
    pub fn size_runtime(self: KindId) u64 {
        return switch (self) {
            .VOID => 0,
            .BOOL => 1,
            .UINT => |uint| uint.size(),
            .INT => |int| int.size(),
            .FLOAT32 => 4,
            .ANY, .FLOAT64, .PTR, .ARRAY, .FUNC, .STRUCT => 8,
        };
    }

    /// Update a user defined type
    pub fn update(self: *KindId, stm: *SymbolTableManager) ScopeError!usize {
        return switch (self.*) {
            .VOID => 0,
            .BOOL => 1,
            .UINT => |uint| uint.size(),
            .INT => |int| int.size(),
            .FLOAT32 => 4,
            .FLOAT64 => 8,
            .PTR => |*ptr| ptr.updatePtr(stm),
            .ARRAY => |*arr| arr.updateArray(stm),
            .FUNC => |*func| func.updateArgSize(stm),
            .STRUCT => |*strct| strct.updateFields(stm),
            else => unreachable,
        };
    }
};

/// Used to mark what kind of scope a variable has
pub const ScopeKind = enum {
    ARG,
    LOCAL,
    GLOBAL,
    FUNC,
    STRUCT,
};

// *********************** //
//*** Data type Classes ***//
// *********************** //

/// Integer type data
const UInteger = struct {
    bits: u16,

    /// Calculate the size of this type in bytes
    pub fn size(self: UInteger) u64 {
        const bytes = std.math.divCeil(u64, self.bits, 8) catch unreachable;
        return bytes;
    }
};

/// Integer type data
const Integer = struct {
    bits: u16,

    /// Calculate the size of this type in bytes
    pub fn size(self: Integer) u64 {
        const bytes = std.math.divCeil(u64, self.bits, 8) catch unreachable;
        return bytes;
    }
};

/// Pointer Type data
const Pointer = struct {
    child: *KindId,
    const_child: bool,

    /// Returns true if this pointer is the same as another pointer
    pub fn equal(self: Pointer, other: Pointer) bool {
        return self.child.equal(other.child.*);
    }

    /// Update a userdefined pointer type
    pub fn updatePtr(self: *Pointer, stm: *SymbolTableManager) ScopeError!usize {
        _ = try self.child.update(stm);
        return 8;
    }
};

/// Array Type data
const Array = struct {
    child: *KindId,
    length: u64,
    const_items: bool,
    static: bool,

    /// Returns true if this array is the same as another array
    pub fn equal(self: Array, other: Array) bool {
        return self.child.equal(other.child.*) and self.length == other.length;
    }

    /// Calculate the size of this type in bytes
    pub fn size(self: Array) u64 {
        if (self.static) return 8;
        const element_size = self.child.size();
        const bytes = element_size * self.length;
        return bytes;
    }

    /// Update a userdefined pointer type
    pub fn updateArray(self: *Array, stm: *SymbolTableManager) ScopeError!usize {
        const child_size = try self.child.update(stm);
        return self.length * child_size;
    }
};

/// Function Type data
const Function = struct {
    arg_kinds: []KindId,
    variadic: bool,
    // Type of return value
    ret_kind: *KindId,
    // How much stack offset
    args_size: usize,

    /// Returns true if this func is the same as another func
    pub fn equal(self: Function, other: Function) bool {
        // Check if both variadic or not
        if (self.variadic != other.variadic) {
            return false;
        }
        // Check arg count
        if (self.arg_kinds.len != other.arg_kinds.len) {
            return false;
        }
        // Check arg types
        for (self.arg_kinds, other.arg_kinds) |self_arg, other_arg| {
            if (!self_arg.equal(other_arg)) {
                return false;
            }
        }

        // Check return types
        if (!self.ret_kind.equal(other.ret_kind.*)) {
            return false;
        }
        // Everything matches
        return true;
    }

    /// Resolve the arg size of a user defined fn kind
    pub fn updateArgSize(self: *Function, stm: *SymbolTableManager) ScopeError!usize {
        var size: usize = 0;
        for (self.arg_kinds) |*kind| {
            const child_size = try kind.update(stm);
            const alignment: u64 = if (child_size > 4) 8 else if (child_size > 2) 4 else if (child_size > 1) 2 else 1;
            const offset = size & (alignment - 1);
            if (offset != 0) {
                size += alignment - offset;
            }
        }
        self.args_size = size;
        _ = try self.ret_kind.update(stm);
        return 8;
    }
};

/// Structure data type
const Struct = struct {
    name: []const u8,
    fields: *StructScope,
    index: u64 = undefined,
    visited: bool = false,
    declared: bool = false,

    /// Returns true if two structs are the same
    pub fn equal(self: Struct, other: Struct) bool {
        return self.name.ptr == other.name.ptr and self.name.len == other.name.len and self.fields == other.fields;
    }

    /// Resolve the struct size of a user defined struct kind
    pub fn updateFields(self: *Struct, stm: *SymbolTableManager) ScopeError!usize {
        const symbol = try stm.getSymbol(self.name);
        if (symbol.kind != .STRUCT) return ScopeError.UndeclaredSymbol;
        self.fields = symbol.kind.STRUCT.fields;
        return self.fields.next_address + 8 - (self.fields.next_address % 8);
    }
};

// *********************** //
//***Values/Const Structs**//
// *********************** //

/// Used to store the constant and if it was used
const ConstantData = struct {
    data: Value,
    size: u64,
    name: ?[]const u8,

    pub fn init(value: Value, size: u64) ConstantData {
        return ConstantData{
            .data = value,
            .size = size,
            .name = null,
        };
    }
};

/// Used to determine the type of a literal value
pub const ValueKind = enum(u8) {
    NULLPTR,
    BOOL,
    UINT,
    INT,
    FLOAT32,
    FLOAT64,
    STRING,
    ARRAY,
};

/// Slice simulation
pub fn LiteralSlice(T: type) type {
    return extern struct {
        ptr: [*]const T,
        len: usize,

        /// Init a LiteralSlice from a zig slice
        pub fn init(zig_slice: []const T) @This() {
            return .{
                .ptr = zig_slice.ptr,
                .len = zig_slice.len,
            };
        }

        /// Return a zig slice version of this LiteralSlice
        pub fn slice(self: @This()) []const T {
            var zig_slice: []const T = undefined;
            zig_slice.len = self.len;
            zig_slice.ptr = self.ptr;
            return zig_slice;
        }
    };
}

/// Unsigned Integer literal storage struct
const UIntegerLiteral = extern struct {
    data: u64,
    bits: u16,

    /// Calculate the size of an integer literal
    pub fn size(self: UIntegerLiteral) usize {
        return std.math.divCeil(usize, self.bits, 8) catch unreachable;
    }
};

/// Integer literal storage struct
const IntegerLiteral = extern struct {
    data: i64,
    bits: u16,

    /// Calculate the size of an integer literal
    pub fn size(self: IntegerLiteral) usize {
        return std.math.divCeil(usize, self.bits, 8) catch unreachable;
    }
};

/// String literal storage struct
const StringLiteral = extern struct {
    data: LiteralSlice(u8),
};

/// Array Literal storage struct
const ArrayLiteral = extern struct {
    kind: *KindId,
    dimensions: LiteralSlice(usize),
    data: LiteralSlice(Value),

    pub fn size(self: ArrayLiteral) usize {
        // Calculate size of LiteralKind
        var self_size: usize = switch (self.kind.*) {
            .BOOL => 1,
            .UINT => self.data.ptr[0].as.uint.size(),
            .INT => self.data.ptr[0].as.int.size(),
            .FLOAT32 => 4,
            .FLOAT64 => 8,
            else => unreachable,
        };
        // Multiply by dimensions
        for (self.dimensions.slice()) |dim| {
            self_size *= dim;
        }
        // Multiply and return
        return self_size;
    }
};

/// Used to store a literal value
pub const Value = extern struct {
    kind: ValueKind,
    as: extern union {
        EMPTY: [6]u64,
        boolean: bool,
        uint: UIntegerLiteral,
        int: IntegerLiteral,
        float32: f32,
        float64: f64,
        string: StringLiteral,
        array: ArrayLiteral,
    },

    /// Init a new null value
    pub fn newNullPtr() Value {
        const val = Value{ .kind = ValueKind.NULLPTR, .as = .{ .EMPTY = [_]u64{0} ** 6 } };
        return val;
    }
    ///Init a new unsigned integer value
    pub fn newUInt(value: u64, bits: u16) Value {
        var val = Value{ .kind = ValueKind.UINT, .as = .{ .EMPTY = [_]u64{0} ** 6 } };
        val.as.uint.bits = bits;
        val.as.uint.data = value;
        return val;
    }
    /// Init a new value as an integer
    pub fn newInt(value: i64, bits: u16) Value {
        var val = Value{ .kind = ValueKind.INT, .as = .{ .EMPTY = [_]u64{0} ** 6 } };
        val.as.int.bits = bits;
        val.as.int.data = value;
        return val;
    }
    /// Init a new value as a boolean
    pub fn newBool(value: bool) Value {
        var val = Value{ .kind = ValueKind.BOOL, .as = .{ .EMPTY = [_]u64{0} ** 6 } };
        val.as.boolean = value;
        return val;
    }
    /// Init a new value as a float32
    pub fn newFloat32(value: f32) Value {
        var val = Value{ .kind = ValueKind.FLOAT32, .as = .{ .EMPTY = [_]u64{0} ** 6 } };
        val.as.float32 = value;
        return val;
    }
    /// Init a new value as a float
    pub fn newFloat64(value: f64) Value {
        var val = Value{ .kind = ValueKind.FLOAT64, .as = .{ .EMPTY = [_]u64{0} ** 6 } };
        val.as.float64 = value;
        return val;
    }
    /// Init a new value as a string
    pub fn newStr(data: []const u8) Value {
        var val = Value{ .kind = ValueKind.STRING, .as = .{ .EMPTY = [_]u64{0} ** 6 } };
        const str_slice = LiteralSlice(u8).init(data);
        val.as.string.data = str_slice;
        return val;
    }
    /// Init a new value as an array
    pub fn newArr(kind: *KindId, dimensions: []const usize, data: []const Value) Value {
        var val = Value{ .kind = ValueKind.ARRAY, .as = .{ .EMPTY = [_]u64{0} ** 6 } };
        const dim_slice = LiteralSlice(usize).init(dimensions);
        const data_slice = LiteralSlice(Value).init(data);
        val.as.array.data = data_slice;
        val.as.array.dimensions = dim_slice;
        val.as.array.kind = kind;
        return val;
    }
};
