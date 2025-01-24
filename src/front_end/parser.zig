const std = @import("std");

// Scanner import
const Scan = @import("scanner.zig");
const Scanner = Scan.Scanner;
const Token = Scan.Token;
const TokenKind = Scan.TokenKind;
// Constant, values, and symbols import
const Symbols = @import("../symbols.zig");
const ValueKind = Symbols.ValueKind;
const Value = Symbols.Value;
const KindId = Symbols.KindId;
const ScopeKind = Symbols.ScopeKind;
// Expression nodes import
const Expr = @import("../expr.zig");
const ExprNode = Expr.ExprNode;
const ExprUnion = Expr.ExprUnion;
// Error import
const Error = @import("../error.zig");
const SyntaxError = Error.SyntaxError;

// Parser fields
const Parser = @This();
allocator: std.mem.Allocator,
scanner: *Scanner,
current: Token,
previous: Token,
had_error: bool,
panic: bool,

/// Parser initializer
pub fn init(allocator: std.mem.Allocator, scanner: *Scanner) Parser {
    // Make a new parser
    const new_parser = Parser{
        .allocator = allocator,
        .scanner = scanner,
        .current = undefined,
        .previous = undefined,
        .had_error = false,
        .panic = false,
    };
    return new_parser;
}

/// Parse until scanner returns an EOF Token
/// Report any errors encountered
pub fn parse(self: *Parser) ?ExprNode {
    // Advance
    _ = self.advance();
    // Parse
    return self.expression() catch null;
}

/// Return true if there was an error while parsing
pub fn hadError(self: *Parser) bool {
    return self.had_error;
}

// ********************** //
// Private helper methods //
// ********************** //

/// Return true if current token is EOF
inline fn isAtEnd(self: Parser) bool {
    return self.current.kind == TokenKind.EOF;
}

/// Check if the next token matches a certain token kind and returns true if it matches
/// Does not advance
inline fn check(self: Parser, kind: TokenKind) bool {
    return self.current.kind == kind;
}

/// If not at end, move current token to previous
/// and scan a new token
fn advance(self: *Parser) Token {
    // Check if at end
    if (!self.isAtEnd()) {
        // Shift current to previous
        self.previous = self.current;
        // Scan next token
        self.current = self.scanner.nextToken();

        // Consume all error tokens
        while (true) {
            // Break if current is not an error
            if (!self.check(TokenKind.ERROR) or self.check(TokenKind.EOF)) break;
            // Report error
            self.errorAtCurrent(self.current.lexeme) catch {};
            // Scan in new token
            self.current = self.scanner.nextToken();
        }
    }
    // Return previous
    return self.previous;
}

/// Take in TokenKinds and check if current token matches any.
/// If a match is found, advance and return true, else false
fn match(self: *Parser, kinds: anytype) bool {
    // Check if current token matches any
    inline for (kinds) |kind| {
        if (self.check(kind)) {
            // Advance
            _ = self.advance();
            // Report match
            return true;
        }
    }
    return false;
}

/// Check if the next token matches a certain TokenKind and advance
/// If next token does not match, raise an error
fn consume(self: *Parser, kind: TokenKind, msg: []const u8) SyntaxError!void {
    // Check if match
    if (self.check(kind)) {
        // Consume
        _ = self.advance();
        return;
    }
    // Did not match, raise error
    return self.errorAtCurrent(msg);
}

// ******************* //
//   Error handling
// ******************* //

/// Display an error message to the user, set had error and enable panic mode
fn reportError(self: *Parser, token: Token, msg: []const u8) SyntaxError {
    const stderr = std.io.getStdErr().writer();

    // Error type
    var errorType = SyntaxError.InvalidExpression;
    // Only display errors when not in panic mode
    if (!self.panic) {
        // Display message
        stderr.print("[Line {d}:{d}]", .{ token.line, token.column }) catch unreachable;

        // Change message based off of token type
        if (token.kind == TokenKind.EOF) {
            _ = stderr.write(" at end") catch unreachable;
        } else if (token.kind == TokenKind.ERROR) {
            errorType = SyntaxError.UnexpectedSymbol;
        } else {
            stderr.print(" at \'{s}\'", .{token.lexeme}) catch unreachable;
        }
        // Display msg
        stderr.print(": {s}\n", .{msg}) catch unreachable;

        // Update had error and panic mode
        self.had_error = true;
        self.panic = true;
    }
    // Raise error
    return errorType;
}

/// Raise an error at the current token. Set had error to true, initialize panic mode,
/// message the user, and return a UnexpectedSymbol error
fn errorAtCurrent(self: *Parser, msg: []const u8) SyntaxError {
    return self.reportError(self.current, msg);
}

/// Raise an error at the previous token. Set had error to true, initialize panic mode,
/// message the user, and return a UnexpectedSymbol error
fn errorAt(self: *Parser, msg: []const u8) SyntaxError {
    return self.reportError(self.previous, msg);
}

