const std = @import("std");
// Imports
// Tokens and TokenKind
const Scan = @import("../front_end/scanner.zig");
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
const GenerationError = Error.GenerationError;
// Expr
const Expr = @import("../expr.zig");
const ExprNode = Expr.ExprNode;

// Writer Type stuff
const info = @typeInfo(@TypeOf(std.fs.File.writer));
const WriterType = info.Fn.return_type orelse void;

// Useful Constants
const DWORD_IMIN: i64 = -0x80000000;
const DWORD_IMAX: i64 = 0x7FFFFFFF;
const DWORD_UMAX: u64 = 0xFFFFFFFF;

/// Used to turn an AST into assembly
const Generator = @This();
// Fields
file: std.fs.File,
writer: *WriterType,
stm: *STM,

// Label counters
/// Used in the generation of if statement labels
label_count: u64,

pub fn init(allocator: std.mem.Allocator, stm: *STM, path: []const u8) !Generator {
    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    const writer_ptr = allocator.create(WriterType) catch unreachable;
    const writer = file.writer();
    // Set up file header
    const header =
        \\default rel
        \\extern printf
        \\global main
        \\section .text
        \\main:
        \\    push rbp
        \\    mov rbp, rsp
        \\
        \\    ; Calculate Expr
        \\
    ;
    try writer.writeAll(header);

    // Make Generator
    writer_ptr.* = writer;
    return .{
        .file = file,
        .writer = writer_ptr,
        .stm = stm,
        .label_count = 0,
    };
}

pub fn deinit(self: Generator, allocator: std.mem.Allocator) void {
    // Write end of file
    self.write(
        \\    
        \\    ; Quit
        \\    xor ecx, ecx
        \\    leave
        \\    ret
        \\
        \\;-------------------------;
        \\;         Natives         ;
        \\;-------------------------;
        \\
    ) catch unreachable;

    // Write native functions source
    var native_func = self.stm.natives_table.natives_table.iterator();
    // Go through each
    while (native_func.next()) |native| {
        if (native.value_ptr.used) {
            self.print("{s}", .{native.value_ptr.source}) catch unreachable;
        }
    }

    // Write .data section
    self.write(
        \\
        \\section .data
        \\    ; Native Constants ;
        \\    SS_SIGN_BIT: dq 0x80000000
        \\    SD_SIGN_BIT: dq 0x8000000000000000
        \\
    ) catch unreachable;
    // Write native data
    // Write native functions source
    native_func = self.stm.natives_table.natives_table.iterator();
    // Go through each
    while (native_func.next()) |native| {
        if (native.value_ptr.used) {
            if (native.value_ptr.data) |data| {
                self.print("{s}", .{data}) catch unreachable;
            }
        }
    }
    self.write("\n    ; Program Constants\n") catch unreachable;

    // Write the program defined data section
    var const_iter = self.stm.constants.iterator();
    while (const_iter.next()) |entry| {
        // Extract entry
        const constant = entry.value_ptr;
        const maybeName = constant.name;
        // See if it has been used, look for name
        if (maybeName) |name| {
            // Get the real value
            const real_value = constant.data;
            // Determine how to write to data section
            switch (real_value.kind) {
                .FLOAT => {
                    const float = real_value.as.float;
                    const kind: u8 = if (float.bits == 32) 'd' else 'q';
                    self.print("    {s}: d{c} {e}\n", .{ name, kind, float.data }) catch unreachable;
                },
                else => unreachable,
            }
        }
    }
    // Close file and deallocate writer
    self.file.close();
    allocator.destroy(self.writer);
}

pub fn gen(self: *Generator, start: ExprNode) GenerationError!void {
    try self.genExpr(start);
}

// Helper methods
inline fn write(self: Generator, msg: []const u8) GenerationError!void {
    _ = self.writer.*.write(msg) catch return GenerationError.FailedToWrite;
}
// Helper methods
inline fn print(self: Generator, fmt: []const u8, data: anytype) GenerationError!void {
    _ = self.writer.*.print(fmt, data) catch return GenerationError.FailedToWrite;
}

// ********************** //
// Expr anaylsis  methods //
// ********************** //

