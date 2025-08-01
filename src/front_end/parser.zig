const std = @import("std");

/// Scanner import
const Scan = @import("scanner.zig");
const Scanner = Scan.Scanner;
const Token = Scan.Token;
const TokenKind = Scan.TokenKind;
/// Constant, values, and symbols import
const Symbols = @import("../symbols.zig");
const ValueKind = Symbols.ValueKind;
const Value = Symbols.Value;
const KindId = Symbols.KindId;
const ScopeKind = Symbols.ScopeKind;
/// Expression nodes import
const Expr = @import("../expr.zig");
const ExprNode = Expr.ExprNode;
const ExprUnion = Expr.ExprUnion;
/// Statement Import
const Stmt = @import("../stmt.zig");
const StmtNode = Stmt.StmtNode;
/// Modules/Program File import
const Module = @import("../module.zig");
/// Error import
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
/// Stores all use dependency module requests
dependencies: std.ArrayList(Stmt.ModStmt),
current_module_name: []const u8,

/// Parser initializer
pub fn init(allocator: std.mem.Allocator, scanner: *Scanner, module_name: []const u8) Parser {
    // Make a new parser
    const new_parser = Parser{
        .allocator = allocator,
        .scanner = scanner,
        .current = undefined,
        .previous = undefined,
        .had_error = false,
        .panic = false,
        .dependencies = std.ArrayList(Stmt.ModStmt).init(allocator),
        .current_module_name = module_name,
    };
    return new_parser;
}

pub fn reset(self: *Parser, source: []const u8, module_name: []const u8) void {
    self.had_error = false;
    self.panic = false;
    self.current = undefined;
    self.previous = undefined;
    self.scanner.reset(source);
    self.dependencies.shrinkRetainingCapacity(0);
    self.current_module_name = module_name;
}

/// Parse until scanner returns an EOF Token
/// Report any errors encountered
pub fn parse(self: *Parser, module: *Module) []Stmt.ModStmt {
    // Advance
    _ = self.advance();
    // Parse
    while (!self.isAtEnd()) {
        // Parse stmt
        const stmt_node = self.global() catch {
            // Attempt to realign to next statement start
            self.globalSynchronize();
            continue;
        };

        // Try to append to module
        module.addStmt(stmt_node) catch unreachable;
    }

    const dependencies = self.allocator.alloc(Stmt.ModStmt, self.dependencies.items.len) catch unreachable;
    std.mem.copyForwards(Stmt.ModStmt, dependencies, self.dependencies.items);
    return dependencies;
}

/// Return true if there was an error while parsing
pub fn hadError(self: *Parser) bool {
    return self.had_error;
}

// ********************** //
// Private helper methods //
// ********************** //
/// Returns true if rhs has a higher precedence / should be swapped
fn checkReversed(lhs: isize, rhs: isize) bool {
    if (lhs < 0) return false;
    if (rhs < 0) return true;
    return rhs > lhs;
}

/// Returns new precedence level
fn newPrecedence(precedence: isize) isize {
    return if (precedence < 0) precedence else precedence + 1;
}

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

