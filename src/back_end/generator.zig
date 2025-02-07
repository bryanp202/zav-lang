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
// Stmt Import
const Stmt = @import("../stmt.zig");
const StmtNode = Stmt.StmtNode;
// Module import
const Module = @import("../module.zig");
// Register Stack
const Registers = @import("register_stack.zig");
const RegisterStack = Registers.RegisterStack;
const Register = Registers.Register;

// Writer Type stuff
const info = @typeInfo(@TypeOf(std.fs.File.writer));
const WriterType = info.Fn.return_type orelse void;

// Useful Constants
const DWORD_IMIN: i64 = -0x80000000;
const DWORD_IMAX: i64 = 0x7FFFFFFF;
const DWORD_UMAX: u64 = 0xFFFFFFFF;
// Register names for cpu 64 bit
const cpu_reg_names = [_][]const u8{ "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15" };
// Alternate sized cpu register names
const cpu_reg_names_32bit = [_][]const u8{ "esi", "edi", "r8d", "r9d", "r10d", "r11d", "r12d", "r13d", "r14d", "r15d" };
const cpu_reg_names_16bit = [_][]const u8{ "si", "di", "r8w", "r9w", "r10w", "r11w", "r12w", "r13w", "r14w", "r15w" };
const cpu_reg_names_8bit = [_][]const u8{ "sil", "dil", "r8b", "r9b", "r10b", "r11b", "r12b", "r13b", "r14b", "r15b" };
// Floating point
const sse_reg_names = [_][]const u8{ "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7" };

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
cpu_reg_stack: RegisterStack(cpu_reg_names),
sse_reg_stack: RegisterStack(sse_reg_names),

pub fn open(allocator: std.mem.Allocator, stm: *STM, name: []const u8) !Generator {
    // Add .asm to path
    const path = std.fmt.allocPrint(allocator, "{s}.asm", .{name}) catch unreachable;

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
        \\    ; Body
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
        .cpu_reg_stack = RegisterStack(cpu_reg_names).init(),
        .sse_reg_stack = RegisterStack(sse_reg_names).init(),
    };
}

pub fn close(self: Generator, allocator: std.mem.Allocator) GenerationError!void {
    // Write end of file
    try self.write(
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
    );

    // Write native functions source
    var native_func = self.stm.natives_table.natives_table.iterator();
    // Go through each
    while (native_func.next()) |native| {
        if (native.value_ptr.used) {
            try self.print("{s}", .{native.value_ptr.source});
        }
    }

    // Write .data section
    try self.write(
        \\
        \\section .data
        \\    ; Native Constants ;
        \\    @SS_SIGN_BIT: dq 0x80000000, 0, 0, 0
        \\    @SD_SIGN_BIT: dq 0x8000000000000000, 0, 0, 0
        \\
    );
    // Write native data
    // Write native functions source
    native_func = self.stm.natives_table.natives_table.iterator();
    // Go through each
    while (native_func.next()) |native| {
        if (native.value_ptr.used) {
            if (native.value_ptr.data) |data| {
                try self.print("{s}", .{data});
            }
        }
    }

    // Write the program defined constants section
    try self.write("\n    ; Program Constants\n");
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
                    try self.print("    {s}: dd {e}\n", .{ name, float });
                },
                .FLOAT64 => {
                    const float = real_value.as.float64;
                    try self.print("    {s}: dq {e}\n", .{ name, float });
                },
                .STRING => {
                    const string = real_value.as.string.data.slice();
                    const extracted_str = string[1 .. string.len - 1];
                    try self.print("    {s}: db `{s}`, 0\n", .{ name, extracted_str });
                },
                else => unreachable,
            }
        }
    }

    // Write global variables to bss section
    try self.write("\nsection .bss\n    ; Program Globals\n");
    // Reset scope stack
    self.stm.resetStack();
    var global_iter = self.stm.active_scope.symbols.iterator();
    // Write each variable to the file
    while (global_iter.next()) |global_entry| {
        // Extract global
        const global = global_entry.value_ptr;
        // Write to file
        try self.print("    _{s}: resb {d}\n", .{ global.name, global.size });
    }

    // Close file and deallocate writer
    self.file.close();
    allocator.destroy(self.writer);
}

