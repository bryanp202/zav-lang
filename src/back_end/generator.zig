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
// Register names
const cpu_reg_name = [_][]const u8{ "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15" };
const cpu_reg_max = cpu_reg_name.len;
const sse_reg_name = [_][]const u8{ "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7" };
const sse_reg_max = cpu_reg_name.len;

/// Used to turn an AST into assembly
const Generator = @This();
// Fields
file: std.fs.File,
writer: *WriterType,
stm: *STM,

// Label counters
/// Used in the generation of if statement labels
label_count: usize,

// Register count
next_cpu_reg: usize,
next_sse_reg: usize,

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
        .next_cpu_reg = 0,
        .next_sse_reg = 0,
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
                .FLOAT32 => {
                    const float = real_value.as.float32;
                    self.print("    {s}: dd {e}\n", .{ name, float }) catch unreachable;
                },
                .FLOAT64 => {
                    const float = real_value.as.float64;
                    self.print("    {s}: dq {e}\n", .{ name, float }) catch unreachable;
                },
                else => unreachable,
            }
        }
    }
    // Close file and deallocate writer
    self.file.close();
    allocator.destroy(self.writer);
}

/// Walk the ast, generating ASM
pub fn gen(self: *Generator, start: ExprNode) GenerationError!void {
    try self.genExpr(start);
}

// ********************** //
// Private helper methods //
// ********************** //

/// Helper methods, uses the writer to output to the asm file
inline fn write(self: Generator, msg: []const u8) GenerationError!void {
    _ = self.writer.*.write(msg) catch return GenerationError.FailedToWrite;
}
/// Helper methods, uses the writer to output to the asm file
/// Takes in fmt and things to put in
inline fn print(self: Generator, fmt: []const u8, data: anytype) GenerationError!void {
    self.writer.*.print(fmt, data) catch return GenerationError.FailedToWrite;
}

/// Get the current cpu register name
fn getCurrCPUReg(self: *Generator) []const u8 {
    return cpu_reg_name[self.next_cpu_reg - 1];
}

/// Get the current sse register name
fn getCurrSSEReg(self: *Generator) []const u8 {
    return sse_reg_name[self.next_sse_reg - 1];
}

/// Get the next cpu register name.
/// Increment the cpu register 'stack', throwing an error if no more registers
fn getNextCPUReg(self: *Generator) GenerationError![]const u8 {
    // Increment
    self.next_cpu_reg += 1;
    // Check if out of bounds
    if (self.next_cpu_reg > cpu_reg_max) {
        return GenerationError.OutOfCPURegisters;
    }
    // Return new current register
    return self.getCurrCPUReg();
}

/// Get the next sse register name.
/// Increment the sse register 'stack', throwing an error if no more registers
fn getNextSSEReg(self: *Generator) GenerationError![]const u8 {
    // Increment
    self.next_sse_reg += 1;
    // Check if out of bounds
    if (self.next_sse_reg > sse_reg_max) {
        return GenerationError.OutOfCPURegisters;
    }
    // Return new current register
    return self.getCurrSSEReg();
}

/// Pop the current cpu register
fn popCPUReg(self: *Generator) []const u8 {
    const reg_name = self.getCurrCPUReg();
    self.next_cpu_reg -= 1;
    return reg_name;
}

/// Pop the current sse register
fn popSSEReg(self: *Generator) []const u8 {
    const reg_name = self.getCurrSSEReg();
    self.next_sse_reg -= 1;
    return reg_name;
}

/// Store all active cpu registers onto the stack.
/// Useful to use before function calls
fn storeCPUReg(self: *Generator) GenerationError!usize {
    // Store register count
    const reg_count = self.next_cpu_reg;

    while (self.next_cpu_reg > 0) {
        const reg_name = self.popCPUReg();
        try self.print("    push {s}\n", .{reg_name});
    }
    // Return count
    return reg_count;
}