/// Take in TokenKinds and check if current token matches any.
/// If a match is found, return true, else false
fn matchNoAdvance(self: *Parser, kinds: anytype) bool {
    // Check if current token matches any
    inline for (kinds) |kind| {
        if (self.check(kind)) {
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

/// Helper function to parse kind, Parses a pointer type
/// pointer kind -> '*' "const"?
fn parsePtrKind(self: *Parser) SyntaxError!KindId {
    const const_child = self.match(.{TokenKind.CONST});
    // Parse child kind
    const child_kind = try self.parseKind();

    const new_kind = KindId.newPtr(self.allocator, child_kind, const_child);
    return new_kind;
}

/// Helper function to parse a function kind
/// fn kind -> fn (arg_kinds) return_kind
/// arg_kinds -> ((kind) (',' (kind))*)?
fn parseFuncKind(self: *Parser) SyntaxError!KindId {
    try self.consume(TokenKind.LEFT_PAREN, "Expected '(' after \"fn\" in function type definition");

    // Make call args list
    var arg_list = std.ArrayList(KindId).init(self.allocator);
    // Check if next token is ')'
    if (!self.match(.{TokenKind.RIGHT_PAREN})) {
        // Parse first arg
        const first_arg_kind = try self.parseKind();
        // Add to list
        arg_list.append(first_arg_kind) catch unreachable;

        // Until ')' or end of file
        while (!self.match(.{TokenKind.RIGHT_PAREN}) or self.isAtEnd()) {
            // Consume ','
            try self.consume(TokenKind.COMMA, "Expected ',' after function type definition argument");
            // Parse first arg
            const arg_kind = try self.parseKind();
            // Add to list
            arg_list.append(arg_kind) catch unreachable;
        }

        // Check if at end
        if (self.isAtEnd()) {
            return self.errorAt("Unclosed function type definition argument list");
        }
    }
    // Parse return kind
    const return_kind = try self.parseKind();
    // Make new func kindid
    const new_func = KindId.newFunc(self.allocator, arg_list.items, false, return_kind);
    return new_func;
}

/// Parse an array kind definition
/// ArrayKind -> '[' integer ']' Kind
fn parseArrayKind(self: *Parser) SyntaxError!KindId {
    // Consume integer
    try self.consume(TokenKind.INTEGER, "Expected a 64 bit unsigned integer for array length");
    const length_token = self.previous;
    // Parse into usize
    const length = std.fmt.parseInt(usize, length_token.lexeme, 10) catch {
        return self.errorAt("Expected a 64 bit unsigned integer for array length");
    };
    try self.consume(TokenKind.RIGHT_SQUARE, "Expected ']' after array length");

    const const_child = self.match(.{TokenKind.CONST});
    // Parse child kind
    const child_kind = try self.parseKind();

    const new_kind = KindId.newArr(self.allocator, child_kind, length, const_child, false);
    return new_kind;
}

/// Parse a generic kind '<' kind_list '>' IDENTIFIER
fn parseUserKind(self: *Parser) SyntaxError!KindId {
    const id = self.previous;

    if (self.match(.{TokenKind.LESS})) {
        const generic_data = try self.parse_generic_kinds();
        return KindId{ .GENERIC_USER_KIND = .{ .id = id, .generic_kinds = generic_data.names } };
    } else {
        return KindId{ .USER_KIND = id.lexeme };
    }
}

/// Parse a kind into a KindId
fn parseKind(self: *Parser) SyntaxError!KindId {
    // Advance to next token
    const token = self.advance();
    return switch (token.kind) {
        .VOID_TYPE => KindId.VOID,
        .BOOL_TYPE => KindId.BOOL,
        .U8_TYPE => KindId.newUInt(8),
        .U16_TYPE => KindId.newUInt(16),
        .U32_TYPE => KindId.newUInt(32),
        .U64_TYPE => KindId.newUInt(64),
        .I8_TYPE => KindId.newInt(8),
        .I16_TYPE => KindId.newInt(16),
        .I32_TYPE => KindId.newInt(32),
        .I64_TYPE => KindId.newInt(64),
        .F32_TYPE => KindId.FLOAT32,
        .F64_TYPE => KindId.FLOAT64,
        .LEFT_SQUARE => try self.parseArrayKind(),
        .STAR => try self.parsePtrKind(),
        .IDENTIFIER => try self.parseUserKind(),
        .FN => try self.parseFuncKind(),
        else => self.errorAt("Expected type"),
    };
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
        stderr.print("Module <root{s}>, Line {d}:{d}]", .{ self.current_module_name, token.line, token.column }) catch unreachable;

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

/// Synchronize to start of next global statement
fn globalSynchronize(self: *Parser) void {
    // Turn of panic mode
    self.panic = false;

    // Advance until end of file or potential start of new statement
    while (self.current.kind != TokenKind.EOF) {
        if (self.matchNoAdvance(.{ TokenKind.CONST, TokenKind.VAR, TokenKind.FN })) return;
        _ = self.advance();
    }
}

/// Synchronize to start of next statement
fn synchronize(self: *Parser) void {
    // Turn of panic mode
    self.panic = false;

    // Advance until end of file or potential start of new statement
    while (self.current.kind != TokenKind.EOF) {
        // Check for semicolon
        if (self.previous.kind == TokenKind.SEMICOLON) return;
        // Check if next token is potential start of statement
        if (self.matchNoAdvance(.{
            TokenKind.LEFT_BRACE,
            TokenKind.IF,
            TokenKind.WHILE,
            TokenKind.FOR,
            TokenKind.CONST,
            TokenKind.VAR,
            TokenKind.SWITCH,
            TokenKind.CONTINUE,
            TokenKind.BREAK,
            TokenKind.RETURN,
        })) return;
        // Advance
        _ = self.advance();
    }
}

//**************************//
//      Struct for Node
//         and Height
//**************************//
const ExprResult = struct {
    expr: ExprNode,
    precedence: isize,

    pub fn init(expr: ExprNode, precedence: isize) ExprResult {
        return .{
            .expr = expr,
            .precedence = precedence,
        };
    }
};

//**************************//
//      Parse Stmts
//**************************//
/// Parse a Global level stmt
/// Global -> GlobalStmt | FunctionStmt
fn global(self: *Parser) SyntaxError!StmtNode {
    // Check if public
    const is_public = self.match(.{TokenKind.PUB});

    if (self.match(.{ TokenKind.CONST, TokenKind.VAR })) {
        return self.globalStmt(is_public);
    } else if (self.match(.{TokenKind.FN})) {
        return self.functionStmt(is_public);
    } else if (self.match(.{TokenKind.STRUCT})) {
        return self.structStmt(is_public);
    } else if (self.match(.{TokenKind.ENUM})) {
        return self.enumStmt(is_public);
    } else if (self.match(.{TokenKind.UNION})) {
        return self.unionStmt(is_public);
    } else if (self.match(.{TokenKind.MOD})) {
        return self.modStmt(is_public);
    } else if (self.match(.{TokenKind.USE})) {
        return self.useStmt(is_public);
    }
    _ = self.advance();
    return self.errorAt("Expected global level declaration statement");
}

const GenericData = struct {
    op: Token,
    names: []Token,
};

const GenericKinds = struct {
    op: Token,
    names: []KindId,
};

fn maybe_parse_generic_data(self: *Parser) SyntaxError!?GenericData {
    if (!self.match(.{TokenKind.LESS})) {
        return null;
    }
    return try self.parse_generic_data();
}

fn parse_generic_data(self: *Parser) SyntaxError!GenericData {
    const op = self.previous;
    var generic_names = std.ArrayList(Token).init(self.allocator);

    try self.consume(TokenKind.IDENTIFIER, "Expected generic type identifier for generic blueprint or generic invocation");
    generic_names.append(self.previous) catch unreachable;
    while (!self.match(.{TokenKind.GREATER}) and !self.isAtEnd()) {
        try self.consume(TokenKind.COMMA, "Expected ',' after generic type");
        try self.consume(TokenKind.IDENTIFIER, "Expected generic type identifier for generic blueprint or generic invocation");
        generic_names.append(self.previous) catch unreachable;
    }

    return GenericData{ .op = op, .names = generic_names.items };
}

fn maybe_parse_generic_kinds(self: *Parser) SyntaxError!?GenericKinds {
    if (!self.match(.{TokenKind.SCOPE_LESS})) {
        return null;
    }
    return try self.parse_generic_kinds();
}

fn parse_generic_kinds(self: *Parser) SyntaxError!GenericKinds {
    const op = self.previous;
    var generic_names = std.ArrayList(KindId).init(self.allocator);

    const first_kind = try self.parseKind();
    generic_names.append(first_kind) catch unreachable;
    while (!self.match(.{TokenKind.GREATER}) and !self.isAtEnd()) {
        try self.consume(TokenKind.COMMA, "Expected ',' after generic type");
        const kind = try self.parseKind();
        generic_names.append(kind) catch unreachable;
    }

    return GenericKinds{ .op = op, .names = generic_names.items };
}

/// ModStmt -> "mod" identifier ";"
fn modStmt(self: *Parser, is_public: bool) SyntaxError!StmtNode {
    const mod_token = self.previous;

    try self.consume(TokenKind.IDENTIFIER, "Expected identifier after mod keyword");
    const module_name = self.previous;
    try self.consume(TokenKind.SEMICOLON, "Expected ';' after module name");

    const new_stmt = self.allocator.create(Stmt.ModStmt) catch unreachable;
    new_stmt.* = Stmt.ModStmt.init(is_public, mod_token, module_name);

    self.dependencies.append(new_stmt.*) catch unreachable;
    return StmtNode{ .MOD = new_stmt };
}

/// UseStmt -> "use" ScopeExpr|IdExpr ("as" IDENTIFIER)? ";"
fn useStmt(self: *Parser, is_public: bool) SyntaxError!StmtNode {
    const use_token = self.previous;

    const token = self.advance();
    const scope = get_scope: switch (token.kind) {
        .SCOPE => {
            // Make fake target scope for global
            const global_token = Token{ .column = token.column, .lexeme = "", .kind = .IDENTIFIER, .line = token.line };
            const global_id_expr = self.allocator.create(Expr.IdentifierExpr) catch unreachable;
            global_id_expr.* = Expr.IdentifierExpr{ .id = global_token, .lexical_scope = undefined };
            const global_scope = ExprNode.init(.{ .IDENTIFIER = global_id_expr });

            break :get_scope try self.scopeExpr(global_scope, token);
        },
        .IDENTIFIER, .SUPER => try self.idExpr(token),
        else => return self.reportError(self.previous, "Expected a scope expression after use keyword"),
    };

    var as_name: ?Token = null;
    if (self.match(.{TokenKind.AS})) {
        try self.consume(TokenKind.IDENTIFIER, "Expected identifier after use statement as keyword");
        as_name = self.previous;
    }

    try self.consume(TokenKind.SEMICOLON, "Expected ';' after module name");

    const new_stmt = self.allocator.create(Stmt.UseStmt) catch unreachable;
    new_stmt.* = Stmt.UseStmt.init(use_token, scope.expr, as_name, is_public);

    return StmtNode{ .USE = new_stmt };
}

/// Parse a global declaration stmt
/// GlobalStmt -> ("const" | "var") (':' type)? '=' expression ';'
fn globalStmt(self: *Parser, is_public: bool) SyntaxError!StmtNode {
    // Get mutability of this declaration
    const mutable = (self.previous.kind == .VAR);
    // Consume identifier
    try self.consume(TokenKind.IDENTIFIER, "Expected identifier name after declare statement");
    const id = self.previous;

    // Check if type declaration was included
    var kind: ?KindId = null;
    if (self.match(.{TokenKind.COLON})) {
        kind = try self.parseKind();
    }

    // Consume "="
    try self.consume(TokenKind.EQUAL, "Expected '=' after identifier in declaration");
    // Get operator
    const op = self.previous;

    // Check if undefined
    var assign_expr: ?ExprNode = null;
    if (!self.match(.{TokenKind.UNDEFINED})) {
        // Parse expression
        const assign_expr_result = try self.expression();
        assign_expr = assign_expr_result.expr;
    }

    // Consume ';'
    try self.consume(TokenKind.SEMICOLON, "Expected ';' after declaration statement");

    // Allocate new DeclareStmt
    const new_stmt = self.allocator.create(Stmt.GlobalStmt) catch unreachable;
    new_stmt.* = Stmt.GlobalStmt.init(is_public, mutable, id, kind, op, assign_expr);

    return StmtNode{ .GLOBAL = new_stmt };
}

/// Parse a function statement
/// FunctionStmt -> "fn" identifier '(' arglist? ')' type BlockStmt
/// arglist -> arg (',' arg)*
/// arg -> identifier ':' type
fn functionStmt(self: *Parser, is_public: bool) SyntaxError!StmtNode {
    // Get op
    const op = self.previous;
    const maybe_generic_data = try self.maybe_parse_generic_data();
    // Get name
    try self.consume(TokenKind.IDENTIFIER, "Expected function identifier");
    const name = self.previous;

    // Consume '('
    try self.consume(TokenKind.LEFT_PAREN, "Expected '(' after function identifier");
    const arg_list_result = try self.parseArgList(TokenKind.RIGHT_PAREN);
    // Check previous was paren
    if (self.previous.kind != .RIGHT_PAREN) {
        return self.errorAt("Expected ')' after function argument list");
    }

    // Parse return kind
    const return_kind = try self.parseKind();
    // Consume '{'
    try self.consume(TokenKind.LEFT_BRACE, "Expected '{' after function return type");
    // Parse body
    const body = try self.blockStmt();

    // Allocate new FunctionStmt
    const new_stmt = self.allocator.create(Stmt.FunctionStmt) catch unreachable;
    new_stmt.* = Stmt.FunctionStmt.init(
        is_public,
        op,
        name,
        arg_list_result.arg_names,
        arg_list_result.arg_kinds,
        return_kind,
        body,
    );
    const function_node = StmtNode{ .FUNCTION = new_stmt };

    if (maybe_generic_data) |generic_data| {
        const new_generic_stmt = self.allocator.create(Stmt.GenericStmt) catch unreachable;
        new_generic_stmt.* = Stmt.GenericStmt.init(generic_data.op, generic_data.names, function_node);
        return StmtNode{ .GENERIC = new_generic_stmt };
    } else {
        return function_node;
    }
}

const ArgList = struct {
    arg_names: []Token,
    arg_kinds: []KindId,
};

/// Helper function to parse argument list
fn parseArgList(self: *Parser, closing_token_kind: TokenKind) SyntaxError!ArgList {
    // Parse args
    var arg_name_list = std.ArrayList(Token).init(self.allocator);
    var arg_kind_list = std.ArrayList(KindId).init(self.allocator);

    // Check if any args
    if (!self.match(.{closing_token_kind})) {
        // Do first arg
        // Get name
        try self.consume(TokenKind.IDENTIFIER, "Expected argument identifier");
        const first_arg_name = self.previous;
        // Consume ':'
        try self.consume(TokenKind.COLON, "Expected ':' after argument identifier");
        // Get type
        const first_arg_kind = try self.parseKind();
        // Add to arg_list
        arg_name_list.append(first_arg_name) catch unreachable;
        arg_kind_list.append(first_arg_kind) catch unreachable;

        // Do sequential args
        while (!self.match(.{closing_token_kind}) and !self.isAtEnd()) {
            // Consume ','
            try self.consume(TokenKind.COMMA, "Expected ',' after argument");

            // Get name
            try self.consume(TokenKind.IDENTIFIER, "Expected argument identifier");
            const arg_name = self.previous;
            // Consume ':'
            try self.consume(TokenKind.COLON, "Expected ':' after argument identifier");
            // Get type
            const arg_kind = try self.parseKind();

            // Add to arg_list
            arg_name_list.append(arg_name) catch unreachable;
            arg_kind_list.append(arg_kind) catch unreachable;
        }
    }

    return ArgList{ .arg_names = arg_name_list.items, .arg_kinds = arg_kind_list.items };
}

/// StructStmt -> "struct" identifier '{' fieldlist '}'
/// FieldList -> (Field | Method)+
/// Field -> identifier ':' KindId ';'
/// Method -> fn identifier '(' arglist ')' block
fn structStmt(self: *Parser, is_public: bool) SyntaxError!StmtNode {
    try self.consume(TokenKind.IDENTIFIER, "Expected identifier after 'struct' keyword");
    const id = self.previous;
    const maybe_generic_data = try self.maybe_parse_generic_data();
    try self.consume(TokenKind.LEFT_BRACE, "Expected '{' before struct field list");

    var field_name_list = std.ArrayList(Token).init(self.allocator);
    var field_kind_list = std.ArrayList(KindId).init(self.allocator);
    var method_list = std.ArrayList(Stmt.FunctionStmt).init(self.allocator);
    // Parse fields and methods
    if (self.match(.{ TokenKind.PUB, TokenKind.FN })) {
        try self.struct_method(&method_list);
    } else { // Field
        try self.struct_field(&field_name_list, &field_kind_list);
    }
    // Do the rest if there are any
    while (!self.match(.{TokenKind.RIGHT_BRACE}) and !self.isAtEnd()) {
        // Check for method
        if (self.match(.{ TokenKind.PUB, TokenKind.FN })) {
            try self.struct_method(&method_list);
        } else { // Field
            try self.struct_field(&field_name_list, &field_kind_list);
        }
    }
    // Check if previous was brace
    if (self.previous.kind != .RIGHT_BRACE) {
        return self.errorAt("Expected '}' after struct field list");
    }

    // Create new stmt
    const new_stmt = self.allocator.create(Stmt.StructStmt) catch unreachable;
    new_stmt.* = Stmt.StructStmt.init(
        is_public,
        id,
        field_name_list.items,
        field_kind_list.items,
        method_list.items,
    );
    const struct_node = StmtNode{ .STRUCT = new_stmt };

    if (maybe_generic_data) |generic_data| {
        const new_gen_node = self.allocator.create(Stmt.GenericStmt) catch unreachable;
        new_gen_node.* = .{ .body = struct_node, .generic_names = generic_data.names, .op = generic_data.op };
        return StmtNode{ .GENERIC = new_gen_node };
    } else {
        return struct_node;
    }
}

/// Parse a struct field
/// Field -> identifier ':' kind ';'
fn struct_field(self: *Parser, field_name_list: *std.ArrayList(Token), field_kind_list: *std.ArrayList(KindId)) SyntaxError!void {
    // First field, must have atleast one
    try self.consume(TokenKind.IDENTIFIER, "Expected field identifier name");
    const field_name = self.previous;
    try self.consume(TokenKind.COLON, "Expected ':' after field identifier name");
    const field_kind = try self.parseKind();
    // Append it
    field_name_list.append(field_name) catch unreachable;
    field_kind_list.append(field_kind) catch unreachable;
    // Consume ';'
    try self.consume(TokenKind.SEMICOLON, "Expected ';' after field definition");
}

/// Parse a struct method
/// Method -> function (but it can use "this" and has the "this" parameter added)
fn struct_method(self: *Parser, method_list: *std.ArrayList(Stmt.FunctionStmt)) SyntaxError!void {
    const is_public = self.previous.kind == TokenKind.PUB;

    if (is_public) {
        try self.consume(TokenKind.FN, "Expected fn after pub keyword in method definition");
    }

    const new_method = try self.functionStmt(is_public);
    method_list.append(new_method.FUNCTION.*) catch unreachable;
}

fn unionStmt(self: *Parser, is_public: bool) SyntaxError!StmtNode {
    try self.consume(TokenKind.IDENTIFIER, "Expected union identifier");
    const id = self.previous;
    const maybe_generic_data = try self.maybe_parse_generic_data();
    try self.consume(TokenKind.LEFT_BRACE, "Expected '{' before union fields");

    var field_name_list = std.ArrayList(Token).init(self.allocator);
    var field_kind_list = std.ArrayList(KindId).init(self.allocator);

    try self.struct_field(&field_name_list, &field_kind_list);
    // Do the rest if there are any
    while (!self.match(.{TokenKind.RIGHT_BRACE}) and !self.isAtEnd()) {
        try self.struct_field(&field_name_list, &field_kind_list);
    }
    // Check if previous was brace
    if (self.previous.kind != .RIGHT_BRACE) {
        return self.errorAt("Expected '}' after struct field list");
    }

    const new_union = self.allocator.create(Stmt.UnionStmt) catch unreachable;
    new_union.* = Stmt.UnionStmt.init(is_public, id, field_name_list.items, field_kind_list.items);
    const union_node = StmtNode{ .UNION = new_union };

    if (maybe_generic_data) |generic_data| {
        const new_generic = self.allocator.create(Stmt.GenericStmt) catch unreachable;
        new_generic.* = Stmt.GenericStmt.init(generic_data.op, generic_data.names, union_node);
        return StmtNode{ .GENERIC = new_generic };
    } else {
        return union_node;
    }
}

fn enumStmt(self: *Parser, is_public: bool) SyntaxError!StmtNode {
    try self.consume(TokenKind.IDENTIFIER, "Expected enum identifier");
    const id = self.previous;
    try self.consume(TokenKind.LEFT_BRACE, "Expected '{' before enum variant list");

    var variant_names_list = std.ArrayList(Token).init(self.allocator);

    try self.consume(TokenKind.IDENTIFIER, "Expected at least one enum variant");
    variant_names_list.append(self.previous) catch unreachable;

    // Do the rest if there are any
    while (!self.match(.{TokenKind.RIGHT_BRACE}) and !self.isAtEnd()) {
        try self.consume(TokenKind.COMMA, "Expected comma between variants");

        try self.consume(TokenKind.IDENTIFIER, "Expected enum variant");
        variant_names_list.append(self.previous) catch unreachable;
    }
    // Check if previous was brace
    if (self.previous.kind != .RIGHT_BRACE) {
        return self.errorAt("Expected '}' after struct field list");
    }

    // Create new stmt
    const new_stmt = self.allocator.create(Stmt.EnumStmt) catch unreachable;
    new_stmt.* = Stmt.EnumStmt.init(is_public, id, variant_names_list.items);
    return StmtNode{ .ENUM = new_stmt };
}

// ************************** //
//      In function stuff     //
// ************************** //

/// Parse a declaration
/// Declaration -> DeclareStmt | statement
fn declaration(self: *Parser) SyntaxError!StmtNode {
    if (self.match(.{ TokenKind.CONST, TokenKind.VAR })) { // DeclareStmt
        return self.declareStmt();
    } else if (self.match(.{TokenKind.DEFER})) {
        return self.deferStmt();
    } else { // Stmt fall through
        return self.statement();
    }
}

/// Parse a declareStmt
/// DeclareStmt -> ("const"|"var") identifier (":" type)? "=" expression ";"
fn declareStmt(self: *Parser) SyntaxError!StmtNode {
    // Get mutability of this declaration
    const mutable = (self.previous.kind == .VAR);
    // Consume identifier
    try self.consume(TokenKind.IDENTIFIER, "Expected identifier name after declare statement");
    const id = self.previous;

    // Check if type declaration was included
    var kind: ?KindId = null;
    if (self.match(.{TokenKind.COLON})) {
        kind = try self.parseKind();
    }

    // Consume "="
    try self.consume(TokenKind.EQUAL, "Expected '=' after identifier in declaration");
    // Get operator
    const op = self.previous;

    // Check if undefined
    var assign_expr: ?ExprNode = null;
    if (!self.match(.{TokenKind.UNDEFINED})) {
        // Parse expression
        const assign_expr_result = try self.expression();
        assign_expr = assign_expr_result.expr;
    }
    // Consume ';'
    try self.consume(TokenKind.SEMICOLON, "Expected ';' after declaration statement");

    // Allocate new DeclareStmt
    const new_stmt = self.allocator.create(Stmt.DeclareStmt) catch unreachable;
    new_stmt.* = Stmt.DeclareStmt.init(mutable, id, kind, op, assign_expr);
    return StmtNode{ .DECLARE = new_stmt };
}

/// DeferStmt -> defer statement
fn deferStmt(self: *Parser) SyntaxError!StmtNode {
    const op = self.previous;

    const stmt = try self.statement();

    const new_stmt = self.allocator.create(Stmt.DeferStmt) catch unreachable;
    new_stmt.* = Stmt.DeferStmt.init(op, stmt);
    return StmtNode{ .DEFER = new_stmt };
}

/// Parse a Stmt
/// statement -> AssignStmt | ExprStmt
fn statement(self: *Parser) SyntaxError!StmtNode {
    if (self.match(.{TokenKind.LEFT_BRACE})) {
        return self.blockStmt();
    } else if (self.match(.{TokenKind.WHILE})) {
        return self.whileStmt();
    } else if (self.match(.{TokenKind.FOR})) {
        return self.forStmt();
    } else if (self.match(.{TokenKind.IF})) {
        return self.ifStmt();
    } else if (self.match(.{TokenKind.RETURN})) {
        return self.returnStmt();
    } else if (self.match(.{TokenKind.BREAK})) {
        return self.breakStmt();
    } else if (self.match(.{TokenKind.CONTINUE})) {
        return self.continueStmt();
    } else if (self.match(.{TokenKind.SWITCH})) {
        return self.switchStmt();
    } else { // ExprStmt or MutStmt fall through
        const expr = try self.expression();
        if (self.match(.{
            TokenKind.EQUAL,
            TokenKind.PLUS_EQUAL,
            TokenKind.MINUS_EQUAL,
            TokenKind.STAR_EQUAL,
            TokenKind.SLASH_EQUAL,
            TokenKind.PERCENT_EQUAL,
            TokenKind.AMPERSAND_EQUAL,
            TokenKind.PIPE_EQUAL,
            TokenKind.CARET_EQUAL,
        })) {
            return self.mutStmt(expr);
        }
        // Fall through to expr stmt
        return self.exprStmt(expr);
    }
}

fn switchStmt(self: *Parser) SyntaxError!StmtNode {
    const op = self.previous;

    // Consume '('
    try self.consume(TokenKind.LEFT_PAREN, "Expected '(' before switch value");
    // Get value expr
    const value_result = try self.expression();
    const value = value_result.expr;
    // Consume ')'
    try self.consume(TokenKind.RIGHT_PAREN, "Expected ')' after switch value");

    try self.consume(TokenKind.LEFT_BRACE, "Expected '{' before switch body");

    const Branch = struct {
        value: []ExprNode,
        arrow: Token,
        stmt: StmtNode,
    };
    var lit_branch_list = std.MultiArrayList(Branch){};
    var else_branch: ?StmtNode = null;
    var then_branch: ?StmtNode = null;
    try self.switchBranch(Branch, &lit_branch_list, &else_branch, &then_branch);

    while (!self.match(.{TokenKind.RIGHT_BRACE})) {
        try self.switchBranch(Branch, &lit_branch_list, &else_branch, &then_branch);
    }

    // Make new stmt node
    const new_stmt = self.allocator.create(Stmt.SwitchStmt) catch unreachable;
    new_stmt.* = Stmt.SwitchStmt.init(
        op,
        value,
        lit_branch_list.items(.value),
        lit_branch_list.items(.arrow),
        lit_branch_list.items(.stmt),
        else_branch,
        then_branch,
    );
    // Return new stmt node
    return StmtNode{ .SWITCH = new_stmt };
}

fn switchBranch(self: *Parser, Branch: type, lit_branch_list: *std.MultiArrayList(Branch), else_branch: *?StmtNode, then_branch: *?StmtNode) SyntaxError!void {
    if (self.match(.{TokenKind.ELSE})) {
        if (else_branch.* != null) {
            return self.errorAt("Duplicate else branch detected in switch body");
        }
        try self.consume(TokenKind.ARROW, "Expected '=>' after switch else branch");
        else_branch.* = try self.statement();
    } else if (self.match(.{TokenKind.THEN})) {
        if (then_branch.* != null) {
            return self.errorAt("Duplicate then branch detected in switch body");
        }
        try self.consume(TokenKind.ARROW, "Expected '=>' after switch then branch");
        then_branch.* = try self.statement();
    } else {
        var value_list = std.ArrayList(ExprNode).init(self.allocator);

        const first_value = try self.literal();
        value_list.append(first_value.expr) catch unreachable;
        while (!self.match(.{TokenKind.ARROW})) {
            try self.consume(TokenKind.PIPE, "Expected '|' between values for a switch branch");
            const value = try self.literal();
            value_list.append(value.expr) catch unreachable;
        }

        const arrow = self.previous;
        const stmt = try self.statement();
        lit_branch_list.append(self.allocator, .{ .value = value_list.items, .arrow = arrow, .stmt = stmt }) catch unreachable;
    }
}

/// Parse a WhileStmt
/// whileStmt -> "while" '(' expression ')' statement ("continue" ':' statement)?
fn whileStmt(self: *Parser) SyntaxError!StmtNode {
    // Store while keyword
    const op = self.previous;

    // Consume '('
    try self.consume(TokenKind.LEFT_PAREN, "Expected '(' before while conditional");
    // Get conditional expr
    const conditional_result = try self.expression();
    const conditional = conditional_result.expr;
    // Consume ')'
    try self.consume(TokenKind.RIGHT_PAREN, "Expected ')' after while conditional");

    // Parse body
    const body = try self.statement();

    // Check for loop stmt
    var loop_stmt: ?StmtNode = null;
    if (self.match(.{TokenKind.LOOP})) {
        // try self.consume(TokenKind.COLON, "Expected ':' after loop keyword");
        // Try to parse the statement
        loop_stmt = try self.statement();
    }

    // Make new stmt node
    const new_stmt = self.allocator.create(Stmt.WhileStmt) catch unreachable;
    new_stmt.* = Stmt.WhileStmt.init(op, conditional, body, loop_stmt);
    // Return new stmt node
    return StmtNode{ .WHILE = new_stmt };
}

/// Parse a WhileStmt
///
/// forStmt -> for (EXPR .. EXPR (, PTR)?) |IDENTIFIER (, IDENTIFIER)?| statement
fn forStmt(self: *Parser) SyntaxError!StmtNode {
    const op = self.previous;
    try self.consume(TokenKind.LEFT_PAREN, "Expected '(' after for keyword");

    const range_start_result = try self.expression();
    const range_start_expr = range_start_result.expr;
    try self.consume(TokenKind.DOT_DOT, "Expected '..' after for range start expression");
    const inclusive = self.match(.{TokenKind.EQUAL});
    const range_end_result = try self.expression();
    const range_end_expr = range_end_result.expr;

    const pointer_expr = if (self.match(.{TokenKind.COMMA})) blk: {
        const result = try self.expression();
        break :blk result.expr;
    } else null;

    try self.consume(TokenKind.RIGHT_PAREN, "Expected ')' after for conditional");
    try self.consume(TokenKind.PIPE, "Expected '|' after for conditional");
    try self.consume(TokenKind.IDENTIFIER, "Expected identifier to alias for loop range");
    const range_id = self.previous;

    const pointer_id = if (pointer_expr != null) blk: {
        try self.consume(TokenKind.COMMA, "Expected ',' seperating range and pointer identifier");
        try self.consume(TokenKind.IDENTIFIER, "Expected identifier for pointer identifier");
        break :blk self.previous;
    } else null;

    try self.consume(TokenKind.PIPE, "Expected '|' after for loop captures");

    const body = try self.statement();

    // Make new stmt node
    const new_stmt = self.allocator.create(Stmt.ForStmt) catch unreachable;
    new_stmt.* = Stmt.ForStmt.init(
        op,
        range_start_expr,
        range_end_expr,
        pointer_expr,
        range_id,
        pointer_id,
        body,
        inclusive,
    );
    // Return new stmt node
    return StmtNode{ .FOR = new_stmt };
}

/// Parses an if stmt
/// IfStmt -> "if" '(' expression ')' statement ("else" statement)?
fn ifStmt(self: *Parser) SyntaxError!StmtNode {
    // Get the if token
    const op = self.previous;

    // Consume '('
    try self.consume(TokenKind.LEFT_PAREN, "Expected '(' before if statement conditional");
    // Parse conditional
    const conditional_result = try self.expression();
    const conditional = conditional_result.expr;
    // Consume ')'
    try self.consume(TokenKind.RIGHT_PAREN, "Expected ')' after if statement conditional");

    // Parse then branch
    const then_branch = try self.statement();

    // Check for else
    var else_branch: ?StmtNode = null;
    if (self.match(.{TokenKind.ELSE})) {
        else_branch = try self.statement();
    }

    // Make new stmt node
    const new_stmt = self.allocator.create(Stmt.IfStmt) catch unreachable;
    new_stmt.* = Stmt.IfStmt.init(op, conditional, then_branch, else_branch);
    // Return new stmt node
    return StmtNode{ .IF = new_stmt };
}

/// Parses a BlockStmt
/// BlockStmt -> '{' statement? '}'
fn blockStmt(self: *Parser) SyntaxError!StmtNode {
    // Make list for body statements
    var stmt_list = std.ArrayList(StmtNode).init(self.allocator);

    // Parse until next '}'
    while (!self.isAtEnd() and !self.check(TokenKind.RIGHT_BRACE)) {
        const stmt = self.declaration() catch {
            // Attempt to synch
            self.synchronize();
            continue;
        };
        stmt_list.append(stmt) catch unreachable;
    }
    // Consume '}'
    try self.consume(TokenKind.RIGHT_BRACE, "Unclosed block statement");

    // Make new stmt node
    const new_stmt = self.allocator.create(Stmt.BlockStmt) catch unreachable;
    new_stmt.* = Stmt.BlockStmt.init(stmt_list.items);
    // Return new stmt node
    return StmtNode{ .BLOCK = new_stmt };
}

/// Parse an MutateStmt
/// MutateStmt -> "mut" identifier "=" expression ";"
fn mutStmt(self: *Parser, id_expr_result: ExprResult) SyntaxError!StmtNode {
    // Get id_expr
    const id_expr = id_expr_result.expr;

    // Get operator
    const op = self.previous;

    // Parse Expression
    const assign_expr_result = try self.expression();
    const assign_expr = assign_expr_result.expr;
    // Consume ';'
    try self.consume(TokenKind.SEMICOLON, "Expected ';' after mutation statement");

    // Make new stmt node
    const new_stmt = self.allocator.create(Stmt.MutStmt) catch unreachable;
    new_stmt.* = Stmt.MutStmt.init(id_expr, op, assign_expr);
    // Return new node
    return StmtNode{ .MUTATE = new_stmt };
}

/// Parse an ExprStmt
/// ExprStm -> expression ";"
fn exprStmt(self: *Parser, expr_result: ExprResult) SyntaxError!StmtNode {
    // Unwrap expressions
    const expr = expr_result.expr;

    // Consume ';'
    try self.consume(TokenKind.SEMICOLON, "Expected ';' after expression statement");
    // Allocate memory for new statement
    const new_stmt = self.allocator.create(Stmt.ExprStmt) catch unreachable;
    new_stmt.* = Stmt.ExprStmt.init(expr);
    // Return new node
    return StmtNode{ .EXPRESSION = new_stmt };
}

/// Parse a return stmt
/// ReturnStmt -> "return" expression? ';'
fn returnStmt(self: *Parser) SyntaxError!StmtNode {
    // Get keyword
    const op = self.previous;
    // Check if ';'
    var expr: ?ExprNode = null;
    if (!self.check(TokenKind.SEMICOLON)) {
        const expr_result = try self.expression();
        expr = expr_result.expr;
    }

    // Consume ';'
    try self.consume(TokenKind.SEMICOLON, "Expected ';' after return statement");
    // Allocate memory for new statement
    const new_stmt = self.allocator.create(Stmt.ReturnStmt) catch unreachable;
    new_stmt.* = Stmt.ReturnStmt.init(op, expr);
    // Return new node
    return StmtNode{ .RETURN = new_stmt };
}

/// Parse a break stmt
/// BreakStmt -> "break" ';'
fn breakStmt(self: *Parser) SyntaxError!StmtNode {
    // Get keyword
    const op = self.previous;
    // Consume ';'
    try self.consume(TokenKind.SEMICOLON, "Expected ';' after break statement");

    // Allocate memory for new statement
    const new_stmt = self.allocator.create(Stmt.BreakStmt) catch unreachable;
    new_stmt.* = Stmt.BreakStmt.init(op);
    // Return new node
    return StmtNode{ .BREAK = new_stmt };
}

/// Parse a break stmt
/// ContinueStmt -> "continue" ';'
fn continueStmt(self: *Parser) SyntaxError!StmtNode {
    // Get keyword
    const op = self.previous;
    // Consume ';'
    try self.consume(TokenKind.SEMICOLON, "Expected ';' after continue statement");

    // Allocate memory for new statement
    const new_stmt = self.allocator.create(Stmt.ContinueStmt) catch unreachable;
    new_stmt.* = Stmt.ContinueStmt.init(op);
    // Return new node
    return StmtNode{ .CONTINUE = new_stmt };
}

//**************************//
//      Parse Exprs
//**************************//

/// Parse an expression
/// expr -> term
fn expression(self: *Parser) SyntaxError!ExprResult {
    return self.if_expr();
}

/// Parse an If Expression
fn if_expr(self: *Parser) SyntaxError!ExprResult {
    // Get lhs
    const expr_result = try self.logic_or();
    var expr = expr_result.expr;
    // Upwrap precedence
    const precendence = expr_result.precedence;
    // Check for '?'
    if (self.match(.{TokenKind.QUESTION_MARK})) {
        // Extract if token
        const if_token = self.previous;

        // Get then branch
        const then_branch = try self.if_expr();
        // Inwrap condition expr
        const then_expr = then_branch.expr;

        // Consume ':'
        try self.consume(TokenKind.COLON, "Expected ':' after conditional then branch");

        // Get then branch
        const else_branch = try self.if_expr();
        // Inwrap condition expr
        const else_expr = else_branch.expr;

        // Make new inner expression
        const new_expr = self.allocator.create(Expr.IfExpr) catch unreachable;
        new_expr.* = Expr.IfExpr.init(if_token, expr, then_expr, else_expr);
        // Get precedence
        expr = ExprNode.init(ExprUnion{ .IF = new_expr });
    }
    // Wrap and return
    return ExprResult.init(expr, precendence);
}

/// Parse an and statement
/// and -> compare ("and" compare)*
fn logic_or(self: *Parser) SyntaxError!ExprResult {
    // Get lhs
    const lhs = try self.logic_and();
    // Unwrap expr
    var expr = lhs.expr;
    // Unwrap precedence
    var precedence = lhs.precedence;

    // While still 'and'
    while (self.match(.{TokenKind.OR})) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const rhs = try self.logic_and();

        // Make new inner expression
        const new_expr = self.allocator.create(Expr.OrExpr) catch unreachable;
        new_expr.* = Expr.OrExpr.init(expr, rhs.expr, operator);

        // Check if precedence needs to be swapped to rhs
        if (checkReversed(precedence, rhs.precedence)) {
            precedence = rhs.precedence;
        }

        expr = ExprNode.init(ExprUnion{ .OR = new_expr });
    }
    // Wrap and return
    return ExprResult.init(expr, precedence);
}

/// Parse an and statement
/// and -> compare ("and" compare)*
fn logic_and(self: *Parser) SyntaxError!ExprResult {
    // Get lhs
    const lhs = try self.compare();
    // Unwrap expr
    var expr = lhs.expr;
    // Unwrap precedence
    var precedence = lhs.precedence;

    // While still 'and'
    while (self.match(.{TokenKind.AND})) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const rhs = try self.compare();

        // Make new inner expression
        const new_expr = self.allocator.create(Expr.AndExpr) catch unreachable;
        new_expr.* = Expr.AndExpr.init(expr, rhs.expr, operator);

        // Check if precedence needs to be swapped to rhs
        if (checkReversed(precedence, rhs.precedence)) {
            precedence = rhs.precedence;
        }

        expr = ExprNode.init(ExprUnion{ .AND = new_expr });
    }
    // Wrap and return
    return ExprResult.init(expr, precedence);
}

/// Parse a compare statement
/// compare -> term (("<"|">"|"<="|">="|"=="|"!=") term)*
fn compare(self: *Parser) SyntaxError!ExprResult {
    const lhs = try self.term();
    // Extract expression
    var expr = lhs.expr;
    // Extract precedence
    var precedence = lhs.precedence;

    // While still >,<,>=,<=
    while (self.match(.{
        TokenKind.GREATER,
        TokenKind.GREATER_EQUAL,
        TokenKind.LESS,
        TokenKind.LESS_EQUAL,
        TokenKind.EQUAL_EQUAL,
        TokenKind.EXCLAMATION_EQUAL,
    })) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const rhs = try self.term();

        // Make new inner expression, with operator
        const new_expr = self.allocator.create(Expr.CompareExpr) catch unreachable;

        // Check if reversed or not
        if (checkReversed(precedence, rhs.precedence)) {
            // Rhs is bigger, swap lh and rh sides
            precedence = rhs.precedence;
            new_expr.* = Expr.CompareExpr.init(rhs.expr, expr, operator, true);
        } else {
            // Lhs is bigger, do not swap
            new_expr.* = Expr.CompareExpr.init(expr, rhs.expr, operator, false);
        }
        // Update expr
        expr = ExprNode.init(ExprUnion{ .COMPARE = new_expr });
        // Update precedence
        precedence = newPrecedence(precedence);
    }
    // Wrap and return
    return ExprResult.init(expr, precedence);
}

/// Parse an addition or subtraction statement
/// term -> factor (("-"|"+") factor)*
fn term(self: *Parser) SyntaxError!ExprResult {
    const lhs = try self.factor();
    // Extract expression
    var expr = lhs.expr;
    // Extract precedence
    var precedence = lhs.precedence;

    // While there are still '+' or '-' tokens
    while (self.match(.{ TokenKind.PLUS, TokenKind.MINUS })) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const rhs = try self.factor();

        // Make new inner expression, with operator
        const new_expr = self.allocator.create(Expr.ArithExpr) catch unreachable;

        // Check if reversed or not
        if (checkReversed(precedence, rhs.precedence)) {
            // Rhs is bigger, swap lh and rh sides
            precedence = rhs.precedence;
            new_expr.* = Expr.ArithExpr.init(rhs.expr, expr, operator, true);
        } else {
            // Lhs is bigger, do not swap
            new_expr.* = Expr.ArithExpr.init(expr, rhs.expr, operator, false);
        }
        // Update expr
        expr = ExprNode.init(ExprUnion{ .ARITH = new_expr });
        // Update precedence
        precedence = newPrecedence(precedence);
    }
    // Wrap and return
    return ExprResult.init(expr, precedence);
}

