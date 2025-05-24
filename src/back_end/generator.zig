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
const BaseWriterType = @typeInfo(@TypeOf(std.fs.File.writer)).@"fn".return_type orelse void;
const BufferedWriterType = std.io.BufferedWriter(4096, BaseWriterType);
const WriterType = @typeInfo(@TypeOf(BufferedWriterType.writer)).@"fn".return_type orelse void;

// Useful Constants
const DWORD_IMIN: i64 = -0x80000000;
const DWORD_IMAX: i64 = 0x7FFFFFFF;
const DWORD_UMAX: u64 = 0xFFFFFFFF;
// Register names for cpu 64 bit
const cpu_reg_names = [_][]const u8{ "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15" };
// Alternate sized cpu register names
pub const cpu_reg_names_32bit = [_][]const u8{ "esi", "edi", "r8d", "r9d", "r10d", "r11d", "r12d", "r13d", "r14d", "r15d" };
pub const cpu_reg_names_16bit = [_][]const u8{ "si", "di", "r8w", "r9w", "r10w", "r11w", "r12w", "r13w", "r14w", "r15w" };
pub const cpu_reg_names_8bit = [_][]const u8{ "sil", "dil", "r8b", "r9b", "r10b", "r11b", "r12b", "r13b", "r14b", "r15b" };
// Floating point
const sse_reg_names = [_][]const u8{ "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7" };

/// Used to turn an AST into assembly
const Generator = @This();
// Fields
file: std.fs.File,
buffered_writer_ptr: *BufferedWriterType,
writer: WriterType,
stm: *STM,
module_path: []const u8,

// Label counters
/// Used in the generation of if statement labels
label_count: usize,
/// Used for break statements jump point
break_label: usize,
/// Used for continue statements jump point
continue_label: usize,
/// Used for jumping to return at end of functions
return_label: usize,

// Access helpers
current_func_locals_size: usize,
current_func_args_size: usize,
// Current stack alignment for current function
func_stack_alignment: usize,

// Register count
cpu_reg_stack: RegisterStack(cpu_reg_names),
sse_reg_stack: RegisterStack(sse_reg_names),

pub fn open(
    allocator: std.mem.Allocator,
    stm: *STM,
    root_path: []const u8,
    path: []const u8,
    module_path: []const u8,
    module_kind: Module.ModuleKind,
    extern_dependencies: std.StringHashMap(void),
) !Generator {
    const dir = try std.fs.openDirAbsolute(root_path, .{});
    const file = try dir.createFile(path, .{ .read = true });
    const base_writer_ptr = allocator.create(BaseWriterType) catch unreachable;
    const buffered_writer_ptr = allocator.create(BufferedWriterType) catch unreachable;
    base_writer_ptr.* = file.writer();
    buffered_writer_ptr.* = std.io.bufferedWriter(base_writer_ptr.*);
    var writer = buffered_writer_ptr.*.writer();

    _ = try writer.write("default rel\n");

    if (module_kind == .ROOT) {
        _ = try writer.write("global _start\n");
    }

    var symbol_iter = stm.scopes.items[0].symbols.iterator();
    while (symbol_iter.next()) |entry| {
        const symbol = entry.value_ptr;
        if (symbol.public and symbol.used) {
            switch (symbol.scope) {
                .GLOBAL, .FUNC => _ = try writer.print("global {s}\n", .{symbol.name}),
                .STRUCT => {
                    var field_iter = symbol.kind.STRUCT.fields.fields.iterator();
                    while (field_iter.next()) |field_entry| {
                        const field = field_entry.value_ptr;
                        if (field.public and field.used) {
                            switch (field.scope) {
                                .GLOBAL, .FUNC => _ = try writer.print("global {s}\n", .{field.name}),
                                else => {},
                            }
                        }
                    }
                },
                else => {},
            }
        }
    }

    // Write all external imports from modules
    var extern_iter = extern_dependencies.iterator();
    while (extern_iter.next()) |entry| {
        const import = entry.key_ptr.*;
        try writer.print("extern {s}\n", .{import});
    }

    _ = try writer.write("section .text\n");

    if (module_kind == .ROOT) {
        // Set up file header
        const header =
            \\_start:
            \\    ; Setup main args
            \\    sub rsp, 40
            \\    call GetCommandLineW ; Get Full string
            \\
            \\    mov rcx, rax
            \\    lea rdx, [@ARGC]
            \\    call CommandLineToArgvW ; Split into wide substrings
            \\    add rsp, 40
            \\    mov [@ARGV], rax
            \\
            \\    xor ebx, ebx
            \\    xor esi, esi
            \\    mov rdi, [@ARGC]
            \\.BUFFER_SIZE_START:
            \\    cmp rsi, rdi ; Test if i is less than argc
            \\    jae .BUFFER_SIZE_END
            \\    mov rcx, 65001
            \\    xor edx, edx
            \\    mov r8, [@ARGV]
            \\    mov r8, [r8+rsi*8]
            \\    mov r9, -1
            \\    push 0
            \\    push 0
            \\    push 0
            \\    push 0
            \\    sub rsp, 40
            \\    call WideCharToMultiByte ; Get the length of current argv[i] conversion
            \\    add rsp, 72
            \\    inc rax
            \\    add rbx, rax
            \\    inc rsi
            \\    jmp .BUFFER_SIZE_START
            \\.BUFFER_SIZE_END:
            \\
            \\    mov rcx, rbx
            \\    sub rsp, 40
            \\    call malloc ; Allocate space for argv buffer
            \\    add rsp, 40
            \\    mov [@ARG_BUFFER], rax
            \\
            \\    xor esi, esi ; arg count
            \\    xor edi, edi ; total length
            \\.BUFFER_MAKE_START:
            \\    cmp rsi, [@ARGC] ; Test if i is less than argc
            \\    jae .BUFFER_MAKE_END
            \\    mov rcx, 65001
            \\    xor edx, edx
            \\    mov r8, [@ARGV]
            \\    mov r8, [r8+rsi*8]
            \\    mov r9, -1
            \\    push 0
            \\    push 0
            \\    push 0
            \\    push rbx
            \\    mov r15, [@ARG_BUFFER]
            \\    lea r15, [r15+rdi]
            \\    push r15
            \\    sub rsp, 32
            \\    call WideCharToMultiByte ; Convert argv[i] to utf8
            \\    inc rax
            \\    mov r14, [rsp+32]
            \\    mov r15, [@ARGV]
            \\    mov [r15+rsi*8], r14
            \\    add rsp, 72
            \\    add rdi, rax
            \\    inc rsi
            \\    jmp .BUFFER_MAKE_START
            \\.BUFFER_MAKE_END:
            \\    mov rcx, [@ARGC]
            \\    mov rdx, [@ARGV]
            \\
            \\    sub rsp, 16
            \\    mov [rsp], rcx
            \\    mov [rsp+8], rdx
            \\
            \\    ; Setup clock
            \\    push rax
            \\    mov rcx, rsp
            \\    sub rsp, 32
            \\    call QueryPerformanceCounter
            \\    add rsp, 32
            \\    pop qword [@CLOCK_START]
            \\
            \\    ; Global Declarations
            \\
        ;
        _ = try writer.write(header);
    }

    return .{
        .file = file,
        .buffered_writer_ptr = buffered_writer_ptr,
        .writer = writer,
        .stm = stm,
        .module_path = module_path,
        .label_count = 0,
        .break_label = undefined,
        .continue_label = undefined,
        .return_label = undefined,
        .current_func_locals_size = undefined,
        .current_func_args_size = undefined,
        .func_stack_alignment = 0,
        .cpu_reg_stack = RegisterStack(cpu_reg_names).init(),
        .sse_reg_stack = RegisterStack(sse_reg_names).init(),
    };
}

pub fn close(self: Generator) GenerationError!void {
    // Write end of file
    try self.write(
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
        if (native.value_ptr.used and native.value_ptr.inline_gen == null) {
            _ = try self.write(native.value_ptr.source);
        }
    }

    // Write .data section
    try self.write(
        \\
        \\section .data
        \\    ; Native Constants and Dependencies;
        \\    @SS_SIGN_BIT: dq 0x80000000, 0, 0, 0
        \\    @SD_SIGN_BIT: dq 0x8000000000000000, 0, 0, 0
        \\    extern QueryPerformanceCounter
        \\    extern GetCommandLineW
        \\    extern CommandLineToArgvW
        \\    extern WideCharToMultiByte
        \\    extern malloc
        \\    extern free
        \\    extern ExitProcess
        \\
    );

    // Write native data
    // Write native functions source
    native_func = self.stm.natives_table.natives_table.iterator();
    // Go through each
    while (native_func.next()) |native| {
        if (native.value_ptr.used) {
            if (native.value_ptr.data) |data| {
                try self.print("{s}\n", .{data});
            }
        }
    }

    // Write the program defined constants section
    try self.write("\n    ; Program Constants ;\n");
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
                    try self.print("    {s}: db `{s}`, 0\n", .{ name, string });
                },
                else => unreachable,
            }
        }
    }

    // Write global variables to bss section
    try self.write(
        \\section .bss
        \\    @CLOCK_START: resb 8
        \\    @ARGC: resb 8
        \\    @ARGV: resb 8
        \\    @ARG_BUFFER: resb 8
        \\
        \\    ; Program Globals ;
        \\
    );
    // Reset scope stack
    self.stm.resetStack();
    var global_iter = self.stm.active_scope.symbols.iterator();
    // Write each variable to the file
    while (global_iter.next()) |global_entry| {
        // Extract global
        const global = global_entry.value_ptr;
        // Write to file if not function and used
        if (global.scope == .GLOBAL and global.used and self.stm.parent_module == global.source_module) {
            try self.print("    {s}: resb {d}\n", .{ global.name, global.size });
        }
    }

    // Flush buffer
    self.buffered_writer_ptr.*.flush() catch return GenerationError.FailedToWrite;
    // Close file
    self.file.close();
}