/// Generate asm for an ExprNode
fn genExpr(self: *Generator, node: ExprNode) GenerationError!void {
    // Get result kind
    const result_kind = node.result_kind;
    // Determine the type of expr and analysis it
    switch (node.expr) {
        .IDENTIFIER => |idExpr| try self.visitIdentifierExpr(idExpr),
        .LITERAL => |litExpr| try self.visitLiteralExpr(litExpr),
        .NATIVE => |nativeExpr| try self.visitNativeExpr(nativeExpr),
        .CONVERSION => |convExpr| try self.visitConvExpr(convExpr, result_kind),
        .UNARY => |unaryExpr| try self.visitUnaryExpr(unaryExpr),
        .ARITH => |arithExpr| try self.visitArithExpr(arithExpr),
        .COMPARE => |compareExpr| try self.visitCompareExpr(compareExpr),
        .AND => |andExpr| try self.visitAndExpr(andExpr),
        .OR => |orExpr| try self.visitOrExpr(orExpr),
        .IF => |ifExpr| try self.visitIfExpr(ifExpr),
        //else => unreachable,
    }
}

/// Generate asm for an IDExpr
fn visitIdentifierExpr(self: *Generator, idExpr: *Expr.IdentifierExpr) GenerationError!void {
    try self.print(
        \\    mov rax, [{s}]        ; Get Identifier
        \\    push rax
        \\
    , .{idExpr.id.lexeme});
}

/// Generate asm for a LiteralExpr
fn visitLiteralExpr(self: *Generator, litExpr: *Expr.LiteralExpr) GenerationError!void {
    // Determine Value kind
    switch (litExpr.value.kind) {
        .BOOL => {
            const lit_val: u16 = if (litExpr.value.as.boolean) 1 else 0;
            try self.print(
                \\    push {d}                ; Push Bool  
                \\
            , .{lit_val});
        },
        .UINT => {
            const lit_val = litExpr.value.as.uint.data;
            // Check if larger than 32bit
            if (lit_val > DWORD_UMAX) {
                try self.print(
                    \\    mov rax, {d}          ; Push Unsigned Integer
                    \\    push rax
                    \\
                , .{litExpr.value.as.uint.data});
            } else {
                try self.print(
                    \\    push {d}          ; Push Unsigned Integer
                    \\
                , .{litExpr.value.as.int.data});
            }
        },
        .INT => {
            const lit_val = litExpr.value.as.int.data;
            // Check if can fit in 32bit
            if (lit_val < DWORD_IMIN or lit_val > DWORD_IMAX) {
                try self.print(
                    \\    mov rax, {d}          ; Push Integer
                    \\    push rax
                    \\
                , .{litExpr.value.as.int.data});
            } else {
                try self.print(
                    \\    push {d}          ; Push Integer
                    \\
                , .{litExpr.value.as.int.data});
            }
        },
        .FLOAT => {
            const float_lit = litExpr.value.as.float;
            const lit_name = self.stm.getConstantId(litExpr.value);
            if (float_lit.bits == 32) {
                try self.print(
                    \\    push qword [{s}]       ; Push f32
                    \\
                , .{lit_name});
            } else if (float_lit.bits == 64) {
                try self.print(
                    \\    push qword [{s}]       ; Push f64
                    \\
                , .{lit_name});
            } else unreachable;
        },
        else => unreachable,
    }
}

/// Generate asm for a native expr call
fn visitNativeExpr(self: *Generator, nativeExpr: *Expr.NativeExpr) GenerationError!void {
    // Check for arguments
    if (nativeExpr.args) |args| {
        // Generate each arg
        for (args, 0..) |arg, count| {
            try self.genExpr(arg);
            // Put appropriate args registers
            switch (count) {
                0 => try self.write("    pop rcx\n"),
                1 => try self.write("    pop rdx\n"),
                2 => try self.write("    pop r8\n"),
                3 => try self.write("    pop r9\n"),
                else => continue,
            }
        }
    }

    // Generate the call
    try self.print("    call {s}\n    push rax\n", .{nativeExpr.name.lexeme});
}

