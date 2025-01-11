const std = @import("std");

// Scanner import
const Scan = @import("scanner.zig");
const Scanner = Scan.Scanner;
const Token = Scan.Token;
const TokenKind = Scan.TokenKind;
// Constant, values, and symbols import
const Symbols = @import("../symbols.zig");
const Value = Symbols.Value;
const KindId = Symbols.KindId;
const ScopeKind = Symbols.ScopeKind;
// Expression nodes import
const Expr = @import("../expr.zig");
const ExprNode = Expr.ExprNode;
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
    return self.term() catch null;
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
        stderr.print("[Line {d}]", .{token.line}) catch unreachable;

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
//      Parse Exprs
//**************************//

/// Parse an expression
/// expr -> term
fn expression(self: *Parser) SyntaxError!ExprNode {
    return self.term();
}

/// Parse an addition or subtraction statement
/// term -> factor (("-"|"+") factor)*
fn term(self: *Parser) SyntaxError!ExprNode {
    var expr = try self.factor();

    // While there are still '+' or '-' tokens
    while (self.match(.{ TokenKind.PLUS, TokenKind.MINUS })) {
        // Get operator
        const operator = self.previous.kind;
        // Parse rhs
        const rhs = try self.factor();

        // Make new inner expression based on operator type
        switch (operator) {
            .PLUS => {
                const new_expr = self.allocator.create(Expr.AddExpr) catch unreachable;
                new_expr.* = .{ .lhs = expr, .rhs = rhs };
                expr = ExprNode{ .ADD = new_expr };
            },
            .MINUS => {
                const new_expr = self.allocator.create(Expr.SubExpr) catch unreachable;
                new_expr.* = .{ .lhs = expr, .rhs = rhs };
                expr = ExprNode{ .SUB = new_expr };
            },
            else => unreachable,
        }
    }
    // Return node
    return expr;
}

/// Parse a multiplication or division statement
/// factor -> unary (("*"|"/"|"%") unary)*
fn factor(self: *Parser) SyntaxError!ExprNode {
    var expr = try self.unary();

    // While there are still '/' or '*' or '%' tokens
    while (self.match(.{ TokenKind.SLASH, TokenKind.STAR, TokenKind.PERCENT })) {
        // Get operator
        const operator = self.previous.kind;
        // Parse rhs
        const rhs = try self.unary();

        // Make new inner expression based on operator type
        switch (operator) {
            .SLASH => {
                const new_expr = self.allocator.create(Expr.DivExpr) catch unreachable;
                new_expr.* = .{ .lhs = expr, .rhs = rhs };
                expr = ExprNode{ .DIV = new_expr };
            },
            .STAR => {
                const new_expr = self.allocator.create(Expr.MultiExpr) catch unreachable;
                new_expr.* = .{ .lhs = expr, .rhs = rhs };
                expr = ExprNode{ .MULTI = new_expr };
            },
            .PERCENT => {
                const new_expr = self.allocator.create(Expr.ModExpr) catch unreachable;
                new_expr.* = .{ .lhs = expr, .rhs = rhs };
                expr = ExprNode{ .MOD = new_expr };
            },
            else => unreachable,
        }
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
        const operator = self.previous.kind;
        // Parse rhs
        const rhs = try self.unary();

        // Make new inner expression based on operator type
        switch (operator) {
            .MINUS => {
                const new_expr = self.allocator.create(Expr.NegateExpr) catch unreachable;
                new_expr.* = .{ .rhs = rhs };
                return ExprNode{ .NEGATE = new_expr };
            },
            .EXCLAMATION => {
                const new_expr = self.allocator.create(Expr.NotExpr) catch unreachable;
                new_expr.* = .{ .rhs = rhs };
                return ExprNode{ .NOT = new_expr };
            },
            else => unreachable,
        }
    }
    // Fall through to literal
    return self.literal();
}

/// Parse a literal value
/// ("(" expr ")") | constant | identifier
fn literal(self: *Parser) SyntaxError!ExprNode {
    // Check if this is a grouping
    if (self.match(.{TokenKind.LEFT_PAREN})) {
        const expr = try self.expression();
        // Consume ')'
        try self.consume(TokenKind.RIGHT_PAREN, "Unclosed parenthesis");
        return expr;
    }
    // Store current token
    const token = self.current;
    // Advance
    _ = self.advance();
    switch (token.kind) {
        .FALSE => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make new value
            const value = Value.newBool(false);
            constant_expr.* = .{ .CONSTANT = value };
            return ExprNode{ .LITERAL = constant_expr };
        },
        .TRUE => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make new value
            const value = Value.newBool(true);
            constant_expr.* = .{ .CONSTANT = value };
            return ExprNode{ .LITERAL = constant_expr };
        },
        .INTEGER => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Parse lexeme
            const parsed_int = std.fmt.parseInt(i64, token.lexeme, 10) catch unreachable;
            // Make new value
            const value = Value.newInt(parsed_int, true, 64);
            constant_expr.* = .{ .CONSTANT = value };
            return ExprNode{ .LITERAL = constant_expr };
        },
        .FLOAT => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Parse lexeme
            const parsed_int = std.fmt.parseFloat(f64, token.lexeme) catch unreachable;
            // Make new value
            const value = Value.newFloat(parsed_int, 64);
            constant_expr.* = .{ .CONSTANT = value };
            return ExprNode{ .LITERAL = constant_expr };
        },
        .STRING => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make new value without quotes
            const value = Value.newStr(token.lexeme[1 .. token.lexeme.len - 1]);
            constant_expr.* = .{ .CONSTANT = value };
            return ExprNode{ .LITERAL = constant_expr };
        },
        .ARRAY_TYPE => {
            // ****************************************************** //
            // FOR NOW THROWS AN ERROR
            return self.errorAt("Do not use arrays yet please thanks");
        },
        .IDENTIFIER => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make new value
            const name = token.lexeme;
            constant_expr.* = .{ .IDENTIFIER = name };
            return ExprNode{ .LITERAL = constant_expr };
        },
        else => return self.errorAt("Invalid Expression"),
    }
}