/// Parse a multiplication or division statement
/// factor -> unary (("*"|"/"|"%") unary)*
fn factor(self: *Parser) SyntaxError!ExprResult {
    const lhs = try self.conversion();
    // Extract expression
    var expr = lhs.expr;
    // Extract precedence
    var precedence = lhs.precedence;

    // While there are still '/' or '*' or '%' tokens
    while (self.match(.{ TokenKind.SLASH, TokenKind.STAR, TokenKind.PERCENT })) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const rhs = try self.conversion();

        // Make new inner expression, with operator
        const new_expr = self.allocator.create(Expr.ArithExpr) catch unreachable;

        // Check if reversed or not
        if (checkReversed(precedence, rhs.precedence)) {
            // Rhs is bigger, swap lh and rh sides
            precedence = rhs.precedence;
            new_expr.* = Expr.ArithExpr.init(rhs.expr, expr, operator, true);
        } else {
            // Lhs is bigger, do not swap
            new_expr.* = Expr.ArithExpr.init(expr, rhs.expr, operator, false);
        }
        // Update expr
        expr = ExprNode.init(ExprUnion{ .ARITH = new_expr });
        // Update precedence
        precedence = newPrecedence(precedence);
    }
    // Wrap and return
    return ExprResult.init(expr, precedence);
}

