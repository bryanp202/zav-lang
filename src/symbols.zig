const std = @import("std");

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
    // Constant Resolution
    constants: std.AutoHashMap(Value, Constant),
    // Stores memory offset for next global
    next_address: u64,

    /// Init a STM
    pub fn init(allocator: std.mem.Allocator) SymbolTableManager {
        // Make global scope
        const global = allocator.create(Scope) catch unreachable;
        global.* = Scope.init(allocator, null);

        // Make scopes stack
        var scopes = std.ArrayList(*Scope).init(allocator);
        scopes.append(global) catch unreachable;

        // Return a new STM
        return SymbolTableManager{
            .allocator = allocator,
            .scopes = scopes,
            .next_scope = 1,
            .active_scope = global,
            .next_address = 0,
        };
    }
    /// Deinit a STM
    pub fn deinit(self: *SymbolTableManager) void {
        // Deinitialize all scopes
        for (self.scopes.items) |scope| {
            scope.deinit();
            self.allocator.destroy(scope);
        }
        // Deinit scopes stack
        self.scopes.deinit();
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
        // Make new scope
        const new_scope = self.allocator.create(Scope) catch unreachable;
        new_scope.* = Scope.init(self.allocator, self.active_scope);
        // Set to active scope
        self.active_scope = new_scope;
        // Add to scopes stack
        self.scopes.append(new_scope) catch unreachable;

        // Increment current scope counter
        self.next_scope += 1;
    }

    /// Push the next scope onto the active scope stack
    pub fn pushScope(self: *SymbolTableManager) void {
        // Put next scope as active scope
        self.active_scope = self.scopes.items[self.current];

        // Increment counter
        self.next_scope += 1;
    }

    /// Pop the current active scope from the active scope stack
    pub fn popScope(self: *SymbolTableManager) void {
        // Pop scope
        self.active_scope = self.active_scope.enclosing.?;
    }

    /// Add a new symbol, with all of its attributes, and assign it a memory location
    /// Static or stack relative depending on scope kind
    pub fn declareSymbol(
        self: *SymbolTableManager,
        name: []const u8,
        kind: KindId,
        scope: ScopeKind,
        dcl_line: u64,
        is_mutable: bool,
    ) !void {
        // Calculate the size of the kind
        const size = kind.size();
        // If scope type of symbol is global, use next memory location and increment it
        const abs_mem_loc = self.next_address;
        if (scope == ScopeKind.GLOBAL) {
            self.next_address += size;
        }

        // Else let the local scope calculate the local scope
        try self.active_scope.declareSymbol(name, kind, scope, dcl_line, is_mutable, abs_mem_loc, size);
    }

    /// Add a new symbol to the top scope on the stack
    pub fn getSymbol(self: SymbolTableManager, name: []const u8) Scope.ScopeError!Symbol {
        // Get top scope
        return self.active_scope.getSymbol(name);
    }

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
    /// Deinitialize a scope
    pub fn deinit(self: *Scope) void {
        // Free KindId for all values in the table
        var symbol_iter = self.symbols.valueIterator();
        while (symbol_iter.next()) |symbol| {
            // Deinit KindId
            symbol.kind.deinit(self.symbols.allocator);
        }
        // Deinit the table
        self.symbols.deinit();
    }

    /// Add a new symbol, providing all of its attributes
    pub fn declareSymbol(
        self: *Scope,
        name: []const u8,
        kind: KindId,
        scope: ScopeKind,
        dcl_line: u64,
        is_mutable: bool,
        mem_loc: ?u64,
        size: u64,
    ) ScopeError!void {
        // Check if in table
        const getOrPut = self.symbols.getOrPut(name) catch unreachable;
        // Check if it is already in table
        if (getOrPut.found_existing) {
            // Free the KindId
            kind.deinit(self.symbols.allocator);
            // Throw error
            return ScopeError.DuplicateDeclaration;
        }

        // Calculate relative memory location if symbol is local
        var location: u64 = undefined;
        if (scope == ScopeKind.LOCAL) {
            location = self.next_address;
            // Increment next address
            self.next_address += kind.size();
        } else {
            location = mem_loc.?;
        }

        // Add symbol to the table
        const new_symbol = Symbol.init(name, kind, scope, dcl_line, is_mutable, location, size);
        getOrPut.value_ptr.* = new_symbol;
    }

    /// Try to get a symbol based off of a name
    pub fn getSymbol(self: *Scope, name: []const u8) ScopeError!Symbol {
        // Check this and all enclosing scopes for a declared symbol as name
        var curr: ?*Scope = self;
        while (curr) |enclosing| : (curr = enclosing.enclosing) {
            const maybeSymbol = enclosing.symbols.get(name);
            if (maybeSymbol) |sym| return sym;
        }
        return ScopeError.UndeclaredSymbol;
    }

    /// Mark a symbol as mutated
    pub fn mutateSymbol(self: Scope, name: []const u8) ScopeError!void {
        // Check this and all enclosing scopes for a declared symbol as name
        var curr: ?*Scope = self;
        while (curr) |enclosing| : (curr = enclosing.enclosing) {
            // Search for symbol
            const maybeSymbol = enclosing.symbols.getPtr(name);

            // Check if matching symbol found
            if (maybeSymbol) |sym| {
                // Check if mutable
                if (sym.is_mutable) {
                    // Throw error
                    return ScopeError.MutateConstantSymbol;
                }
                sym.has_mutated = true;
            }
        }
        return ScopeError.UndeclaredSymbol;
    }

    /// Scope searching error type
    pub const ScopeError = error{ DuplicateDeclaration, MutateConstantSymbol, UndeclaredSymbol };
};