/// Walk the ast, generating ASM
pub fn genModule(self: *Generator, module: Module) GenerationError!void {
    // Reset STM stack
    self.stm.resetStack();

    if (module.kind == .ROOT) {
        // Generate all statements in the module
        for (module.globalSlice()) |global| {
            try self.visitGlobalStmt(global.GLOBAL.*);
        }

        // Call main
        try self.write("\n    call __main ; Execute main\n");
        // Write exit
        try self.write(
            \\    add rsp, 16
            \\    push rax
            \\
            \\    mov rcx, [@ARG_BUFFER]
            \\    sub rsp, 32
            \\    call free
            \\    add rsp, 32
            \\
            \\    mov rcx, [rsp]
            \\    call ExitProcess
            \\    ret
            \\
            \\    
        );
    }

    // Generate all methods for each struct in the module
    for (module.structSlice()) |strct| {
        const struct_sym = self.stm.peakSymbol(strct.STRUCT.id.lexeme) catch unreachable;
        for (strct.STRUCT.methods) |method| {
            const method_field = struct_sym.kind.STRUCT.fields.peakField(method.name.lexeme) catch unreachable;
            try self.visitFunctionStmt(method, method_field.kind.FUNC.args_size, method_field.used, method_field.name);
        }
    }

    // Generate all functions in the module
    for (module.functionSlice()) |function| {
        const function_sym = self.stm.peakSymbol(function.FUNCTION.name.lexeme) catch unreachable;
        try self.visitFunctionStmt(function.FUNCTION.*, function_sym.kind.FUNC.args_size, function_sym.used, function_sym.name);
    }
}

// ********************** //
// Private helper methods //
// ********************** //

/// Returns the realigned next address for the stack
fn realignStack(next_address: u64, size: u64) u64 {
    // Get allignment of data size
    const alignment: u64 = if (size > 4) 8 else if (size > 2) 4 else if (size > 1) 2 else 1;
    const offset = next_address & (alignment - 1);

    // Check if needs to be realigned
    if (offset != 0) {
        return next_address + (alignment - offset);
    }
    // Is already aligned
    return next_address;
}

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
pub inline fn write(self: Generator, msg: []const u8) GenerationError!void {
    _ = self.writer.write(msg) catch return GenerationError.FailedToWrite;
}
/// Helper methods, uses the writer to output to the asm file
/// Takes in fmt and things to put in
pub inline fn print(self: Generator, fmt: []const u8, data: anytype) GenerationError!void {
    self.writer.print(fmt, data) catch return GenerationError.FailedToWrite;
}

/// Get the current cpu register name
pub fn getCurrCPUReg(self: *Generator) Register {
    return self.cpu_reg_stack.current();
}

/// Get the current sse register name
pub fn getCurrSSEReg(self: *Generator) Register {
    return self.sse_reg_stack.current();
}

/// Get the next cpu register name.
/// Increment the cpu register 'stack', throwing an error if no more registers
pub fn getNextCPUReg(self: *Generator) GenerationError!Register {
    return self.cpu_reg_stack.loadNew();
}

/// Get the next sse register name.
/// Increment the sse register 'stack', throwing an error if no more registers
pub fn getNextSSEReg(self: *Generator) GenerationError!Register {
    return self.sse_reg_stack.loadNew();
}

/// Pop the current cpu register
pub fn popCPUReg(self: *Generator) Register {
    return self.cpu_reg_stack.pop();
}

/// Push a register onto the cpu register stack
pub fn pushCPUReg(self: *Generator, reg: Register) void {
    return self.cpu_reg_stack.push(reg);
}

/// Push a register onto the sse register stack
pub fn pushSSEReg(self: *Generator, reg: Register) void {
    return self.sse_reg_stack.push(reg);
}

/// Pop the current sse register
pub fn popSSEReg(self: *Generator) Register {
    return self.sse_reg_stack.pop();
}

/// Store all active cpu registers onto the stack.
/// Useful to use before function calls
fn storeCPUReg(self: *Generator) GenerationError!usize {
    // Store register count
    const reg_count = self.cpu_reg_stack.count;

    for (0..reg_count) |_| {
        const reg = self.popCPUReg();
        try self.print("    push {s}\n", .{reg.name});
    }
    // Update stack alignment
    self.func_stack_alignment += 8 * reg_count;
    // Return count
    return reg_count;
}

/// Store all active sse registers onto the stack.
/// Useful to use before function calls
fn storeSSEReg(self: *Generator) GenerationError!usize {
    // Store register count
    const reg_count = self.sse_reg_stack.count;

    for (0..reg_count) |_| {
        const reg = self.popSSEReg();
        try self.print("    sub rsp, 8\n movq [rsp], {s}\n", .{reg.name});
    }
    // Update stack alignment
    self.func_stack_alignment += 8 * reg_count;
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
    // Update stack alignment
    self.func_stack_alignment -= 8 * reg_count;
}

/// Pop all stored sse registers from the stack.
/// Used after storeCPUReg
fn restoreSSEReg(self: *Generator, reg_count: usize) GenerationError!void {
    for (0..reg_count) |_| {
        const reg = try self.getNextSSEReg();
        try self.print("    movq {s}, [rsp]\n    add rsp, 8\n", .{reg.name});
    }
    // Update stack alignment
    self.func_stack_alignment -= 8 * reg_count;
}

// ********************** //
// Stmt anaylsis  methods //
// ********************** //
/// Determine the type of stmt and call appropriate helper function
fn genStmt(self: *Generator, stmt: StmtNode) GenerationError!void {
    // Determine kind of stmt
    switch (stmt) {
        .EXPRESSION => |exprStmt| try self.visitExprStmt(exprStmt.*),
        .DECLARE => |declareStmt| try self.visitDeclareStmt(declareStmt.*),
        .MUTATE => |mutStmt| try self.visitMutateStmt(mutStmt.*),
        .WHILE => |whileStmt| try self.visitWhileStmt(whileStmt.*),
        .IF => |ifStmt| try self.visitIfStmt(ifStmt.*),
        .RETURN => |returnStmt| try self.visitReturnStmt(returnStmt.*),
        .BLOCK => |blockStmt| try self.visitBlockStmt(blockStmt.*),
        .BREAK => |breakStmt| try self.visitBreakStmt(breakStmt.*),
        .CONTINUE => |continueStmt| try self.visitContinueStmt(continueStmt.*),
        else => unreachable,
    }
}

/// Generate the asm for a global declare stmt
fn visitGlobalStmt(self: *Generator, globalStmt: Stmt.GlobalStmt) GenerationError!void {
    // Get the symbol
    const identifier = self.stm.peakSymbol(globalStmt.id.lexeme) catch unreachable;
    // If not used, do not generate
    if (!identifier.used) {
        return;
    }

    if (globalStmt.expr) |define_expr| {
        // Generate expression
        try self.genExpr(define_expr);

        // Pop register based on result type
        const result_kind = define_expr.result_kind;
        switch (result_kind) {
            .FLOAT32 => {
                const reg = self.popSSEReg();
                try self.print("    movss [{s}], {s} ; Declare identifier\n", .{ identifier.name, reg.name });
            },
            .FLOAT64 => {
                const reg = self.popSSEReg();
                try self.print("    movsd [{s}], {s} ; Declare identifier\n", .{ identifier.name, reg.name });
            },
            .STRUCT => {
                const reg = self.popCPUReg();
                const struct_size = globalStmt.kind.?.size();
                const global_reg = Register{.name = identifier.name, .index = cpu_reg_names.len + 1};
                try self.copy_struct(global_reg, reg, struct_size, 0);
            },
            else => {
                // Get size and size keyword
                const size = globalStmt.kind.?.size_runtime();
                // Get register
                const reg = self.popCPUReg();
                // Get properly sized register
                const sized_reg = getSizedCPUReg(reg.index, size);

                // Write assignment
                try self.print("    mov [{s}], {s} ; Declare identifier\n", .{ identifier.name, sized_reg });
            },
        }
    }
}