/// Parse a type conversion
/// Sub type of unary
/// conversion -> ('<' type '>')* unary
fn conversion(self: *Parser) SyntaxError!ExprResult {
    const result = try self.unary();
    var expr = result.expr;

    while (self.match(.{TokenKind.AS})) {
        const op = self.previous;
        const kind = try self.parseKind();

        // Make new inner expression, with operator
        const new_expr = self.allocator.create(Expr.ConversionExpr) catch unreachable;
        new_expr.* = Expr.ConversionExpr.init(op, expr);
        expr = ExprNode{
            .expr = ExprUnion{ .CONVERSION = new_expr },
            .result_kind = kind,
        };
    }

    // Wrap in ExprResult
    return ExprResult.init(expr, result.precedence);
}

/// Parse a unary expression
/// unary -> ("-"|"!"|"&") (unary | literal)
fn unary(self: *Parser) SyntaxError!ExprResult {
    // Recurse until no more '-' or '!' or '&'
    if (self.match(.{ TokenKind.MINUS, TokenKind.EXCLAMATION, TokenKind.AMPERSAND })) {
        // Get operator
        const operator = self.previous;
        // Parse rhs
        const operand = try self.unary();

        // Make new inner expression, with operator
        const new_expr = self.allocator.create(Expr.UnaryExpr) catch unreachable;
        new_expr.* = Expr.UnaryExpr.init(operand.expr, operator);
        const node = ExprNode.init(ExprUnion{ .UNARY = new_expr });
        // Wrap in ExprResult
        return ExprResult.init(node, operand.precedence);
    }

    // Fall through to Access/call/index
    return self.access();
}