/// Walk the ast, generating ASM
pub fn gen(self: *Generator, module: Module) GenerationError!void {
    // Generate all statements in the module
    for (module.stmts()) |stmt| {
        try self.genStmt(stmt);
    }
}

// ********************** //
// Private helper methods //
// ********************** //

/// Return the keyword such as "byte", "dword" for a given KindId size
fn getSizeKeyword(size: u64) []const u8 {
    return switch (size) {
        1 => "byte",
        2 => "word",
        4 => "dword",
        else => "qword",
    };
}

/// Return the properly sized name for a cpu register
fn getSizedCPUReg(index: usize, size: u64) []const u8 {
    return switch (size) {
        1 => Generator.cpu_reg_names_8bit[index],
        2 => Generator.cpu_reg_names_16bit[index],
        4 => Generator.cpu_reg_names_32bit[index],
        else => Generator.cpu_reg_names[index],
    };
}

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
fn getCurrCPUReg(self: *Generator) Register {
    return self.cpu_reg_stack.current();
}

/// Get the current sse register name
fn getCurrSSEReg(self: *Generator) Register {
    return self.sse_reg_stack.current();
}

/// Get the next cpu register name.
/// Increment the cpu register 'stack', throwing an error if no more registers
fn getNextCPUReg(self: *Generator) GenerationError!Register {
    return self.cpu_reg_stack.loadNew();
}

/// Get the next sse register name.
/// Increment the sse register 'stack', throwing an error if no more registers
fn getNextSSEReg(self: *Generator) GenerationError!Register {
    return self.sse_reg_stack.loadNew();
}

/// Pop the current cpu register
fn popCPUReg(self: *Generator) Register {
    return self.cpu_reg_stack.pop();
}

/// Push a register onto the cpu register stack
fn pushCPUReg(self: *Generator, reg: Register) void {
    return self.cpu_reg_stack.push(reg);
}

/// Push a register onto the sse register stack
fn pushSSEReg(self: *Generator, reg: Register) void {
    return self.sse_reg_stack.push(reg);
}

/// Pop the current sse register
fn popSSEReg(self: *Generator) Register {
    return self.sse_reg_stack.pop();
}

/// Store all active cpu registers onto the stack.
/// Useful to use before function calls
fn storeCPUReg(self: *Generator) GenerationError!usize {
    // Store register count
    const reg_count = self.cpu_reg_stack.count;

    for (reg_count) |_| {
        const reg = self.popCPUReg();
        try self.print("    push {s}\n", .{reg.name});
    }
    // Return count
    return reg_count;
}

/// Store all active sse registers onto the stack.
/// Useful to use before function calls
fn storeSSEReg(self: *Generator) GenerationError!usize {
    // Store register count
    const reg_count = self.sse_reg_stack.count;

    for (reg_count) |_| {
        const reg = self.popSSEReg();
        try self.print("    push {s}\n", .{reg.name});
    }
    // Return count
    return reg_count;
}

/// Pop all stored cpu registers from the stack.
/// Used after storeCPUReg
fn restoreCPUReg(self: *Generator, reg_count: usize) GenerationError!void {
    for (0..reg_count) |_| {
        const reg = try self.getNextCPUReg();
        try self.print("    pop {s}\n", .{reg.name});
    }
}

/// Pop all stored sse registers from the stack.
/// Used after storeCPUReg
fn restoreSSEReg(self: *Generator, reg_count: usize) GenerationError!void {
    for (0..reg_count) |_| {
        const reg = try self.getNextSSEReg();
        try self.print("    movsd {s}, [rsp]\n    add rsp, 8\n", .{reg.name});
    }
}

// ********************** //
// Stmt anaylsis  methods //
// ********************** //
/// Determine the type of stmt and call appropriate helper function
fn genStmt(self: *Generator, stmt: StmtNode) GenerationError!void {
    // Determine kind of stmt
    switch (stmt) {
        .EXPRESSION => |exprStmt| try self.visitExprStmt(exprStmt),
        .DECLARE => |declareStmt| try self.visitDeclareStmt(declareStmt),
        else => unreachable,
    }
}