/// Generate asm for type conversions
fn visitConvExpr(self: *Generator, convExpr: *Expr.ConversionExpr, result_kind: KindId) GenerationError!void {
    // Generate operand
    try self.genExpr(convExpr.operand);
    // Extrand operand type
    const operand_type = convExpr.operand.result_kind;
    // Generate self
    switch (result_kind) {
        // Converting to a float
        .FLOAT => |float_lit| switch (operand_type) {
            // Converting f32 to f64
            .FLOAT => {
                try self.write(
                    \\    pxor xmm0, xmm0       ; Converting f32 to f64
                    \\    pop r10
                    \\    cvtss2sd xmm0, r10
                    \\    movq r10, xmm0
                    \\    push r10
                    \\
                );
            },
            // Source was not a float
            else => {
                if (float_lit.bits == 32) {
                    try self.write(
                        \\    pxor xmm0, xmm0       ; Converting to f32
                        \\    pop r10
                        \\    cvtsi2ss xmm0, r10
                        \\    movq r10, xmm0
                        \\    push r10
                        \\
                    );
                } else if (float_lit.bits == 64) {
                    try self.write(
                        \\    pxor xmm0, xmm0       ; Converting to f64
                        \\    pop r10
                        \\    cvtsi2sd xmm0, r10
                        \\    movq r10, xmm0
                        \\    push r10
                        \\
                    );
                } else unreachable;
            },
        },
        else => unreachable,
    }
}

/// Generate asm for a UnaryExpr
fn visitUnaryExpr(self: *Generator, unaryExpr: *Expr.UnaryExpr) GenerationError!void {
    // Generate operand
    try self.genExpr(unaryExpr.operand);
    // Extract result_kind
    const result_kind = unaryExpr.operand.result_kind;

    // Generate self
    // Check if float or not
    switch (result_kind) {
        .FLOAT => |float_lit| switch (unaryExpr.op.kind) {
            TokenKind.MINUS => {
                if (float_lit.bits == 32) {
                    try self.write(
                        \\    mov r10, [SS_SIGN_BIT] ; Negating f32
                        \\    xor [rsp], r10
                        \\
                    );
                } else if (float_lit.bits == 64) {
                    try self.write(
                        \\    mov r10, [SD_SIGN_BIT] ; Negating f64
                        \\    xor [rsp], r10
                        \\
                    );
                } else unreachable;
            },
            else => unreachable,
        },
        else => switch (unaryExpr.op.kind) {
            TokenKind.EXCLAMATION => try self.write(
                \\    mov r10, 1            ; Bool Not
                \\    xor [rsp], r10
                \\
            ),
            TokenKind.MINUS => try self.write(
                \\    neg qword [rsp]       ; Integer Negate
                \\
            ),
            else => unreachable,
        },
    }
}

/// Generate asm for an ArithExpr
fn visitArithExpr(self: *Generator, arithExpr: *Expr.ArithExpr) GenerationError!void {
    // Generate lhs
    try self.genExpr(arithExpr.lhs);
    // Generate rhs
    try self.genExpr(arithExpr.rhs);
    // Extract result kind
    const result_kind = arithExpr.lhs.result_kind;

    // Gen self
    // Check kind
    switch (result_kind) {
        .FLOAT => |float_lit| {
            const addType: u8 = if (float_lit.bits == 64) 'd' else 's';
            switch (arithExpr.op.kind) {
                TokenKind.PLUS => {
                    try self.print(
                        \\    pop r11               ; Float Add
                        \\    movq xmm1, r11
                        \\    pop r10
                        \\    movq xmm0, r10
                        \\    adds{c} xmm0, xmm1
                        \\    movq r10, xmm0
                        \\    push r10
                        \\
                    , .{addType});
                },
                TokenKind.MINUS => {
                    try self.print(
                        \\    pop r11               ; Float Sub
                        \\    movq xmm1, r11
                        \\    pop r10
                        \\    movq xmm0, r10
                        \\    subs{c} xmm0, xmm1
                        \\    movq r10, xmm0
                        \\    push r10
                        \\
                    , .{addType});
                },
                TokenKind.STAR => {
                    try self.print(
                        \\    pop r11               ; Float Mult
                        \\    movq xmm1, r11
                        \\    pop r10
                        \\    movq xmm0, r10
                        \\    muls{c} xmm0, xmm1
                        \\    movq r10, xmm0
                        \\    push r10
                        \\
                    , .{addType});
                },
                TokenKind.SLASH => {
                    try self.print(
                        \\    pop r11               ; Float Div
                        \\    movq xmm1, r11
                        \\    pop r10
                        \\    movq xmm0, r10
                        \\    divs{c} xmm0, xmm1
                        \\    movq r10, xmm0
                        \\    push r10
                        \\
                    , .{addType});
                },
                else => unreachable,
            }
        },
        else => switch (arithExpr.op.kind) {
            TokenKind.PLUS => try self.write(
                \\    pop r11               ; Integer Add
                \\    pop r10
                \\    add r10, r11
                \\    push r10
                \\
            ),
            TokenKind.MINUS => try self.write(
                \\    pop r11               ; Integer Sub
                \\    pop r10
                \\    sub r10, r11
                \\    push r10
                \\
            ),
            TokenKind.STAR => try self.write(
                \\    pop r11               ; Integer Mult
                \\    pop r10
                \\    imul r10, r11
                \\    push r10
                \\
            ),
            TokenKind.SLASH => try self.write(
                \\    pop r10               ; Integer Div
                \\    pop rax
                \\    xor rdx, rdx
                \\    idiv r10
                \\    push rax
                \\
            ),
            TokenKind.PERCENT => try self.write(
                \\    pop r10               ; Integer Mod
                \\    pop rax
                \\    xor rdx, rdx
                \\    idiv r10
                \\    push rdx
                \\
            ),
            else => unreachable,
        },
    }
}