/// Parse a dereference or struct access expression
/// dotExpr -> idExpr '.' (identifier | '*')
fn address(self: *Parser, expr: ExprNode, operator: Token) SyntaxError!ExprNode {
    // Check if Field or Dereference
    if (self.match(.{TokenKind.STAR})) {
        const new_expr = self.allocator.create(Expr.DereferenceExpr) catch unreachable;
        new_expr.* = Expr.DereferenceExpr.init(expr, operator);
        const node = ExprNode.init(ExprUnion{ .DEREFERENCE = new_expr });
        return node;
    }
    // Field access
    try self.consume(TokenKind.IDENTIFIER, "Expected a struct field name");
    const field_name = self.previous;

    const new_expr = self.allocator.create(Expr.FieldExpr) catch unreachable;
    new_expr.* = Expr.FieldExpr.init(expr, field_name, operator);
    const node = ExprNode.init(ExprUnion{ .FIELD = new_expr });
    return node;
}

/// Helper function to "access"
/// Parse a user function call expression
/// call -> identifier '(' expression (',' expression)* ')'
fn call(self: *Parser, expr: ExprNode, operator: Token, precedence: *isize) SyntaxError!ExprNode {
    // Make call args list
    var arg_list = std.ArrayList(ExprNode).init(self.allocator);

    // Check if next token is ')'
    if (!self.match(.{TokenKind.RIGHT_PAREN})) {
        // Parse first arg
        const first_arg_result = try self.expression();
        const first_arg = first_arg_result.expr;
        // Add to list
        arg_list.append(first_arg) catch unreachable;

        // Until ')' or end of file
        while (!self.match(.{TokenKind.RIGHT_PAREN}) or self.isAtEnd()) {
            // Consume ','
            try self.consume(TokenKind.COMMA, "Expected ',' after function call argument");
            // Parse first arg
            const arg_result = try self.expression();
            const arg = arg_result.expr;
            // Add to list
            arg_list.append(arg) catch unreachable;
        }

        // Check if at end
        if (self.isAtEnd()) {
            return self.errorAt("Unclosed function call argument list");
        }
    }
    // Set precedence to -1
    precedence.* = -1;
    // Make new expression
    const new_expr = self.allocator.create(Expr.CallExpr) catch unreachable;
    // Make new call expression
    new_expr.* = Expr.CallExpr.init(expr, operator, arg_list.items);
    const node = ExprNode.init(ExprUnion{ .CALL = new_expr });
    return node;
}

