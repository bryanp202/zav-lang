const std = @import("std");
// Imports
// Tokens and TokenKind
const Scan = @import("scanner.zig");
const Token = Scan.Token;
const TokenKind = Scan.TokenKind;
// STM, Symbols, types, and constants
const Symbols = @import("../symbols.zig");
const STM = Symbols.SymbolTableManager;
const Value = Symbols.Value;
const KindId = Symbols.KindId;
const Symbol = Symbols.Symbol;
const ScopeKind = Symbols.ScopeKind;
// Error
const Error = @import("../error.zig");
const SemanticError = Error.SemanticError;
const ScopeError = Error.ScopeError;
// Expr
const Expr = @import("../expr.zig");
const ExprNode = Expr.ExprNode;
// Stmts
const Stmt = @import("../stmt.zig");
const StmtNode = Stmt.StmtNode;
// Module
const Module = @import("../module.zig");

// Type Checker fields
const TypeChecker = @This();
allocator: std.mem.Allocator,
stm: *STM,
// Control flow handling
loop_depth: u32,
switch_depth: u32,
// Error handling
had_error: bool,
panic: bool,
// Current functions return type
current_return_kind: KindId,
current_scope_count: u16,

/// Initialize a new TypeChecker
pub fn init(allocator: std.mem.Allocator) TypeChecker {
    return TypeChecker{
        .allocator = allocator,
        .stm = undefined,
        .loop_depth = 0,
        .switch_depth = 0,
        .had_error = false,
        .panic = false,
        .current_return_kind = KindId.VOID,
        .current_scope_count = undefined,
    };
}

/// Trace through a AST, checking for type errors
/// and adding more lower level AST nodes as needed
/// in preparation for code generation
/// Returns true if semantics are okay
pub fn check(self: *TypeChecker, module: *Module) void {
    self.stm = &module.stm;

    // Define all enums
    for (module.enumSlice()) |enm| {
        self.declareEnum(enm.ENUM) catch {
            self.panic = false;
            self.had_error = true;
            continue;
        };
    }
    // If had error in enum names, return
    if (self.had_error) {
        return;
    }

    // Index all struct definitions
    for (module.structSlice(), 0..) |strct, index| {
        // Add it to symbol table
        self.indexStruct(strct.STRUCT.id, index, strct.STRUCT.public) catch {
            self.panic = false;
            self.had_error = true;
            continue;
        };
    }
    // If had error in struct names, return
    if (self.had_error) {
        return;
    }

    // Define all structs
    for (module.structSlice()) |strct| {
        // Get from stm
        const symbol = self.stm.getSymbol(strct.STRUCT.id.lexeme) catch unreachable;
        if (!symbol.kind.STRUCT.declared) {
            // Declare the new kind with its fields, checking for circular dependencies
            self.declareStruct(module, symbol, strct.STRUCT) catch {
                self.panic = false;
                self.had_error = true;
                return;
            };
        }
    }

    // Check all global statements and functions first
    // Declare all functions
    for (module.functionSlice()) |function| {
        // Declare function but do not analyze body
        self.declareFunction(function.FUNCTION) catch {
            self.panic = false;
            self.had_error = true;
            continue;
        };
    }
    // Visit globals
    for (module.globalSlice()) |*global| {
        // Analyze globals
        self.visitGlobalStmt(global.GLOBAL) catch {
            self.panic = false;
            self.had_error = true;
            continue;
        };
    }
    // Look for function called main and make sure it has proper arguments
    self.checkForMain() catch {
        self.had_error = true;
        return;
    };

    // If had error in delcarations return
    if (self.had_error) {
        return;
    }

    // Reset the symbol table managers stack for function evaluation
    self.stm.resetStack();

    // Check all method bodies in each struct
    for (module.structSlice()) |*strct| {
        // Get struct symbol
        const struct_symbol = self.stm.peakSymbol(strct.STRUCT.id.lexeme) catch unreachable;
        for (strct.STRUCT.methods) |*method| {
            // Get args size
            const method_field = struct_symbol.kind.STRUCT.fields.getField(method.name.lexeme) catch unreachable;
            const args_size = method_field.kind.FUNC.args_size;
            // analyze all function bodies, continue if there was an error
            self.visitFunctionStmt(method, args_size) catch {
                self.panic = false;
                self.had_error = true;
                continue;
            };
        }
    }

    // Check all function bodies in the module
    for (module.functionSlice()) |*function| {
        // Get arg_size
        const func_symbol = self.stm.peakSymbol(function.FUNCTION.name.lexeme) catch unreachable;
        const args_size = func_symbol.kind.FUNC.args_size;
        // analyze all function bodies, continue if there was an error
        self.visitFunctionStmt(function.FUNCTION, args_size) catch {
            self.panic = false;
            self.had_error = true;
            continue;
        };
    }

    // Check for unmutated var in global scope
    self.checkVarInScope();
}

/// Returns true if this type checker has ever encountered an error
pub fn hadError(self: TypeChecker) bool {
    return self.had_error;
}

// ********************** //
// Private helper methods //
// ********************** //
/// Look for main function, ensure it has proper argmunents and return type
fn checkForMain(self: *TypeChecker) SemanticError!void {
    // Used to report errors
    const stderr = std.io.getStdErr().writer();
    // Search for symbol
    const main_func = self.stm.getSymbol("main") catch {
        _ = stderr.write("Expected 'main' function with args (argc: u64, argv: **u8)\n") catch unreachable;
        return SemanticError.InvalidMainFunction;
    };

    // Check types of main
    const main_kindid = main_func.kind;
    if (main_kindid == .FUNC) {
        const main_kind = main_kindid.FUNC;
        if (main_kind.arg_kinds.len == 2) {
            const first_arg = main_kind.arg_kinds[0];
            if (first_arg == .INT and first_arg.INT.bits == 64) {
                const second_arg = main_kind.arg_kinds[1];
                if (second_arg == .PTR and second_arg.PTR.child.* == .PTR) {
                    const second_arg_child = second_arg.PTR.child.*;
                    if (second_arg_child == .PTR and second_arg_child.PTR.child.* == .UINT and second_arg_child.PTR.child.UINT.bits == 8) {
                        return;
                    }
                }
            }
        }
    }

    _ = stderr.write("Expected 'main' function with args (argc: i64, argv: **u8)\n") catch unreachable;
    return SemanticError.InvalidMainFunction;
}

/// Pop the active STM scope, checking for any unmutated var declared symbols
fn checkVarInScope(self: *TypeChecker) void {
    // Used to report errors
    const stderr = std.io.getStdErr().writer();

    // Check each symbol
    var symbol_iter = self.stm.active_scope.symbols.iterator();
    // Check each symbol
    while (symbol_iter.next()) |entry| {
        const symbol = entry.value_ptr;
        if (symbol.is_mutable and !symbol.has_mutated) {
            // Alert user
            stderr.print(
                "[Declared on Line {d}] as \'{s}\': Var identifier was never mutated\n",
                .{ symbol.dcl_line, symbol.name },
            ) catch unreachable;
            // Update had error
            self.had_error = true;
        }
    }
}

/// Return the new size for a UInt being upgraded to a signed int
/// UInt.bits < 64 -> x2; else 64
/// This causes some potentially weird behaviour on i64, u64 interactions, but only in very large numbers
inline fn upgradeUIntBits(bits: u16) KindId {
    const new_bits = if (bits < 64) bits * 2 else bits;
    return KindId.newInt(new_bits);
}

/// Report an error and set error flag
/// Do not show errors in panic mode
/// Show where a the previous usage of the identifier was declared
fn reportDuplicateError(self: *TypeChecker, duplicate_id: Token, dcl_line: u64, dcl_column: u64) SemanticError {
    const stderr = std.io.getStdErr().writer();

    // Only display errors when not in panic mode
    if (!self.panic) {
        // Display message
        stderr.print(
            "[Line {d}:{d}] at \'{s}\': Identifier already declared on [Line {d}:{d}]\n",
            .{ duplicate_id.line, duplicate_id.column, duplicate_id.lexeme, dcl_line, dcl_column },
        ) catch unreachable;

        // Update had error and panic mode
        self.had_error = true;
        self.panic = true;
    }
    // Raise error
    return SemanticError.DuplicateDeclaration;
}

/// Report an error and set error flag
/// Do not show additional errors in panic mode
fn reportError(self: *TypeChecker, errorType: SemanticError, token: Token, msg: []const u8) SemanticError {
    const stderr = std.io.getStdErr().writer();

    // Only display errors when not in panic mode
    if (!self.panic) {
        // Display message
        stderr.print("[Line {d}:{d}] at \'{s}\': {s}\n", .{ token.line, token.column, token.lexeme, msg }) catch unreachable;

        // Update had error and panic mode
        self.had_error = true;
        self.panic = true;
    }
    // Raise error
    return errorType;
}