//**************************//
//      Parse Stmts
//**************************//
// Parse a statement
// Stmt -> printStmt | exprStmt
//fn statement(self: *Parser) SyntaxError!StmtNode {
//    if (self.match(.{TokenKind.PRINT})) {
//
//    } else {
//        const expr = self.expression();
//        return StmtNode{ .EXPR = expr };
//    }
//}

//**************************//
//      Parse Exprs
//**************************//

/// Parse an expression
/// expr -> term
fn expression(self: *Parser) SyntaxError!ExprNode {
    return self.if_stmt();
}

/// Parse an If Statement
fn if_stmt(self: *Parser) SyntaxError!ExprNode {
    // Check for if
    if (self.match(.{TokenKind.IF})) {
        // Extract if token
        const if_token = self.previous;

        // Consume '('
        try self.consume(TokenKind.LEFT_PAREN, "Expect '('  after 'if'");
        // Get conditional expr
        const condition = try self.if_stmt();
        errdefer condition.deinit(self.allocator);
        // Consume ')'
        try self.consume(TokenKind.RIGHT_PAREN, "Expect ')' after 'if'");

        // Get then_branch
        const then_branch = try self.if_stmt();
        errdefer then_branch.deinit(self.allocator);

        // Consume else
        try self.consume(TokenKind.ELSE, "If expressions must have an else branch");

        // Get else_branch
        const else_branch = try self.if_stmt();

        // Make new inner expression
        const new_expr = self.allocator.create(Expr.IfExpr) catch unreachable;
        new_expr.* = Expr.IfExpr.init(if_token, condition, then_branch, else_branch);
        return ExprNode.init(ExprUnion{ .IF = new_expr });
    }
    // No if, get logical or expr
    return try self.logic_or();
}

/// Parse an and statement
/// and -> compare ("and" compare)*
fn logic_or(self: *Parser) SyntaxError!ExprNode {
    // Get lhs
    var expr = try self.logic_and();
    errdefer expr.deinit(self.allocator);

    // While still 'or'
    while (self.match(.{TokenKind.OR})) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const rhs = try self.logic_and();

        // Make new inner expression
        const new_expr = self.allocator.create(Expr.OrExpr) catch unreachable;
        new_expr.* = Expr.OrExpr.init(expr, rhs, operator);
        expr = ExprNode.init(ExprUnion{ .OR = new_expr });
    }
    // Return the expression
    return expr;
}

/// Parse an and statement
/// and -> compare ("and" compare)*
fn logic_and(self: *Parser) SyntaxError!ExprNode {
    // Get lhs
    var expr = try self.compare();
    errdefer expr.deinit(self.allocator);

    // While still 'and'
    while (self.match(.{TokenKind.AND})) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const rhs = try self.compare();

        // Make new inner expression
        const new_expr = self.allocator.create(Expr.AndExpr) catch unreachable;
        new_expr.* = Expr.AndExpr.init(expr, rhs, operator);
        expr = ExprNode.init(ExprUnion{ .AND = new_expr });
    }
    // Return the expression
    return expr;
}

/// Parse a compare statement
/// compare -> term (("<"|">"|"<="|">="|"=="|"!=") term)*
fn compare(self: *Parser) SyntaxError!ExprNode {
    // Get lhs
    var expr = try self.term();
    errdefer expr.deinit(self.allocator);

    // While still >,<,>=,<=
    while (self.match(.{ TokenKind.GREATER, TokenKind.GREATER_EQUAL, TokenKind.LESS, TokenKind.LESS_EQUAL, TokenKind.EQUAL_EQUAL, TokenKind.EXCLAMATION_EQUAL })) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const rhs = try self.term();

        // Make new inner expression
        const new_expr = self.allocator.create(Expr.CompareExpr) catch unreachable;
        new_expr.* = Expr.CompareExpr.init(expr, rhs, operator);
        expr = ExprNode.init(ExprUnion{ .COMPARE = new_expr });
    }
    // Return the expression
    return expr;
}

/// Parse an addition or subtraction statement
/// term -> factor (("-"|"+") factor)*
fn term(self: *Parser) SyntaxError!ExprNode {
    var expr = try self.factor();
    errdefer expr.deinit(self.allocator);

    // While there are still '+' or '-' tokens
    while (self.match(.{ TokenKind.PLUS, TokenKind.MINUS })) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const rhs = try self.factor();

        // Make new inner expression, with operator
        const new_expr = self.allocator.create(Expr.ArithExpr) catch unreachable;
        new_expr.* = Expr.ArithExpr.init(expr, rhs, operator);
        expr = ExprNode.init(ExprUnion{ .ARITH = new_expr });
    }
    // Return node
    return expr;
}