/// Helper function to "access"
/// Parse a index expression
/// index -> "[" U(INT) "]"
fn index(self: *Parser, expr: ExprNode, operator: Token, precedence: *isize) SyntaxError!ExprNode {
    // Parse number in square brackets
    const rhs = try self.expression();

    // Consume "]"
    try self.consume(TokenKind.RIGHT_SQUARE, "Expected ']' after index expression");

    // Create a new IndexExpr
    const new_expr = self.allocator.create(Expr.IndexExpr) catch unreachable;

    // Check if precedence needs to be updated
    if (checkReversed(precedence.*, rhs.precedence)) {
        precedence.* = rhs.precedence;
        // And swap IndexExpr
        new_expr.* = Expr.IndexExpr.init(rhs.expr, expr, operator, true);
    } else {
        new_expr.* = Expr.IndexExpr.init(expr, rhs.expr, operator, false);
    }

    const node = ExprNode.init(ExprUnion{ .INDEX = new_expr });
    return node;
}

/// Parse an access expression
/// Access -> literal (index | call)*
/// index -> "[" U(INT) "]"
/// call -> "(" (expr ("," expr)*)? ")"
fn access(self: *Parser) SyntaxError!ExprResult {
    // Evaluate lhs
    const lhs = try self.literal();
    // Extract expr
    var expr = lhs.expr;
    // Extract precedence
    var precedence = lhs.precedence;

    // While there are "(" or "["
    while (self.match(.{ TokenKind.LEFT_PAREN, TokenKind.LEFT_SQUARE, TokenKind.DOT })) {
        // Get "operator"
        const operator = self.previous;

        // Parse rhs based on operator kind
        // Make new expr node and store it in expr
        expr = switch (operator.kind) {
            .LEFT_PAREN => try self.call(expr, operator, &precedence),
            .LEFT_SQUARE => try self.index(expr, operator, &precedence),
            .DOT => try self.address(expr, operator),
            else => unreachable,
        };
    }
    // Wrap result
    return ExprResult.init(expr, precedence);
}