/// Generate the asm for a function declaration
fn visitFunctionStmt(self: *Generator, functionStmt: Stmt.FunctionStmt, args_size: usize, used: bool, name: []const u8) GenerationError!void {
    // Do not generate if not used
    if (!used) {
        self.stm.next_scope += functionStmt.scope_count;
        return;
    }

    self.current_func_args_size = args_size;
    // Get locals stack size
    const locals_size = functionStmt.locals_size + ((8 - (functionStmt.locals_size & 7)) & 7);
    self.current_func_locals_size = locals_size;
    // Enter scope
    self.stm.pushScope();

    self.func_stack_alignment = 0;

    // Write the functions label
    try self.print("\n{s}:\n", .{name});
    // Allocate stack space for locals
    if (locals_size > 0) {
        try self.print("    sub rsp, {d} ; Reserve locals space\n", .{locals_size});
        self.func_stack_alignment += locals_size;
    }
    // Generate label for return
    self.return_label = self.label_count;
    self.label_count += 1;

    // Push rbp and move rsp to rbp
    try self.write("    push rbp\n    mov rbp, rsp\n");
    self.func_stack_alignment += 8;

    // Generate body
    try self.genStmt(functionStmt.body);

    // Generate default return null
    try self.write("    xor eax, eax\n");

    // Generate return stmt
    try self.print(".L{d}:\n", .{self.return_label});
    // If void return, zero out rax
    if (functionStmt.return_kind == .VOID) {
        try self.write("    xor eax, eax\n");
    }
    // Pop rbp
    try self.write("    pop rbp\n");
    self.func_stack_alignment -= 8;
    // Free locals and return
    if (locals_size > 0) {
        try self.print("    add rsp, {d}\n", .{locals_size});
        self.func_stack_alignment -= locals_size;
    }
    try self.write("    ret\n");

    // Exit scope
    self.stm.popScope();
}

/// Generate the asm for a declare stmt
fn visitDeclareStmt(self: *Generator, declareStmt: Stmt.DeclareStmt) GenerationError!void {
    // If defined, generate
    if (declareStmt.expr) |define_expr| {
        // Generate expression
        try self.genExpr(define_expr);
        // Get stack offset
        const offset = declareStmt.stack_offset - self.current_func_args_size;

        // Pop register based on result type
        const result_kind = define_expr.result_kind;

        switch (result_kind) {
            .FLOAT32 => {
                const reg = self.popSSEReg();
                try self.print("    movss [rbp + {d}], {s} ; Declare identifier\n", .{ offset, reg.name });
            },
            .FLOAT64 => {
                const reg = self.popSSEReg();
                try self.print("    movsd [rbp + {d}], {s} ; Declare identifier\n", .{ offset, reg.name });
            },
            .STRUCT => {
                const expr_reg = self.popCPUReg();
                const struct_size = result_kind.size();
                const rbp_reg = Register{.name = "rbp", .index = cpu_reg_names.len + 1};
                try self.copy_struct(rbp_reg, expr_reg, struct_size, offset);
            },
            else => {
                // Get size and size keyword
                const size = declareStmt.kind.?.size_runtime();
                // Get register
                const reg = self.popCPUReg();
                // Get properly sized register
                const sized_reg = getSizedCPUReg(reg.index, size);

                // Write assignment
                try self.print("    mov [rbp + {d}], {s} ; Declare identifier\n", .{ offset, sized_reg });
            },
        }
    }
}

/// Generate the asm for a block stmt
fn visitBlockStmt(self: *Generator, blockStmt: Stmt.BlockStmt) GenerationError!void {
    // Push scope
    self.stm.pushScope();
    // Generate each statement
    for (blockStmt.statements) |stmt| {
        try self.genStmt(stmt);
    }

    // Pop scope
    self.stm.popScope();
}

/// Generate the asm for an expr stmt
fn visitExprStmt(self: *Generator, exprStmt: Stmt.ExprStmt) GenerationError!void {
    // Generate the stored exprnode
    try self.genExpr(exprStmt.expr);
    // Pop last register, based on if float or not
    const result_kind = exprStmt.expr.result_kind;
    if (result_kind == .FLOAT32 or result_kind == .FLOAT64) {
        _ = self.popSSEReg();
    } else {
        _ = self.popCPUReg();
    }
}