// *********************** //
//***   Symbol Struct   ***//
// *********************** //

/// Used to store information about a variable/symbol
pub const Symbol = struct {
    name: []const u8,
    kind: KindId,
    scope: ScopeKind,
    dcl_line: u64,
    is_mutable: bool,
    has_mutated: bool,
    mem_loc: u64,
    size: u64,

    /// Make a new symbol
    pub fn init(name: []const u8, kind: KindId, scope: ScopeKind, dcl_line: u64, is_mutable: bool, mem_loc: u64, size: u64) Symbol {
        return Symbol{
            .name = name,
            .kind = kind,
            .scope = scope,
            .dcl_line = dcl_line,
            .is_mutable = is_mutable,
            .has_mutated = false,
            .mem_loc = mem_loc,
            .size = size,
        };
    }
};

// *********************** //
//***  Data type Stuff  ***//
// *********************** //

// Enum for the types available in Zav
pub const Kinds = enum {
    VOID,
    BOOL,
    INT,
    FLOAT,
    PTR,
    ARRAY,
};

/// Used to mark what type a variable is
pub const KindId = union(Kinds) {
    VOID: void,
    BOOL: void,
    INT: Integer,
    FLOAT: Float,
    PTR: Pointer,
    ARRAY: Array,

    /// Deinit a KindId
    pub fn deinit(self: KindId, allocator: std.mem.Allocator) void {
        // Check if type needs to be destroyed
        switch (self) {
            // If non allocated types, do nothing
            .VOID, .BOOL, .INT, .FLOAT => return,
            // If a pointer delete all children
            .PTR => |ptr| {
                // Walk the linked list of children until a terminal node is found
                var curr = ptr.child;
                var next: *KindId = undefined;
                while (true) {
                    switch (curr.*) {
                        .PTR => |pointer| {
                            next = pointer.child;
                            allocator.destroy(curr);
                            curr = next;
                        },
                        .ARRAY => |array| {
                            next = array.child;
                            allocator.destroy(curr);
                            curr = next;
                        },
                        else => {
                            allocator.destroy(curr);
                            break;
                        },
                    }
                }
            },
            // If an array, delete all children
            .ARRAY => |arr| {
                // Walk the linked list of children until a terminal node is found
                var curr = arr.child;
                var next: *KindId = undefined;
                while (true) {
                    switch (curr.*) {
                        .PTR => |pointer| {
                            next = pointer.child;
                            allocator.destroy(curr);
                            curr = next;
                        },
                        .ARRAY => |array| {
                            next = array.child;
                            allocator.destroy(curr);
                            curr = next;
                        },
                        else => {
                            allocator.destroy(curr);
                            break;
                        },
                    }
                }
            },
        }
    }

    /// Init a new void
    pub fn newVoid() KindId {
        return KindId{
            .VOID,
        };
    }
    /// Init a new boolean
    pub fn newBool() KindId {
        return KindId.BOOL;
    }
    // Init a new integer
    pub fn newInt(bits: u16, signed: bool) KindId {
        const int = Integer{
            .signed = signed,
            .bits = bits,
        };
        return KindId{
            .INT = int,
        };
    }
    // Init a new float
    pub fn newFloat(bits: u16) KindId {
        const float = Float{
            .bits = bits,
        };
        return KindId{
            .FLOAT = float,
        };
    }
    // Init a new pointer
    pub fn newPtr(allocator: std.mem.Allocator, child_kind: KindId, levels: u16) KindId {
        // Dynamically allocate the child KindId tag
        const child_ptr = allocator.create(KindId) catch unreachable;
        child_ptr.* = child_kind;
        // Make new pointer
        const ptr = Pointer{
            .child = child_ptr,
            .levels = levels,
        };
        return KindId{
            .PTR = ptr,
        };
    }
    // Init a new pointer
    pub fn newArr(allocator: std.mem.Allocator, child_kind: KindId, length: u64) KindId {
        // Dynamically allocate the child KindId tag
        const child_ptr = allocator.create(KindId) catch unreachable;
        child_ptr.* = child_kind;
        // Make new array
        const arr = Array{
            .child = child_ptr,
            .length = length,
        };
        return KindId{
            .ARRAY = arr,
        };
    }

    /// Return the size of the Kind
    pub fn size(self: KindId) u64 {
        return switch (self) {
            .VOID => 0,
            .BOOL => 1,
            .INT => |int| int.size(),
            .FLOAT => |float| float.size(),
            .PTR => 8,
            .ARRAY => |arr| arr.size(),
        };
    }
};

/// Used to mark what kind of scope a variable has
pub const ScopeKind = enum {
    LOCAL,
    GLOBAL,
};

// *********************** //
//*** Data type Classes ***//
// *********************** //

/// Integer type data
pub const Integer = struct {
    signed: bool,
    bits: u16,

    /// Calculate the size of this type in bytes
    pub fn size(self: Integer) u64 {
        const bytes = std.math.divCeil(u64, self.bits, 8) catch unreachable;
        return bytes;
    }
};

/// Float Type data
pub const Float = struct {
    bits: u16,

    /// Calculate the size of this type in bytes
    pub fn size(self: Float) u64 {
        const bytes = std.math.divCeil(u64, self.bits, 8) catch unreachable;
        return bytes;
    }
};

/// Pointer Type data
pub const Pointer = struct {
    child: *KindId,
    levels: u16,
};

/// Array Type data
pub const Array = struct {
    child: *KindId,
    length: u64,

    /// Calculate the size of this type in bytes
    pub fn size(self: Array) u64 {
        const element_size = self.child.size();
        const bytes = element_size * self.length;
        return bytes;
    }
};

// *********************** //
//***Values/Const Structs**//
// *********************** //