/// Parse a literal value
/// ("(" expr ")") | constant | identifier | native "(" arguments? ")"
fn literal(self: *Parser) SyntaxError!ExprResult {
    // Check if this is a grouping
    if (self.match(.{TokenKind.LEFT_PAREN})) {
        // Parse new sub expression
        const expr = try self.expression();

        // Consume ')'
        try self.consume(TokenKind.RIGHT_PAREN, "Unclosed parenthesis");
        return expr;
    }

    // Store current token and advance
    const token = self.advance();
    switch (token.kind) {
        .IDENTIFIER, .SUPER => return self.idExpr(token),
        .NULLPTR => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make new value
            const value = Value.newNullPtr();
            constant_expr.* = .{ .value = value, .literal = token };
            const expr = ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
            // Wrap in ExprResult
            return ExprResult.init(expr, 0);
        },
        .FALSE => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make new value
            const value = Value.newBool(false);
            constant_expr.* = .{ .value = value, .literal = token };
            const expr = ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
            // Wrap in ExprResult
            return ExprResult.init(expr, 0);
        },
        .TRUE => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make new value
            const value = Value.newBool(true);
            constant_expr.* = .{ .value = value, .literal = token };
            const expr = ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
            // Wrap in ExprResult
            return ExprResult.init(expr, 0);
        },
        .INTEGER => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;

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
                const node = ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
                // Wrap in ExprResult
                return ExprResult.init(node, 0);
            };

            // Make new value
            const value = Value.newInt(parsed_int, 64);
            constant_expr.* = .{ .value = value, .literal = token };
            const node = ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
            // Wrap in ExprResult
            return ExprResult.init(node, 0);
        },
        .FLOAT => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Parse lexeme
            const parsed_float = std.fmt.parseFloat(f64, token.lexeme) catch unreachable;

            if (parsed_float == std.math.inf(f64)) return self.reportError(token, "Floating point value to large to parse");

            // Make new value
            const value = Value.newFloat64(parsed_float);
            constant_expr.* = .{ .value = value, .literal = token };
            const node = ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
            // Wrap in ExprResult
            return ExprResult.init(node, 0);
        },
        .CHARACTER => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Parse lexeme
            const char = token.lexeme[1];
            // Make new value
            const value = Value.newUInt(char, 8);
            constant_expr.* = .{ .value = value, .literal = token };
            const node = ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
            // Wrap in ExprResult
            return ExprResult.init(node, 0);
        },
        .STRING => {
            // Make new constant expression
            const constant_expr = self.allocator.create(Expr.LiteralExpr) catch unreachable;
            // Make a new value without quotes

            // Make new value without quotes
            const value = Value.newStr(token.lexeme[1 .. token.lexeme.len - 1]);
            constant_expr.* = .{ .value = value, .literal = token };
            const node = ExprNode.init(ExprUnion{ .LITERAL = constant_expr });
            // Wrap in ExprResult
            return ExprResult.init(node, 0);
        },
        .ARRAY_TYPE => {
            // ****************************************************** //
            // FOR NOW THROWS AN ERROR
            return self.errorAt("Do not use arrays yet please thanks");
        },
        .SCOPE => {
            // Make fake target scope for global
            const global_token = Token{ .column = token.column, .lexeme = "", .kind = .IDENTIFIER, .line = token.line };
            const global_id_expr = self.allocator.create(Expr.IdentifierExpr) catch unreachable;
            global_id_expr.* = Expr.IdentifierExpr{ .id = global_token, .lexical_scope = undefined };
            const global_scope = ExprNode.init(.{ .IDENTIFIER = global_id_expr });

            return self.scopeExpr(global_scope, token);
        },
        .NATIVE => {
            // Consume the '('
            try self.consume(TokenKind.LEFT_PAREN, "Expected '(' after native function");
            // Create arg list
            var arg_list = std.ArrayList(ExprNode).init(self.allocator);

            // Check if next if next is ')'
            if (!self.check(TokenKind.RIGHT_PAREN)) {
                const first_arg = try self.expression();
                arg_list.append(first_arg.expr) catch unreachable;
                // Parse until no more commas
                while (self.match(.{TokenKind.COMMA})) {
                    const next_arg = try self.expression();
                    arg_list.append(next_arg.expr) catch unreachable;
                }
            }
            // Consume ')'
            try self.consume(TokenKind.RIGHT_PAREN, "Expected ')' after arg list");

            // Make new nativeExpr
            const native_expr = self.allocator.create(Expr.NativeExpr) catch unreachable;
            native_expr.name = token;
            // "borrow" arg_list's items
            native_expr.args = arg_list.items;

            const node = ExprNode.init(ExprUnion{ .NATIVE = native_expr });
            // Wrap in ExprResult
            return ExprResult.init(node, -1);
        },
        .PIPE => return try self.lambdaExpr(),
        .EOF => return self.errorAtCurrent("Expected an expression but found end of file"),
        else => return self.errorAt("Expected an expression"),
    }
}

