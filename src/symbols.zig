const std = @import("std");

// Error import
const Error = @import("error.zig");
const ScopeError = Error.ScopeError;
// Natives Table
const NativesTable = @import("natives.zig");
const Module = @import("module.zig");

const Stmt = @import("stmt.zig");
const Token = @import("front_end/scanner.zig").Token;
const TypeChecker = @import("front_end/type_checker.zig");

// *********************** //
//*** STM type Classes  ***//
// *********************** //

/// Used to store the scoping and naming information of a source program
pub const SymbolTableManager = struct {
    allocator: std.mem.Allocator,
    // Symbol Resolution
    scopes: std.ArrayList(*Scope),
    active_scope: *Scope,
    /// Constant Resolution
    constants: std.AutoHashMap([48]u8, ConstantData),
    /// Stores memory offset for next global
    next_address: u64,
    /// Stores the count of constants, used for name generation
    constant_count: u64,
    /// Used to resolve native functions
    natives_table: NativesTable,
    /// Used for global/absolute scoping
    global_module: *Module,
    parent_module: *Module,
    /// Used for user defined scoping
    current_scope_target: ?KindId,
    /// Stores all unique external accesses
    extern_dependencies: std.StringHashMap(void),

    /// Init a STM
    pub fn init(allocator: std.mem.Allocator, global_module: *Module) SymbolTableManager {
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
            .active_scope = global,
            .next_address = 0,
            .constants = const_map,
            .constant_count = 0,
            .natives_table = natives_table,
            .global_module = global_module,
            .parent_module = undefined,
            .current_scope_target = null,
            .extern_dependencies = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn setParentModule(self: *SymbolTableManager, module: *Module) void {
        self.parent_module = module;
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
        self.scopes.append(new_scope) catch unreachable;
    }

    /// Pop the current active scope from the active scope stack
    pub fn popScope(self: *SymbolTableManager) void {
        // Get old scope size
        const next_address = self.active_scope.next_address;
        // Pop scope
        self.active_scope = self.active_scope.enclosing.?;
        _ = self.scopes.pop();

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
        public: bool,
    ) !u64 {
        // Calculate the size of the kind
        const size = kind.size();
        const module = self.parent_module;

        // Else let the local scope calculate the local scope
        const mem_loc = try self.active_scope.declareSymbol(
            module,
            name,
            kind,
            scope,
            dcl_line,
            dcl_column,
            is_mutable,
            public,
            &self.next_address,
            size,
        );

        // Return the memory location
        return mem_loc;
    }

    /// Add a new symbol, with all of its attributes, and assign it with a null memory location
    pub fn declareSymbolWithSize(
        self: *SymbolTableManager,
        name: []const u8,
        kind: KindId,
        scope: ScopeKind,
        dcl_line: u64,
        dcl_column: u64,
        is_mutable: bool,
        public: bool,
        size: usize,
    ) !u64 {
        const new_size = @max(kind.size(), size);
        const module = self.parent_module;

        // Else let the local scope calculate the local scope
        const mem_loc = try self.active_scope.declareSymbol(
            module,
            name,
            kind,
            scope,
            dcl_line,
            dcl_column,
            is_mutable,
            public,
            &self.next_address,
            new_size,
        );

        // Return the memory location
        return mem_loc;
    }

    pub fn importSymbol(self: *SymbolTableManager, symbol: Symbol, as_name: []const u8) ScopeError!void {
        try self.active_scope.importSymbol(symbol, as_name, self.parent_module);
    }

    pub fn addDependency(self: *SymbolTableManager, dependency: *Module, name: []const u8, dcl_line: u64, dcl_column: u64, public: bool) !void {
        const new_dependency = KindId{ .MODULE = dependency };
        _ = try self.declareSymbol(name, new_dependency, ScopeKind.MODULE, dcl_line, dcl_column, false, public);
    }

    pub fn changeTargetScope(self: *SymbolTableManager, target: []const u8) !void {
        if (self.current_scope_target == null) {
            // Check if absolute scope or not
            if (target.len == 0) {
                self.current_scope_target = KindId{ .MODULE = self.global_module };
            } else {
                const symbol = try self.peakSymbol(target);

                if (symbol.source_module != self.parent_module and !symbol.public and symbol.borrowing_module != self.parent_module) {
                    return ScopeError.SymbolNotPublic;
                }

                self.current_scope_target = symbol.kind;
            }
        } else {
            switch (self.current_scope_target.?) {
                .MODULE => |module| {
                    const symbol = try module.stm.peakSymbol(target);

                    if (symbol.source_module != self.parent_module and !symbol.public) {
                        return ScopeError.SymbolNotPublic;
                    }

                    self.current_scope_target = symbol.kind;
                },
                else => return ScopeError.UndeclaredSymbol,
            }
        }
    }

    /// Add a new symbol to the top scope on the stack, assign it a memory location
    /// if it has not been assigned one. Global scope variables will use a static memory location
    /// and Local scope variables use a relative stack location
    pub fn getSymbol(self: *SymbolTableManager, name: []const u8) !*Symbol {
        const current_scope_target = self.current_scope_target;

        if (current_scope_target) |target| {
            self.current_scope_target = null;

            const symbol = switch (target) {
                .MODULE => |module| try module.stm.getSymbol(name),
                .ENUM => |enm| enm.variants.getPtr(name) orelse return ScopeError.UndeclaredSymbol,
                .STRUCT => |strct| blk: {
                    const struct_symbol = try strct.fields.getField(self, name);
                    if (struct_symbol.kind != .FUNC) {
                        return ScopeError.InvalidScope;
                    }
                    break :blk struct_symbol;
                },
                else => return ScopeError.InvalidScope,
            };

            if (symbol.source_module != self.parent_module) {
                if (!symbol.public and symbol.borrowing_module != self.parent_module) {
                    return ScopeError.SymbolNotPublic;
                }

                if (symbol.scope == .FUNC or symbol.scope == .GLOBAL) self.extern_dependencies.put(symbol.name, {}) catch unreachable;
            }

            return symbol;
        }

        // Get symbol, starting at active_scope
        const symbol = try self.active_scope.getSymbol(name);

        return symbol;
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

    /// Insert a used symbol, potentially changing names for value
    pub fn importSymbol(self: *Scope, symbol: Symbol, as_name: []const u8, borrowing_module: *Module) ScopeError!void {
        const getOrPut = self.symbols.getOrPut(as_name) catch unreachable;
        if (getOrPut.found_existing) {
            return ScopeError.DuplicateDeclaration;
        }
        getOrPut.value_ptr.* = symbol;
        getOrPut.value_ptr.borrowing_module = borrowing_module;
    }

    /// Add a new symbol, providing all of its attributes and a null address
    pub fn declareSymbol(
        self: *Scope,
        module: *Module,
        name: []const u8,
        kind: KindId,
        scope: ScopeKind,
        dcl_line: u64,
        dcl_column: u64,
        is_mutable: bool,
        public: bool,
        global_next_address: *u64,
        size: u64,
    ) ScopeError!u64 {
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

        // Declare nothing if name is "_"
        if (!std.mem.eql(u8, name, "_")) {
            // Check if in table
            const getOrPut = self.symbols.getOrPut(name) catch unreachable;
            // Check if it is already in table
            if (getOrPut.found_existing) {
                // Throw error
                return ScopeError.DuplicateDeclaration;
            }

            // Add symbol to the table
            const new_symbol = Symbol.init(
                module,
                name,
                kind,
                scope,
                dcl_line,
                dcl_column,
                is_mutable,
                public,
                mem_loc,
                size,
            );
            getOrPut.value_ptr.* = new_symbol;
        }
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

pub const UnionScope = struct {
    fields: std.StringHashMap(Symbol),
    max_size: usize,
    declared: bool = false,
    visited: bool = false,

    pub fn init(allocator: std.mem.Allocator) UnionScope {
        return UnionScope{
            .fields = std.StringHashMap(Symbol).init(allocator),
            .max_size = 0,
        };
    }

    pub fn addField(self: *UnionScope, module: *Module, name: []const u8, dcl_line: u64, dcl_column: u64, kind: KindId, is_public: bool) ScopeError!void {
        const getOrPut = self.fields.getOrPut(name) catch unreachable;
        if (getOrPut.found_existing) {
            return ScopeError.DuplicateDeclaration;
        }

        const field_size = kind.size();
        const field = Symbol.init(
            module,
            name,
            kind,
            ScopeKind.LOCAL,
            dcl_line,
            dcl_column,
            true,
            is_public,
            0,
            field_size,
        );
        getOrPut.value_ptr.* = field;

        self.max_size = @max(self.max_size, field_size);
    }

    pub fn getField(self: *UnionScope, stm: *SymbolTableManager, name: []const u8) ScopeError!*Symbol {
        const field = self.fields.getPtr(name) orelse {
            return ScopeError.UndeclaredSymbol;
        };

        if (field.source_module != stm.parent_module) {
            stm.extern_dependencies.put(field.name, {}) catch unreachable;
        }

        field.used = true;
        return field;
    }

    pub fn size(self: UnionScope) u64 {
        return self.max_size;
    }
};

pub const StructScope = struct {
    fields: std.StringHashMap(Symbol),
    next_address: usize,
    is_open: bool,
    declared: bool = false,
    visited: bool = false,
    methods_declared: bool = false,
    method_bodies_eval: bool = false,

    /// Make a new struct scope, used to store the names, relative location, and types of a struct's fields
    pub fn init(allocator: std.mem.Allocator) StructScope {
        return StructScope{
            .fields = std.StringHashMap(Symbol).init(allocator),
            .next_address = 0,
            .is_open = false,
        };
    }

    pub fn open(self: *StructScope) void {
        self.is_open = true;
    }

    pub fn close(self: *StructScope) void {
        self.is_open = false;
    }

    /// Add a new field to this scope
    pub fn addField(self: *StructScope, struct_name: []const u8, module: *Module, scope: ScopeKind, name: []const u8, dcl_line: u64, dcl_column: u64, kind: KindId, is_public: bool) ScopeError!void {
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
            const field = Symbol.init(module, name, kind, scope, dcl_line, dcl_column, true, is_public, mem_loc, kind_size);
            getOrPut.value_ptr.* = field;
        } else {
            const field = Symbol.initAsField(module, struct_name, name, kind, scope, dcl_line, dcl_column, true, is_public, undefined, undefined);
            getOrPut.value_ptr.* = field;
        }
    }

    /// Get a field by name from this scope
    pub fn getField(self: *StructScope, stm: *SymbolTableManager, name: []const u8) ScopeError!*Symbol {
        const field = self.fields.getPtr(name) orelse {
            return ScopeError.UndeclaredSymbol;
        };

        if (field.source_module != stm.parent_module) {
            stm.extern_dependencies.put(field.name, {}) catch unreachable;
        }
        if (!self.is_open and !field.public) return ScopeError.SymbolNotPublic;

        field.used = true;
        return field;
    }

    pub fn peakField(self: *StructScope, name: []const u8) ScopeError!*Symbol {
        const field = self.fields.getPtr(name) orelse {
            return ScopeError.UndeclaredSymbol;
        };
        return field;
    }

    /// Calculate the size of this scope
    pub fn size(self: StructScope) u64 {
        const kind_size = self.next_address;
        const alignment: usize = if (kind_size >= 8) 8 else if (kind_size >= 4) 4 else if (kind_size >= 2) 2 else 1;
        return kind_size + (alignment - kind_size % alignment) % alignment;
    }
};

// ******************************* //
//***   Symbol / Field Struct   ***//
// ******************************* //

/// Used to store information about a variable/symbol
pub const Symbol = struct {
    source_module: *Module,
    borrowing_module: *Module,
    name: []const u8,
    kind: KindId,
    scope: ScopeKind,
    dcl_line: u64,
    dcl_column: u64,
    is_mutable: bool,
    public: bool,
    has_mutated: bool,
    mem_loc: u64,
    size: u64,
    used: bool,

    /// Make a new symbol
    pub fn init(module: *Module, name: []const u8, kind: KindId, scope: ScopeKind, dcl_line: u64, dcl_column: u64, is_mutable: bool, public: bool, mem_loc: u64, size: u64) Symbol {
        const symbol_name = if (scope != .LOCAL)
            std.fmt.allocPrint(module.stm.allocator, "{s}__{s}", .{ module.path, name }) catch unreachable
        else
            name;
        return Symbol{
            .source_module = module,
            .borrowing_module = module,
            .name = symbol_name,
            .kind = kind,
            .scope = scope,
            .dcl_line = dcl_line,
            .dcl_column = dcl_column,
            .is_mutable = is_mutable,
            .public = public,
            .has_mutated = false,
            .mem_loc = mem_loc,
            .size = size,
            .used = false,
        };
    }

    /// Make a new symbol
    pub fn initAsField(module: *Module, struct_name: []const u8, name: []const u8, kind: KindId, scope: ScopeKind, dcl_line: u64, dcl_column: u64, is_mutable: bool, public: bool, mem_loc: u64, size: u64) Symbol {
        const symbol_name = if (public)
            (std.fmt.allocPrint(module.stm.allocator, "{s}__{s}__{s}", .{ module.path, struct_name, name }) catch unreachable)
        else
            (std.fmt.allocPrint(module.stm.allocator, "{s}__{s}", .{ struct_name, name }) catch unreachable);

        return Symbol{
            .source_module = module,
            .borrowing_module = module,
            .name = symbol_name,
            .kind = kind,
            .scope = scope,
            .dcl_line = dcl_line,
            .dcl_column = dcl_column,
            .is_mutable = is_mutable,
            .public = public,
            .has_mutated = false,
            .mem_loc = mem_loc,
            .size = size,
            .used = false,
        };
    }
};

// *********************** //
//***  Data type Stuff  ***//
// *********************** //

// Enum for the types available in Zav
pub const Kinds = enum { ANY, VOID, BOOL, UINT, INT, FLOAT32, FLOAT64, PTR, ARRAY, FUNC, STRUCT, UNION, ENUM, USER_KIND, MODULE, GENERIC, GENERIC_USER_KIND };

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
    UNION: Union,
    ENUM: Enum,
    USER_KIND: []const u8,
    MODULE: *Module,
    GENERIC: Generic,
    GENERIC_USER_KIND: GenericUserKind,

    pub fn copy(self: KindId, allocator: std.mem.Allocator) KindId {
        switch (self) {
            .PTR => |ptr| {
                const new_child = ptr.child.copy(allocator);
                return KindId.newPtr(allocator, new_child, ptr.const_child);
            },
            .ARRAY => |arr| {
                const new_child = arr.child.copy(allocator);
                return KindId.newArr(allocator, new_child, arr.length, arr.const_items, arr.static);
            },
            .FUNC => |func| {
                const new_ret_kind = allocator.create(KindId) catch unreachable;
                new_ret_kind.* = func.ret_kind.*;
                const new_arg_kinds = allocator.alloc(KindId, func.arg_kinds.len) catch unreachable;
                for (0..new_arg_kinds.len) |i| {
                    new_arg_kinds[i] = func.arg_kinds[i].copy(allocator);
                }
                const new_func = Function{
                    .arg_kinds = new_arg_kinds,
                    .ret_kind = new_ret_kind,
                    .variadic = func.variadic,
                    .args_size = func.args_size,
                    .made_anon_ptr = func.made_anon_ptr,
                };
                return KindId{ .FUNC = new_func };
            },
            .GENERIC_USER_KIND => |gen_user_kind| {
                const new_gen_kinds = allocator.alloc(KindId, gen_user_kind.generic_kinds.len) catch unreachable;
                for (0..new_gen_kinds.len) |i| {
                    new_gen_kinds[i] = gen_user_kind.generic_kinds[i].copy(allocator);
                }
                const new_gen = GenericUserKind{ .generic_kinds = new_gen_kinds, .id = gen_user_kind.id };
                return KindId{ .GENERIC_USER_KIND = new_gen };
            },
            else => return self,
        }
    }

    pub fn to_str(self: KindId, str: *std.ArrayList(u8), stm: *SymbolTableManager) void {
        switch (self) {
            .VOID => str.appendSlice("void") catch unreachable,
            .BOOL => str.appendSlice("bool") catch unreachable,
            .UINT => |uint| {
                const str_rep = std.fmt.allocPrint(str.allocator, "u{d}", .{uint.bits}) catch unreachable;
                str.appendSlice(str_rep) catch unreachable;
                str.allocator.free(str_rep);
            },
            .INT => |int| {
                const str_rep = std.fmt.allocPrint(str.allocator, "i{d}", .{int.bits}) catch unreachable;
                str.appendSlice(str_rep) catch unreachable;
                str.allocator.free(str_rep);
            },
            .FLOAT32 => str.appendSlice("f32") catch unreachable,
            .FLOAT64 => str.appendSlice("f64") catch unreachable,
            .PTR => |ptr| {
                if (ptr.const_child) {
                    str.appendSlice("@p") catch unreachable;
                } else {
                    str.appendSlice("@cp") catch unreachable;
                }
                ptr.child.to_str(str, stm);
            },
            .ARRAY => |arr| {
                if (arr.const_items) {
                    str.appendSlice("@a") catch unreachable;
                } else {
                    str.appendSlice("@ca") catch unreachable;
                }
                arr.child.to_str(str, stm);
            },
            .FUNC => |func| {
                const str_rep = std.fmt.allocPrint(str.allocator, "fn{d}", .{func.arg_kinds.len}) catch unreachable;
                str.appendSlice(str_rep) catch unreachable;
                str.allocator.free(str_rep);
                for (func.arg_kinds) |arg| {
                    arg.to_str(str, stm);
                }
                func.ret_kind.to_str(str, stm);
            },
            .STRUCT => |strct| {
                const symbol = stm.getSymbol(strct.name) catch unreachable;
                str.appendSlice(symbol.name) catch unreachable;
            },
            .UNION => |unin| {
                const symbol = stm.getSymbol(unin.name) catch unreachable;
                str.appendSlice(symbol.name) catch unreachable;
            },
            .ENUM => |enm| {
                const symbol = stm.getSymbol(enm.name) catch unreachable;
                str.appendSlice(symbol.name) catch unreachable;
            },
            else => unreachable,
        }
    }

    pub fn newGeneric(body: Stmt.StmtNode, generic_names: []Token) KindId {
        const gen = Generic{ .body = body, .generic_names = generic_names };
        return KindId{ .GENERIC = gen };
    }
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

        const final_arg_kinds = if (ret_kind == .STRUCT or ret_kind == .UNION) blk: {
            const new_arg_kinds = allocator.alloc(KindId, arg_kinds.len + 1) catch unreachable;
            std.mem.copyForwards(KindId, new_arg_kinds, arg_kinds);
            new_arg_kinds[new_arg_kinds.len - 1] = KindId.newPtr(allocator, ret_kind, false);
            break :blk new_arg_kinds;
        } else arg_kinds;
        const made_anon_ptr = ret_kind == .STRUCT or ret_kind == .UNION;

        const func = Function{
            .arg_kinds = final_arg_kinds,
            .variadic = variadic,
            .ret_kind = ret_ptr,
            .args_size = undefined,
            .made_anon_ptr = made_anon_ptr,
        };
        return KindId{ .FUNC = func };
    }
    /// Init a new Struct kindid with a defined scope
    pub fn newStructWithIndex(allocator: std.mem.Allocator, name: []const u8, index: *Stmt.StructStmt, stm: *SymbolTableManager) KindId {
        const new_scope = allocator.create(StructScope) catch unreachable;
        new_scope.* = StructScope.init(allocator);
        const new_struct = Struct{ .name = name, .fields = new_scope, .index = index, .stm = stm };
        return KindId{ .STRUCT = new_struct };
    }
    /// Init a new Struct kindid with no scope
    pub fn newStruct(name: []const u8) KindId {
        const new_struct = Struct{ .name = name, .fields = undefined };
        return KindId{ .STRUCT = new_struct };
    }
    pub fn newUnion(allocator: std.mem.Allocator, name: []const u8, index: *Stmt.UnionStmt, stm: *SymbolTableManager) KindId {
        const new_scope = allocator.create(UnionScope) catch unreachable;
        new_scope.* = UnionScope.init(allocator);
        const new_union = Union{ .name = name, .fields = new_scope, .index = index, .stm = stm };
        return KindId{ .UNION = new_union };
    }
    /// Make an enum with a variant field
    pub fn newEnumWithVariants(name: []const u8, variants: *std.StringHashMap(Symbol)) KindId {
        const new_enum = Enum{ .name = name, .variants = variants };
        return KindId{ .ENUM = new_enum };
    }
    /// Make an empty enum
    pub fn newEnum(name: []const u8) KindId {
        const new_enum = Enum{ .name = name, .variants = undefined };
        return KindId{ .ENUM = new_enum };
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
            .UNION => |unon| return other == .UNION and unon.equal(other.UNION),
            .ENUM => |enm| return other == .ENUM and enm.equal(other.ENUM),
            .USER_KIND, .MODULE, .GENERIC, .GENERIC_USER_KIND => unreachable,
        };
    }

    /// Return the size of the Kind
    pub fn size(self: KindId) u64 {
        return switch (self) {
            .VOID, .MODULE, .GENERIC => 0,
            .BOOL => 1,
            .UINT => |uint| uint.size(),
            .INT => |int| int.size(),
            .FLOAT32 => 4,
            .ANY, .FLOAT64, .PTR, .FUNC => 8,
            .ARRAY => |arr| arr.size(),
            .STRUCT => |stct| stct.fields.size(),
            .UNION => |unon| unon.fields.size(),
            .ENUM => 2,
            .USER_KIND, .GENERIC_USER_KIND => unreachable,
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
            .ANY, .FLOAT64, .PTR, .ARRAY, .FUNC, .STRUCT, .UNION => 8,
            .ENUM => 2,
            .USER_KIND, .MODULE, .GENERIC, .GENERIC_USER_KIND => unreachable,
        };
    }

    /// Update a user defined type
    pub fn update(self: *KindId, stm: *SymbolTableManager, checker: *TypeChecker) ScopeError!usize {
        return switch (self.*) {
            .VOID => 0,
            .BOOL => 1,
            .UINT => |uint| uint.size(),
            .INT => |int| int.size(),
            .FLOAT32 => 4,
            .FLOAT64 => 8,
            .PTR => |*ptr| ptr.updatePtr(stm, checker),
            .ARRAY => |*arr| arr.updateArray(stm, checker),
            .FUNC => |*func| func.updateArgSize(stm, checker),
            .UNION => |*unon| unon.updateFields(stm, unon.name),
            .STRUCT => |*strct| strct.updateFields(stm, strct.name),
            .ENUM => |*enm| enm.updateVariants(stm, enm.name),
            .USER_KIND => |name| {
                const symbol = try stm.peakSymbol(name);

                switch (symbol.kind) {
                    .STRUCT => {
                        self.* = symbol.kind;
                        self.STRUCT.name = name;
                        return self.STRUCT.updateFields(stm, name);
                    },
                    .UNION => {
                        self.* = symbol.kind;
                        self.UNION.name = name;
                        return self.UNION.updateFields(stm, name);
                    },
                    .ENUM => {
                        self.* = symbol.kind;
                        self.ENUM.name = name;
                        return self.ENUM.updateVariants(stm, name);
                    },
                    else => {
                        if (symbol.scope != .KIND) {
                            return ScopeError.UndeclaredSymbol;
                        } else {
                            self.* = symbol.kind;
                            return self.update(stm, checker);
                        }
                    },
                }
            },
            .GENERIC_USER_KIND => return checker.check_generic_user_kind(self) catch return ScopeError.UndeclaredSymbol,
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
    METHOD,
    STRUCT,
    UNION,
    ENUM,
    ENUM_VARIANT,
    MODULE,
    KIND,
    GENERIC,
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
    pub fn updatePtr(self: *Pointer, stm: *SymbolTableManager, checker: *TypeChecker) ScopeError!usize {
        _ = try self.child.update(stm, checker);
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
    pub fn updateArray(self: *Array, stm: *SymbolTableManager, checker: *TypeChecker) ScopeError!usize {
        const child_size = try self.child.update(stm, checker);
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
    made_anon_ptr: bool,

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
    pub fn updateArgSize(self: *Function, stm: *SymbolTableManager, checker: *TypeChecker) ScopeError!usize {
        _ = try self.ret_kind.update(stm, checker);
        if (!self.made_anon_ptr) {
            if (self.ret_kind.* == .STRUCT or self.ret_kind.* == .UNION) {
                const new_arg_kinds = stm.allocator.alloc(KindId, self.arg_kinds.len + 1) catch unreachable;
                std.mem.copyForwards(KindId, new_arg_kinds, self.arg_kinds);
                new_arg_kinds[new_arg_kinds.len - 1] = KindId.newPtr(stm.allocator, self.ret_kind.*, false);
                self.arg_kinds = new_arg_kinds;
            }
            self.made_anon_ptr = true;
        }

        var size: usize = 0;
        for (self.arg_kinds) |*kind| {
            const child_size = try kind.update(stm, checker);
            size += child_size;
            const alignment: u64 = if (child_size > 4) 8 else if (child_size > 2) 4 else if (child_size > 1) 2 else 1;
            const offset = size & (alignment - 1);
            if (offset != 0) {
                size += alignment - offset;
            }
        }
        self.args_size = size;

        return 8;
    }
};

/// Structure data type
pub const Struct = struct {
    name: []const u8,
    fields: *StructScope,
    index: *Stmt.StructStmt = undefined,
    stm: *SymbolTableManager = undefined,

    /// Returns true if two structs are the same
    pub fn equal(self: Struct, other: Struct) bool {
        return self.fields == other.fields;
    }

    /// Resolve the struct size of a user defined struct kind
    pub fn updateFields(self: *Struct, stm: *SymbolTableManager, name: []const u8) ScopeError!usize {
        const symbol = try stm.getSymbol(name);
        if (symbol.kind != .STRUCT) return ScopeError.UndeclaredSymbol;
        self.fields = symbol.kind.STRUCT.fields;
        return self.fields.next_address;
    }
};

pub const Union = struct {
    name: []const u8,
    fields: *UnionScope,
    index: *Stmt.UnionStmt = undefined,
    stm: *SymbolTableManager = undefined,

    pub fn equal(self: Union, other: Union) bool {
        return self.fields == other.fields;
    }

    pub fn updateFields(self: *Union, stm: *SymbolTableManager, name: []const u8) ScopeError!usize {
        const symbol = try stm.getSymbol(name);
        if (symbol.kind != .UNION) return ScopeError.UndeclaredSymbol;
        self.fields = symbol.kind.UNION.fields;
        return self.fields.max_size;
    }
};

/// Stores enum types
///
/// All enums are treated as u16 at runtime
pub const Enum = struct {
    name: []const u8,
    variants: *std.StringHashMap(Symbol),

    pub fn equal(self: Enum, other: Enum) bool {
        return self.variants == other.variants;
    }

    /// Resolve the struct size of a user defined struct kind
    pub fn updateVariants(self: *Enum, stm: *SymbolTableManager, name: []const u8) ScopeError!usize {
        const symbol = try stm.getSymbol(name);
        if (symbol.kind != .ENUM) return ScopeError.UndeclaredSymbol;
        self.variants = symbol.kind.ENUM.variants;
        return 2;
    }
};

pub const Generic = struct {
    generic_names: []Token,
    body: Stmt.StmtNode,
};

pub const GenericUserKind = struct {
    generic_kinds: []KindId,
    id: Token,
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