/// Parse a multiplication or division statement
/// factor -> unary (("*"|"/"|"%") unary)*
fn factor(self: *Parser) SyntaxError!ExprNode {
    var expr = try self.unary();
    errdefer expr.deinit(self.allocator);

    // While there are still '/' or '*' or '%' tokens
    while (self.match(.{ TokenKind.SLASH, TokenKind.STAR, TokenKind.PERCENT })) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const rhs = try self.unary();

        // Make new inner expression, with operator
        const new_expr = self.allocator.create(Expr.ArithExpr) catch unreachable;
        new_expr.* = Expr.ArithExpr.init(expr, rhs, operator);
        expr = ExprNode.init(ExprUnion{ .ARITH = new_expr });
    }
    // Return node
    return expr;
}

/// Parse a unary statement
/// unary -> ("-"|"!") (unary | literal)
fn unary(self: *Parser) SyntaxError!ExprNode {
    // Recurse until no more '+' or '!'
    if (self.match(.{ TokenKind.MINUS, TokenKind.EXCLAMATION })) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const operand = try self.unary();

        // Make new inner expression, with operator
        const new_expr = self.allocator.create(Expr.UnaryExpr) catch unreachable;
        new_expr.* = Expr.UnaryExpr.init(operand, operator);
        return ExprNode.init(ExprUnion{ .UNARY = new_expr });
    }
    // Fall through to literal
    return self.literal();
}

/// Parse a literal value
/// ("(" expr ")") | constant | identifier | native "(" arguments? ")"
fn literal(self: *Parser) SyntaxError!ExprNode {
    // Check if this is a grouping
    if (self.match(.{TokenKind.LEFT_PAREN})) {
        // Parse new sub expression, freeing on error
        const expr = try self.expression();
        errdefer expr.deinit(self.allocator);

        // Consume ')'
        try self.consume(TokenKind.RIGHT_PAREN, "Unclosed parenthesis");
        return expr;
    }
    // Store current token and advance
    const token = self.advance();
    switch (token.kind) {
        .FALSE => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make new value
            const value = Value.newBool(false);
            constant_expr.* = .{ .value = value, .literal = token };
            return ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
        },
        .TRUE => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make new value
            const value = Value.newBool(true);
            constant_expr.* = .{ .value = value, .literal = token };
            return ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
        },
        .INTEGER => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            errdefer self.allocator.destroy(constant_expr);

            // Parse lexeme
            const parsed_int = std.fmt.parseInt(i64, token.lexeme, 10) catch {
                // Try to make it unsigned
                const parsed_uint = std.fmt.parseInt(u64, token.lexeme, 10) catch {
                    // Cannot be parsed into i64 or u64
                    return self.reportError(token, "Integer cannot be parsed into i64 or u64");
                };

                // Make u64
                const value = Value.newUInt(parsed_uint, 64);
                constant_expr.* = .{ .value = value, .literal = token };
                return ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
            };

            // Make new value
            const value = Value.newInt(parsed_int, 64);
            constant_expr.* = .{ .value = value, .literal = token };
            return ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
        },
        .FLOAT => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Parse lexeme
            const parsed_int = std.fmt.parseFloat(f64, token.lexeme) catch unreachable;
            // Make new value
            const value = Value.newFloat(parsed_int, 64);
            constant_expr.* = .{ .value = value, .literal = token };
            return ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
        },
        .STRING => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make a new value without quotes

            // Make new value without quotes
            const value = Value.newStr(token.lexeme);
            constant_expr.* = .{ .value = value, .literal = token };
            return ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
        },
        .ARRAY_TYPE => {
            // ****************************************************** //
            // FOR NOW THROWS AN ERROR
            return self.errorAt("Do not use arrays yet please thanks");
        },
        .IDENTIFIER => {
            // Make new constant expression
            const identifier_expr = self.allocator.create(Expr.IdentifierExpr) catch unreachable;
            identifier_expr.* = .{ .id = token };
            return ExprNode.init(ExprUnion{ .IDENTIFIER = identifier_expr });
        },
        .NATIVE => {
            // Consume the '('
            try self.consume(TokenKind.LEFT_PAREN, "Expected '(' after native function");
            // Create arg list
            var arg_list = std.ArrayList(ExprNode).init(self.allocator);
            defer arg_list.deinit();

            // Check if next if next is ')'
            if (!self.check(TokenKind.RIGHT_PAREN)) {
                const first_arg = try self.expression();
                arg_list.append(first_arg) catch unreachable;
                // Parse until no more commas
                while (self.match(.{TokenKind.COMMA})) {
                    const next_arg = try self.expression();
                    arg_list.append(next_arg) catch unreachable;
                }
            }
            // Consume ')'
            try self.consume(TokenKind.RIGHT_PAREN, "Expect ')' after arg list");

            // Make copy of arg_list items
            const args = self.allocator.alloc(Expr.ExprNode, arg_list.items.len) catch unreachable;
            @memcpy(args, arg_list.items);
            // Make new nativeExpr
            const native_expr = self.allocator.create(Expr.NativeExpr) catch unreachable;
            native_expr.name = token;
            native_expr.args = args;

            return ExprNode.init(ExprUnion{ .NATIVE = native_expr });
        },
        .EOF => return self.errorAtCurrent("Expected an expression"),
        else => return self.errorAt("Invalid expression"),
    }
}