/// Generate the asm for a declare stmt
fn visitDeclareStmt(self: *Generator, declareStmt: *Stmt.DeclareStmt) GenerationError!void {
    // Get the symbol
    const identifier = self.stm.getSymbol(declareStmt.id.lexeme) catch unreachable;
    // Check scope type
    if (identifier.scope == .GLOBAL) {
        // Global
        // Generate expression
        try self.genExpr(declareStmt.expr);

        // Pop register based on result type
        const result_kind = declareStmt.expr.result_kind;
        if (result_kind == .FLOAT32) {
            const reg = self.popSSEReg();
            try self.print("    movss [_{s}], {s} ; Declare identifier\n", .{ identifier.name, reg.name });
        }
        if (result_kind == .FLOAT64) {
            const reg = self.popSSEReg();
            try self.print("    movsd [_{s}], {s} ; Declare identifier\n", .{ identifier.name, reg.name });
        } else {
            // Get size and size keyword
            const size = declareStmt.kind.?.size_runtime();
            // Get register
            const reg = self.popCPUReg();
            // Get properly sized register
            const sized_reg = getSizedCPUReg(reg.index, size);

            // Write assignment
            try self.print("    mov [_{s}], {s} ; Declare identifier\n", .{ identifier.name, sized_reg });
        }
    } else if (identifier.scope == .LOCAL) {
        // Local
        unreachable;
    } else {
        unreachable;
    }
}

/// Generate the asm for an expr stmt
fn visitExprStmt(self: *Generator, exprStmt: *Stmt.ExprStmt) GenerationError!void {
    // Generate the stored exprnode
    try self.genExpr(exprStmt.expr);
    // Pop last register, based on if float or not
    if (exprStmt.expr.result_kind == .FLOAT32 or exprStmt.expr.result_kind == .FLOAT64) {
        _ = self.popSSEReg();
    } else {
        _ = self.popCPUReg();
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
        .IDENTIFIER => |idExpr| try self.visitIdentifierExpr(idExpr, result_kind),
        .LITERAL => |litExpr| try self.visitLiteralExpr(litExpr),
        .NATIVE => |nativeExpr| try self.visitNativeExpr(nativeExpr, result_kind),
        .CONVERSION => |convExpr| try self.visitConvExpr(convExpr, result_kind),
        .INDEX => |indexExpr| try self.visitIndexExpr(indexExpr, result_kind),
        .UNARY => |unaryExpr| try self.visitUnaryExpr(unaryExpr),
        .ARITH => |arithExpr| try self.visitArithExpr(arithExpr),
        .COMPARE => |compareExpr| try self.visitCompareExpr(compareExpr),
        .AND => |andExpr| try self.visitAndExpr(andExpr),
        .OR => |orExpr| try self.visitOrExpr(orExpr),
        .IF => |ifExpr| try self.visitIfExpr(ifExpr, result_kind),
        //else => unreachable,
    }
}

/// Generate asm for an IDExpr
fn visitIdentifierExpr(self: *Generator, idExpr: *Expr.IdentifierExpr, result_kind: KindId) GenerationError!void {
    // Get size of kind
    const kind_size = result_kind.size_runtime();
    // Get keyword based on size
    const size_keyword = getSizeKeyword(kind_size);

    if (result_kind == .FLOAT32) {
        const reg = try self.getNextSSEReg();
        // Mov normally
        try self.print(
            "    movss {s}, {s} [_{s}] ; Get Identifier\n",
            .{ reg.name, size_keyword, idExpr.id.lexeme },
        );
    } else if (result_kind == .FLOAT64) {
        const reg = try self.getNextSSEReg();
        // Mov normally
        try self.print(
            "    movsd {s}, {s} [_{s}] ; Get Identifier\n",
            .{ reg.name, size_keyword, idExpr.id.lexeme },
        );
    } else {
        const reg = try self.getNextCPUReg();
        // Check if size is 64 bit
        if (kind_size == 8) {
            // Mov normally
            try self.print(
                "    mov {s}, {s} [_{s}] ; Get Identifier\n",
                .{ reg.name, size_keyword, idExpr.id.lexeme },
            );
        } else {
            // Check if unsigned
            if (result_kind == .INT) {
                // Move and extend sign bit
                try self.print(
                    "    movsx {s}, {s} [_{s}] ; Get Identifier\n",
                    .{ reg.name, size_keyword, idExpr.id.lexeme },
                );
            } else {
                // Move and zero top
                try self.print(
                    "    movzx {s}, {s} [_{s}] ; Get Identifier\n",
                    .{ reg.name, size_keyword, idExpr.id.lexeme },
                );
            }
        }
    }
}