/// Generate the asm for a mutate stmt
fn visitMutateStmt(self: *Generator, mutStmt: Stmt.MutStmt) GenerationError!void {
    // Generate the assignment expression
    try self.genExpr(mutStmt.assign_expr);
    // Generate the id expression
    try self.genIDExpr(mutStmt.id_expr);

    // Pop id of the stack
    const id_reg = self.popCPUReg();
    // Check if result is a float or not
    if (mutStmt.id_kind == .FLOAT32) {
        // Get register
        const expr_reg = self.popSSEReg();
        // Check if '='
        if (mutStmt.op.kind == .EQUAL) {
            // Write to memory
            try self.print("    movd [{s}], {s} ; Mutate\n", .{ id_reg.name, expr_reg.name });
        } else {
            // Check op type
            switch (mutStmt.op.kind) {
                .PLUS_EQUAL => {
                    try self.print("    addss {s}, [{s}] ; Mutate\n", .{ expr_reg.name, id_reg.name });
                    try self.print("    movd [{s}], {s}\n", .{ id_reg.name, expr_reg.name });
                },
                .MINUS_EQUAL => {
                    try self.print("    subss {s}, [{s}] ; Mutate\n", .{ expr_reg.name, id_reg.name });
                    try self.print("    movd [{s}], {s}\n", .{ id_reg.name, expr_reg.name });
                },
                .STAR_EQUAL => {
                    try self.print("    mulss {s}, [{s}] ; Mutate\n", .{ expr_reg.name, id_reg.name });
                    try self.print("    movd [{s}], {s}\n", .{ id_reg.name, expr_reg.name });
                },
                .SLASH_EQUAL => {
                    // Get temp register after expr_reg
                    _ = try self.getNextSSEReg();
                    _ = try self.getNextSSEReg();
                    const temp_reg = self.popSSEReg();
                    _ = self.popSSEReg();
                    try self.print("    movss {s}, [{s}] ; Mutate\n", .{ temp_reg.name, id_reg.name });
                    try self.print("    divss {s}, {s}\n", .{ temp_reg.name, expr_reg.name });
                    try self.print("    movd [{s}], {s}\n", .{ id_reg.name, temp_reg.name });
                },
                .CARET_EQUAL => {
                    // Get temp register after expr_reg
                    _ = try self.getNextSSEReg();
                    _ = try self.getNextSSEReg();
                    const temp_reg = self.popSSEReg();
                    _ = self.popSSEReg();
                    try self.print("    movsd {s}, [{s}] ; Mutate\n", .{ temp_reg.name, id_reg.name });
                    try self.print("    xorps {s}, {s}\n", .{ temp_reg.name, expr_reg.name });
                    try self.print("    movd [{s}], {s}\n", .{ id_reg.name, temp_reg.name });
                },
                .AMPERSAND_EQUAL => {
                    // Get temp register after expr_reg
                    _ = try self.getNextSSEReg();
                    _ = try self.getNextSSEReg();
                    const temp_reg = self.popSSEReg();
                    _ = self.popSSEReg();
                    try self.print("    movsd {s}, [{s}] ; Mutate\n", .{ temp_reg.name, id_reg.name });
                    try self.print("    andps {s}, {s}\n", .{ temp_reg.name, expr_reg.name });
                    try self.print("    movd [{s}], {s}\n", .{ id_reg.name, temp_reg.name });
                },
                .PIPE_EQUAL => {
                    // Get temp register after expr_reg
                    _ = try self.getNextSSEReg();
                    _ = try self.getNextSSEReg();
                    const temp_reg = self.popSSEReg();
                    _ = self.popSSEReg();
                    try self.print("    movsd {s}, [{s}] ; Mutate\n", .{ temp_reg.name, id_reg.name });
                    try self.print("    orps {s}, {s}\n", .{ temp_reg.name, expr_reg.name });
                    try self.print("    movd [{s}], {s}\n", .{ id_reg.name, temp_reg.name });
                },
                else => unreachable,
            }
        }
    } else if (mutStmt.id_kind == .FLOAT64) {
        // Get register
        const expr_reg = self.popSSEReg();
        // Check if '='
        if (mutStmt.op.kind == .EQUAL) {
            // Write to memory
            try self.print("    movq [{s}], {s} ; Mutate\n", .{ id_reg.name, expr_reg.name });
        } else {
            // Check op type
            switch (mutStmt.op.kind) {
                .PLUS_EQUAL => {
                    try self.print("    addsd {s}, [{s}] ; Mutate\n", .{ expr_reg.name, id_reg.name });
                    try self.print("    movq [{s}], {s}\n", .{ id_reg.name, expr_reg.name });
                },
                .MINUS_EQUAL => {
                    try self.print("    subsd {s}, [{s}] ; Mutate\n", .{ expr_reg.name, id_reg.name });
                    try self.print("    movq [{s}], {s}\n", .{ id_reg.name, expr_reg.name });
                },
                .STAR_EQUAL => {
                    try self.print("    mulsd {s}, [{s}] ; Mutate\n", .{ expr_reg.name, id_reg.name });
                    try self.print("    movq [{s}], {s}\n", .{ id_reg.name, expr_reg.name });
                },
                .SLASH_EQUAL => {
                    // Get temp register after expr_reg
                    _ = try self.getNextSSEReg();
                    _ = try self.getNextSSEReg();
                    const temp_reg = self.popSSEReg();
                    _ = self.popSSEReg();
                    try self.print("    movsd {s}, [{s}] ; Mutate\n", .{ temp_reg.name, id_reg.name });
                    try self.print("    divsd {s}, {s}\n", .{ temp_reg.name, expr_reg.name });
                    try self.print("    movq [{s}], {s}\n", .{ id_reg.name, temp_reg.name });
                },
                .CARET_EQUAL => {
                    // Get temp register after expr_reg
                    _ = try self.getNextSSEReg();
                    _ = try self.getNextSSEReg();
                    const temp_reg = self.popSSEReg();
                    _ = self.popSSEReg();
                    try self.print("    movsd {s}, [{s}] ; Mutate\n", .{ temp_reg.name, id_reg.name });
                    try self.print("    xorps {s}, {s}\n", .{ temp_reg.name, expr_reg.name });
                    try self.print("    movq [{s}], {s}\n", .{ id_reg.name, temp_reg.name });
                },
                .AMPERSAND_EQUAL => {
                    // Get temp register after expr_reg
                    _ = try self.getNextSSEReg();
                    _ = try self.getNextSSEReg();
                    const temp_reg = self.popSSEReg();
                    _ = self.popSSEReg();
                    try self.print("    movsd {s}, [{s}] ; Mutate\n", .{ temp_reg.name, id_reg.name });
                    try self.print("    andps {s}, {s}\n", .{ temp_reg.name, expr_reg.name });
                    try self.print("    movq [{s}], {s}\n", .{ id_reg.name, temp_reg.name });
                },
                .PIPE_EQUAL => {
                    // Get temp register after expr_reg
                    _ = try self.getNextSSEReg();
                    _ = try self.getNextSSEReg();
                    const temp_reg = self.popSSEReg();
                    _ = self.popSSEReg();
                    try self.print("    movsd {s}, [{s}] ; Mutate\n", .{ temp_reg.name, id_reg.name });
                    try self.print("    orps {s}, {s}\n", .{ temp_reg.name, expr_reg.name });
                    try self.print("    movq [{s}], {s}\n", .{ id_reg.name, temp_reg.name });
                },
                else => unreachable,
            }
        }
    } else if (mutStmt.id_kind == .STRUCT) {
        const expr_reg = self.popCPUReg();
        const struct_size = mutStmt.id_kind.size();
        try self.copy_struct(id_reg, expr_reg, struct_size, 0);
    } else {
        // Get register
        const expr_reg = self.popCPUReg();
        // Get sized reg
        const size = mutStmt.id_kind.size_runtime();
        const sized_reg = getSizedCPUReg(expr_reg.index, size);
        // Check op type
        switch (mutStmt.op.kind) {
            .EQUAL => try self.print("    mov [{s}], {s} ; Mutate\n", .{ id_reg.name, sized_reg }),
            .PLUS_EQUAL => try self.print("    add [{s}], {s} ; Mutate\n", .{ id_reg.name, sized_reg }),
            .MINUS_EQUAL => try self.print("    sub [{s}], {s} ; Mutate\n", .{ id_reg.name, sized_reg }),
            .STAR_EQUAL => {
                const size_keyword = getSizeKeyword(size);
                const sized_rax = switch (size) {
                    1 => "al",
                    2 => "ax",
                    4 => "eax",
                    else => "rax", ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                };
                try self.print(
                    \\    xor rax, rax ; Mutate    
                    \\    mov {s}, {s} [{s}]
                    \\    imul {s}, {s}
                    \\    mov [{s}], {s}
                    \\
                , .{ sized_rax, size_keyword, id_reg.name, sized_reg, sized_rax, id_reg.name, sized_reg });
            },
            .SLASH_EQUAL => {
                const size_keyword = getSizeKeyword(size);
                try self.print(
                    \\    xor rax, rax ; Mutate
                    \\    mov rax, {s} [{s}]
                    \\    xor edx, edx
                    \\    idiv {s}
                    \\    mov [{s}], rax
                    \\
                , .{ size_keyword, id_reg.name, expr_reg.name, id_reg.name });
            },
            .PERCENT_EQUAL => {
                const size_keyword = getSizeKeyword(size);
                try self.print(
                    \\    xor rax, rax ; Mutate
                    \\    mov rax, {s} [{s}]
                    \\    xor edx, edx
                    \\    idiv {s}
                    \\    mov [{s}], rdx
                    \\
                , .{ size_keyword, id_reg.name, expr_reg.name, id_reg.name });
            },
            .CARET_EQUAL => try self.print("    xor [{s}], {s} ; Mutate\n", .{ id_reg.name, sized_reg }),
            .AMPERSAND_EQUAL => try self.print("    and [{s}], {s} ; Mutate\n", .{ id_reg.name, sized_reg }),
            .PIPE_EQUAL => try self.print("    or [{s}], {s} ; Mutate\n", .{ id_reg.name, sized_reg }),
            else => unreachable,
        }
    }
}

/// Generate the asm for a while loop
fn visitWhileStmt(self: *Generator, whileStmt: Stmt.WhileStmt) GenerationError!void {
    // Store old break label
    const old_break_label = self.break_label;
    // Get new label for end/outside of loop
    const exit_label = self.label_count;
    self.label_count += 1;
    // Update break label
    self.break_label = exit_label;

    // Generate the conditional once to jump over the loop if
    try self.genExpr(whileStmt.conditional);
    // Pop the value
    const jump_over_cond_reg = self.popCPUReg();
    // Generate conditional jump over
    try self.print(
        "    test {s}, {s} ; Exit check\n    jz .L{d}\n",
        .{ jump_over_cond_reg.name, jump_over_cond_reg.name, exit_label },
    );

    // Generate start of loop label
    const start_label = self.label_count;
    self.label_count += 1;
    try self.print(".L{d}:\n", .{start_label});

    // Store old continue label
    const old_cont_label = self.continue_label;
    // Generate the continue label
    const cont_label = self.label_count;
    self.label_count += 1;
    // Update cont label
    self.continue_label = cont_label;

    // Generate body
    try self.genStmt(whileStmt.body);

    // Write label for continue statements
    try self.print(".L{d}:\n", .{self.continue_label});
    // Check for loop stmt
    if (whileStmt.loop_stmt) |loop_stmt| {
        // Generate it
        try self.genStmt(loop_stmt);
    }

    // Write conditional again
    try self.genExpr(whileStmt.conditional);
    // Pop the value
    const body_cond_reg = self.popCPUReg();
    // Generate conditional jump over
    try self.print(
        "    test {s}, {s} ; Loop check\n    jnz .L{d}\n",
        .{ body_cond_reg.name, body_cond_reg.name, start_label },
    );

    // Generate exit label
    try self.print(".L{d}:\n", .{exit_label});
    // Set break label and continue label to old on
    self.break_label = old_break_label;
    self.continue_label = old_cont_label;
}

/// Generate an if statement
fn visitIfStmt(self: *Generator, ifStmt: Stmt.IfStmt) GenerationError!void {
    // Generate conditional
    try self.genExpr(ifStmt.conditional);

    // Get end of then branch label
    const else_label = self.label_count;
    self.label_count += 1;

    // Pop conditional register
    const cond_reg = self.popCPUReg();
    // Write jump over then branch check
    try self.print("    test {s}, {s}\n    jz .L{d}\n", .{ cond_reg.name, cond_reg.name, else_label });
    // Generate then branch
    try self.genStmt(ifStmt.then_branch);

    // Check for else branch
    if (ifStmt.else_branch) |else_branch| {
        // Get label for jump over else branch
        const if_end_label = self.label_count;
        self.label_count += 1;

        // Generate jump to end
        try self.print("    jmp .L{d}\n", .{if_end_label});
        // Generate then branch skip label
        try self.print(".L{d}:\n", .{else_label});

        // Generate else branch
        try self.genStmt(else_branch);
        // Write end of if label
        try self.print(".L{d}:\n", .{if_end_label});
    } else {
        // Generate then branch skip label
        try self.print(".L{d}:\n", .{else_label});
    }
}

