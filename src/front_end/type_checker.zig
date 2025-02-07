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
had_error: bool,
panic: bool,

/// Initialize a new TypeChecker
pub fn init(allocator: std.mem.Allocator, stm: *STM) TypeChecker {
    return TypeChecker{
        .allocator = allocator,
        .stm = stm,
        .had_error = false,
        .panic = false,
    };
}

/// Trace through a AST, checking for type errors
/// and adding more lower level AST nodes as needed
/// in preparation for code generation
/// Returns true if semantics are okay
pub fn check(self: *TypeChecker, module: *Module) void {
    // Check all stmts in the module
    for (module.stmts()) |*stmt| {
        // analyze stmt, continue if there was an error
        self.analyzeStmt(stmt) catch {
            self.panic = false;
            continue;
        };
    }
}

/// Returns true if this type checker has ever encountered an error
pub fn hadError(self: TypeChecker) bool {
    return self.had_error;
}

// ********************** //
// Private helper methods //
// ********************** //

/// Return the new size for a UInt being upgraded to a signed int
/// UInt.bits < 64 -> x2; else 64
/// This causes some potentially weird behaviour on i64, u64 interactions, but only in very large numbers
inline fn upgradeUIntBits(bits: u16) KindId {
    const new_bits = if (bits < 64) bits * 2 else bits;
    return KindId.newInt(new_bits);
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
    convExpr.* = Expr.ConversionExpr.init(node.*);
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
                if (l_uint.bits > r_int.bits) {
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
/// analyze the types of stmtnodes
fn analyzeStmt(self: *TypeChecker, stmt: *StmtNode) SemanticError!void {
    return switch (stmt.*) {
        .DECLARE => |declareStmt| self.visitDeclareStmt(declareStmt),
        .EXPRESSION => |exprStmt| self.visitExprStmt(exprStmt),
        else => unreachable,
    };
}

/// Analze the types of an DeclareStmt
fn visitDeclareStmt(self: *TypeChecker, declareExpr: *Stmt.DeclareStmt) SemanticError!void {
    // Get the type of expression
    const expr_kind = try self.analyzeExpr(&declareExpr.expr);
    // Extract declaration kind
    const maybe_declared_kind = declareExpr.kind;

    // Check if declared with a kind
    if (maybe_declared_kind) |declared_kind| {
        // Check if the expr kind and declared kind are coerceable
        const coerce_result = try self.coerceKinds(declareExpr.op, declared_kind, expr_kind);

        // Check if declared kind was "upgraded"
        if (!declared_kind.equal(coerce_result.final_kind)) {
            return self.reportError(
                SemanticError.TypeMismatch,
                declareExpr.op,
                "Invalid assignment, cannot implicitly downgrade types",
            );
        }

        // Check if need to insert conversion nodes
        if (coerce_result.upgraded_rhs) {
            insertConvExpr(
                self.allocator,
                &declareExpr.expr,
                coerce_result.final_kind,
            );
        }
    } else {
        // Update kind to expr result kind
        declareExpr.kind = expr_kind;
    }

    // Create new symbol in STM
    self.stm.declareSymbol(
        declareExpr.id.lexeme,
        declareExpr.kind.?,
        ScopeKind.GLOBAL,
        declareExpr.id.line,
        declareExpr.mutable,
    ) catch {
        return self.reportError(SemanticError.DuplicateDeclaration, declareExpr.id, "Duplicate usage of identifier");
    };
}

/// analyze the types of an ExprStmt
fn visitExprStmt(self: *TypeChecker, exprStmt: *Stmt.ExprStmt) SemanticError!void {
    // analyze the expression stored
    _ = try self.analyzeExpr(&exprStmt.expr);
}

// ********************** //
// Expr anaylsis  methods //
// ********************** //

/// Analysis a ExprNode
fn analyzeExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Determine the type of expr and analysis it
    return switch (node.*.expr) {
        .IDENTIFIER => self.visitIdentifierExpr(node),
        .LITERAL => self.visitLiteralExpr(node),
        .NATIVE => self.visitNativeExpr(node),
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
        .BOOL => {
            node.result_kind = KindId.BOOL;
            return node.result_kind;
        },
        .UINT => {
            const uintVal = literal_expr.value.as.uint;
            node.result_kind = KindId.newUInt(uintVal.bits);
            return node.result_kind;
        },
        .INT => {
            const intVal = literal_expr.value.as.int;
            node.result_kind = KindId.newInt(intVal.bits);
            return node.result_kind;
        },
        .FLOAT32 => {
            node.result_kind = KindId.FLOAT32;
            return node.result_kind;
        },
        .FLOAT64 => {
            node.result_kind = KindId.FLOAT64;
            return node.result_kind;
        },
        .STRING => {
            const strVal = literal_expr.value.as.string;
            node.result_kind = KindId.newArr(self.allocator, KindId.newUInt(8), strVal.data.len, true);
            return node.result_kind;
        },
        .ARRAY => {
            // Get array value
            const arrVal = &literal_expr.value.as.array;
            // Make KindId for array
            var new_array_kind: KindId = arrVal.kind.*;
            // Loop for each dimension of arrVal
            for (arrVal.dimensions.slice()) |dim| {
                new_array_kind = KindId.newArr(self.allocator, new_array_kind, dim, true);
            }
            // Update result kind
            node.result_kind = new_array_kind;
            return node.result_kind;
        },
    }
}

/// Visit an Identifier Expr
fn visitIdentifierExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract name from id token
    const token = node.*.expr.IDENTIFIER.id;
    const name = token.lexeme;
    // Try to get the symbol, else throw error
    const symbol = self.stm.getSymbol(name) catch {
        return self.reportError(SemanticError.UnresolvableIdentifier, token, "Identifier is undeclared");
    };
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
    // Get native kindid
    const native_name = nativeExpr.name.lexeme[1..];
    // Check for native function
    const maybe_native = self.stm.natives_table.getNativeKind(native_name);

    // Check if native found
    if (maybe_native == null) {
        // Throw error
        return self.reportError(
            SemanticError.UnresolvableIdentifier,
            native_token,
            "Invalid native function",
        );
    }
    const native = maybe_native.?.FUNC;
    const call_args = nativeExpr.args;

    // Check if any args
    if (native.arg_kinds != null) {
        // Check arg count
        if (native.arg_kinds.?.len != call_args.?.len) {
            return self.reportError(
                SemanticError.TypeMismatch,
                native_token,
                "Invalid amount of arguments",
            );
        }
        // Check arg types
        for (native.arg_kinds.?, call_args.?) |native_arg_kind, *call_arg| {
            // Evaluate argument type
            var arg_kind = try self.analyzeExpr(call_arg);

            // Decay any arrays into pointers
            if (arg_kind == .ARRAY) {
                // Downgrade to a ptr
                arg_kind = KindId.newPtrFromArray(arg_kind, arg_kind.ARRAY.const_items);
                // Update call_arg kind
                call_arg.*.result_kind = arg_kind;
            }

            // Check if pointer arguments are being given pointer parameters
            if ((native_arg_kind == .PTR or native_arg_kind == .ARRAY) and (arg_kind != .PTR and arg_kind != .ARRAY)) {
                return self.reportError(
                    SemanticError.UnsafeCoercion,
                    native_token,
                    "Cannot implicitly convert number into pointer",
                );
            }

            // Check if match or coerceable
            const coerce_result = try self.coerceKinds(
                native_token,
                native_arg_kind,
                arg_kind,
            );

            // Check if argument was coerced
            if (coerce_result.upgraded_lhs) {
                return self.reportError(
                    SemanticError.TypeMismatch,
                    native_token,
                    "Invalid argument, cannot implicitly downgrade types",
                );
            }
            // Check if need to insert conversion nodes
            if (coerce_result.upgraded_rhs) {
                insertConvExpr(
                    self.allocator,
                    call_arg,
                    coerce_result.final_kind,
                );
            }
        }
    } else {
        // Check both no args
        if (call_args != null) {
            return self.reportError(
                SemanticError.TypeMismatch,
                native_token,
                "Unexpected arguments",
            );
        }
    }
    // Everything matches
    node.result_kind = native.ret_kind.*;
    return native.ret_kind.*;
}

fn visitIndexExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract index expression
    const indexExpr = node.expr.INDEX;
    // Find lhs kind
    const lhs_kind = try self.analyzeExpr(&indexExpr.lhs);
    // Used to return child kind
    var dereferenced_kind: KindId = undefined;

    // Check if lhs is an array and index is inbounds of array
    if (lhs_kind == .ARRAY) {
        dereferenced_kind = lhs_kind.ARRAY.dereference() catch
            {
            return self.reportError(SemanticError.TypeMismatch, indexExpr.op, "Can only index pointers and arrays");
        };
    } else if (lhs_kind == .PTR) {
        dereferenced_kind = lhs_kind.PTR.dereference() catch {
            return self.reportError(SemanticError.TypeMismatch, indexExpr.op, "Can only index pointers and arrays");
        };
    } else {
        return self.reportError(SemanticError.TypeMismatch, indexExpr.op, "Can only index pointers and arrays");
    }

    // Find rhs kind
    const rhs_kind = try self.analyzeExpr(&indexExpr.rhs);
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
    if (kind != .INT and kind != .UINT and kind != .FLOAT32 and kind != .FLOAT64 and kind != .PTR) {
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