/// Store all active sse registers onto the stack.
/// Useful to use before function calls
fn storeSSEReg(self: *Generator) GenerationError!usize {
    // Store register count
    const reg_count = self.next_sse_reg;

    while (self.next_cpu_reg > 0) {
        const reg_name = self.popSSEReg();
        try self.print("    sub rsp, 8\n    movsd [rsp], {s}\n", .{reg_name});
    }
    // Return count
    return reg_count;
}

/// Pop all stored cpu registers from the stack.
/// Used after storeCPUReg
fn restoreCPUReg(self: *Generator, reg_count: usize) GenerationError!void {
    for (0..reg_count) |_| {
        const reg_name = try self.getNextCPUReg();
        try self.print("    pop {s}\n", .{reg_name});
    }
}

/// Pop all stored sse registers from the stack.
/// Used after storeCPUReg
fn restoreSSEReg(self: *Generator, reg_count: usize) GenerationError!void {
    for (0..reg_count) |_| {
        const reg_name = try self.getNextSSEReg();
        try self.print("    movsd {s}, [rsp]\n    add rsp, 8\n", .{reg_name});
    }
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
        .NATIVE => |nativeExpr| try self.visitNativeExpr(nativeExpr, result_kind),
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
            // Get a new register
            const reg_name = try self.getNextCPUReg();
            // Extract the real data from union
            const lit_val: u16 = if (litExpr.value.as.boolean) 1 else 0;
            try self.print("    mov {s}, {d} ; Load Bool\n", .{ reg_name, lit_val });
        },
        .UINT => {
            // Get a new register
            const reg_name = try self.getNextCPUReg();
            // Extract the real data from union
            const lit_val = litExpr.value.as.uint.data;
            try self.print("    mov {s}, {d} ; Load Unsigned Integer\n", .{ reg_name, lit_val });
        },
        .INT => {
            // Get a new register
            const reg_name = try self.getNextCPUReg();
            // Extract the real data from union
            const lit_val = litExpr.value.as.int.data;
            try self.print("    mov {s}, {d} ; Load Integer\n", .{ reg_name, lit_val });
        },
        .FLOAT32 => {
            // Get a new register
            const reg_name = try self.getNextSSEReg();
            // Get the constants name
            const lit_name = self.stm.getConstantId(litExpr.value);
            try self.print("    movss {s}, [{s}] ; Load F32\n", .{ reg_name, lit_name });
        },
        .FLOAT64 => {
            // Get a new register
            const reg_name = try self.getNextSSEReg();
            // Get the constants name
            const lit_name = self.stm.getConstantId(litExpr.value);
            try self.print("    movsd {s}, [{s}] ; Load F64\n", .{ reg_name, lit_name });
        },
        else => unreachable,
    }
}

/// Generate asm for a native expr call
fn visitNativeExpr(self: *Generator, nativeExpr: *Expr.NativeExpr, result_kind: KindId) GenerationError!void {
    // Preserve current registers
    const cpu_reg_count = try self.storeCPUReg();
    const sse_reg_count = try self.storeSSEReg();

    // Check for arguments
    if (nativeExpr.args) |args| {
        // Generate each arg
        for (args) |arg| {
            try self.genExpr(arg);
            // Push onto the stack
            switch (arg.result_kind) {
                .BOOL, .UINT, .INT => {
                    // Get a new register
                    const reg_name = self.popCPUReg();
                    try self.print("    push {s}\n", .{reg_name});
                },
                .FLOAT32 => {
                    // Get a new register
                    const reg_name = self.popSSEReg();
                    try self.print("    sub rsp, 8\n    movss {s}\n", .{reg_name});
                },
                .FLOAT64 => {
                    // Get a new register
                    const reg_name = self.popSSEReg();
                    try self.print("    sub rsp, 8\n    movsd {s}\n", .{reg_name});
                },
                else => unreachable,
            }
        }
    }

    // Generate the call
    try self.print("    call {s}\n", .{nativeExpr.name.lexeme});
    // Pop off arguments at end of call, if there are any
    if (nativeExpr.args) |args| {
        try self.print("    add rsp, {d}\n", .{args.len * 8});
    }

    // Pop registers back
    try self.restoreCPUReg(cpu_reg_count);
    try self.restoreSSEReg(sse_reg_count);
    // Put result into next register
    switch (result_kind) {
        .BOOL, .UINT, .INT => {
            // Get a new register
            const reg_name = try self.getNextCPUReg();
            try self.print("    mov {s}, rax\n", .{reg_name});
        },
        .FLOAT32 => {
            // Get a new register
            const reg_name = try self.getNextSSEReg();
            try self.print("    movss {s}, rax\n", .{reg_name});
        },
        .FLOAT64 => {
            // Get a new register
            const reg_name = try self.getNextSSEReg();
            try self.print("    movsd {s}, rax\n", .{reg_name});
        },
        else => unreachable,
    }
}