/// Generate a return stmt
fn visitReturnStmt(self: *Generator, returnStmt: Stmt.ReturnStmt) GenerationError!void {
    // Determine if return expression provided
    if (returnStmt.expr) |return_expr| {
        // Generate it
        try self.genExpr(return_expr);

        // Move to rax
        switch (return_expr.result_kind) {
            .FLOAT32 => {
                // Get cpu register
                const reg = self.popSSEReg();
                try self.print("    movd rax, {s}\n", .{reg.name});
            },
            .FLOAT64 => {
                // Get cpu register
                const reg = self.popSSEReg();
                try self.print("    movq rax, {s}\n", .{reg.name});
            },
            else => {
                // Get cpu register
                const reg = self.popCPUReg();
                try self.print("    mov rax, {s}\n", .{reg.name});
            },
        }
    }
    // Jump to return label
    try self.print("    jmp .L{d}\n", .{self.return_label});
}

/// Generate the jump for a break stmt
fn visitBreakStmt(self: *Generator, breakStmt: Stmt.BreakStmt) GenerationError!void {
    _ = breakStmt;
    // Write jump
    try self.print("    jmp .L{d}\n", .{self.break_label});
}

/// Generate the jump for a continue stmt
fn visitContinueStmt(self: *Generator, continueStmt: Stmt.ContinueStmt) GenerationError!void {
    _ = continueStmt;
    // Write jump
    try self.print("    jmp .L{d}\n", .{self.continue_label});
}

// ********************** //
// Expr anaylsis  methods //
// ********************** //

/// Generate asm for the lhs of a mutate expression
fn genIDExpr(self: *Generator, node: ExprNode) GenerationError!void {
    // Determine the type of expr and analysis it
    switch (node.expr) {
        .IDENTIFIER => |idExpr| try self.visitIdentifierExprID(idExpr),
        .INDEX => |indexExpr| try self.visitIndexExprID(indexExpr),
        .DEREFERENCE => |derefExpr| try self.visitDereferenceExprID(derefExpr),
        .FIELD => |fieldExpr| try self.visitFieldExprID(fieldExpr),
        else => unreachable,
    }
}

