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
// Error
const Error = @import("../error.zig");
const SemanticError = Error.SemanticError;
const ScopeError = Error.ScopeError;
// Expr
const Expr = @import("../expr.zig");
const ExprNode = Expr.ExprNode;

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
pub fn check(self: *TypeChecker, expr: *ExprNode) bool {
    _ = self.analysisExpr(expr) catch return false;
    return !self.had_error;
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
/// Stores data about a coercion attempt
const CoercionResult = struct {
    final_kind: KindId,
    upgraded_lhs: bool,
    upgraded_rhs: bool,

    pub fn init(kind: KindId, left_upgrade: bool, right_upgrade: bool) CoercionResult {
        return CoercionResult{ .final_kind = kind, .upgraded_lhs = left_upgrade, .upgraded_rhs = right_upgrade };
    }
};

const hi = fn (u8) void;

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
            .FLOAT => {
                // Return the float
                return CoercionResult.init(rhs_kind, true, false);
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
            .FLOAT => {
                // Return the float
                return CoercionResult.init(rhs_kind, true, false);
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
            .FLOAT => {
                // Return the float
                return CoercionResult.init(rhs_kind, true, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
        },
        // Left Float
        .FLOAT => |l_float| switch (rhs_kind) {
            // Left Float | Right Int
            .BOOL, .UINT, .INT => {
                // Return the float
                return CoercionResult.init(lhs_kind, false, true);
            },
            // Left Float | Right Float
            .FLOAT => |r_float| {
                // Return the float with more bits
                if (l_float.bits > r_float.bits) {
                    return CoercionResult.init(lhs_kind, false, true);
                }
                if (l_float.bits < r_float.bits) {
                    return CoercionResult.init(rhs_kind, true, false);
                }
                // Else they are the same, no coercion
                return CoercionResult.init(lhs_kind, false, false);
            },
            // All other combinations are illegal
            else => return self.reportError(SemanticError.TypeMismatch, op, "Invalid type coercion"),
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
// Expr anaylsis  methods //
// ********************** //

/// Analysis a ExprNode
fn analysisExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Determine the type of expr and analysis it
    return switch (node.*.expr) {
        .IDENTIFIER => try self.visitIdentifierExpr(node),
        .LITERAL => self.visitLiteralExpr(node),
        .NATIVE => self.visitNativeExpr(node),
        .CONVERSION => self.visitConvExpr(node),
        .UNARY => try self.visitUnaryExpr(node),
        .ARITH => try self.visitArithExpr(node),
        .COMPARE => try self.visitCompareExpr(node),
        .AND => try self.visitAndExpr(node),
        .OR => try self.visitOrExpr(node),
        .IF => try self.visitIfExpr(node),
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
            node.result_kind = KindId.newBool();
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
        .FLOAT => {
            const floatVal = literal_expr.value.as.float;
            node.result_kind = KindId.newFloat(floatVal.bits);
            return node.result_kind;
        },
        .STRING => {
            const strVal = literal_expr.value.as.string;
            node.result_kind = KindId.newArr(self.allocator, KindId.newUInt(8), strVal.data.len);
            return node.result_kind;
        },
        .ARRAY => {
            // Get array value
            //const arrVal = &literal_expr.value.as.array;
            // Make KindId for array
            //node.result_kind = KindId.newArr(arrVal);
            //return node.result_kind;
            unreachable;
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
    // Return its stored kind
    return symbol.kind;
}

//************************************//
//       Call Exprs
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
            const arg_kind = try self.analysisExpr(call_arg);

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
                // Make new expression
                const convExpr = self.allocator.create(Expr.ConversionExpr) catch unreachable;
                // Put old node into new expr
                convExpr.* = Expr.ConversionExpr.init(call_arg.*);
                // Make new node
                const new_node = ExprNode.initWithKind(
                    Expr.ExprUnion{ .CONVERSION = convExpr },
                    coerce_result.final_kind,
                );
                // Put in old nodes spot
                call_arg.* = new_node;
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

//************************************//
//       Conversion Expr
//************************************//

/// Visit a conversion expr
fn visitConvExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    const convExpr = node.expr.CONVERSION;
    const convKind = node.result_kind;
    const operandKind = try self.analysisExpr(&convExpr.operand);
    _ = operandKind;
    // convKind == convExpr.operand.result_kind || areLegal()
    return convKind;
}

/// Visit a unary expr
fn visitUnaryExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract unaryExpr
    const unaryExpr = node.expr.UNARY;
    // Get kind of rhs
    const rhs_kind = try self.analysisExpr(&unaryExpr.operand);

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
                .INT => {
                    // Update result kind
                    node.result_kind = rhs_kind;
                    return rhs_kind;
                },
                .FLOAT => {
                    // Set return type of node
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
    const rhs_kind = try self.analysisExpr(&arithExpr.rhs);
    // Get lhs type
    const lhs_kind = try self.analysisExpr(&arithExpr.lhs);
    // Get operator
    const op = arithExpr.op;

    // Check if match or coerceable
    const coerce_result = try self.coerceKinds(
        op,
        lhs_kind,
        rhs_kind,
    );

    // Check if legal type for arithmetic
    if (coerce_result.final_kind != .INT and coerce_result.final_kind != .UINT and coerce_result.final_kind != .FLOAT) {
        // No boolean algebra
        return self.reportError(
            SemanticError.TypeMismatch,
            op,
            "Arithmatic expressions only support unsigned int, int, or float results",
        );
    }

    // Check for illegal combos
    // Modulus
    if (op.kind == .PERCENT and coerce_result.final_kind == .FLOAT) {
        // No float modulo
        return self.reportError(
            SemanticError.TypeMismatch,
            op,
            "Cannot use modulo operator with floats",
        );
    }

    // Check for inserts
    // Left side
    if (coerce_result.upgraded_lhs) {
        // Make new expression
        const convExpr = self.allocator.create(Expr.ConversionExpr) catch unreachable;
        // Put old node into new expr
        convExpr.* = Expr.ConversionExpr.init(arithExpr.*.lhs);
        // Make new node
        const new_node = ExprNode.initWithKind(
            Expr.ExprUnion{ .CONVERSION = convExpr },
            coerce_result.final_kind,
        );
        // Put in old nodes spot
        arithExpr.*.lhs = new_node;
    } else if (coerce_result.upgraded_rhs) {
        // Right side
        // Make new expression
        const convExpr = self.allocator.create(Expr.ConversionExpr) catch unreachable;
        // Put old node into new expr
        convExpr.* = Expr.ConversionExpr.init(arithExpr.*.rhs);
        // Make new node
        const new_node = ExprNode.initWithKind(
            Expr.ExprUnion{ .CONVERSION = convExpr },
            coerce_result.final_kind,
        );
        // Put in old nodes spot
        arithExpr.*.rhs = new_node;
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
    const rhs_kind = try self.analysisExpr(&compareExpr.rhs);
    // Get lhs type
    const lhs_kind = try self.analysisExpr(&compareExpr.lhs);
    // Get operator
    const op = compareExpr.op;

    // Check if match or coerceable
    const coerce_result = try self.coerceKinds(
        op,
        lhs_kind,
        rhs_kind,
    );

    // Check for inserts
    // Left side
    if (coerce_result.upgraded_lhs) {
        // Make new expression
        const convExpr = self.allocator.create(Expr.ConversionExpr) catch unreachable;
        // Put old node into new expr
        convExpr.* = Expr.ConversionExpr.init(compareExpr.*.lhs);
        // Make new node
        const new_node = ExprNode.initWithKind(
            Expr.ExprUnion{ .CONVERSION = convExpr },
            coerce_result.final_kind,
        );
        // Put in old nodes spot
        compareExpr.*.lhs = new_node;
    } else if (coerce_result.upgraded_rhs) {
        // Right side
        // Make new expression
        const convExpr = self.allocator.create(Expr.ConversionExpr) catch unreachable;
        // Put old node into new expr
        convExpr.* = Expr.ConversionExpr.init(compareExpr.*.rhs);
        // Make new node
        const new_node = ExprNode.initWithKind(
            Expr.ExprUnion{ .CONVERSION = convExpr },
            coerce_result.final_kind,
        );
        // Put in old nodes spot
        compareExpr.*.rhs = new_node;
    }

    // Update return kind
    node.result_kind = coerce_result.final_kind;
    return node.result_kind;
}

/// Visit a logical and expr
fn visitAndExpr(self: *TypeChecker, node: *ExprNode) SemanticError!KindId {
    // Extract or expr
    var andExpr = node.expr.AND;
    // Get rhs type
    const rhs_kind = try self.analysisExpr(&andExpr.rhs);
    // Get lhs type
    const lhs_kind = try self.analysisExpr(&andExpr.lhs);
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
    const rhs_kind = try self.analysisExpr(&orExpr.rhs);
    // Get lhs type
    const lhs_kind = try self.analysisExpr(&orExpr.lhs);
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
    const condition_type = try self.analysisExpr(&ifExpr.conditional);
    // Get then branch type
    const then_kind = try self.analysisExpr(&ifExpr.then_branch);
    // Get else branch type
    const else_kind = try self.analysisExpr(&ifExpr.else_branch);
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
        // Make new expression
        const convExpr = self.allocator.create(Expr.ConversionExpr) catch unreachable;
        // Put old node into new expr
        convExpr.* = Expr.ConversionExpr.init(ifExpr.*.then_branch);
        // Make new node
        const new_node = ExprNode.initWithKind(
            Expr.ExprUnion{ .CONVERSION = convExpr },
            coerce_result.final_kind,
        );
        // Put in old nodes spot
        ifExpr.*.then_branch = new_node;
    } else if (coerce_result.upgraded_rhs) {
        // Right side
        // Make new expression
        const convExpr = self.allocator.create(Expr.ConversionExpr) catch unreachable;
        // Put old node into new expr
        convExpr.* = Expr.ConversionExpr.init(ifExpr.*.else_branch);
        // Make new node
        const new_node = ExprNode.initWithKind(
            Expr.ExprUnion{ .CONVERSION = convExpr },
            coerce_result.final_kind,
        );
        // Put in old nodes spot
        ifExpr.*.else_branch = new_node;
    }

    // Update return kind
    node.result_kind = coerce_result.final_kind;
    return node.result_kind;
}