fn idExpr(self: *Parser, id_token: Token) SyntaxError!ExprResult {
    const maybe_generic_data = try self.maybe_parse_generic_kinds();
    const new_id_expr = if (maybe_generic_data) |generic_data| blk: {
        const new_gen_expr = self.allocator.create(Expr.GenericExpr) catch unreachable;
        new_gen_expr.* = .{ .kinds = generic_data.names, .op = generic_data.op, .operand = id_token };
        break :blk ExprNode.init(ExprUnion{ .GENERIC = new_gen_expr });
    } else blk: {
        const identifier_expr = self.allocator.create(Expr.IdentifierExpr) catch unreachable;
        identifier_expr.* = .{ .id = id_token, .lexical_scope = undefined };
        break :blk ExprNode.init(ExprUnion{ .IDENTIFIER = identifier_expr });
    };

    if (self.match(.{TokenKind.SCOPE})) {
        const first_scope_op = self.previous;
        return self.scopeExpr(new_id_expr, first_scope_op);
    }
    return ExprResult.init(new_id_expr, 0);
}

fn scopeExpr(self: *Parser, scope: ExprNode, scope_op: Token) SyntaxError!ExprResult {
    if (!self.match(.{ TokenKind.IDENTIFIER, TokenKind.SUPER })) {
        return self.errorAt("Expected identifier or super after scope operator");
    }
    const id_token = self.previous;
    const operand = try self.idExpr(id_token);
    const expr = self.allocator.create(Expr.ScopeExpr) catch unreachable;
    expr.* = Expr.ScopeExpr.init(scope, scope_op, operand.expr);
    const scope_node = ExprNode.init(ExprUnion{ .SCOPE = expr });
    return ExprResult.init(scope_node, 0);
}

fn lambdaExpr(self: *Parser) SyntaxError!ExprResult {
    const op = self.previous;

    const arg_list_result = try self.parseArgList(TokenKind.PIPE);
    // Check previous was paren
    if (self.previous.kind != .PIPE) {
        return self.errorAt("Expected ')' after function argument list");
    }

    try self.consume(TokenKind.RETURN_ARROW, "Expected '->' after lamba arg list");

    const ret_kind = try self.parseKind();

    // If body is just an expression, turn it into a return stmt
    const body = if (!self.match(.{TokenKind.LEFT_BRACE})) blk: {
        const expr_result = try self.expression();
        const expr = expr_result.expr;

        const new_return_stmt = self.allocator.create(Stmt.ReturnStmt) catch unreachable;
        new_return_stmt.* = Stmt.ReturnStmt.init(op, expr);
        break :blk StmtNode{ .RETURN = new_return_stmt };
    } else try self.blockStmt();

    const lambda_expr = self.allocator.create(Expr.LambdaExpr) catch unreachable;
    lambda_expr.* = Expr.LambdaExpr.init(op, arg_list_result.arg_names, arg_list_result.arg_kinds, ret_kind, body);
    const new_node = ExprNode.init(.{ .LAMBDA = lambda_expr });

    return ExprResult.init(new_node, 0);
}