/// Generate asm for an ExprNode
fn genExpr(self: *Generator, node: ExprNode) GenerationError!void {
    // Get result kind
    const result_kind = node.result_kind;
    // Determine the type of expr and analysis it
    switch (node.expr) {
        .SCOPE => unreachable,
        .IDENTIFIER => |idExpr| try self.visitIdentifierExpr(idExpr, result_kind),
        .LITERAL => |litExpr| try self.visitLiteralExpr(litExpr),
        .NATIVE => |nativeExpr| try self.visitNativeExpr(nativeExpr, result_kind),
        .CALL => |callExpr| try self.visitCallExpr(callExpr, result_kind),
        .CONVERSION => |convExpr| try self.visitConvExpr(convExpr, result_kind),
        .FIELD => |fieldExpr| try self.visitFieldExpr(fieldExpr, result_kind),
        .DEREFERENCE => |derefExpr| try self.visitDereferenceExpr(derefExpr, result_kind),
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

/// Generate the asm for an IdentifierExpr but for the lhs of an assignment
fn visitIdentifierExprID(self: *Generator, idExpr: *Expr.IdentifierExpr) GenerationError!void {
    // Get register to store pointer in
    const reg = try self.getNextCPUReg();
    // Get pointer to the identifier
    const id_name = idExpr.lexical_scope;

    // Access based on scope kind
    switch (idExpr.scope_kind) {
        .ARG => try self.print("    lea {s}, [rbp+{d}] ; Get Arg\n", .{ reg.name, idExpr.stack_offset + self.current_func_locals_size }),
        .LOCAL => try self.print("    lea {s}, [rbp+{d}] ; Get Local\n", .{ reg.name, idExpr.stack_offset - self.current_func_args_size }),
        .GLOBAL, .FUNC => try self.print("    lea {s}, [{s}] ; Get Global\n", .{ reg.name, id_name }),
        else => unreachable,
    }
}

/// Generate asm for an IDExpr
fn visitIdentifierExpr(self: *Generator, idExpr: *Expr.IdentifierExpr, result_kind: KindId) GenerationError!void {
    // Get size of kind
    const kind_size = result_kind.size_runtime();
    // Get keyword based on size
    const size_keyword = getSizeKeyword(kind_size);

    // Get stack offset based on scope kind
    const stack_offset: ?u64 = switch (idExpr.scope_kind) {
        .ARG => idExpr.stack_offset + self.current_func_locals_size,
        .LOCAL => idExpr.stack_offset - self.current_func_args_size,
        .GLOBAL, .FUNC => null,
        else => unreachable,
    };

    // If there is an offset, use it
    // Else treat as a global
    if (stack_offset) |offset| {
        // Generate as local/arg
        if (result_kind == .FLOAT32) {
            const reg = try self.getNextSSEReg();
            // Mov normally
            try self.print(
                "    movss {s}, {s} [rbp+{d}] ; Get Arg/Local\n",
                .{ reg.name, size_keyword, offset },
            );
        } else if (result_kind == .FLOAT64) {
            const reg = try self.getNextSSEReg();
            // Mov normally
            try self.print(
                "    movsd {s}, {s} [rbp+{d}] ; Get Arg/Local\n",
                .{ reg.name, size_keyword, offset },
            );
        } else if (result_kind == .ARRAY or result_kind == .STRUCT) {
            const reg = try self.getNextCPUReg();
            // Mov normally
            try self.print(
                "    lea {s}, {s} [rbp+{d}] ; Get Arg/Local\n",
                .{ reg.name, size_keyword, offset },
            );
        } else {
            const reg = try self.getNextCPUReg();
            // Check if size is 64 bit
            if (kind_size == 8) {
                // Mov normally
                try self.print(
                    "    mov {s}, {s} [rbp+{d}] ; Get Arg/Local\n",
                    .{ reg.name, size_keyword, offset },
                );
            } else {
                // Check if unsigned
                if (result_kind == .INT) {
                    // Move and extend sign bit
                    try self.print(
                        "    movsx {s}, {s} [rbp+{d}] ; Get Arg/Local\n",
                        .{ reg.name, size_keyword, offset },
                    );
                } else {
                    // Move and zero top
                    if (kind_size == 4) {
                        // Get resized register
                        const sized_reg = getSizedCPUReg(reg.index, 4);
                        try self.print(
                            "    mov {s}, {s} [rbp+{d}] ; Get Arg/Local\n",
                            .{ sized_reg, size_keyword, offset },
                        );
                    } else {
                        try self.print(
                            "    movzx {s}, {s} [rbp+{d}] ; Get Arg/Local\n",
                            .{ reg.name, size_keyword, offset },
                        );
                    }
                }
            }
        }
    } else {
        const path = idExpr.lexical_scope;

        if (result_kind == .FUNC) {
            const reg = try self.getNextCPUReg();
            // Write function pointer load
            try self.print("    lea {s}, [{s}] ; Get Function\n", .{ reg.name, path });
        } else if (result_kind == .FLOAT32) {
            const reg = try self.getNextSSEReg();
            // Mov normally
            try self.print(
                "    movss {s}, {s} [{s}] ; Get Global\n",
                .{ reg.name, size_keyword, path },
            );
        } else if (result_kind == .FLOAT64) {
            const reg = try self.getNextSSEReg();
            // Mov normally
            try self.print(
                "    movsd {s}, {s} [{s}] ; Get Global\n",
                .{ reg.name, size_keyword, path },
            );
        } else if (result_kind == .ARRAY or result_kind == .STRUCT) {
            const reg = try self.getNextCPUReg();
            // Mov normally
            try self.print(
                "    lea {s}, {s} [{s}] ; Get Global\n",
                .{ reg.name, size_keyword, path },
            );
        } else {
            const reg = try self.getNextCPUReg();
            // Check if size is 64 bit
            if (kind_size == 8) {
                // Mov normally
                try self.print(
                    "    mov {s}, {s} [{s}] ; Get Global\n",
                    .{ reg.name, size_keyword, path },
                );
            } else {
                // Check if unsigned
                if (result_kind == .INT) {
                    // Move and extend sign bit
                    try self.print(
                        "    movsx {s}, {s} [{s}] ; Get Global\n",
                        .{ reg.name, size_keyword, path },
                    );
                } else {
                    // Move and zero top
                    try self.print(
                        "    movzx {s}, {s} [{s}] ; Get Global\n",
                        .{ reg.name, size_keyword, path },
                    );
                }
            }
        }
    }
}

/// Generate asm for a LiteralExpr
fn visitLiteralExpr(self: *Generator, litExpr: *Expr.LiteralExpr) GenerationError!void {
    // Determine Value kind
    switch (litExpr.value.kind) {
        .NULLPTR => {
            // Get a new register
            const reg = try self.getNextCPUReg();
            try self.print("    mov {s}, 0 ; Load NULLPTR\n", .{reg.name});
        },
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
            try self.print("    lea {s}, [{s}]\n", .{ reg.name, lit_name });
        },
        else => unreachable,
    }
}

/// Generate asm for a native expr call
fn visitNativeExpr(self: *Generator, nativeExpr: *Expr.NativeExpr, result_kind: KindId) GenerationError!void {
    // Preserve current registers
    const cpu_reg_count = try self.storeCPUReg();
    const sse_reg_count = try self.storeSSEReg();

    // Holds active args
    var args: []ExprNode = undefined;
    args.len = 0;
    // Get natives name
    const native_name = nativeExpr.name.lexeme[1..];
    // Extract arguments
    const total_args = nativeExpr.args;

    // Remove any comptime only args
    const ct_arg_count = self.stm.natives_table.getComptimeArgCount(native_name);
    // Slice to remove args
    args = total_args[ct_arg_count..total_args.len];

    // Make space for all args
    self.func_stack_alignment += 8;
    self.func_stack_alignment += if (args.len > 4) (args.len - 4) * 8 else 0;
    const call_align = (16 - ((self.func_stack_alignment) % 16)) & 15;
    self.func_stack_alignment += call_align;
    const args_size = args.len * 8;
    const arg_space = args_size + call_align;
    if (arg_space > 0) {
        try self.print("    sub rsp, {d} ; Make space for native args\n", .{arg_space});
    }

    // Generate each arg
    for (args, 0..) |arg, count| {
        // Generate the arg expression
        try self.genExpr(arg);

        // Calculate stack position
        const stack_pos = count * 8;

        // Push onto the stack
        switch (arg.result_kind) {
            .BOOL => {
                // Get register and pop
                const reg = self.popCPUReg();
                // Insert arg based on size
                try self.print(
                    "    movzx {s}, {s}\n    mov [rsp+{d}], {s}\n",
                    .{ reg.name, cpu_reg_names_8bit[reg.index], stack_pos, reg.name },
                );
            },
            .UINT => |uint| {
                // Get register and pop
                const reg = self.popCPUReg();
                // Insert arg based on size
                switch (uint.size()) {
                    1 => try self.print(
                        "    movzx {s}, {s}\n    mov [rsp+{d}], {s}\n",
                        .{ reg.name, cpu_reg_names_8bit[reg.index], stack_pos, reg.name },
                    ),
                    2 => try self.print(
                        "    movzx {s}, {s}\n    mov [rsp+{d}], {s}\n",
                        .{ reg.name, cpu_reg_names_16bit[reg.index], stack_pos, reg.name },
                    ),
                    4 => try self.print(
                        "    mov {s}, {s}\n    mov [rsp+{d}], {s}\n",
                        .{ cpu_reg_names_32bit[reg.index], cpu_reg_names_32bit[reg.index], stack_pos, reg.name },
                    ),
                    else => try self.print("    mov [rsp+{d}], {s}\n", .{ stack_pos, reg.name }),
                }
            },
            .INT => |int| {
                // Get register and pop
                const reg = self.popCPUReg();
                // Insert arg based on size
                switch (int.size()) {
                    1 => try self.print(
                        "    movsx {s}, {s}\n    mov [rsp+{d}], {s}\n",
                        .{ reg.name, cpu_reg_names_8bit[reg.index], stack_pos, reg.name },
                    ),
                    2 => try self.print(
                        "    movsx {s}, {s}\n    mov [rsp+{d}], {s}\n",
                        .{ reg.name, cpu_reg_names_16bit[reg.index], stack_pos, reg.name },
                    ),
                    4 => try self.print(
                        "    movsx {s}, {s}\n    mov [rsp+{d}], {s}\n",
                        .{ reg.name, cpu_reg_names_32bit[reg.index], stack_pos, reg.name },
                    ),
                    else => try self.print("    mov [rsp+{d}], {s}\n", .{ stack_pos, reg.name }),
                }
            },
            .PTR, .FUNC => {
                // Get register and pop
                const reg = self.popCPUReg();
                try self.print("    mov [rsp+{d}], {s}\n", .{ stack_pos, reg.name });
            },
            .FLOAT32 => {
                // Get register and pop
                const reg = self.popSSEReg();
                try self.print(
                    "    xor eax, eax\n    movss rax, {s}\n    mov [rsp+{d}], rax\n",
                    .{ reg.name, stack_pos },
                );
            },
            .FLOAT64 => {
                // Get register and pop
                const reg = self.popSSEReg();
                try self.print("    movsd [rsp+{d}], {s}\n", .{ stack_pos, reg.name });
            },
            .VOID => {
                // Get register and pop
                const reg = self.popCPUReg();
                try self.print("    mov [rsp+{d}], {s}\n", .{ stack_pos, reg.name });
            },
            .ENUM => {
                // Get register and pop
                const reg = self.popCPUReg();
                try self.print(
                    "    movzx {s}, {s}\n    mov [rsp+{d}], {s}\n",
                    .{ reg.name, cpu_reg_names_16bit[reg.index], stack_pos, reg.name },
                );
            },
            else => unreachable,
        }
    }
    // Move first four args into registers
    if (args.len > 3) {
        // Pop two args
        _ = try self.write("    pop rcx\n    pop rdx\n    pop r8\n    pop r9\n");
    } else if (args.len == 3) {
        // Pop three args
        _ = try self.write("    pop rcx\n    pop rdx\n    pop r8\n");
    } else if (args.len == 2) {
        // Pop two args
        _ = try self.write("    pop rcx\n    pop rdx\n");
    } else if (args.len == 1) {
        // Pop one arg to proper register
        _ = try self.write("    pop rcx\n");
    }

    // Attempt to write inline
    const wrote_inline = try self.stm.natives_table.writeNativeInline(
        self,
        native_name,
        nativeExpr.arg_kinds,
    );

    // Check if inline or not
    if (!wrote_inline) {
        // Generate the call
        try self.print("    call {s}\n", .{nativeExpr.name.lexeme});
    }
    // Get pop size
    const pop_size = (if (args.len >= 4) (args.len - 4) * 8 else 0) + call_align;
    // Check if pop size is greater than 0
    if (pop_size > 0) {
        try self.print("    add rsp, {d}\n", .{pop_size});
        self.func_stack_alignment -= pop_size;
    }
    self.func_stack_alignment -= 8;

    // Pop registers back
    try self.restoreSSEReg(sse_reg_count);
    try self.restoreCPUReg(cpu_reg_count);
    // Put result into next register
    switch (result_kind) {
        .VOID, .BOOL, .UINT, .INT, .PTR, .FUNC, .ENUM => {
            // Get a new register
            const reg = try self.getNextCPUReg();
            try self.print("    mov {s}, rax\n", .{reg.name});
        },
        .FLOAT32 => {
            // Get a new register
            const reg = try self.getNextSSEReg();
            try self.print("    movq {s}, rax\n", .{reg.name});
        },
        .FLOAT64 => {
            // Get a new register
            const reg = try self.getNextSSEReg();
            try self.print("    movq {s}, rax\n", .{reg.name});
        },
        else => unreachable,
    }
}

/// Generate a user defined function call
fn visitCallExpr(self: *Generator, callExpr: *Expr.CallExpr, result_kind: KindId) GenerationError!void {
    // Generate the operand
    try self.genExpr(callExpr.caller_expr);
    // Get arguments size
    const args_size = callExpr.caller_expr.result_kind.FUNC.args_size;
    // Align it
    const args_size_aligned = args_size + 8;

    // Pop function pointer register
    const func_ptr_reg = self.popCPUReg();
    // Push register onto the stack
    const cpu_reg_count = try self.storeCPUReg();
    const sse_reg_count = try self.storeSSEReg();

    self.func_stack_alignment += args_size_aligned;
    const call_align = (16 - ((self.func_stack_alignment) % 16)) & 15;
    self.func_stack_alignment += call_align;
    const arg_space = args_size_aligned + call_align;
    // Reserve stack space
    if (arg_space > 8) {
        try self.print("    sub rsp, {d} ; Reserve call arg space\n", .{arg_space - 8});
    }
    // Move function ptr to top of stack
    try self.print("    push {s}\n", .{func_ptr_reg.name});
    // Update stack alignment
    self.func_stack_alignment += 8;

    // Store next address on the stack
    var next_address: u64 = 8;
    // Generate each argument
    for (callExpr.args) |arg| {
        // Generate arg
        try self.genExpr(arg);

        // Move onto stack based on size
        switch (arg.result_kind) {
            .BOOL => {
                // Get kind size
                const size = 1;
                // Pop cpu register
                const reg = self.popCPUReg();
                // Get sized register
                const sized_reg = getSizedCPUReg(reg.index, size);
                // Move to stack
                try self.print("    mov [rsp+{d}], {s}\n", .{ next_address, sized_reg });
                // Increment next address
                next_address += size;
            },
            .UINT => |uint| {
                // Get kind size
                const size = uint.size();
                // Check for alignment
                next_address = realignStack(next_address, size);

                // Pop cpu register
                const reg = self.popCPUReg();
                // Get sized register
                const sized_reg = getSizedCPUReg(reg.index, size);
                // Move to stack
                try self.print("    mov [rsp+{d}], {s}\n", .{ next_address, sized_reg });
                // Increment next address
                next_address += size;
            },
            .INT => |int| {
                // Get kind size
                const size = int.size();
                // Check for alignment
                next_address = realignStack(next_address, size);

                // Pop cpu register
                const reg = self.popCPUReg();
                // Get sized register
                const sized_reg = getSizedCPUReg(reg.index, size);
                // Move to stack
                try self.print("    mov [rsp+{d}], {s}\n", .{ next_address, sized_reg });
                // Increment next address
                next_address += size;
            },
            .FLOAT32 => {
                // Get kind size
                const size: u64 = 4;
                // Check for alignment
                next_address = realignStack(next_address, size);

                // Pop cpu register
                const reg = self.popSSEReg();
                // Move to stack
                try self.print("    movd [rsp+{d}], {s}\n", .{ next_address, reg.name });
                // Increment next address
                next_address += size;
            },
            .FLOAT64 => {
                // Get kind size
                const size: u64 = 8;
                // Check for alignment
                next_address = realignStack(next_address, size);

                // Pop cpu register
                const reg = self.popSSEReg();
                // Move to stack
                try self.print("    movq [rsp+{d}], {s}\n", .{ next_address, reg.name });
                // Increment next address
                next_address += size;
            },
            .PTR, .FUNC => {
                // Get kind size
                const size: u64 = 8;
                // Check for alignment
                next_address = realignStack(next_address, size);

                // Pop cpu register
                const reg = self.popCPUReg();
                // Move to stack
                try self.print("    mov [rsp+{d}], {s}\n", .{ next_address, reg.name });
                // Increment next address
                next_address += size;
            },
            .ENUM => {
                // Get kind size
                const size = 2;
                // Check for alignment
                next_address = realignStack(next_address, size);

                // Pop cpu register
                const reg = self.popCPUReg();
                // Get sized register
                const sized_reg = getSizedCPUReg(reg.index, size);
                // Move to stack
                try self.print("    mov [rsp+{d}], {s}\n", .{ next_address, sized_reg });
                // Increment next address
                next_address += size;
            },
            else => unreachable,
        }
    }

    // Generate call
    try self.write("    pop rcx\n    call rcx\n");
    self.func_stack_alignment -= 8;
    // Remove locals from stack
    if (arg_space > 8) {
        try self.print("    add rsp, {d}\n", .{arg_space - 8});
        self.func_stack_alignment -= arg_space;
    }

    // Restore registers
    try self.restoreSSEReg(sse_reg_count);
    try self.restoreCPUReg(cpu_reg_count);
    // Move result
    switch (result_kind) {
        .BOOL, .UINT, .INT, .PTR, .FUNC, .VOID, .ENUM => {
            // Get a new register
            const reg = try self.getNextCPUReg();
            try self.print("    mov {s}, rax\n", .{reg.name});
        },
        .FLOAT32 => {
            // Get a new register
            const reg = try self.getNextSSEReg();
            try self.print("    movq {s}, rax\n", .{reg.name});
        },
        .FLOAT64 => {
            // Get a new register
            const reg = try self.getNextSSEReg();
            try self.print("    movq {s}, rax\n", .{reg.name});
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
            switch (result_kind) {
                // Converting to FLOAT64
                .FLOAT64 => {
                    // Get register name
                    const src_reg = self.getCurrSSEReg();
                    try self.print("    cvtss2sd {s}, {s} ; F32 to F64\n", .{ src_reg.name, src_reg.name });
                },
                else => undefined,
            }
        },
        // Converting FROM FLOAT64
        .FLOAT64 => {
            switch (result_kind) {
                // Converting to FLOAT32 from FLOAT64
                .FLOAT32 => {
                    // Get register name
                    const src_reg = self.getCurrSSEReg();
                    try self.print("    cvtsd2ss {s}, {s} ; F64 to F32\n", .{ src_reg.name, src_reg.name });
                },
                else => undefined,
            }
        },
        // Non floating point source
        .BOOL, .UINT, .INT => {
            switch (result_kind) {
                // Converting to FLOAT64
                .FLOAT32 => {
                    // Get register name
                    const src_reg = self.popCPUReg();
                    // Get new F64 register
                    const target_reg = try self.getNextSSEReg();
                    try self.print("    cvtsi2ss {s}, {s} ; Non-floating point to F32\n", .{ target_reg.name, src_reg.name });
                },
                // Converting to FLOAT64
                .FLOAT64 => {
                    // Get register name
                    const src_reg = self.popCPUReg();
                    // Get new F64 register
                    const target_reg = try self.getNextSSEReg();
                    try self.print("    cvtsi2sd {s}, {s} ; Non-floating point to F64\n", .{ target_reg.name, src_reg.name });
                },
                else => undefined,
            }
        },
        else => undefined,
    }
}

/// Generate asm for a FieldExpr
fn visitFieldExprID(self: *Generator, fieldExpr: *Expr.FieldExpr) GenerationError!void {
    // Generate the lhs
    try self.genIDExpr(fieldExpr.operand);
    const source_reg = self.getCurrCPUReg();
    const offset = fieldExpr.stack_offset;
    // Generate the field offset access
    if (offset > 0) {
        try self.print("    lea {s}, [{s}+{d}] ; Field access\n", .{ source_reg.name, source_reg.name, offset });
    }
}

/// Generate asm for a FieldExpr
fn visitFieldExpr(self: *Generator, fieldExpr: *Expr.FieldExpr, result_kind: KindId) GenerationError!void {
    // Check if method
    if (fieldExpr.method_name) |name| {
        const dest_reg = try self.getNextCPUReg();
        try self.print("    lea {s}, [{s}] ; Method access\n", .{ dest_reg.name, name });
        return;
    }

    // Generate the lhs
    try self.genIDExpr(fieldExpr.operand);
    const source_reg = self.popCPUReg();
    const offset = fieldExpr.stack_offset;

    // Generate the field offset access
    switch (result_kind) {
        .FLOAT32 => {
            const dest_reg = try self.getNextSSEReg();
            try self.print("    movss {s}, [{s}+{d}] ; Field access\n", .{ dest_reg.name, source_reg.name, offset });
        },
        .FLOAT64 => {
            const dest_reg = try self.getNextSSEReg();
            try self.print("    movsd {s}, [{s}+{d}] ; Field access\n", .{ dest_reg.name, source_reg.name, offset });
        },
        else => {
            const reg = try self.getNextCPUReg();
            const kind_size = result_kind.size_runtime();
            const size_keyword = getSizeKeyword(kind_size);
            // Check if size is 64 bit
            if (kind_size == 8) {
                // Mov normally
                try self.print(
                    "    mov {s}, {s} [{s}+{d}] ; Field access\n",
                    .{ reg.name, size_keyword, source_reg.name, offset },
                );
            } else {
                // Check if unsigned
                if (result_kind == .INT) {
                    // Move and extend sign bit
                    try self.print(
                        "    movsx {s}, {s} [{s}+{d}] ; Field access\n",
                        .{ reg.name, size_keyword, source_reg.name, offset },
                    );
                } else {
                    // Move and zero top
                    if (kind_size == 4) {
                        // Get resized register
                        const sized_reg = getSizedCPUReg(reg.index, 4);
                        try self.print(
                            "    mov {s}, {s} [{s}+{d}] ; Field access\n",
                            .{ sized_reg, size_keyword, source_reg.name, offset },
                        );
                    } else {
                        try self.print(
                            "    movzx {s}, {s} [{s}+{d}] ; Field access\n",
                            .{ reg.name, size_keyword, source_reg.name, offset },
                        );
                    }
                }
            }
        },
    }
}

/// Generate asm for an indexExpr
fn visitIndexExprID(self: *Generator, indexExpr: *Expr.IndexExpr) GenerationError!void {
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

    // Get correct size kind for child
    const access_kind = if (indexExpr.reversed) indexExpr.rhs.result_kind else indexExpr.lhs.result_kind;
    // Check if array
    if (access_kind == .ARRAY) {
        // Write array offset * child size
        const child_size = access_kind.ARRAY.child.size();
        try self.print("    imul {s}, {d}\n", .{ rhs_reg.name, child_size });
        try self.print("    lea {s}, [{s}+{s}] ; Array Index\n", .{ lhs_reg.name, lhs_reg.name, rhs_reg.name });
    } else {
        const child_size = access_kind.PTR.child.size();
        try self.print("    imul {s}, {d}\n", .{ rhs_reg.name, child_size });
        // LEA the address
        try self.print("    lea {s}, [{s}+{s}] ; Ptr Index\n", .{ lhs_reg.name, lhs_reg.name, rhs_reg.name });
    }

    // Push lhs_reg back onto stack
    self.pushCPUReg(lhs_reg);
}

/// Generate asm for a dereference expr, in ID expression
fn visitDereferenceExprID(self: *Generator, derefExpr: *Expr.DereferenceExpr) GenerationError!void {
    // Generate the operand
    try self.genExpr(derefExpr.operand);
}

/// Generate asm for a dereference expr
fn visitDereferenceExpr(self: *Generator, derefExpr: *Expr.DereferenceExpr, result_kind: KindId) GenerationError!void {
    // Generate the operand
    try self.genExpr(derefExpr.operand);
    // Dereference the pointer
    const source_reg = self.popCPUReg();

    switch (result_kind) {
        .FLOAT32 => {
            const dest_reg = try self.getNextSSEReg();
            try self.print("    movss {s}, [{s}] ; Dereference Pointer\n", .{ dest_reg.name, source_reg.name });
        },
        .FLOAT64 => {
            const dest_reg = try self.getNextSSEReg();
            try self.print("    movsd {s}, [{s}] ; Dereference Pointer\n", .{ dest_reg.name, source_reg.name });
        },
        else => {
            const dest_reg = try self.getNextCPUReg();
            try self.print("    mov {s}, [{s}] ; Dereference Pointer\n", .{ dest_reg.name, source_reg.name });
        },
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

    // Get correct size kind for child
    const access_kind = if (indexExpr.reversed) indexExpr.rhs.result_kind else indexExpr.lhs.result_kind;
    // Check if array
    if (access_kind == .ARRAY) {
        // Write array offset * child size
        const child_size = access_kind.ARRAY.child.size();
        // Multiply address by child_size
        try self.print("    imul {s}, {d}\n", .{ rhs_reg.name, child_size });
        // Check if float 32
        if (result_kind == .FLOAT32) {
            // Get floating register
            const result_reg = try self.getNextSSEReg();
            // Write index access
            try self.print(
                "    movss {s}, [{s}+{s}]\n ; Array Index",
                .{ result_reg.name, lhs_reg.name, rhs_reg.name },
            );
        } else if (result_kind == .FLOAT64) {
            // Get floating register
            const result_reg = try self.getNextSSEReg();
            // Write index access
            try self.print(
                "    movsd {s}, [{s}+{s}] ; Array Index\n",
                .{ result_reg.name, lhs_reg.name, rhs_reg.name },
            );
        } else {
            // Get the size of the result
            const size = result_kind.size();
            const size_keyword = getSizeKeyword(size);
            // Push lhs_reg back on the stack
            const result_reg = try self.getNextCPUReg();

            // If size is 8 normal, else special size keyword
            if (size == 8) {
                // Write index access
                try self.print(
                    "    mov {s}, [{s}+{s}] ; Array Index\n",
                    .{ result_reg.name, lhs_reg.name, rhs_reg.name },
                );
            } else {
                // Get operation kind
                const op_char: u8 = if (result_kind == .UINT) 'z' else 's';
                // Write index access
                try self.print(
                    "    mov{c}x {s}, {s} [{s}+{s}] ; Array Index\n",
                    .{ op_char, result_reg.name, size_keyword, lhs_reg.name, rhs_reg.name },
                );
            }
        }
    } else {
        const child_size = access_kind.PTR.child.size_runtime();
        // Multiply index by child_size
        try self.print("    imul {s}, {d}\n", .{ rhs_reg.name, child_size });
        // Check if float 32
        if (result_kind == .FLOAT32) {
            // Get floating register
            const result_reg = try self.getNextSSEReg();
            // Write index access
            try self.print("    movss {s}, [{s}+{s}] ; Ptr Index\n", .{ result_reg.name, lhs_reg.name, rhs_reg.name });
        } else if (result_kind == .FLOAT64) {
            // Get floating register
            const result_reg = try self.getNextSSEReg();
            // Write index access
            try self.print("    movsd {s}, [{s}+{s}] ; Ptr Index\n", .{ result_reg.name, lhs_reg.name, rhs_reg.name });
        } else {
            // Get the size of the result
            const size = result_kind.size_runtime();
            const size_keyword = getSizeKeyword(size);
            // Push lhs_reg back on the stack
            const result_reg = try self.getNextCPUReg();

            // If size is 8 normal, else special size keyword
            if (size == 8) {
                // Write index access
                try self.print("    mov {s}, [{s}+{s}] ; Ptr Index\n", .{ result_reg.name, lhs_reg.name, rhs_reg.name });
            } else {
                // Get operation kind
                const op_char: u8 = if (result_kind == .UINT) 'z' else 's';
                // Write index access
                try self.print(
                    "    mov{c}x {s}, {s} [{s}+{s}] ; Ptr Index\n",
                    .{ op_char, result_reg.name, size_keyword, lhs_reg.name, rhs_reg.name },
                );
            }
        }
    }
}

/// Generate asm for a UnaryExpr
fn visitUnaryExpr(self: *Generator, unaryExpr: *Expr.UnaryExpr) GenerationError!void {
    // Check if operand is '&'
    if (unaryExpr.op.kind == .AMPERSAND) {
        try self.genIDExpr(unaryExpr.operand);
        return;
    }

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

            // Zero out top parts of registers if necessary
            const lhs_size = compareExpr.lhs.result_kind.size_runtime();
            if (lhs_size != 8) {
                const sized_reg = getSizedCPUReg(lhs_reg.index, lhs_size);
                if (lhs_size == 4) {
                    try self.print("    mov {s}, {s}\n", .{ sized_reg, sized_reg });
                } else {
                    try self.print("    movzx {s}, {s}\n", .{ lhs_reg.name, sized_reg });
                }
            }
            // Zero out top parts of registers if necessary
            const rhs_size = compareExpr.rhs.result_kind.size_runtime();
            if (rhs_size != 8) {
                const sized_reg = getSizedCPUReg(rhs_reg.index, rhs_size);
                if (lhs_size == 4) {
                    try self.print("    mov {s}, {s}\n", .{ sized_reg, sized_reg });
                } else {
                    try self.print("    movzx {s}, {s}\n", .{ rhs_reg.name, sized_reg });
                }
            }

            // Print common asm for all compares
            try self.print("    cmp {s}, {s} ; UINT ", .{ lhs_reg.name, rhs_reg.name });
            switch (compareExpr.op.kind) {
                .GREATER => try self.write(">\n    seta al\n"),
                .GREATER_EQUAL => try self.write(">=\n    setae al\n"),
                .LESS => try self.write("<\n    setb al\n"),
                .LESS_EQUAL => try self.write("<=\n    setbe al\n"),
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

            // Zero out top parts of registers if necessary
            const lhs_size = compareExpr.lhs.result_kind.size_runtime();
            if (lhs_size != 8) {
                const sized_reg = getSizedCPUReg(lhs_reg.index, lhs_size);
                try self.print("    movsx {s}, {s}\n", .{ lhs_reg.name, sized_reg });
            }
            // Zero out top parts of registers if necessary
            const rhs_size = compareExpr.rhs.result_kind.size_runtime();
            if (rhs_size != 8) {
                const sized_reg = getSizedCPUReg(rhs_reg.index, rhs_size);
                try self.print("    movsx {s}, {s}\n", .{ rhs_reg.name, sized_reg });
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

// Helper functions for common patterns
fn copy_struct(self: *Generator, output_reg: Register, input_reg: Register, struct_size: usize, offset: usize) GenerationError!void {
    var amt_copied: usize = 0;

    const output_8byte_reg = if (output_reg.index > cpu_reg_names.len) output_reg.name else getSizedCPUReg(output_reg.index, 8);
    while (amt_copied + 8 <= struct_size) {
        const relative_offset = amt_copied + offset;
        try self.print("    mov rax, [{s}+{d}]\n", .{input_reg.name, amt_copied});
        try self.print("    mov [{s}+{d}], rax\n", .{output_8byte_reg, relative_offset});
        amt_copied += 8;
    }

    if (amt_copied + 4 <= struct_size) {
        const output_4byte_reg = if (output_reg.index > cpu_reg_names.len) output_reg.name else getSizedCPUReg(output_reg.index, 4);
        const relative_offset = amt_copied + offset;
        try self.print("    mov eax, [{s}+{d}]\n", .{input_reg.name, amt_copied});
        try self.print("    mov [{s}+{d}], eax\n", .{output_4byte_reg, relative_offset});
        amt_copied += 4;
    }

    if (amt_copied + 2 <= struct_size) {
        const output_2byte_reg = if (output_reg.index > cpu_reg_names.len) output_reg.name else getSizedCPUReg(output_reg.index, 2);
        const relative_offset = amt_copied + offset;
        try self.print("    mov ax, [{s}+{d}]\n", .{input_reg.name, amt_copied});
        try self.print("    mov [{s}+{d}], ax\n", .{output_2byte_reg, relative_offset});
        amt_copied += 2;
    }

    if (amt_copied + 1 <= struct_size) {
        const output_1byte_reg = if (output_reg.index > cpu_reg_names.len) output_reg.name else getSizedCPUReg(output_reg.index, 1);
        const relative_offset = amt_copied + offset;
        try self.print("    mov ax, [{s}+{d}]\n", .{input_reg.name, amt_copied});
        try self.print("    mov [{s}+{d}], ax\n", .{output_1byte_reg, relative_offset});
        amt_copied += 1;
    }

    std.debug.assert(amt_copied == struct_size);
}