// ************************* //
// Two type upgrade/coercion //
// ************************* //
/// Inserts a conversion expression
fn insertConvExpr(allocator: std.mem.Allocator, node: *ExprNode, kind: KindId) void {
    // Make new expression
    const convExpr = allocator.create(Expr.ConversionExpr) catch unreachable;
    // Put old node into new expr
    convExpr.* = Expr.ConversionExpr.init(undefined, node.*);
    // Make new node
    const new_node = ExprNode.initWithKind(
        Expr.ExprUnion{ .CONVERSION = convExpr },
        kind,
    );
    // Put in old nodes spot
    node.* = new_node;
}

/// Stores data about a coercion attempt
const CoercionResult = struct {
    final_kind: KindId,
    upgraded_lhs: bool,
    upgraded_rhs: bool,

    pub fn init(kind: KindId, left_upgrade: bool, right_upgrade: bool) CoercionResult {
        return CoercionResult{ .final_kind = kind, .upgraded_lhs = left_upgrade, .upgraded_rhs = right_upgrade };
    }
};

/// Returns a CoercionResult for two KindIds, one argument/static type and one expression defined type
/// If the two kindids can be coerced or are equal, then it returns the upgraded type,
/// but will return error if the static kind is upgraded
fn staticCoerceKinds(self: *TypeChecker, op: Token, static_kind: KindId, rhs_kind: KindId) SemanticError!CoercionResult {
    switch (static_kind) {
        // Any kind
        .ANY => {
            return CoercionResult.init(rhs_kind, false, false);
        },
        // Left Bool
        .BOOL => switch (rhs_kind) {
            // Left Bool | Right Bool
            .BOOL => {
                // Return lhs, both the same
                return CoercionResult.init(static_kind, false, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left UInt
        .UINT => |l_uint| switch (rhs_kind) {
            // Left UInt | Right Bool
            .BOOL => {
                return CoercionResult.init(static_kind, false, false);
            },
            // Left UInt | Right UInt
            .UINT => |r_uint| {
                // See if static type is bigger or equal
                if (l_uint.bits >= r_uint.bits) {
                    return CoercionResult.init(static_kind, false, false);
                }
                // Throw error
                return self.reportError(SemanticError.TypeMismatch, op, "Cannot implicitly downgrade UINT size");
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left Int
        .INT => |l_int| switch (rhs_kind) {
            // Left Int | Right Bool
            .BOOL => {
                // Return the int
                return CoercionResult.init(static_kind, false, false);
            },
            // Left Int | Right UInt
            .UINT => |r_uint| {
                // See what upgraded UINT would be
                const signed_int = upgradeUIntBits(r_uint.bits);
                // Determine if int can hold upgraded UINT
                if (l_int.bits >= signed_int.INT.bits) {
                    return CoercionResult.init(static_kind, false, false);
                }
                // Cannot fit error
                return self.reportError(SemanticError.UnsafeCoercion, op, "This INT cannot store all values of this UINT");
            },
            // Left Int | Right Int
            .INT => |r_int| {
                // See if static type is bigger or equal
                if (l_int.bits >= r_int.bits) {
                    return CoercionResult.init(static_kind, false, false);
                }
                // Throw error
                return self.reportError(SemanticError.TypeMismatch, op, "Cannot implicitly downgrade INT size");
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left Float32
        .FLOAT32 => switch (rhs_kind) {
            // Left Float | Right Int
            .BOOL, .UINT, .INT => {
                // Return the float
                return CoercionResult.init(static_kind, false, true);
            },
            // Left Float | Right Float
            .FLOAT32 => {
                // Else they are the same, no coercion
                return CoercionResult.init(static_kind, false, false);
            },
            .FLOAT64 => {
                // Return error
                return self.reportError(SemanticError.TypeMismatch, op, "Cannot implicitly downgrade F32 to F64 size");
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left Float32
        .FLOAT64 => switch (rhs_kind) {
            // Left Float | Right Int
            .BOOL, .UINT, .INT => {
                // Return the float
                return CoercionResult.init(static_kind, false, true);
            },
            // Left Float | Right Float
            .FLOAT32 => {
                // Return the float with more bits
                return CoercionResult.init(static_kind, false, true);
            },
            .FLOAT64 => {
                // Else they are the same, no coercion
                return CoercionResult.init(static_kind, false, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left PTR
        .PTR => |l_ptr| switch (rhs_kind) {
            .PTR => |r_ptr| {
                if (!l_ptr.equal(r_ptr)) {
                    return self.reportError(SemanticError.TypeMismatch, op, "Pointers must be the same kind");
                }
                // Check if making constant data mutable
                if (r_ptr.const_child and !l_ptr.const_child) {
                    return self.reportError(SemanticError.UnsafeCoercion, op, "Cannot downgrade pointer of constant data");
                }
                // Return static kind
                return CoercionResult.init(static_kind, false, false);
            },
            // Right - array
            .ARRAY => |array| {
                // Check if making constant data mutable
                if (array.const_items and !l_ptr.const_child) {
                    return self.reportError(SemanticError.UnsafeCoercion, op, "Cannot downgrade pointer of constant data");
                }
                const array_ptr = KindId.newPtrFromArray(rhs_kind, array.const_items);
                if (!l_ptr.equal(array_ptr.PTR)) {
                    return self.reportError(SemanticError.TypeMismatch, op, "Pointers must be the same kind");
                }
                // Return a static kind
                return CoercionResult.init(static_kind, false, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left bool | Right Array
        .ARRAY => |l_array| switch (rhs_kind) {
            // Right - array
            .ARRAY => |r_array| {
                // Check if making constant data mutable
                if (r_array.const_items and !l_array.const_items) {
                    return self.reportError(SemanticError.UnsafeCoercion, op, "Cannot downgrade array of constant data");
                }
                // If not equal, error
                if (!l_array.equal(r_array)) {
                    return self.reportError(SemanticError.TypeMismatch, op, "Arrays must be the same length");
                }
                // Return static kind
                return CoercionResult.init(static_kind, false, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // For all other types
        else => {
            // If the equal
            if (static_kind.equal(rhs_kind)) {
                // Return lhs and and no upgrades
                return CoercionResult.init(static_kind, false, false);
            }
            // Else no implicit coercion defined
            return self.reportError(SemanticError.TypeMismatch, op, "Incompatible types");
        },
    }
}

/// Returns a CoercionResult for two KindIds
/// If the two kindids can be coerced or are equal, then it returns the upgraded type
fn coerceKinds(self: *TypeChecker, op: Token, lhs_kind: KindId, rhs_kind: KindId) SemanticError!CoercionResult {
    switch (lhs_kind) {
        // Left Bool
        .BOOL => switch (rhs_kind) {
            // Left Bool | Right Bool
            .BOOL => {
                // Return lhs, both the same
                return CoercionResult.init(lhs_kind, false, false);
            },
            // Left Bool | Right (U)Int
            .UINT, .INT => {
                // Return rhs, both the same
                return CoercionResult.init(rhs_kind, false, false);
            },
            // Left Bool | Right Float
            .FLOAT32, .FLOAT64 => {
                // Return the float
                return CoercionResult.init(rhs_kind, true, false);
            },
            // Left Bool | Right ptr
            .PTR => {
                // Return the ptr
                return CoercionResult.init(rhs_kind, false, false);
            },
            // Left bool | Right Array
            .ARRAY => |array| {
                // Decay to pointer
                const new_ptr = KindId.newPtrFromArray(rhs_kind, array.const_items);
                return CoercionResult.init(new_ptr, false, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left UInt
        .UINT => |l_uint| switch (rhs_kind) {
            // Left UInt | Right Bool
            .BOOL => {
                return CoercionResult.init(lhs_kind, false, false);
            },
            // Left UInt | Right UInt
            .UINT => |r_uint| {
                // Return the int with the most bits
                const bigger_kind = if (l_uint.bits >= r_uint.bits) lhs_kind else rhs_kind;
                return CoercionResult.init(bigger_kind, false, false);
            },
            // Left UInt | Right Int
            .INT => |r_int| {
                // Determine (u)int with most bits
                if (l_uint.bits >= r_int.bits) {
                    // Upgrade unsigned
                    const signed_int = upgradeUIntBits(l_uint.bits);
                    return CoercionResult.init(signed_int, false, false);
                }
                // Rhs is bigger
                return CoercionResult.init(rhs_kind, false, false);
            },
            // Left UInt | Right Float
            .FLOAT32, .FLOAT64 => {
                // Return the float
                return CoercionResult.init(rhs_kind, true, false);
            },
            // Left Uint | Right ptr
            .PTR => {
                // Return the ptr
                return CoercionResult.init(rhs_kind, false, false);
            },
            // Left Uint | Right Array
            .ARRAY => |array| {
                // Decay to pointer
                const new_ptr = KindId.newPtrFromArray(rhs_kind, array.const_items);
                return CoercionResult.init(new_ptr, false, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left Int
        .INT => |l_int| switch (rhs_kind) {
            // Left Int | Right Bool
            .BOOL => {
                // Return the int
                return CoercionResult.init(lhs_kind, false, false);
            },
            // Left Int | Right UInt
            .UINT => |r_uint| {
                // Determine (u)int with most bits
                if (l_int.bits > r_uint.bits) {
                    return CoercionResult.init(lhs_kind, false, false);
                }
                // Upgrade unsigned
                const signed_int = upgradeUIntBits(r_uint.bits);
                return CoercionResult.init(signed_int, false, false);
            },
            // Left Int | Right Int
            .INT => |r_int| {
                // Return the int with the most bits
                const bigger_kind = if (l_int.bits >= r_int.bits) lhs_kind else rhs_kind;
                return CoercionResult.init(bigger_kind, false, false);
            },
            // Left Int | Right Float
            .FLOAT32, .FLOAT64 => {
                // Return the float
                return CoercionResult.init(rhs_kind, true, false);
            },
            // Left Int | Right ptr
            .PTR => {
                // Return the ptr
                return CoercionResult.init(rhs_kind, false, false);
            },
            // Left Int | Right Array
            .ARRAY => |array| {
                // Decay to pointer
                const new_ptr = KindId.newPtrFromArray(rhs_kind, array.const_items);
                return CoercionResult.init(new_ptr, false, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left Float32
        .FLOAT32 => switch (rhs_kind) {
            // Left Float | Right Int
            .BOOL, .UINT, .INT => {
                // Return the float
                return CoercionResult.init(lhs_kind, false, true);
            },
            // Left Float | Right Float
            .FLOAT32 => {
                // Else they are the same, no coercion
                return CoercionResult.init(lhs_kind, false, false);
            },
            .FLOAT64 => {
                // Return the float with more bits
                return CoercionResult.init(rhs_kind, true, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left Float32
        .FLOAT64 => switch (rhs_kind) {
            // Left Float | Right Int
            .BOOL, .UINT, .INT => {
                // Return the float
                return CoercionResult.init(lhs_kind, false, true);
            },
            // Left Float | Right Float
            .FLOAT32 => {
                // Return the float with more bits
                return CoercionResult.init(lhs_kind, false, true);
            },
            .FLOAT64 => {
                // Else they are the same, no coercion
                return CoercionResult.init(lhs_kind, false, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left PTR
        .PTR => |l_ptr| switch (rhs_kind) {
            // Right - Integer number kind
            .BOOL, .UINT, .INT => return CoercionResult.init(rhs_kind, false, false),
            // Right - Ptr
            .PTR => |r_ptr| {
                if (!l_ptr.equal(r_ptr)) {
                    return self.reportError(SemanticError.TypeMismatch, op, "Pointers must be the same kind");
                }
                // Return a I64
                const new_int = KindId.newInt(64);
                return CoercionResult.init(new_int, false, false);
            },
            // Right - array
            .ARRAY => |array| {
                const array_ptr = KindId.newPtrFromArray(rhs_kind, array.const_items);
                if (!l_ptr.equal(array_ptr.PTR)) {
                    return self.reportError(SemanticError.TypeMismatch, op, "Pointers must be the same kind");
                }
                // Return a I64
                const new_int = KindId.newInt(64);
                return CoercionResult.init(new_int, false, false);
            },
            else => return self.reportError(
                SemanticError.TypeMismatch,
                op,
                "Pointers only support Non-floating point numbers",
            ),
        },
        // Left bool | Right Array
        .ARRAY => |l_array| switch (rhs_kind) {
            .BOOL, .UINT, .INT => {
                // Decay to pointer
                const new_ptr = KindId.newPtrFromArray(lhs_kind, l_array.const_items);
                return CoercionResult.init(new_ptr, false, false);
            },
            // Right - ptr
            .PTR => |r_ptr| {
                const array_ptr = KindId.newPtrFromArray(lhs_kind, l_array.const_items);
                if (!array_ptr.PTR.equal(r_ptr)) {
                    return self.reportError(SemanticError.TypeMismatch, op, "Pointers must be the same kind");
                }
                // Return a I64
                const new_int = KindId.newInt(64);
                return CoercionResult.init(new_int, false, false);
            },
            // Right - array
            .ARRAY => |r_array| {
                // Convert to pointers
                const l_array_ptr = KindId.newPtrFromArray(lhs_kind, l_array.const_items);
                const r_array_ptr = KindId.newPtrFromArray(rhs_kind, r_array.const_items);
                // If not equal, error
                if (!l_array_ptr.PTR.equal(r_array_ptr.PTR)) {
                    return self.reportError(SemanticError.TypeMismatch, op, "Pointers must be the same kind");
                }
                // Return a I64
                const new_int = KindId.newInt(64);
                return CoercionResult.init(new_int, false, false);
            },
            else => return self.reportError(
                SemanticError.TypeMismatch,
                op,
                "Arrays only support non-floating point numbers",
            ),
        },
        // For all other types
        else => {
            // If the equal
            if (lhs_kind.equal(rhs_kind)) {
                // Return lhs and and no upgrades
                return CoercionResult.init(lhs_kind, false, false);
            }
            // Else no implicit coercion defined
            return self.reportError(SemanticError.TypeMismatch, op, "Incompatible types");
        },
    }
}

// ********************** //
// Stmt anaylsis  methods //
// ********************** //

/// Declare a enum type, checking if name has already been used
fn declareEnum(self: *TypeChecker, enum_stmt: *Stmt.EnumStmt) SemanticError!void {
    const EnumVariant = Symbols.Enum.EnumVariant;

    const new_variants = self.allocator.create(std.StringHashMap(EnumVariant)) catch unreachable;
    new_variants.* = std.StringHashMap(EnumVariant).init(self.allocator);

    for (0.., enum_stmt.variant_names) |value, variant| {
        const getOrPut = new_variants.getOrPut(variant.lexeme) catch unreachable;

        if (getOrPut.found_existing) {
            const line = getOrPut.value_ptr.*.dcl_line;
            const column = getOrPut.value_ptr.*.dcl_column;
            return self.reportDuplicateError(variant, line, column);
        }

        getOrPut.value_ptr.* = EnumVariant{ .value = @as(u16, @intCast(value)), .name = variant.lexeme, .dcl_line = variant.line, .dcl_column = variant.column };
    }

    const enum_kind = KindId.newEnumWithVariants(enum_stmt.id.lexeme, new_variants);

    _ = self.stm.declareSymbol(
        enum_stmt.id.lexeme,
        enum_kind,
        ScopeKind.ENUM,
        enum_stmt.id.line,
        enum_stmt.id.column,
        false,
        enum_stmt.public,
    ) catch {
        const old_id = self.stm.getSymbol(enum_stmt.id.lexeme) catch unreachable;
        return self.reportDuplicateError(enum_stmt.id, old_id.dcl_line, old_id.dcl_column);
    };
}

/// Index and add a struct to the STM
fn indexStruct(self: *TypeChecker, name: Token, index: u64, public: bool) SemanticError!void {
    // Create new struct with scope and index
    const new_struct = KindId.newStructWithIndex(self.allocator, name.lexeme, index);
    // Try to add to stm global scope
    _ = self.stm.declareSymbol(
        name.lexeme,
        new_struct,
        ScopeKind.STRUCT,
        name.line,
        name.column,
        false,
        public,
    ) catch {
        const old_id = self.stm.getSymbol(name.lexeme) catch unreachable;
        return self.reportDuplicateError(name, old_id.dcl_line, old_id.dcl_column);
    };
}

/// Analyze a struct defintion
fn declareStruct(
    self: *TypeChecker,
    module: *Module,
    symbol: *Symbol,
    structStmt: *Stmt.StructStmt,
) SemanticError!void {
    // Get Struct kind
    const struct_kind = &symbol.kind.STRUCT;
    // Check if declared
    if (struct_kind.declared) {
        return;
    }
    // If not, mark as visited
    struct_kind.*.visited = true;

    // Add each field to the struct, declaring any structs encountered
    for (structStmt.field_names, structStmt.field_kinds) |name, *kind| {
        switch (kind.*) {
            .USER_KIND => |unknown_name| {
                // Get from stm
                const field_symbol = self.stm.getSymbol(unknown_name) catch {
                    return self.reportError(SemanticError.UnresolvableIdentifier, name, "Undefined struct type");
                };

                switch (field_symbol.kind) {
                    .STRUCT => {
                        // If already visited, throw error
                        if (field_symbol.kind.STRUCT.visited) {
                            struct_kind.*.visited = false;
                            return self.reportError(SemanticError.UnresolvableIdentifier, name, "Circular dependency detected");
                        }
                        // Visit this struct if not already declared
                        if (!field_symbol.kind.STRUCT.declared) {
                            const field_index = field_symbol.kind.STRUCT.index;
                            const field_structStmt = module.structSlice()[field_index].STRUCT;
                            self.declareStruct(module, field_symbol, field_structStmt) catch {
                                self.panic = false;
                                return self.reportError(SemanticError.UnresolvableIdentifier, name, " |");
                            };
                        }

                        // Update StructScope
                        kind.* = KindId{ .STRUCT = Symbols.Struct{ .name = unknown_name, .fields = field_symbol.kind.STRUCT.fields } };
                    },
                    .ENUM => kind.* = KindId{ .ENUM = Symbols.Enum{ .name = unknown_name, .variants = field_symbol.kind.ENUM.variants } },
                    else => undefined,
                }
            },
            .PTR => |*ptr_arg| _ = ptr_arg.updatePtr(self.stm) catch {
                return self.reportError(
                    SemanticError.UnresolvableIdentifier,
                    name,
                    "Could not resolve type in pointer type definition",
                );
            },
            .ARRAY => |*array_arg| _ = array_arg.updateArray(self.stm) catch {
                return self.reportError(
                    SemanticError.UnresolvableIdentifier,
                    name,
                    "Could not resolve type in array type definition",
                );
            },
            .FUNC => |*func_arg| _ = func_arg.updateArgSize(self.stm) catch {
                return self.reportError(
                    SemanticError.UnresolvableIdentifier,
                    name,
                    "Could not resolve type in function type definition",
                );
            },
            // If array, find the root child, if struct do the same thing as above
            // If pointer, find the root child, if struct store StructScope in type
            .VOID => return self.reportError(SemanticError.TypeMismatch, name, "Cannot have void type struct fields"),
            else => undefined,
        }

        // Add field to struct
        symbol.kind.STRUCT.fields.addField(ScopeKind.LOCAL, name.lexeme, name.line, name.column, kind.*) catch {
            const old_field = symbol.kind.STRUCT.fields.getField(name.lexeme) catch unreachable;
            return self.reportDuplicateError(name, old_field.dcl_line, old_field.dcl_column);
        };
    }

    // Add each method to the struct, but do not analyze body yet
    for (structStmt.methods) |*method| {
        // Make KindId
        var new_func = KindId.newFunc(self.allocator, method.arg_kinds, false, method.return_kind);

        // Add new scope for arguments
        self.stm.addScope();

        // Check if first argument is pointer to self
        if (method.arg_kinds.len < 1 or method.arg_kinds[0] != .PTR) {
            return self.reportError(
                SemanticError.UnresolvableIdentifier,
                method.arg_names[0],
                "Expect a pointer to struct type as first parameter of struct method",
            );
        }

        const ptr_child_kind = method.arg_kinds[0].PTR.child;
        _ = ptr_child_kind.update(self.stm) catch {
            return self.reportError(SemanticError.UnresolvableIdentifier, method.name, "Could not resolve struct type in this argument");
        };

        if (!symbol.kind.equal(ptr_child_kind.*)) {
            return self.reportError(
                SemanticError.UnresolvableIdentifier,
                method.arg_names[0],
                "Expect a pointer to struct type as first parameter of struct method",
            );
        }

        // Declare args
        for (method.arg_names, method.arg_kinds) |name, *kind| {
            _ = kind.update(self.stm) catch {
                return self.reportError(SemanticError.UnresolvableIdentifier, name, "Could not resolve struct type in this argument");
            };
            // Declare arg
            _ = self.stm.declareSymbol(
                name.lexeme,
                kind.*,
                ScopeKind.ARG,
                name.line,
                name.column,
                false,
                false,
            ) catch {
                const old_id = self.stm.getSymbol(name.lexeme) catch unreachable;
                return self.reportDuplicateError(name, old_id.dcl_line, old_id.dcl_column);
            };
        }

        // Get size of arguments
        const args_size = self.stm.active_scope.next_address;
        // Update stack offset for arguments
        new_func.FUNC.args_size = args_size;

        // Pop scope
        self.stm.popScope();

        // Add field to struct
        symbol.kind.STRUCT.fields.addField(
            ScopeKind.FUNC,
            method.name.lexeme,
            method.name.line,
            method.name.column,
            new_func,
        ) catch {
            const old_field = symbol.kind.STRUCT.fields.getField(method.name.lexeme) catch unreachable;
            return self.reportDuplicateError(method.name, old_field.dcl_line, old_field.dcl_column);
        };
    }

    // Mark as not visited and declared
    struct_kind.*.visited = false;
    struct_kind.*.declared = true;
}

/// Declare a function, but do not check its body
fn declareFunction(self: *TypeChecker, func: *Stmt.FunctionStmt) SemanticError!void {
    // Create new function
    var new_func = KindId.newFunc(self.allocator, func.arg_kinds, false, func.return_kind);
    // Update the function return to see if there are any user defined structs or function arguments/return types
    _ = new_func.FUNC.ret_kind.update(self.stm) catch {
        return self.reportError(
            SemanticError.UnresolvableIdentifier,
            func.op,
            "Could not resolve struct type in function return type",
        );
    };

    // Add new scope for arguments
    self.stm.addScope();
    // Declare args
    for (func.arg_names, func.arg_kinds) |name, *kind| {
        _ = kind.update(self.stm) catch {
            return self.reportError(SemanticError.UnresolvableIdentifier, name, "Could not resolve struct type in this argument");
        };
        // Declare arg
        _ = self.stm.declareSymbol(
            name.lexeme,
            kind.*,
            ScopeKind.ARG,
            name.line,
            name.column,
            false,
            false,
        ) catch {
            const old_id = self.stm.getSymbol(name.lexeme) catch unreachable;
            return self.reportDuplicateError(name, old_id.dcl_line, old_id.dcl_column);
        };
    }

    // Get size of arguments
    const args_size = self.stm.active_scope.next_address;
    // Update stack offset for arguments
    new_func.FUNC.args_size = args_size;

    // Pop scope
    self.stm.popScope();

    // Declare this function
    _ = self.stm.declareSymbol(
        func.name.lexeme,
        new_func,
        ScopeKind.FUNC,
        func.name.line,
        func.name.column,
        false,
        func.public,
    ) catch {
        const old_id = self.stm.getSymbol(func.name.lexeme) catch unreachable;
        return self.reportDuplicateError(func.name, old_id.dcl_line, old_id.dcl_column);
    };
}

/// Analyze a function body
fn visitFunctionStmt(self: *TypeChecker, func: *Stmt.FunctionStmt, args_size: usize) SemanticError!void {
    // Enter new scope
    self.stm.pushScope();
    // Update current return kind
    self.current_return_kind = func.return_kind;

    // Reset current function scope count
    self.current_scope_count = 1;
    // Analyze body
    try self.analyzeStmt(&func.body);
    // Update scope count
    func.scope_count = self.current_scope_count;

    // Get scope size
    const stack_size = self.stm.active_scope.next_address;
    // Update FunctionStmts local variable stack size
    func.locals_size = stack_size - args_size;

    // Exit scope
    self.stm.popScope();
}

/// Analze the types of an GlobalStmt
fn visitGlobalStmt(self: *TypeChecker, globalStmt: *Stmt.GlobalStmt) SemanticError!void {
    // Get the type of expression
    const maybe_expr_kind: ?KindId = if (globalStmt.expr != null) try self.analyzeExpr(&globalStmt.expr.?) else null;
    // Extract declaration kind
    const maybe_declared_kind = globalStmt.kind;

    // Check if both null
    if (maybe_expr_kind == null and maybe_declared_kind == null) {
        return self.reportError(SemanticError.UnsafeCoercion, globalStmt.id, "Expected a type in global declaration");
    }

    // Check if declared with a kind
    if (maybe_declared_kind != null) {
        _ = globalStmt.kind.?.update(self.stm) catch {
            return self.reportError(SemanticError.UnresolvableIdentifier, globalStmt.op, "Could not resolve type in declaration type");
        };

        // Check if rhs has kind
        if (maybe_expr_kind) |expr_kind| {
            // Check if the expr kind and declared kind are coerceable
            const coerce_result = try self.staticCoerceKinds(globalStmt.op, globalStmt.kind.?, expr_kind);

            // Check if need to insert conversion nodes
            if (coerce_result.upgraded_rhs) {
                insertConvExpr(
                    self.allocator,
                    &globalStmt.expr.?,
                    coerce_result.final_kind,
                );
            }
            globalStmt.kind = coerce_result.final_kind;
        } else {
            globalStmt.kind = globalStmt.kind.?;
        }
    } else {
        // Update kind to expr result kind
        globalStmt.kind = maybe_expr_kind.?;
    }

    // Create new symbol in STM
    _ = self.stm.declareSymbol(
        globalStmt.id.lexeme,
        globalStmt.kind.?,
        ScopeKind.GLOBAL,
        globalStmt.id.line,
        globalStmt.id.column,
        globalStmt.mutable,
        globalStmt.public,
    ) catch {
        const old_id = self.stm.getSymbol(globalStmt.id.lexeme) catch unreachable;
        return self.reportDuplicateError(globalStmt.id, old_id.dcl_line, old_id.dcl_column);
    };
}

/// analyze the types of stmtnodes
fn analyzeStmt(self: *TypeChecker, stmt: *StmtNode) SemanticError!void {
    return switch (stmt.*) {
        .DECLARE => |declareStmt| self.visitDeclareStmt(declareStmt),
        .EXPRESSION => |exprStmt| self.visitExprStmt(exprStmt),
        .MUTATE => |mutStmt| self.visitMutateStmt(mutStmt),
        .WHILE => |whileStmt| self.visitWhileStmt(whileStmt),
        .IF => |ifStmt| self.visitIfStmt(ifStmt),
        .BLOCK => |blockStmt| self.visitBlockStmt(blockStmt),
        .RETURN => |returnStmt| self.visitReturnStmt(returnStmt),
        .BREAK => |breakStmt| self.visitBreakStmt(breakStmt),
        .CONTINUE => |continueStmt| self.visitContinueStmt(continueStmt),
        else => unreachable,
    };
}

/// Analze the types of an DeclareStmt
fn visitDeclareStmt(self: *TypeChecker, declareExpr: *Stmt.DeclareStmt) SemanticError!void {
    // Get the type of expression
    const maybe_expr_kind: ?KindId = if (declareExpr.expr != null) try self.analyzeExpr(&declareExpr.expr.?) else null;
    // Extract declaration kind
    const maybe_declared_kind = declareExpr.kind;

    // Check if both null
    if (maybe_declared_kind == null and maybe_expr_kind == null) {
        return self.reportError(SemanticError.UnsafeCoercion, declareExpr.id, "Expected a type in local declaration");
    }

    // Check if declared with a kind
    if (maybe_declared_kind != null) {
        _ = declareExpr.kind.?.update(self.stm) catch {
            return self.reportError(SemanticError.UnresolvableIdentifier, declareExpr.op, "Could not resolve type in declaration type");
        };

        if (maybe_expr_kind) |expr_kind| {
            // Check if the expr kind and declared kind are coerceable
            const coerce_result = try self.staticCoerceKinds(declareExpr.op, declareExpr.kind.?, expr_kind);
            // Check if need to insert conversion nodes
            if (coerce_result.upgraded_rhs) {
                insertConvExpr(
                    self.allocator,
                    &declareExpr.expr.?,
                    coerce_result.final_kind,
                );
            }
            declareExpr.kind = coerce_result.final_kind;
        } else {
            declareExpr.kind = declareExpr.kind.?;
        }
    } else {
        // Update kind to expr result kind
        declareExpr.kind = maybe_expr_kind.?;
    }

    // Create new symbol in STM
    const stack_offset = self.stm.declareSymbol(
        declareExpr.id.lexeme,
        declareExpr.kind.?,
        ScopeKind.LOCAL,
        declareExpr.id.line,
        declareExpr.id.column,
        declareExpr.mutable,
        false,
    ) catch {
        const old_id = self.stm.getSymbol(declareExpr.id.lexeme) catch unreachable;
        return self.reportDuplicateError(declareExpr.id, old_id.dcl_line, old_id.dcl_column);
    };

    // Update stack offset
    declareExpr.stack_offset = stack_offset + 8;
}

/// Analyze types of a mutation statement
fn visitMutateStmt(self: *TypeChecker, mutStmt: *Stmt.MutStmt) SemanticError!void {
    // Analze the id expression
    const id_result = try self.analyzeIDExpr(&mutStmt.id_expr, mutStmt.op);
    const id_kind = id_result.kind;
    const is_mutable = id_result.mutable;
    // Update id_kind in stmt
    mutStmt.id_kind = id_kind;

    // Make sure it is mutable
    if (!is_mutable) {
        return self.reportError(SemanticError.TypeMismatch, mutStmt.op, "Cannot mutate constant identifiers, data, or functions");
    }

    // Check if lhs is a float and using '%='
    if (mutStmt.op.kind == .PERCENT_EQUAL and (id_kind == .FLOAT32 or id_kind == .FLOAT64)) {
        return self.reportError(
            SemanticError.TypeMismatch,
            mutStmt.op,
            "Floating point numbers do not support the modulo operator",
        );
    }

    // Get assign expr kind
    const expr_kind = try self.analyzeExpr(&mutStmt.assign_expr);
    // Coerce rhs into lhs
    const coerce_result = try self.staticCoerceKinds(mutStmt.op, id_kind, expr_kind);

    // Check if need to insert conversion nodes
    if (coerce_result.upgraded_rhs) {
        insertConvExpr(
            self.allocator,
            &mutStmt.assign_expr,
            coerce_result.final_kind,
        );
    }
}

/// analyze the types of an ExprStmt
fn visitExprStmt(self: *TypeChecker, exprStmt: *Stmt.ExprStmt) SemanticError!void {
    // analyze the expression stored
    _ = try self.analyzeExpr(&exprStmt.expr);
}

/// Analyze the types of a whileStmt
fn visitWhileStmt(self: *TypeChecker, whileStmt: *Stmt.WhileStmt) SemanticError!void {
    // Analyze the conditional kind
    const cond_kind = try self.analyzeExpr(&whileStmt.conditional);
    // Check if kind is a bool
    if (cond_kind != .BOOL) {
        return self.reportError(SemanticError.TypeMismatch, whileStmt.op, "Expected while loop conditional to be a bool");
    }

    // Increase loop depth
    self.loop_depth += 1;
    // Check types of body
    try self.analyzeStmt(&whileStmt.body);
    // Check types of loop stmt if there is one
    if (whileStmt.loop_stmt != null) {
        try self.analyzeStmt(&whileStmt.loop_stmt.?);
    }
    // Exit loop
    self.loop_depth -= 1;
}

/// Analyze the types of an ifStmt
fn visitIfStmt(self: *TypeChecker, ifStmt: *Stmt.IfStmt) SemanticError!void {
    // Check if conditional is bool
    const cond_kind = try self.analyzeExpr(&ifStmt.conditional);
    if (cond_kind != .BOOL) {
        return self.reportError(SemanticError.TypeMismatch, ifStmt.op, "Expected a bool for if statement conditional");
    }

    // Check then branch
    try self.analyzeStmt(&ifStmt.then_branch);
    // If else branch, check it
    if (ifStmt.else_branch != null) {
        try self.analyzeStmt(&ifStmt.else_branch.?);
    }
}

/// Analyze the types of a blockStmt
fn visitBlockStmt(self: *TypeChecker, blockStmt: *Stmt.BlockStmt) SemanticError!void {
    // Enter new scope
    self.stm.addScope();
    self.current_scope_count += 1;
    // Loop through each statement in the block, checking its types
    for (blockStmt.statements) |*stmt| {
        self.analyzeStmt(stmt) catch {
            self.panic = false;
            continue;
        };
    }
    // Check var in scope
    self.checkVarInScope();

    // Pop scope
    self.stm.popScope();
}

/// Analyze the return types of a return stmt
fn visitReturnStmt(self: *TypeChecker, returnStmt: *Stmt.ReturnStmt) SemanticError!void {
    // Check if return current return type is void
    if (self.current_return_kind == .VOID) {
        if (returnStmt.expr != null) {
            return self.reportError(SemanticError.TypeMismatch, returnStmt.op, "Expected no return expression");
        }
    } else if (returnStmt.*.expr) |*return_expr| {
        // Check if return types matches
        const expr_kind = try self.analyzeExpr(return_expr);
        const coerce_result = try self.staticCoerceKinds(returnStmt.op, self.current_return_kind, expr_kind);
        // If rhs upgraded, add conversion node
        if (coerce_result.upgraded_rhs) {
            insertConvExpr(self.allocator, return_expr, self.current_return_kind);
        }
    } else {
        return self.reportError(SemanticError.TypeMismatch, returnStmt.op, "Expected a return expression");
    }
}

/// Analyze break stmt
/// Check if in loop or switch
fn visitBreakStmt(self: *TypeChecker, breakStmt: *Stmt.BreakStmt) SemanticError!void {
    // Check if in loop or switch
    if (self.loop_depth == 0 and self.switch_depth == 0) {
        return self.reportError(SemanticError.InvalidControlFlow, breakStmt.op, "Expected to be inside of a loop or switch statement");
    }
}

/// Analyze break stmt
/// Check if in loop or switch
fn visitContinueStmt(self: *TypeChecker, continueStmt: *Stmt.ContinueStmt) SemanticError!void {
    // Check if in loop or switch
    if (self.loop_depth == 0) {
        return self.reportError(SemanticError.InvalidControlFlow, continueStmt.op, "Expected to be inside of a loop statement");
    }
}

// ********************** //
// Expr anaylsis  methods //
// ********************** //

/// Used to return if an assignment operand is mutable or not
const IDResult = struct {
    kind: KindId,
    mutable: bool,
};

/// Analysis an ID expression
fn analyzeIDExpr(self: *TypeChecker, node: *ExprNode, op: Token) SemanticError!IDResult {
    switch (node.*.expr) {
        .IDENTIFIER => return self.visitIdentifierExprWrapped(node),
        .INDEX => return self.visitIndexExprWrapped(node),
        .DEREFERENCE => return self.visitDereferenceExprWrapped(node),
        .FIELD => return self.visitFieldExprWrapped(node),
        else => return self.reportError(SemanticError.TypeMismatch, op, "Expected an identifier or dereferenced pointer/array for assignment"),
    }
}

/// Analysis a ExprNode
fn analyzeExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Determine the type of expr and analysis it
    return switch (node.*.expr) {
        .IDENTIFIER => self.visitIdentifierExpr(node),
        .LITERAL => self.visitLiteralExpr(node),
        .NATIVE => self.visitNativeExpr(node),
        .DEREFERENCE => self.visitDereferenceExpr(node),
        .FIELD => self.visitFieldExpr(node),
        .CALL => self.visitCallExpr(node),
        .CONVERSION => self.visitConvExpr(node),
        .INDEX => self.visitIndexExpr(node),
        .UNARY => self.visitUnaryExpr(node),
        .ARITH => self.visitArithExpr(node),
        .COMPARE => self.visitCompareExpr(node),
        .AND => self.visitAndExpr(node),
        .OR => self.visitOrExpr(node),
        .IF => self.visitIfExpr(node),
        //else => unreachable,
    };
}

/// Visit a literal
fn visitLiteralExpr(self: *TypeChecker, node: *ExprNode) KindId {
    // Extract literal
    const literal_expr = node.expr.LITERAL;
    // Add value to the stm constant table
    self.stm.addConstant(literal_expr.value);

    // Replace literal.* with a constAccessExpr
    //const constAccExpr = Expr.constantAccessExpr{}

    // Return a KindId for the value stored in literal
    switch (literal_expr.value.kind) {
        .NULLPTR => {
            const new_ptr = KindId.newPtr(self.allocator, KindId.ANY, false);
            node.result_kind = new_ptr;
        },
        .BOOL => {
            node.result_kind = KindId.BOOL;
        },
        .UINT => {
            const uintVal = literal_expr.value.as.uint;
            node.result_kind = KindId.newUInt(uintVal.bits);
        },
        .INT => {
            const intVal = literal_expr.value.as.int;
            node.result_kind = KindId.newInt(intVal.bits);
        },
        .FLOAT32 => {
            node.result_kind = KindId.FLOAT32;
        },
        .FLOAT64 => {
            node.result_kind = KindId.FLOAT64;
        },
        .STRING => {
            const strVal = literal_expr.value.as.string;
            node.result_kind = KindId.newArr(self.allocator, KindId.newUInt(8), strVal.data.len, true, true);
        },
        .ARRAY => {
            // Get array value
            const arrVal = &literal_expr.value.as.array;
            // Make KindId for array
            var new_array_kind: KindId = arrVal.kind.*;
            // Loop for each dimension of arrVal
            for (arrVal.dimensions.slice()) |dim| {
                new_array_kind = KindId.newArr(self.allocator, new_array_kind, dim, true, false);
            }
            // Update result kind
            node.result_kind = new_array_kind;
        },
    }
    return node.result_kind;
}

/// Visit an Identifier Expr wrapped with an IDResult
fn visitIdentifierExprWrapped(self: *TypeChecker, node: *ExprNode) SemanticError!IDResult {
    // Extract name from id token
    const token = node.*.expr.IDENTIFIER.id;
    const name = token.lexeme;

    // Check if trying to access lexical scope
    if (node.expr.IDENTIFIER.lexical_scope) |lexical_scope| {
        return self.reportError(SemanticError.UnmutatedVarIdentifier, lexical_scope, "Cannot modify values accessed through scopes");
    }

    // Try to get the symbol, else throw error
    const symbol = self.stm.getSymbol(name) catch {
        return self.reportError(SemanticError.UnresolvableIdentifier, token, "Identifier is undeclared");
    };
    // Set symbol as mutated
    symbol.has_mutated = true;

    // Update scope kind
    node.*.expr.IDENTIFIER.scope_kind = symbol.scope;
    // Set stack offset based on scope type
    switch (symbol.scope) {
        .ARG => node.*.expr.IDENTIFIER.stack_offset = symbol.mem_loc + 16,
        .LOCAL => node.*.expr.IDENTIFIER.stack_offset = symbol.mem_loc + 8,
        .GLOBAL, .FUNC => undefined,
        .STRUCT, .ENUM => return self.reportError(SemanticError.TypeMismatch, token, "Cannot directly access struct or enum type"),
    }

    // Wrap in id_result with constant status of symbol
    const id_result = IDResult{ .kind = symbol.kind, .mutable = symbol.is_mutable };
    // Return id result and update final
    node.result_kind = symbol.kind;
    return id_result;
}

/// Visit an Identifier Expr
fn visitIdentifierExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract name from id token
    const token = node.*.expr.IDENTIFIER.id;
    const name = token.lexeme;

    // Check if trying to access lexical scope
    if (node.expr.IDENTIFIER.lexical_scope) |lexical_scope| {
        const scope_target = self.stm.getSymbol(lexical_scope.lexeme) catch {
            return self.reportError(SemanticError.UnresolvableIdentifier, lexical_scope, "Could not find lexical scope target");
        };

        switch (scope_target.kind) {
            .ENUM => |enm| {
                const variant = enm.variants.get(name) orelse {
                    return self.reportError(SemanticError.UnresolvableIdentifier, token, "Undeclared enum variant");
                };

                const new_literal = self.allocator.create(Expr.LiteralExpr) catch unreachable;
                new_literal.* = Expr.LiteralExpr{ .literal = token, .value = Value.newUInt(variant.value, 16) };
                node.* = ExprNode.init(Expr.ExprUnion{ .LITERAL = new_literal });
            },
            else => return self.reportError(SemanticError.TypeMismatch, lexical_scope, "Can only lexically scope enum kinds"),
        }
        node.*.result_kind = scope_target.kind;
        return scope_target.kind;
    }

    // Try to get the symbol, else throw error
    const symbol = self.stm.getSymbol(name) catch {
        return self.reportError(SemanticError.UnresolvableIdentifier, token, "Identifier is undeclared");
    };

    // Update scope kind
    node.*.expr.IDENTIFIER.scope_kind = symbol.scope;
    // Set stack offset based on scope type
    switch (symbol.scope) {
        .ARG => node.*.expr.IDENTIFIER.stack_offset = symbol.mem_loc + 16,
        .LOCAL => node.*.expr.IDENTIFIER.stack_offset = symbol.mem_loc + 8,
        .GLOBAL, .FUNC => undefined,
        .STRUCT, .ENUM => return self.reportError(SemanticError.TypeMismatch, token, "Cannot directly access struct or enum type"),
    }

    // Return its stored kind and update final
    node.result_kind = symbol.kind;
    return node.result_kind;
}

//************************************//
//       Access Exprs
//************************************//
fn visitNativeExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract nativeExpr
    const nativeExpr = node.expr.NATIVE;
    // Get native token
    const native_token = nativeExpr.name;
    // Get native name
    const native_name = nativeExpr.name.lexeme[1..];
    // Check for native function kindid
    const native_kind: KindId = self.stm.natives_table.getNativeKind(native_name) orelse {
        // Did not find throw error
        return self.reportError(
            SemanticError.UnresolvableIdentifier,
            native_token,
            "Invalid native function",
        );
    };

    // Extract function kindid
    const native = native_kind.FUNC;
    // Get caller args
    const call_args = nativeExpr.args;
    // Update native calls kindids
    nativeExpr.arg_kinds = self.allocator.alloc(KindId, call_args.len) catch unreachable;

    // Check arg count, if variadic ensure all static arguments are present
    if (native.arg_kinds.len != call_args.len and !(native.arg_kinds.len <= call_args.len and native.variadic)) {
        return self.reportError(
            SemanticError.TypeMismatch,
            native_token,
            "Invalid amount of arguments",
        );
    }
    // Check arg types, ignoring variadic arguments
    const static_arg_count = native.arg_kinds.len;
    for (native.arg_kinds, call_args[0..static_arg_count], 0..) |native_arg_kind, *call_arg, count| {
        // Evaluate argument type
        var arg_kind = try self.analyzeExpr(call_arg);
        // Update arg_kinds
        nativeExpr.arg_kinds[count] = arg_kind;

        // Decay any arrays into pointers
        if (arg_kind == .ARRAY) {
            // Downgrade to a ptr
            arg_kind = KindId.newPtrFromArray(arg_kind, arg_kind.ARRAY.const_items);
            // Update call_arg kind
            call_arg.*.result_kind = arg_kind;
        }

        // Check if match or coerceable
        const coerce_result = try self.staticCoerceKinds(
            native_token,
            native_arg_kind,
            arg_kind,
        );

        // Check if need to insert conversion nodes
        if (coerce_result.upgraded_rhs) {
            insertConvExpr(
                self.allocator,
                call_arg,
                coerce_result.final_kind,
            );
        }
    }

    // Check types of all variadic arguments
    for (call_args[static_arg_count..call_args.len]) |*call_arg| {
        // Evaluate
        var arg_kind = try self.analyzeExpr(call_arg);

        // Decay any arrays into pointers
        if (arg_kind == .ARRAY) {
            // Downgrade to a ptr
            arg_kind = KindId.newPtrFromArray(arg_kind, arg_kind.ARRAY.const_items);
        }

        // Check if float32 needs to be upgraded to float 64
        if (arg_kind == .FLOAT32) {
            // Upgrade to a float 64
            insertConvExpr(self.allocator, call_arg, KindId.FLOAT64);
        } else {
            // Update call_arg kind
            call_arg.*.result_kind = arg_kind;
        }
    }
    // Everything matches
    node.result_kind = native.ret_kind.*;
    return native.ret_kind.*;
}

fn visitCallExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract nativeExpr
    const callExpr = node.expr.CALL;

    // Parse caller_expr
    const callee_kind = try self.analyzeExpr(&callExpr.caller_expr);
    // Check if function
    if (callee_kind != .FUNC) {
        return self.reportError(SemanticError.TypeMismatch, callExpr.op, "Expected a function type");
    }
    // Extract function
    const callee = callee_kind.FUNC;

    // Check if a method
    if (callExpr.caller_expr.expr == .FIELD) {
        const new_method_args = self.allocator.alloc(ExprNode, callExpr.args.len + 1) catch unreachable;
        // Make new dereference node for first argument
        const new_address = self.allocator.create(Expr.UnaryExpr) catch unreachable;
        var ampersand_token = callExpr.caller_expr.expr.FIELD.op;
        ampersand_token.kind = TokenKind.AMPERSAND;
        new_address.* = Expr.UnaryExpr.init(callExpr.caller_expr.expr.FIELD.operand, ampersand_token);
        const first_arg_node = ExprNode.init(Expr.ExprUnion{ .UNARY = new_address });
        new_method_args[0] = first_arg_node;
        std.mem.copyForwards(ExprNode, new_method_args[1..], callExpr.args);
        callExpr.args = new_method_args;
    }

    // Check arg count
    if (callExpr.args.len != callee.arg_kinds.len) {
        return self.reportError(
            SemanticError.TypeMismatch,
            callExpr.op,
            "Invalid amount of arguments",
        );
    }
    // Check arg types
    for (callee.arg_kinds, callExpr.args) |callee_arg, *caller_arg| {
        // Evaluate argument type
        var arg_kind = try self.analyzeExpr(caller_arg);

        // Decay any arrays into pointers
        if (arg_kind == .ARRAY) {
            // Downgrade to a ptr
            arg_kind = KindId.newPtrFromArray(arg_kind, arg_kind.ARRAY.const_items);
            // Update call_arg kind
            caller_arg.*.result_kind = arg_kind;
        }

        // Check if match or coerceable
        const coerce_result = try self.staticCoerceKinds(
            callExpr.op,
            callee_arg,
            arg_kind,
        );

        // Check if need to insert conversion nodes
        if (coerce_result.upgraded_rhs) {
            insertConvExpr(
                self.allocator,
                caller_arg,
                coerce_result.final_kind,
            );
        }
    }
    // Everything matches
    node.result_kind = callee.ret_kind.*;
    return node.result_kind;
}

//************************************//
//   Pointers and Dereference Expr
//************************************//

/// Used for ID expression resolution, returns if the data is constant or not
fn visitFieldExprWrapped(self: *TypeChecker, node: *ExprNode) SemanticError!IDResult {
    const fieldExpr = node.expr.FIELD;
    // Analyze operand
    const operand_result = try self.analyzeIDExpr(&fieldExpr.operand, fieldExpr.op);
    const operand_kind = operand_result.kind;

    // Check if operand is a struct
    if (operand_kind != .STRUCT) {
        return self.reportError(SemanticError.TypeMismatch, fieldExpr.op, "Expected a struct type for field access");
    }
    // Check if struct has the field
    const field = operand_kind.STRUCT.fields.getField(fieldExpr.field_name.lexeme) catch {
        return self.reportError(SemanticError.UnresolvableIdentifier, fieldExpr.field_name, "Unresolvable field name");
    };
    // Update offset from base of struct
    fieldExpr.stack_offset = field.relative_loc;
    node.result_kind = field.kind;
    // Check if mutable
    const mutable = operand_result.mutable and field.scope != .FUNC;
    return IDResult{ .kind = field.kind, .mutable = mutable };
}

/// Visit Field Expr
/// fieldExpr -> expression '.' identifier
/// Used to access struct fields
fn visitFieldExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    const fieldExpr = node.expr.FIELD;
    // Analyze operand
    const operand_kind = try self.analyzeExpr(&fieldExpr.operand);

    // Check if operand is a struct
    if (operand_kind != .STRUCT) {
        return self.reportError(SemanticError.TypeMismatch, fieldExpr.op, "Expected a struct type for field access");
    }
    // Check if struct has the field
    const field = operand_kind.STRUCT.fields.getField(fieldExpr.field_name.lexeme) catch {
        return self.reportError(SemanticError.UnresolvableIdentifier, fieldExpr.field_name, "Unresolvable field name");
    };
    // Update offset from base of struct
    fieldExpr.stack_offset = field.relative_loc;
    node.result_kind = field.kind;
    // Check if method
    if (field.scope == .FUNC) {
        fieldExpr.method_parent = operand_kind;
    }
    return field.kind;
}

/// Used for ID Expression resolution, returns if data is constant or not
fn visitDereferenceExprWrapped(self: *TypeChecker, node: *ExprNode) SemanticError!IDResult {
    const derefExpr = node.expr.DEREFERENCE;
    // Find operand kind
    const operand_kind = try self.analyzeExpr(&derefExpr.operand);

    // Check if operand is a pointer
    if (operand_kind != .PTR) {
        return self.reportError(SemanticError.TypeMismatch, derefExpr.op, "Expected a pointer type for dereference");
    }

    const child_kind = operand_kind.PTR.child;
    const mutable = !operand_kind.PTR.const_child;
    node.result_kind = child_kind.*;
    // Return dereferenced pointer type
    return IDResult{ .kind = child_kind.*, .mutable = mutable };
}

/// Analyze a dereference expr
/// derefExpr -> expression '.' '*'
fn visitDereferenceExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    const derefExpr = node.expr.DEREFERENCE;
    // Find operand kind
    const operand_kind = try self.analyzeExpr(&derefExpr.operand);

    // Check if operand is a pointer
    if (operand_kind != .PTR) {
        return self.reportError(SemanticError.TypeMismatch, derefExpr.op, "Expected a pointer type for dereference");
    }

    const child_kind = operand_kind.PTR.child;
    node.result_kind = child_kind.*;
    return child_kind.*;
}

/// Used for ID Expression resolution, returns if data is constant or not
fn visitIndexExprWrapped(self: *TypeChecker, node: *ExprNode) SemanticError!IDResult {
    // Extract index expression
    const indexExpr = node.expr.INDEX;
    // Find lhs kind
    const lhs_kind = if (indexExpr.reversed) try self.analyzeExpr(&indexExpr.rhs) else try self.analyzeExpr(&indexExpr.lhs);
    // Used to return child kind
    var dereferenced_kind: KindId = undefined;
    var mutable: bool = undefined;

    // Check if lhs is an array and index is inbounds of array
    if (lhs_kind == .ARRAY) {
        dereferenced_kind = lhs_kind.ARRAY.child.*;
        mutable = !lhs_kind.ARRAY.const_items;
    } else if (lhs_kind == .PTR) {
        dereferenced_kind = lhs_kind.PTR.child.*;
        mutable = !lhs_kind.PTR.const_child;
    } else {
        return self.reportError(SemanticError.TypeMismatch, indexExpr.op, "Can only index pointers and arrays");
    }

    // Find rhs kind
    const rhs_kind = if (indexExpr.reversed) try self.analyzeExpr(&indexExpr.lhs) else try self.analyzeExpr(&indexExpr.rhs);
    // Checl if rhs is a U(INT)
    if (rhs_kind != .UINT and rhs_kind != .INT) {
        return self.reportError(SemanticError.TypeMismatch, indexExpr.op, "Can only access int or uint indexes");
    }

    // Update result kind
    node.result_kind = dereferenced_kind;
    // Wrap in IDResult
    return IDResult{ .kind = dereferenced_kind, .mutable = mutable };
}

fn visitIndexExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract index expression
    const indexExpr = node.expr.INDEX;
    // Find lhs kind
    const lhs_kind = if (indexExpr.reversed) try self.analyzeExpr(&indexExpr.rhs) else try self.analyzeExpr(&indexExpr.lhs);
    // Used to return child kind
    var dereferenced_kind: KindId = undefined;

    // Check if lhs is an array and index is inbounds of array
    if (lhs_kind == .ARRAY) {
        dereferenced_kind = lhs_kind.ARRAY.child.*;
    } else if (lhs_kind == .PTR) {
        dereferenced_kind = lhs_kind.PTR.child.*;
    } else {
        return self.reportError(SemanticError.TypeMismatch, indexExpr.op, "Can only index pointers and arrays");
    }

    // Find rhs kind
    const rhs_kind = if (indexExpr.reversed) try self.analyzeExpr(&indexExpr.lhs) else try self.analyzeExpr(&indexExpr.rhs);
    // Checl if rhs is a U(INT)
    if (rhs_kind != .UINT and rhs_kind != .INT) {
        return self.reportError(SemanticError.TypeMismatch, indexExpr.op, "Can only access int or uint indexes");
    }

    // Update result kind
    node.result_kind = dereferenced_kind;
    return node.result_kind;
}

//************************************//
//       Conversion Expr
//************************************//

/// Visit a conversion expr
fn visitConvExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    const convExpr = node.expr.CONVERSION;
    _ = node.result_kind.update(self.stm) catch {
        return self.reportError(SemanticError.UnresolvableIdentifier, convExpr.op, "Could not resolve struct type in this argument");
    };
    const convKind = node.result_kind;
    const operandKind = try self.analyzeExpr(&convExpr.operand);
    _ = operandKind;
    // convKind == convExpr.operand.result_kind || areLegal()
    return convKind;
}

/// Visit a unary expr
fn visitUnaryExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract unaryExpr
    const unaryExpr = node.expr.UNARY;
    // Get kind of rhs
    const rhs_kind = try self.analyzeExpr(&unaryExpr.operand);

    // Check type of this unary expr
    switch (unaryExpr.op.kind) {
        // Not Expression
        .EXCLAMATION => {
            // Return rhs_kind if it is a boolean, else report type error
            switch (rhs_kind) {
                .BOOL => {
                    // Set return type of node
                    node.result_kind = rhs_kind;
                    return rhs_kind;
                },
                else => return self.reportError(
                    SemanticError.TypeMismatch,
                    unaryExpr.op,
                    "Expected a bool",
                ),
            }
        },
        // Not expression
        .MINUS => {
            // Return rhs_kind if rhs_kind is a number, else report type error
            switch (rhs_kind) {
                .UINT => {
                    // Make signed, and upgrade size if possible
                    const signed_int = upgradeUIntBits(rhs_kind.UINT.bits);
                    // Update result kind
                    node.result_kind = signed_int;
                    return signed_int;
                },
                .INT, .FLOAT32, .FLOAT64 => {
                    // Update result kind
                    node.result_kind = rhs_kind;
                    return rhs_kind;
                },
                else => return self.reportError(
                    SemanticError.TypeMismatch,
                    unaryExpr.op,
                    "Expected an uint, int, or float",
                ),
            }
        },
        .AMPERSAND => {
            // Visit as id expr
            const id_result = try self.analyzeIDExpr(&unaryExpr.operand, unaryExpr.op);
            // Make new pointer
            const new_ptr = KindId.newPtr(self.allocator, id_result.kind, !id_result.mutable);
            node.result_kind = new_ptr;
            return node.result_kind;
        },
        else => unreachable,
    }
}

/// Visit a binary expr
fn visitArithExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract ARITH expr
    var arithExpr = node.expr.ARITH;
    // Get rhs type
    const rhs_kind = try self.analyzeExpr(&arithExpr.rhs);
    // Get lhs type
    const lhs_kind = try self.analyzeExpr(&arithExpr.lhs);
    // Get operator
    const op = arithExpr.op;

    // Check if match or coerceable
    const coerce_result = try self.coerceKinds(
        op,
        lhs_kind,
        rhs_kind,
    );

    // Rename form to be shorter
    const kind = coerce_result.final_kind;
    // Check if legal type for arithmetic
    if (kind != .INT and kind != .UINT and kind != .FLOAT32 and kind != .FLOAT64 and kind != .PTR) {
        // No boolean algebra
        return self.reportError(
            SemanticError.TypeMismatch,
            op,
            "Arithmatic expressions only support unsigned int, int, or float results",
        );
    }

    // Check for illegal combos
    // Modulus
    if (op.kind == .PERCENT and (kind == .FLOAT32 or kind == .FLOAT64)) {
        // No float modulo
        return self.reportError(
            SemanticError.TypeMismatch,
            op,
            "Cannot use modulo operator with floats",
        );
    }
    // Non addition or subtraction pointer
    if (kind == .PTR and op.kind != .PLUS and op.kind != .MINUS) {
        // No pointer division, multi, or mod
        return self.reportError(
            SemanticError.TypeMismatch,
            op,
            "Pointers only support '+' and '-' arithmetic operators",
        );
    }

    // Check for inserts
    // Left side
    if (coerce_result.upgraded_lhs) {
        insertConvExpr(
            self.allocator,
            &arithExpr.*.lhs,
            coerce_result.final_kind,
        );
    } else if (coerce_result.upgraded_rhs) {
        insertConvExpr(
            self.allocator,
            &arithExpr.*.rhs,
            coerce_result.final_kind,
        );
    }

    // Update return kind
    node.result_kind = coerce_result.final_kind;
    return node.result_kind;
}

/// Visit a comparision expr
fn visitCompareExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract compare expr
    var compareExpr = node.expr.COMPARE;
    // Get rhs type
    const rhs_kind = try self.analyzeExpr(&compareExpr.rhs);
    // Get lhs type
    const lhs_kind = try self.analyzeExpr(&compareExpr.lhs);
    // Get operator
    const op = compareExpr.op;

    // Check if match or coerceable
    const coerce_result = try self.coerceKinds(
        op,
        lhs_kind,
        rhs_kind,
    );

    // Rename form to be shorter
    const kind = coerce_result.final_kind;
    // Check if legal type for comparison
    if (kind != .INT and kind != .UINT and kind != .FLOAT32 and kind != .FLOAT64 and kind != .PTR and kind != .ENUM) {
        return self.reportError(SemanticError.TypeMismatch, op, "Cannot compare non-number values");
    }

    // Check for inserts
    // Left side
    if (coerce_result.upgraded_lhs) {
        insertConvExpr(
            self.allocator,
            &compareExpr.*.lhs,
            coerce_result.final_kind,
        );
    } else if (coerce_result.upgraded_rhs) {
        insertConvExpr(
            self.allocator,
            &compareExpr.*.rhs,
            coerce_result.final_kind,
        );
    }

    // Update return kind
    node.result_kind = KindId.BOOL;
    return node.result_kind;
}

/// Visit a logical and expr
fn visitAndExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract or expr
    var andExpr = node.expr.AND;
    // Get rhs type
    const rhs_kind = try self.analyzeExpr(&andExpr.rhs);
    // Get lhs type
    const lhs_kind = try self.analyzeExpr(&andExpr.lhs);
    // Get operator
    const op = andExpr.op;

    // Check if both types are bools
    if (lhs_kind != .BOOL or rhs_kind != .BOOL) {
        // Throw error
        return self.reportError(SemanticError.TypeMismatch, op, "Expected a bool");
    }

    // Update type
    node.result_kind = lhs_kind;
    return node.result_kind;
}

/// Visit a logical or expr
fn visitOrExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract or expr
    var orExpr = node.expr.OR;
    // Get rhs type
    const rhs_kind = try self.analyzeExpr(&orExpr.rhs);
    // Get lhs type
    const lhs_kind = try self.analyzeExpr(&orExpr.lhs);
    // Get operator
    const op = orExpr.op;

    // Check if both types are bools
    if (lhs_kind != .BOOL or rhs_kind != .BOOL) {
        // Throw error
        return self.reportError(SemanticError.TypeMismatch, op, "Expected a bool");
    }

    // Update type
    node.result_kind = lhs_kind;
    return node.result_kind;
}

/// Visit an if expression
fn visitIfExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract if expr
    const ifExpr = node.expr.IF;
    // Get conditional type
    const condition_type = try self.analyzeExpr(&ifExpr.conditional);
    // Get then branch type
    const then_kind = try self.analyzeExpr(&ifExpr.then_branch);
    // Get else branch type
    const else_kind = try self.analyzeExpr(&ifExpr.else_branch);
    // Get token
    const if_token = ifExpr.if_token;

    // Check if condition is a boolean
    if (condition_type != .BOOL) {
        // Throw error
        return self.reportError(SemanticError.TypeMismatch, if_token, "Conditional must be a 'bool' type");
    }

    // Check if match or coerceable
    const coerce_result = try self.coerceKinds(
        if_token,
        then_kind,
        else_kind,
    );

    // Check for inserts
    // Left side
    if (coerce_result.upgraded_lhs) {
        insertConvExpr(
            self.allocator,
            &ifExpr.*.then_branch,
            coerce_result.final_kind,
        );
    } else if (coerce_result.upgraded_rhs) {
        insertConvExpr(
            self.allocator,
            &ifExpr.*.else_branch,
            coerce_result.final_kind,
        );
    }

    // Update return kind
    if (then_kind == .PTR or then_kind == .ARRAY) {
        node.result_kind = then_kind;
    } else if (else_kind == .PTR or else_kind == .ARRAY) {
        node.result_kind = else_kind;
    } else {
        node.result_kind = coerce_result.final_kind;
    }

    return node.result_kind;
}