/// Generate asm for a compare expr
fn visitCompareExpr(self: *Generator, compareExpr: *Expr.CompareExpr) GenerationError!void {
    // Generate lhs
    try self.genExpr(compareExpr.lhs);
    // Generate rhs
    try self.genExpr(compareExpr.rhs);

    const result_kind = compareExpr.lhs.result_kind;

    // Generate compare
    switch (result_kind) {
        // Float operands
        .FLOAT => |float_lit| {
            const addType: u8 = if (float_lit.bits == 64) 'd' else 's';
            switch (compareExpr.op.kind) {
                .GREATER => try self.print(
                    \\    pop r11               ; Float Greater than
                    \\    movq xmm1, r11
                    \\    pop r10
                    \\    movq xmm0, r10
                    \\    comis{c} xmm0, xmm1
                    \\    seta al
                    \\    movzx rax, al
                    \\    push rax
                    \\
                , .{addType}),
                .GREATER_EQUAL => try self.print(
                    \\    pop r11               ; Float Greater Equal than
                    \\    movq xmm1, r11
                    \\    pop r10
                    \\    movq xmm0, r10
                    \\    comis{c} xmm0, xmm1
                    \\    setnb al
                    \\    movzx rax, al
                    \\    push rax
                    \\
                , .{addType}),
                .LESS => try self.print(
                    \\    pop r11               ; Float Less than
                    \\    movq xmm1, r11
                    \\    pop r10
                    \\    movq xmm0, r10
                    \\    ucomis{c} xmm1, xmm0
                    \\    seta al
                    \\    movzx rax, al
                    \\    push rax
                    \\
                , .{addType}),
                .LESS_EQUAL => try self.print(
                    \\    pop r11               ; Float Less Equal than
                    \\    movq xmm1, r11
                    \\    pop r10
                    \\    movq xmm0, r10
                    \\    comis{c} xmm1, xmm0
                    \\    setnb al
                    \\    movzx rax, al
                    \\    push rax
                    \\
                , .{addType}),
                .EQUAL_EQUAL => try self.print(
                    \\    pop r11               ; Float Equal
                    \\    movq xmm1, r11
                    \\    pop r10
                    \\    movq xmm0, r10
                    \\    ucomis{c} xmm0, xmm1
                    \\    sete al
                    \\    movzx rax, al
                    \\    push rax
                    \\
                , .{addType}),
                .EXCLAMATION_EQUAL => try self.print(
                    \\    pop r11               ; Float Not Equal
                    \\    movq xmm1, r11
                    \\    pop r10
                    \\    movq xmm0, r10
                    \\    ucomis{c} xmm0, xmm1
                    \\    setne al
                    \\    movzx rax, al
                    \\    push rax
                    \\
                , .{addType}),
                else => unreachable,
            }
        },
        // Unsigned
        .UINT => switch (compareExpr.op.kind) {
            .GREATER => try self.write(
                \\    pop r11               ; Unsigned Integer Greater than
                \\    pop r10
                \\    cmp r11, r10
                \\    setb al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            .GREATER_EQUAL => try self.write(
                \\    pop r11               ; Unsigned Integer Greater Equal than
                \\    pop r10
                \\    cmp r11, r10
                \\    setnb al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            .LESS => try self.write(
                \\    pop r11               ; Unsigned Integer Less than
                \\    pop r10
                \\    cmp r10, r11
                \\    setb al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            .LESS_EQUAL => try self.write(
                \\    pop r11               ; Unsigned Integer Less Equal than
                \\    pop r10
                \\    cmp r10, r11
                \\    setnb al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            .EQUAL_EQUAL => try self.write(
                \\    pop r11               ; Unsigned Integer Equal
                \\    pop r10
                \\    cmp r10, r11
                \\    sete al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            .EXCLAMATION_EQUAL => try self.write(
                \\    pop r11               ; Unsigned Integer Not Equal
                \\    pop r10
                \\    cmp r10, r11
                \\    setne al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            else => unreachable,
        },
        // Integer operands
        else => switch (compareExpr.op.kind) {
            .GREATER => try self.write(
                \\    pop r11               ; Integer Greater than
                \\    pop r10
                \\    cmp r10, r11
                \\    setg al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            .GREATER_EQUAL => try self.write(
                \\    pop r11               ; Integer Greater Equal than
                \\    pop r10
                \\    cmp r10, r11
                \\    setge al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            .LESS => try self.write(
                \\    pop r11               ; Integer Less than
                \\    pop r10
                \\    cmp r10, r11
                \\    setl al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            .LESS_EQUAL => try self.write(
                \\    pop r11               ; Integer Less Equal than
                \\    pop r10
                \\    cmp r10, r11
                \\    setle al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            .EQUAL_EQUAL => try self.write(
                \\    pop r11               ; Integer Equal
                \\    pop r10
                \\    cmp r10, r11
                \\    sete al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            .EXCLAMATION_EQUAL => try self.write(
                \\    pop r11               ; Integer Not Equal
                \\    pop r10
                \\    cmp r10, r11
                \\    setne al
                \\    movzx rax, al
                \\    push rax
                \\
            ),
            else => unreachable,
        },
    }
}

/// Generator asm for a logical and expression
fn visitAndExpr(self: *Generator, andExpr: *Expr.AndExpr) GenerationError!void {
    // Left side
    try self.genExpr(andExpr.lhs);

    // Get label counts
    const label_c = self.label_count;
    // Increment label
    self.label_count += 1;

    // Generate check for lhs
    try self.print(
        \\    cmp byte [rsp], 0     ; Logical AND Short Check
        \\    jz .L{d}
        \\    pop r10
        \\
    , .{label_c});

    // Right side
    try self.genExpr(andExpr.rhs);
    // Generate label and evaluation
    try self.print(
        \\.L{d}:                    ; End of Logical AND
        \\
    , .{label_c});
}

/// Generator asm for a logical or expression
fn visitOrExpr(self: *Generator, orExpr: *Expr.OrExpr) GenerationError!void {
    // Left side
    try self.genExpr(orExpr.lhs);

    // Get label counts
    const label_c = self.label_count;
    // Increment label
    self.label_count += 1;
    // Generate check for lhs
    try self.print(
        \\    cmp byte [rsp], 1     ; Logical OR Short Check
        \\    jz .L{d}
        \\    pop r10
        \\
    , .{label_c});

    // Right side
    try self.genExpr(orExpr.rhs);
    // Generate label and evaluation
    try self.print(
        \\.L{d}:                      ; End of Logical OR
        \\
    , .{label_c});
}

/// Generate asm for an if expression
fn visitIfExpr(self: *Generator, ifExpr: *Expr.IfExpr) GenerationError!void {
    // Evaluate the conditional
    try self.genExpr(ifExpr.conditional);

    // Get first label
    const label_c = self.label_count;
    // Increment it
    self.label_count += 1;
    // Write asm for jump
    try self.print(
        \\    pop r10               ; If Expr
        \\    test r10, r10 
        \\    jz .L{d}
        \\
    , .{label_c});

    // Generate the then branch
    try self.genExpr(ifExpr.then_branch);

    // Get second label
    const label_c2 = self.label_count;
    // Increment it
    self.label_count += 1;

    // Write asm for then branch jump to end and else jump label
    try self.print(
        \\    jmp .L{d}
        \\.L{d}:
        \\
    , .{ label_c2, label_c });

    // Generate the else branch
    try self.genExpr(ifExpr.else_branch);
    // Write the asm for jump to end label
    try self.print(
        \\.L{d}:                      ; End of If Expr
        \\
    , .{label_c2});
}
