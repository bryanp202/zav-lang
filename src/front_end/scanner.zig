const std = @import("std");

pub const Scanner = struct {
    source: []const u8,
    start: u64,
    current: u64,
    line: u64,
    column: u64,
    column_start: u64,
    // Lexeme Table
    lexeme_table: std.StringHashMap([]u8),

    /// Initializer
    pub fn init(allocator: std.mem.Allocator, source: []const u8) Scanner {
        return Scanner{
            .source = source,
            .start = 0,
            .current = 0,
            .line = 1,
            .column = 1,
            .column_start = 1,
            .lexeme_table = std.StringHashMap([]u8).init(allocator),
        };
    }

    pub fn reset(self: *Scanner, source: []const u8) void {
        self.column = 0;
        self.line = 0;
        self.column_start = 0;
        self.start = 0;
        self.current = 0;
        self.source = source;
    }

    /// Scan next token and return it
    pub fn nextToken(self: *Scanner) Token {
        // Skip past whitespace
        self.skipWhiteSpace();
        // Update pos markers
        self.start = self.current;
        self.column_start = self.column;

        // Check if at end of file
        if (self.isAtEnd()) {
            return self.emitToken(TokenKind.EOF);
        }

        // Check if numeric
        if (isDigit(self.peek())) {
            return self.number();
        }
        // Check if alpha
        if (isAlpha(self.peek())) {
            return self.identifier();
        }

        // Advance
        const c = self.advance();

        // Determine what symbol it is
        switch (c) {
            // Single char tokens
            ';' => return self.emitToken(TokenKind.SEMICOLON),
            ',' => return self.emitToken(TokenKind.COMMA),
            '.' => return self.emitToken(TokenKind.DOT),
            '(' => return self.emitToken(TokenKind.LEFT_PAREN),
            ')' => return self.emitToken(TokenKind.RIGHT_PAREN),
            '{' => return self.emitToken(TokenKind.LEFT_BRACE),
            '}' => return self.emitToken(TokenKind.RIGHT_BRACE),
            ']' => return self.emitToken(TokenKind.RIGHT_SQUARE),
            '?' => return self.emitToken(TokenKind.QUESTION_MARK),
            // Native Func literal
            '@' => return self.native(),
            // Char literal
            '\'' => return self.character(),
            // String literal
            '\"' => return self.string(),

            // Single or double
            // Arithmatic and Assignment
            '+' => {
                const kind = if (self.match('=')) TokenKind.PLUS_EQUAL else TokenKind.PLUS;
                return self.emitToken(kind);
            },
            '-' => {
                const kind = if (self.match('=')) TokenKind.MINUS_EQUAL else TokenKind.MINUS;
                return self.emitToken(kind);
            },
            '*' => {
                const kind = if (self.match('=')) TokenKind.STAR_EQUAL else TokenKind.STAR;
                return self.emitToken(kind);
            },
            '/' => {
                const kind = if (self.match('=')) TokenKind.SLASH_EQUAL else TokenKind.SLASH;
                return self.emitToken(kind);
            },
            '%' => {
                const kind = if (self.match('=')) TokenKind.PERCENT_EQUAL else TokenKind.PERCENT;
                return self.emitToken(kind);
            },
            // Bitwise and Assignment
            '^' => {
                const kind = if (self.match('=')) TokenKind.CARET_EQUAL else TokenKind.CARET;
                return self.emitToken(kind);
            },
            '|' => {
                const kind = if (self.match('=')) TokenKind.PIPE_EQUAL else TokenKind.PIPE;
                return self.emitToken(kind);
            },
            '&' => {
                const kind = if (self.match('=')) TokenKind.AMPERSAND_EQUAL else TokenKind.AMPERSAND;
                return self.emitToken(kind);
            },
            '!' => {
                const kind = if (self.match('=')) TokenKind.EXCLAMATION_EQUAL else TokenKind.EXCLAMATION;
                return self.emitToken(kind);
            },
            // Logical Operations and Assignment
            '<' => {
                const kind = if (self.match('=')) TokenKind.LESS_EQUAL else TokenKind.LESS;
                return self.emitToken(kind);
            },
            '>' => {
                const kind = if (self.match('=')) TokenKind.GREATER_EQUAL else TokenKind.GREATER;
                return self.emitToken(kind);
            },
            '=' => {
                const kind = if (self.match('=')) TokenKind.EQUAL_EQUAL else TokenKind.EQUAL;
                return self.emitToken(kind);
            },
            // Indexing and Array type
            '[' => {
                const kind = if (self.match(']')) TokenKind.ARRAY_TYPE else TokenKind.LEFT_SQUARE;
                return self.emitToken(kind);
            },
            // Scopes or type declaration
            ':' => {
                const kind = if (self.match(':')) TokenKind.SCOPE else TokenKind.COLON;
                return self.emitToken(kind);
            },

            else => return self.emitError("Unexpected symbol"),
        }
    }

    //// Helper Methods ////
    /// Generate a token from a lexeme and TokenKind
    fn generateToken(self: *Scanner, kind: TokenKind, lexeme: []const u8) Token {
        // Look up lexeme
        const value = self.lexeme_table.getOrPut(lexeme) catch unreachable;
        if (value.found_existing) {
            return Token{
                .kind = kind,
                .lexeme = value.key_ptr.*,
                .line = self.line,
                .column = self.column_start,
            };
        }
        return Token{
            .kind = kind,
            .lexeme = lexeme,
            .line = self.line,
            .column = self.column_start,
        };
    }

    /// Emit a token of a specified type based on start and current counters
    fn emitToken(self: *Scanner, kind: TokenKind) Token {
        const lexeme = self.source[self.start..self.current];
        return self.generateToken(kind, lexeme);
    }

    /// Emit an error token with a message
    fn emitError(self: *Scanner, msg: []const u8) Token {
        return self.generateToken(TokenKind.ERROR, msg);
    }

    /// Check if at end of file
    fn isAtEnd(self: Scanner) bool {
        return self.source[self.current] == '\x00';
    }

    /// Get next character and return it
    fn advance(self: *Scanner) u8 {
        self.current += 1;
        self.column += 1;
        return self.source[self.current - 1];
    }

    /// Look forward one char
    fn peek(self: Scanner) u8 {
        return self.source[self.current];
    }

    /// Look forward two chars
    fn peekNext(self: Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current + 1];
    }

    /// Check if next char matches an expected char and advance if it does
    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.peek() != expected) return false;
        self.current += 1;
        return true;
    }

    /// Return true if char is [0-9]
    fn isDigit(char: u8) bool {
        return char >= '0' and char <= '9';
    }

    /// Return true if char is [a-z]|[A-Z]|_
    fn isAlpha(char: u8) bool {
        return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or char == '_';
    }

    /// Return true if [a-z]|[A-Z]|_|[0-9]
    fn isAlphaNumeric(char: u8) bool {
        return isAlpha(char) or isDigit(char);
    }

    /// Skip past all comments, spaces, newlines, and tabs
    fn skipWhiteSpace(self: *Scanner) void {
        // Loop until no more white space is found
        while (true) {
            switch (self.peek()) {
                ' ', '\r', '\t' => _ = self.advance(),
                // Keep track of new lines
                '\n' => {
                    _ = self.advance();
                    self.column = 1;
                    self.line += 1;
                },

                // Check for comments //
                '/' => {
                    // Check for multi-line comment
                    switch (self.peekNext()) {
                        '*' => {
                            // Consume '/'
                            _ = self.advance();
                            // Consume '*'
                            _ = self.advance();
                            // Go until '*/'
                            while (!self.isAtEnd() and self.peek() != '*' or self.peekNext() != '/') {
                                // Check for new lines
                                const maybeNewLine = self.advance();
                                if (maybeNewLine == '\n') self.line += 1;
                            }
                            // Check if at end
                            if (!self.isAtEnd()) {
                                // Consume '*/'
                                _ = self.advance();
                                _ = self.advance();
                            }
                        },
                        '/' => {
                            // Single line comment
                            while (!self.isAtEnd() and self.peek() != '\n') {
                                _ = self.advance();
                            }
                        },
                        // Not a comment
                        else => break,
                    }
                },
                // Not whitespace
                else => break,
            }
        }
    }

    /// Scan a number literal
    fn number(self: *Scanner) Token {
        // Run until end of predecimal point
        while (isDigit(self.peek())) {
            _ = self.advance();
        }

        // Check if decimal point and is float
        if (self.peek() == '.') {
            // Consume '.'
            _ = self.advance();
            while (isDigit(self.peek())) {
                _ = self.advance();
            }
            return self.emitToken(TokenKind.FLOAT);
        }
        // Else return integer
        return self.emitToken(TokenKind.INTEGER);
    }

    /// Scan a char literal
    fn character(self: *Scanner) Token {
        _ = self.advance();
        // Check for closing \'
        if (self.peek() != '\'') {
            return self.emitError("Expected closing single quote after character");
        }
        _ = self.advance();

        return self.emitToken(TokenKind.CHARACTER);
    }

    /// Scan a string literal
    fn string(self: *Scanner) Token {
        var current: u8 = 0;
        // Continue until end of file or closing '"' (ignores \") or new line
        while ((self.peek() != '\"' or current == '\\') and self.peek() != '\n' and !self.isAtEnd()) {
            current = self.advance();
        }
        // Check if string was not closed
        if (self.isAtEnd() or self.peek() == '\n') {
            return self.emitError("Unclosed string");
        }
        // Consume '"'
        _ = self.advance();
        return self.emitToken(TokenKind.STRING);
    }

    /// Scan a native function call literal
    fn native(self: *Scanner) Token {
        // Check if there is a func name
        if (!isAlphaNumeric(self.peek())) {
            return self.emitError("Must provide a native function name");
        }
        // Consume all alphanumeric characters
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }
        return self.emitToken(TokenKind.NATIVE);
    }

    /// Return a Token for a variable name, follows pattern ([a-z]|[A-Z]|_)([a-z]|[A-Z]|_|[0-9])*
    fn varIdentifier(self: *Scanner) Token {
        // Consume all alphanumeric characters
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }
        return self.emitToken(TokenKind.IDENTIFIER);
    }

    /// Check if a keyword has been found
    fn checkKeyword(self: *Scanner, remainder: []const u8, kind: TokenKind) Token {
        if ((self.source.len > self.current + remainder.len) and (!isAlphaNumeric(self.source[self.current + remainder.len])) and (std.mem.eql(u8, self.source[self.current .. self.current + remainder.len], remainder))) {
            // Increment current char position
            self.current += remainder.len;
            // Increment column
            self.column += remainder.len;
            return self.emitToken(kind);
        }
        return self.varIdentifier();
    }

    /// Scan an identifier or keyword
    fn identifier(self: *Scanner) Token {
        identifier_loop: {
            switch (self.peek()) {
                'a' => {
                    _ = self.advance();
                    switch (self.peek()) {
                        'n' => {
                            _ = self.advance();
                            return self.checkKeyword("d", TokenKind.AND);
                        },
                        's' => {
                            _ = self.advance();
                            return self.checkKeyword("", TokenKind.AS);
                        },
                        else => break :identifier_loop,
                    }
                },
                'b' => {
                    _ = self.advance();
                    switch (self.peek()) {
                        'o' => {
                            _ = self.advance();
                            return self.checkKeyword("ol", TokenKind.BOOL_TYPE);
                        },
                        'r' => {
                            _ = self.advance();
                            return self.checkKeyword("eak", TokenKind.BREAK);
                        },
                        else => break :identifier_loop,
                    }
                },
                'c' => {
                    _ = self.advance();
                    switch (self.peek()) {
                        'o' => {
                            _ = self.advance();
                            switch (self.peek()) {
                                'n' => {
                                    _ = self.advance();
                                    switch (self.peek()) {
                                        's' => {
                                            _ = self.advance();
                                            return self.checkKeyword("t", TokenKind.CONST);
                                        },
                                        't' => {
                                            _ = self.advance();
                                            return self.checkKeyword("inue", TokenKind.CONTINUE);
                                        },
                                        else => break :identifier_loop,
                                    }
                                },
                                else => break :identifier_loop,
                            }
                        },
                        else => break :identifier_loop,
                    }
                },
                'd' => {
                    _ = self.advance();
                    return self.checkKeyword("o", TokenKind.DO);
                },
                'e' => {
                    _ = self.advance();
                    switch (self.peek()) {
                        'l' => {
                            _ = self.advance();
                            return self.checkKeyword("se", TokenKind.ELSE);
                        },
                        'n' => {
                            _ = self.advance();
                            return self.checkKeyword("um", TokenKind.ENUM);
                        },
                        else => break :identifier_loop,
                    }
                },
                'f' => {
                    _ = self.advance();
                    switch (self.peek()) {
                        '1' => {
                            _ = self.advance();
                            return self.checkKeyword("28", TokenKind.F128_TYPE);
                        },
                        '3' => {
                            _ = self.advance();
                            return self.checkKeyword("2", TokenKind.F32_TYPE);
                        },
                        '6' => {
                            _ = self.advance();
                            return self.checkKeyword("4", TokenKind.F64_TYPE);
                        },
                        'a' => {
                            _ = self.advance();
                            return self.checkKeyword("lse", TokenKind.FALSE);
                        },
                        'n' => {
                            _ = self.advance();
                            return self.checkKeyword("", TokenKind.FN);
                        },
                        'o' => {
                            _ = self.advance();
                            return self.checkKeyword("r", TokenKind.FOR);
                        },
                        else => break :identifier_loop,
                    }
                },
                'i' => {
                    _ = self.advance();
                    switch (self.peek()) {
                        '1' => {
                            _ = self.advance();
                            switch (self.peek()) {
                                '2' => {
                                    _ = self.advance();
                                    return self.checkKeyword("8", TokenKind.I128_TYPE);
                                },
                                '6' => {
                                    _ = self.advance();
                                    return self.checkKeyword("", TokenKind.I16_TYPE);
                                },
                                else => break :identifier_loop,
                            }
                        },
                        '3' => {
                            _ = self.advance();
                            return self.checkKeyword("2", TokenKind.I32_TYPE);
                        },
                        '6' => {
                            _ = self.advance();
                            return self.checkKeyword("4", TokenKind.I64_TYPE);
                        },
                        '8' => {
                            _ = self.advance();
                            return self.checkKeyword("", TokenKind.I8_TYPE);
                        },
                        'f' => {
                            _ = self.advance();
                            return self.checkKeyword("", TokenKind.IF);
                        },
                        else => break :identifier_loop,
                    }
                },
                'l' => {
                    _ = self.advance();
                    return self.checkKeyword("oop", TokenKind.LOOP);
                },
                'm' => {
                    _ = self.advance();
                    return self.checkKeyword("od", TokenKind.MOD);
                },
                'n' => {
                    _ = self.advance();
                    return self.checkKeyword("ullptr", TokenKind.NULLPTR);
                },
                'o' => {
                    _ = self.advance();
                    return self.checkKeyword("r", TokenKind.OR);
                },
                'p' => {
                    _ = self.advance();
                    return self.checkKeyword("ub", TokenKind.PUB);
                },
                'r' => {
                    _ = self.advance();
                    return self.checkKeyword("eturn", TokenKind.RETURN);
                },
                's' => {
                    _ = self.advance();
                    switch (self.peek()) {
                        't' => {
                            _ = self.advance();
                            return self.checkKeyword("ruct", TokenKind.STRUCT);
                        },
                        'w' => {
                            _ = self.advance();
                            return self.checkKeyword("itch", TokenKind.SWITCH);
                        },
                        else => break :identifier_loop,
                    }
                },
                't' => {
                    _ = self.advance();
                    return self.checkKeyword("rue", TokenKind.TRUE);
                },
                'u' => {
                    _ = self.advance();
                    switch (self.peek()) {
                        '1' => {
                            _ = self.advance();
                            switch (self.peek()) {
                                '2' => {
                                    _ = self.advance();
                                    return self.checkKeyword("8", TokenKind.U128_TYPE);
                                },
                                '6' => {
                                    _ = self.advance();
                                    return self.checkKeyword("", TokenKind.U16_TYPE);
                                },
                                else => break :identifier_loop,
                            }
                        },
                        '3' => {
                            _ = self.advance();
                            return self.checkKeyword("2", TokenKind.U32_TYPE);
                        },
                        '6' => {
                            _ = self.advance();
                            return self.checkKeyword("4", TokenKind.U64_TYPE);
                        },
                        '8' => {
                            _ = self.advance();
                            return self.checkKeyword("", TokenKind.U8_TYPE);
                        },
                        'n' => {
                            _ = self.advance();
                            return self.checkKeyword("defined", TokenKind.UNDEFINED);
                        },
                        's' => {
                            _ = self.advance();
                            return self.checkKeyword("e", TokenKind.USE);
                        },
                        else => break :identifier_loop,
                    }
                },
                'v' => {
                    _ = self.advance();
                    switch (self.peek()) {
                        'a' => {
                            _ = self.advance();
                            return self.checkKeyword("r", TokenKind.VAR);
                        },
                        'o' => {
                            _ = self.advance();
                            return self.checkKeyword("id", TokenKind.VOID_TYPE);
                        },
                        else => break :identifier_loop,
                    }
                },
                'w' => {
                    _ = self.advance();
                    return self.checkKeyword("hile", TokenKind.WHILE);
                },
                else => break :identifier_loop,
            }
        }
        return self.varIdentifier();
    }
};