/// Generate asm for type conversions
fn visitConvExpr(self: *Generator, convExpr: *Expr.ConversionExpr, result_kind: KindId) GenerationError!void {
    // Generate operand
    try self.genExpr(convExpr.operand);
    // Extrand operand type
    const operand_type = convExpr.operand.result_kind;
    // Generate self
    switch (operand_type) {
        // Converting FROM FLOAT32
        .FLOAT32 => {
            // Get register name
            const src_reg = self.getCurrSSEReg();
            switch (result_kind) {
                // Converting to FLOAT64
                .FLOAT64 => {
                    try self.print("    cvtss2sd {s}, {s} ; F32 to F64\n", .{ src_reg, src_reg });
                },
                else => unreachable,
            }
        },
        // Converting FROM FLOAT64
        .FLOAT64 => {
            // Get register name
            const src_reg = self.getCurrSSEReg();
            switch (result_kind) {
                // Converting to FLOAT32 from FLOAT64
                .FLOAT32 => {
                    try self.print("    cvtsd2ss {s}, {s} ; F64 to F32\n", .{ src_reg, src_reg });
                },
                else => unreachable,
            }
        },
        // Non floating point source
        .BOOL, .UINT, .INT => {
            // Get register name
            const src_reg = self.popCPUReg();
            switch (result_kind) {
                // Converting to FLOAT64
                .FLOAT32 => {
                    // Get new F64 register
                    const target_reg = try self.getNextSSEReg();
                    try self.print("    cvtsi2ss {s}, {s} ; Non-floating point to F32\n", .{ target_reg, src_reg });
                },
                // Converting to FLOAT64
                .FLOAT64 => {
                    // Get new F64 register
                    const target_reg = try self.getNextSSEReg();
                    try self.print("    cvtsi2sd {s}, {s} ; Non-floating point to F64\n", .{ target_reg, src_reg });
                },
                else => unreachable,
            }
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
        .FLOAT32 => {
            // Get register name
            const reg_name = self.getCurrSSEReg();
            switch (unaryExpr.op.kind) {
                TokenKind.MINUS => {
                    try self.print("    xor {s}, [SS_SIGN_BIT] ; F32 Negate\n", .{reg_name});
                },
                else => unreachable,
            }
        },
        .FLOAT64 => {
            // Get register name
            const reg_name = self.getCurrSSEReg();
            switch (unaryExpr.op.kind) {
                TokenKind.MINUS => {
                    try self.print("    xor {s}, [SD_SIGN_BIT] ; F64 Negate\n", .{reg_name});
                },
                else => unreachable,
            }
        },
        else => {
            // Get register name
            const reg_name = self.getCurrCPUReg();
            switch (unaryExpr.op.kind) {
                TokenKind.EXCLAMATION => try self.print("    xor {s}, 1 ; Bool not\n", .{reg_name}),
                TokenKind.MINUS => try self.print("    neg {s} ; Non-floating point negate\n", .{reg_name}),
                else => unreachable,
            }
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
        .FLOAT32, .FLOAT64 => {
            // Get registers
            const rhs_reg = self.popSSEReg();
            const lhs_reg = self.getCurrSSEReg();
            // Get op char
            const op_char: u8 = if (result_kind == .FLOAT32) 's' else 'd';

            switch (arithExpr.op.kind) {
                TokenKind.PLUS => try self.print("    adds{c} {s}, {s} ; Float Add\n", .{ op_char, lhs_reg, rhs_reg }),
                TokenKind.MINUS => try self.print("    subs{c} {s}, {s} ; Float Sub\n", .{ op_char, lhs_reg, rhs_reg }),
                TokenKind.STAR => try self.print("    muls{c} {s}, {s} ; Float Mul\n", .{ op_char, lhs_reg, rhs_reg }),
                TokenKind.SLASH => try self.print("    divs{c} {s}, {s} ; Float Div\n", .{ op_char, lhs_reg, rhs_reg }),
                else => unreachable,
            }
        },
        else => {
            // Get registers
            const rhs_reg = self.popCPUReg();
            const lhs_reg = self.getCurrCPUReg();

            switch (arithExpr.op.kind) {
                TokenKind.PLUS => try self.print("    add {s}, {s} ; Integer Add\n", .{ lhs_reg, rhs_reg }),
                TokenKind.MINUS => try self.print("    sub {s}, {s} ; Integer  Sub\n", .{ lhs_reg, rhs_reg }),
                TokenKind.STAR => try self.print("    add {s}, {s} ; Integer Add\n", .{ lhs_reg, rhs_reg }),
                TokenKind.SLASH => try self.print(
                    \\    mov rax, {s} ; Integer Div
                    \\    xor edx, edx
                    \\    idiv {s}
                    \\    mov {s}, rax
                    \\
                , .{ lhs_reg, rhs_reg, lhs_reg }),
                TokenKind.PERCENT => try self.print(
                    \\    mov rax, {s} ; Integer Mod
                    \\    xor edx, edx
                    \\    idiv {s}
                    \\    mov {s}, rds
                    \\
                , .{ lhs_reg, rhs_reg, lhs_reg }),
                else => unreachable,
            }
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
        .FLOAT32, .FLOAT64 => {
            // Get register names, and free rhs'
            const rhs_reg = self.popSSEReg();
            const lhs_reg = self.getCurrSSEReg();
            // Get op char for data size
            const op_char: u8 = if (result_kind == .FLOAT32) 's' else 'd';

            switch (compareExpr.op.kind) {
                .GREATER => try self.print(
                    \\    comis{c} {s}, {s} ; Float >
                    \\    seta al
                    \\    movzx {s}, al
                    \\
                , .{ op_char, lhs_reg, rhs_reg, lhs_reg }),
                .GREATER_EQUAL => try self.print(
                    \\    comis{c} {s}, {s} ; Float >=
                    \\    setnb al
                    \\    movzx {s}, al
                    \\
                , .{ op_char, lhs_reg, rhs_reg, lhs_reg }),
                .LESS => try self.print(
                    \\    comis{c} {s}, {s} ; Float <
                    \\    seta al
                    \\    movzx {s}, al
                    \\
                , .{ op_char, rhs_reg, lhs_reg, lhs_reg }),
                .LESS_EQUAL => try self.print(
                    \\    comis{c} {s}, {s} ; Float <=
                    \\    setnb al
                    \\    movzx {s}, al
                    \\
                , .{ op_char, rhs_reg, lhs_reg, lhs_reg }),
                .EQUAL_EQUAL => try self.print(
                    \\    comis{c} {s}, {s} ; Float ==
                    \\    sete al
                    \\    movzx {s}, al
                    \\
                , .{ op_char, lhs_reg, rhs_reg, lhs_reg }),
                .EXCLAMATION_EQUAL => try self.print(
                    \\    comis{c} {s}, {s} ; Float !=
                    \\    setne al
                    \\    movzx {s}, al
                    \\
                , .{ op_char, lhs_reg, rhs_reg, lhs_reg }),
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