/// Generate asm for a LiteralExpr
fn visitLiteralExpr(self: *Generator, litExpr: *Expr.LiteralExpr) GenerationError!void {
    // Determine Value kind
    switch (litExpr.value.kind) {
        .BOOL => {
            // Get a new register
            const reg = try self.getNextCPUReg();
            // Extract the real data from union
            const lit_val: u16 = if (litExpr.value.as.boolean) 1 else 0;
            try self.print("    mov {s}, {d} ; Load BOOL\n", .{ reg.name, lit_val });
        },
        .UINT => {
            // Get a new register
            const reg = try self.getNextCPUReg();
            // Extract the real data from union
            const lit_val = litExpr.value.as.uint.data;
            try self.print("    mov {s}, {d} ; Load UINT\n", .{ reg.name, lit_val });
        },
        .INT => {
            // Get a new register
            const reg = try self.getNextCPUReg();
            // Extract the real data from union
            const lit_val = litExpr.value.as.int.data;
            try self.print("    mov {s}, {d} ; Load INT\n", .{ reg.name, lit_val });
        },
        .FLOAT32 => {
            // Get a new register
            const reg = try self.getNextSSEReg();
            // Get the constants name
            const lit_name = self.stm.getConstantId(litExpr.value);
            try self.print("    movss {s}, [{s}] ; Load F32\n", .{ reg.name, lit_name });
        },
        .FLOAT64 => {
            // Get a new register
            const reg = try self.getNextSSEReg();
            // Get the constants name
            const lit_name = self.stm.getConstantId(litExpr.value);
            try self.print("    movsd {s}, [{s}] ; Load F64\n", .{ reg.name, lit_name });
        },
        .STRING => {
            // Get a new register
            const reg = try self.getNextCPUReg();
            // Get the constants name
            const lit_name = self.stm.getConstantId(litExpr.value);
            try self.print("    mov {s}, {s}\n", .{ reg.name, lit_name });
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
                .BOOL, .UINT, .INT, .PTR => {
                    // Get register and pop
                    const reg = self.popCPUReg();
                    try self.print("    push {s}\n", .{reg.name});
                },
                .FLOAT32 => {
                    // Get register and pop
                    const reg = self.popSSEReg();
                    try self.print("    sub rsp, 8\n    movss [rsp], {s}\n", .{reg.name});
                },
                .FLOAT64 => {
                    // Get register and pop
                    const reg = self.popSSEReg();
                    try self.print("    sub rsp, 8\n    movsd [rsp], {s}\n", .{reg.name});
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
            const reg = try self.getNextCPUReg();
            try self.print("    mov {s}, rax\n", .{reg.name});
        },
        .FLOAT32 => {
            // Get a new register
            const reg = try self.getNextSSEReg();
            try self.print("    movss {s}, rax\n", .{reg.name});
        },
        .FLOAT64 => {
            // Get a new register
            const reg = try self.getNextSSEReg();
            try self.print("    movsd {s}, rax\n", .{reg.name});
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
                    try self.print("    cvtss2sd {s}, {s} ; F32 to F64\n", .{ src_reg.name, src_reg.name });
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
                    try self.print("    cvtsd2ss {s}, {s} ; F64 to F32\n", .{ src_reg.name, src_reg.name });
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
                    try self.print("    cvtsi2ss {s}, {s} ; Non-floating point to F32\n", .{ target_reg.name, src_reg.name });
                },
                // Converting to FLOAT64
                .FLOAT64 => {
                    // Get new F64 register
                    const target_reg = try self.getNextSSEReg();
                    try self.print("    cvtsi2sd {s}, {s} ; Non-floating point to F64\n", .{ target_reg.name, src_reg.name });
                },
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

/// Generate asm for an indexExpr
fn visitIndexExpr(self: *Generator, indexExpr: *Expr.IndexExpr, result_kind: KindId) GenerationError!void {
    // Generate lhs
    try self.genExpr(indexExpr.lhs);
    // Generate rhs
    try self.genExpr(indexExpr.rhs);

    // Generate index call
    var lhs_reg: Register = undefined;
    var rhs_reg: Register = undefined;
    // Get register names, checking if reversed
    if (indexExpr.reversed) {
        lhs_reg = self.popCPUReg();
        rhs_reg = self.popCPUReg();
    } else {
        rhs_reg = self.popCPUReg();
        lhs_reg = self.popCPUReg();
    }

    // Check if array
    if (indexExpr.lhs.result_kind == .ARRAY) {
        // Write array offset * child size
        const child_size = indexExpr.lhs.result_kind.ARRAY.child.size_runtime();
        try self.print("    imul {s}, {d} ; Array Index\n", .{ rhs_reg.name, child_size });
    }

    // Add pointer and offset
    try self.print("    add {s}, {s} ; Ptr Index\n", .{ lhs_reg.name, rhs_reg.name });

    // Check if float 32
    if (result_kind == .FLOAT32) {
        // Get floating register
        const result_reg = try self.getNextSSEReg();
        // Write index access
        try self.print("    movss {s}, [{s}]\n", .{ result_reg.name, lhs_reg.name });
    } else if (result_kind == .FLOAT64) {
        // Get floating register
        const result_reg = try self.getNextSSEReg();
        // Write index access
        try self.print("    movsd {s}, [{s}]\n", .{ result_reg.name, lhs_reg.name });
    } else {
        // Get the size of the result
        const size = result_kind.size_runtime();
        const size_keyword = getSizeKeyword(size);
        // Push lhs_reg back on the stack
        const result_reg = try self.getNextCPUReg();

        // If size is 8 normal, else special size keyword
        if (size == 8) {
            // Write index access
            try self.print("    mov {s}, {s} [{s}]\n", .{ result_reg.name, size_keyword, lhs_reg.name });
        } else {
            // Get operation kind
            const op_char: u8 = if (result_kind == .UINT) 'z' else 's';
            // Write index access
            try self.print("    mov{c}x {s}, {s} [{s}]\n", .{ op_char, result_reg.name, size_keyword, lhs_reg.name });
        }
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
            const reg = self.getCurrSSEReg();
            switch (unaryExpr.op.kind) {
                TokenKind.MINUS => {
                    try self.print("    xorps {s}, oword [@SS_SIGN_BIT] ; F32 Negate\n", .{reg.name});
                },
                else => unreachable,
            }
        },
        .FLOAT64 => {
            // Get register name
            const reg = self.getCurrSSEReg();
            switch (unaryExpr.op.kind) {
                TokenKind.MINUS => {
                    try self.print("    xorps {s}, oword [@SD_SIGN_BIT] ; F64 Negate\n", .{reg.name});
                },
                else => unreachable,
            }
        },
        else => {
            // Get register name
            const reg = self.getCurrCPUReg();
            switch (unaryExpr.op.kind) {
                TokenKind.EXCLAMATION => try self.print("    xor {s}, 1 ; Bool not\n", .{reg.name}),
                TokenKind.MINUS => try self.print("    neg {s} ; (U)INT negate\n", .{reg.name}),
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
            var lhs_reg: Register = undefined;
            var rhs_reg: Register = undefined;
            // Get register names, checking if reversed
            if (arithExpr.reversed) {
                lhs_reg = self.popSSEReg();
                rhs_reg = self.popSSEReg();
            } else {
                rhs_reg = self.popSSEReg();
                lhs_reg = self.popSSEReg();
            }
            // Get op char
            const op_char: u8 = if (result_kind == .FLOAT32) 's' else 'd';

            switch (arithExpr.op.kind) {
                TokenKind.PLUS => try self.print("    adds{c} {s}, {s} ; Float Add\n", .{ op_char, lhs_reg.name, rhs_reg.name }),
                TokenKind.MINUS => try self.print("    subs{c} {s}, {s} ; Float Sub\n", .{ op_char, lhs_reg.name, rhs_reg.name }),
                TokenKind.STAR => try self.print("    muls{c} {s}, {s} ; Float Mul\n", .{ op_char, lhs_reg.name, rhs_reg.name }),
                TokenKind.SLASH => try self.print("    divs{c} {s}, {s} ; Float Div\n", .{ op_char, lhs_reg.name, rhs_reg.name }),
                else => unreachable,
            }
            // Push lhs back
            self.pushSSEReg(lhs_reg);
        },
        else => {
            var lhs_reg: Register = undefined;
            var rhs_reg: Register = undefined;
            // Get register names, checking if reversed
            if (arithExpr.reversed) {
                lhs_reg = self.popCPUReg();
                rhs_reg = self.popCPUReg();
            } else {
                rhs_reg = self.popCPUReg();
                lhs_reg = self.popCPUReg();
            }

            switch (arithExpr.op.kind) {
                TokenKind.PLUS => try self.print("    add {s}, {s} ; (U)INT Add\n", .{ lhs_reg.name, rhs_reg.name }),
                TokenKind.MINUS => try self.print("    sub {s}, {s} ; (U)INT  Sub\n", .{ lhs_reg.name, rhs_reg.name }),
                TokenKind.STAR => try self.print("    imul {s}, {s} ; (U)INT Mul\n", .{ lhs_reg.name, rhs_reg.name }),
                TokenKind.SLASH => try self.print(
                    \\    mov rax, {s} ; (U)INT Div
                    \\    xor edx, edx
                    \\    idiv {s}
                    \\    mov {s}, rax
                    \\
                , .{ lhs_reg.name, rhs_reg.name, lhs_reg.name }),
                TokenKind.PERCENT => try self.print(
                    \\    mov rax, {s} ; (U)INT Mod
                    \\    xor edx, edx
                    \\    idiv {s}
                    \\    mov {s}, rdx
                    \\
                , .{ lhs_reg.name, rhs_reg.name, lhs_reg.name }),
                else => unreachable,
            }
            // Push lhs register back on the stack
            self.pushCPUReg(lhs_reg);
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
            var lhs_reg: Register = undefined;
            var rhs_reg: Register = undefined;
            // Get register names, checking if reversed
            if (compareExpr.reversed) {
                lhs_reg = self.popSSEReg();
                rhs_reg = self.popSSEReg();
            } else {
                rhs_reg = self.popSSEReg();
                lhs_reg = self.popSSEReg();
            }

            // Get op char for data size
            const op_char: u8 = if (result_kind == .FLOAT32) 's' else 'd';
            // Print common op for float compare
            try self.print("    comis{c} {s}, {s} ; Float ", .{ op_char, lhs_reg.name, rhs_reg.name });

            switch (compareExpr.op.kind) {
                .GREATER => try self.write(">\n    seta al\n"),
                .GREATER_EQUAL => try self.write(">=\n    setnb al\n"),
                .LESS => try self.write("<\n    setb al\n"),
                .LESS_EQUAL => try self.write("<=\n    setna al\n"),
                .EQUAL_EQUAL => try self.write("==\n    sete al\n"),
                .EXCLAMATION_EQUAL => try self.write("!=\n    setne al\n"),
                else => unreachable,
            }
            // Get new result register
            const result_reg = try self.getNextCPUReg();
            // Print ending common op for float compare
            try self.print("    movzx {s}, al\n", .{result_reg.name});
        },
        // Unsigned
        .UINT => {
            var lhs_reg: Register = undefined;
            var rhs_reg: Register = undefined;
            // Get register names, checking if reversed
            if (compareExpr.reversed) {
                lhs_reg = self.popCPUReg();
                rhs_reg = self.popCPUReg();
            } else {
                rhs_reg = self.popCPUReg();
                lhs_reg = self.popCPUReg();
            }

            // Print common asm for all compares
            try self.print("    cmp {s}, {s} ; UINT ", .{ lhs_reg.name, rhs_reg.name });
            switch (compareExpr.op.kind) {
                .GREATER => try self.write(">\n    setb al\n"),
                .GREATER_EQUAL => try self.write(">=\n    seta al\n"),
                .LESS => try self.write("<\n    setna al\n"),
                .LESS_EQUAL => try self.write("<=\n    setnb al\n"),
                .EQUAL_EQUAL => try self.write("==\n    sete al\n"),
                .EXCLAMATION_EQUAL => try self.write("!=\n    setne al\n"),
                else => unreachable,
            }
            // Print common asm for all compares
            try self.print("    movzx {s}, al\n", .{lhs_reg.name});
            // Push lhs back on the stack
            self.pushCPUReg(lhs_reg);
        },
        // Integer operands
        else => {
            var lhs_reg: Register = undefined;
            var rhs_reg: Register = undefined;
            // Get register names, checking if reversed
            if (compareExpr.reversed) {
                lhs_reg = self.popCPUReg();
                rhs_reg = self.popCPUReg();
            } else {
                rhs_reg = self.popCPUReg();
                lhs_reg = self.popCPUReg();
            }

            // Print common asm for all compares
            try self.print("    cmp {s}, {s} ; INT ", .{ lhs_reg.name, rhs_reg.name });
            switch (compareExpr.op.kind) {
                .GREATER => try self.write(">\n    setg al\n"),
                .GREATER_EQUAL => try self.write(">=\n    setge al\n"),
                .LESS => try self.write("<\n    setl al\n"),
                .LESS_EQUAL => try self.write("<=\n    setle al\n"),
                .EQUAL_EQUAL => try self.write("==\n    sete al\n"),
                .EXCLAMATION_EQUAL => try self.write("!=\n    setne al\n"),
                else => unreachable,
            }
            // Print common asm for all compares
            try self.print("    movzx {s}, al\n", .{lhs_reg.name});
            // Push lhs register back on the stack
            self.pushCPUReg(lhs_reg);
        },
    }
}

/// Generator asm for a logical and expression
fn visitAndExpr(self: *Generator, andExpr: *Expr.AndExpr) GenerationError!void {
    // Left side
    try self.genExpr(andExpr.lhs);
    // Pop lhs of the or
    const lhs_reg = self.popCPUReg();

    // Get label counts
    const label_c = self.label_count;
    // Increment label
    self.label_count += 1;
    // Generate check for lhs
    try self.print(
        \\    test {s}, {s} ; Logical AND
        \\    jz .L{d}
        \\
    , .{ lhs_reg.name, lhs_reg.name, label_c });

    // Right side
    try self.genExpr(andExpr.rhs);
    // Write end of or jump label
    try self.print(".L{d}:\n", .{label_c});
}

/// Generator asm for a logical or expression
fn visitOrExpr(self: *Generator, orExpr: *Expr.OrExpr) GenerationError!void {
    // Left side
    try self.genExpr(orExpr.lhs);
    // Pop lhs of the or
    const lhs_reg = self.popCPUReg();

    // Get label counts
    const label_c = self.label_count;
    // Increment label
    self.label_count += 1;
    // Generate check for lhs
    try self.print(
        \\    test {s}, {s} ; Logical OR
        \\    jnz .L{d}
        \\
    , .{ lhs_reg.name, lhs_reg.name, label_c });

    // Right side
    try self.genExpr(orExpr.rhs);
    // Write end of or jump label
    try self.print(".L{d}:\n", .{label_c});
}

/// Generate asm for an if expression
fn visitIfExpr(self: *Generator, ifExpr: *Expr.IfExpr, result_kind: KindId) GenerationError!void {
    // Evaluate the conditional
    try self.genExpr(ifExpr.conditional);

    // Get current cpu register for conditional value
    const conditional_reg = self.popCPUReg();
    // Get first label
    const label_c = self.label_count;
    // Increment it
    self.label_count += 1;
    // Write asm for jump
    try self.print(
        \\    test {s}, {s} ; If Expr
        \\    jz .L{d}
        \\
    , .{ conditional_reg.name, conditional_reg.name, label_c });

    // Generate the then branch
    try self.genExpr(ifExpr.then_branch);
    // Pop then branch register
    if (result_kind == .FLOAT32 or result_kind == .FLOAT64) {
        _ = self.popSSEReg();
    } else {
        _ = self.popCPUReg();
    }

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
    try self.print(".L{d}: ; End of If Expr\n", .{label_c2});
}