pub const TokenKind = enum {
    //// Single char ////
    DOT,
    SEMICOLON,
    COMMA,
    QUESTION_MARK,
    LEFT_BRACE,
    RIGHT_BRACE,
    LEFT_PAREN,
    RIGHT_PAREN,

    //// Single or double char ////
    // Arithmatic and Assignment
    PLUS,
    MINUS,
    STAR,
    SLASH,
    PERCENT,
    PLUS_EQUAL,
    MINUS_EQUAL,
    STAR_EQUAL,
    SLASH_EQUAL,
    PERCENT_EQUAL,
    // Bitwise Operations and Assignment
    CARET,
    PIPE,
    AMPERSAND,
    EXCLAMATION,
    CARET_EQUAL,
    PIPE_EQUAL,
    AMPERSAND_EQUAL,
    EXCLAMATION_EQUAL,
    // Logical Operations and Assignment
    LESS,
    GREATER,
    EQUAL,
    LESS_EQUAL,
    GREATER_EQUAL,
    EQUAL_EQUAL,
    // Indexing
    LEFT_SQUARE,
    RIGHT_SQUARE,
    // Array
    ARRAY_TYPE,
    COLON,
    SCOPE,

    //// Literals ////
    INTEGER,
    FLOAT,
    CHARACTER,
    STRING,
    IDENTIFIER,
    NATIVE,

    //// Types ////
    // Signed Int
    I8_TYPE,
    I16_TYPE,
    I32_TYPE,
    I64_TYPE,
    I128_TYPE,
    // Unsigned int
    U8_TYPE,
    U16_TYPE,
    U32_TYPE,
    U64_TYPE,
    U128_TYPE,
    // Floating point
    F32_TYPE,
    F64_TYPE,
    F128_TYPE,
    // Boolean
    BOOL_TYPE,
    VOID_TYPE,

    //// Keywords ////
    AND,
    BREAK,
    CONST,
    VAR,
    CONTINUE,
    STRUCT,
    ENUM,
    SWITCH,
    DO,
    IF,
    WHILE,
    FOR,
    TRUE,
    FALSE,
    ELSE,
    OR,
    RETURN,
    LOOP,
    FN,
    UNDEFINED,
    NULLPTR,
    PUB,
    MOD,
    USE,
    AS,

    //// Parser Tokens ////
    ERROR,
    EOF,
};

pub const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
    line: u64,
    column: u64,
};
