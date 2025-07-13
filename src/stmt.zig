const std = @import("std");

// Constants, types, and Symbol import
const Symbol = @import("symbols.zig");
const Value = Symbol.Value;
const KindId = Symbol.KindId;
// Token
const Token = @import("front_end/scanner.zig").Token;
// Expr
const Expr = @import("expr.zig");
const ExprNode = Expr.ExprNode;

pub const StmtNode = union(enum) {
    MOD: *ModStmt,
    USE: *UseStmt,
    GLOBAL: *GlobalStmt,
    MUTATE: *MutStmt,
    DECLARE: *DeclareStmt,
    EXPRESSION: *ExprStmt,
    WHILE: *WhileStmt,
    BLOCK: *BlockStmt,
    IF: *IfStmt,
    BREAK: *BreakStmt,
    CONTINUE: *ContinueStmt,
    FUNCTION: *FunctionStmt,
    RETURN: *ReturnStmt,
    STRUCT: *StructStmt,
    UNION: *UnionStmt,
    ENUM: *EnumStmt,
    SWITCH: *SwitchStmt,
    DEFER: *DeferStmt,
    FOR: *ForStmt,
    GENERIC: *GenericStmt,

    /// Deep copy a stmtnode
    pub fn copy(self: StmtNode, allocator: std.mem.Allocator) StmtNode {
        return switch (self) {
            .MOD => |modStmt| modStmt.copy(allocator),
            .USE => |useStmt| useStmt.copy(allocator),
            .GLOBAL => |globalStmt| globalStmt.copy(allocator),
            .MUTATE => |mutStmt| mutStmt.copy(allocator),
            .DECLARE => |declStmt| declStmt.copy(allocator),
            .EXPRESSION => |exprStmt| exprStmt.copy(allocator),
            .WHILE => |whileStmt| whileStmt.copy(allocator),
            .BLOCK => |blockStmt| blockStmt.copy(allocator),
            .IF => |ifStmt| ifStmt.copy(allocator),
            .BREAK => |breakStmt| breakStmt.copy(allocator),
            .CONTINUE => |contStmt| contStmt.copy(allocator),
            .FUNCTION => |funcStmt| funcStmt.copy(allocator),
            .UNION => |unionStmt| unionStmt.copy(allocator),
            .ENUM => |enumStmt| enumStmt.copy(allocator),
            .SWITCH => |switchStmt| switchStmt.copy(allocator),
            .DEFER => |deferStmt| deferStmt.copy(allocator),
            .FOR => |forStmt| forStmt.copy(allocator),
            .RETURN => |returnStmt| returnStmt.copy(allocator),
            .STRUCT => |structStmt| structStmt.copy(allocator),
            .GENERIC => unreachable,
        };
    }

    /// Display a stmt
    pub fn display(self: StmtNode) void {
        // Display based off of self
        switch (self) {
            .MOD => |modStmt| {
                if (modStmt.public) {
                    std.debug.print("pub ", .{});
                }
                std.debug.print("mod {s};\n", .{modStmt.module_name.lexeme});
            },
            .USE => |useStmt| {
                if (useStmt.public) {
                    std.debug.print("pub ", .{});
                }
                std.debug.print("use ", .{});
                useStmt.scopes.display();
                if (useStmt.rename) |name| {
                    std.debug.print("as {s}", .{name.lexeme});
                }
                std.debug.print(";\n", .{});
            },
            .GLOBAL => |globalStmt| {
                if (globalStmt.public) {
                    std.debug.print("pub ", .{});
                }
                if (globalStmt.mutable) {
                    std.debug.print("global var {s}", .{globalStmt.id.lexeme});
                } else {
                    std.debug.print("global const {s}", .{globalStmt.id.lexeme});
                }
                // Check if type is given
                if (globalStmt.kind) |kind| {
                    std.debug.print(": {any}", .{kind});
                }
                std.debug.print(" = ", .{});
                if (globalStmt.expr) |expr| {
                    expr.display();
                } else {
                    std.debug.print("undefined", .{});
                }
                std.debug.print(";\n", .{});
            },
            .MUTATE => |mutStmt| {
                mutStmt.id_expr.display();
                std.debug.print(" {s} ", .{mutStmt.op.lexeme});
                mutStmt.assign_expr.display();
                std.debug.print(";\n", .{});
            },
            .DECLARE => |declareStmt| {
                if (declareStmt.mutable) {
                    std.debug.print("var {s}", .{declareStmt.id.lexeme});
                } else {
                    std.debug.print("const {s}", .{declareStmt.id.lexeme});
                }
                // Check if type is given
                if (declareStmt.kind) |kind| {
                    std.debug.print(": {any}", .{kind});
                }
                std.debug.print(" = ", .{});
                if (declareStmt.expr) |expr| {
                    expr.display();
                } else {
                    std.debug.print("undefined", .{});
                }
                std.debug.print(";\n", .{});
            },
            .EXPRESSION => |exprStmt| {
                exprStmt.expr.display();
                std.debug.print(";\n", .{});
            },
            .WHILE => |whileStmt| {
                std.debug.print("while(", .{});
                whileStmt.conditional.display();
                std.debug.print(") ", .{});
                whileStmt.body.display();
                if (whileStmt.loop_stmt) |loop_stmt| {
                    std.debug.print(" loop ", .{});
                    loop_stmt.display();
                }
            },
            .IF => |ifStmt| {
                std.debug.print("if(", .{});
                ifStmt.conditional.display();
                std.debug.print(")", .{});
                ifStmt.then_branch.display();
                if (ifStmt.else_branch) |else_branch| {
                    std.debug.print("else ", .{});
                    else_branch.display();
                }
            },
            .BLOCK => |blockStmt| {
                std.debug.print("{{\n", .{});
                for (blockStmt.statements) |stmt| {
                    stmt.display();
                }
                std.debug.print("}}\n", .{});
            },
            .BREAK => {
                std.debug.print("break;\n", .{});
            },
            .CONTINUE => {
                std.debug.print("continue;\n", .{});
            },
            .FUNCTION => |funcStmt| {
                if (funcStmt.public) {
                    std.debug.print("pub ", .{});
                }
                std.debug.print("fn {s} (\n", .{funcStmt.name.lexeme});
                // Print args
                for (funcStmt.arg_names, funcStmt.arg_kinds) |name, kind| {
                    std.debug.print("    {s}: {any},\n", .{ name.lexeme, kind });
                }
                std.debug.print(") {any} ", .{funcStmt.return_kind});
                funcStmt.body.display();
            },
            .RETURN => |returnStmt| {
                std.debug.print("return", .{});
                if (returnStmt.expr) |expr| {
                    std.debug.print(" ", .{});
                    expr.display();
                }
                std.debug.print(";\n", .{});
            },
            .STRUCT => |structStmt| {
                if (structStmt.public) {
                    std.debug.print("pub ", .{});
                }
                std.debug.print("struct {s} {{\n", .{structStmt.id.lexeme});
                // Print Fields
                for (structStmt.field_names, structStmt.field_kinds) |name, kind| {
                    std.debug.print("    {s}: {any},\n", .{ name.lexeme, kind });
                }
                // Print Methods
                for (structStmt.methods) |method| {
                    method.display();
                }
                std.debug.print("}}\n", .{});
            },
            .ENUM => |enumStmt| {
                if (enumStmt.public) {
                    std.debug.print("pub ", .{});
                }
                std.debug.print("enum {s} {{\n", .{enumStmt.id.lexeme});
                for (enumStmt.variant_names) |variant| {
                    std.debug.print("    {s},\n", .{variant.lexeme});
                }
                std.debug.print("}}\n", .{});
            },
            .SWITCH => |switchStmt| {
                std.debug.print("switch (", .{});
                switchStmt.value.display();
                std.debug.print(") {{\n", .{});
                for (switchStmt.literal_branch_values, switchStmt.literal_branch_stmts) |values, stmt| {
                    std.debug.print("    ", .{});
                    values[0].display();
                    for (values[1..]) |val| {
                        std.debug.print(" | ", .{});
                        val.display();
                    }
                    std.debug.print(" => ", .{});
                    stmt.display();
                }
                if (switchStmt.else_branch) |stmt| {
                    std.debug.print("    else => ", .{});
                    stmt.display();
                }
                if (switchStmt.then_branch) |stmt| {
                    std.debug.print("    then => ", .{});
                    stmt.display();
                }
                std.debug.print("}}\n", .{});
            },
            .DEFER => |deferStmt| {
                std.debug.print("defer ", .{});
                deferStmt.stmt.display();
            },
            .FOR => |forStmt| forStmt.display(),
            .UNION => |unionStmt| unionStmt.display(),
            .GENERIC => |genericStmt| genericStmt.display(),
        }
    }
};

// ************** //
//   Stmt Structs //
// ************** //
/// Used to bring a module into the hierarchy
///
/// ModStmt -> "pub"? "use" identifier ";"
pub const ModStmt = struct {
    public: bool,
    op: Token,
    module_name: Token,

    pub fn init(public: bool, op: Token, module_name: Token) ModStmt {
        return ModStmt{
            .public = public,
            .op = op,
            .module_name = module_name,
        };
    }

    pub fn copy(self: ModStmt, allocator: std.mem.Allocator) StmtNode {
        const new_mod = allocator.create(ModStmt) catch unreachable;
        new_mod.* = self;
        return StmtNode{ .MOD = new_mod };
    }
};

/// Bring symbol into a module scope
///
/// useStmt -> "use" ScopeExpr|IdExpr ("as" IDENTIFIER) ;
pub const UseStmt = struct {
    op: Token,
    scopes: ExprNode,
    rename: ?Token,
    public: bool,
    imported: bool = false,

    pub fn init(op: Token, scopes: ExprNode, as_name: ?Token, is_public: bool) UseStmt {
        return UseStmt{
            .op = op,
            .scopes = scopes,
            .rename = as_name,
            .public = is_public,
        };
    }

    pub fn copy(self: UseStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(UseStmt) catch unreachable;
        new_stmt.* = UseStmt{
            .op = self.op,
            .scopes = self.scopes.copy(allocator),
            .rename = self.rename,
            .public = self.public,
            .imported = self.imported,
        };
        return StmtNode{ .USE = new_stmt };
    }
};

/// Used to store an MutExpr
/// MutStmt -> identifier "=" expression ";"
pub const MutStmt = struct {
    id_expr: ExprNode,
    op: Token,
    assign_expr: ExprNode,
    id_kind: KindId,

    /// Initialize an AssignStmt with an exprnode
    pub fn init(id_expr: ExprNode, op: Token, assign_expr: ExprNode) MutStmt {
        return MutStmt{
            .id_expr = id_expr,
            .op = op,
            .assign_expr = assign_expr,
            .id_kind = undefined,
        };
    }

    pub fn copy(self: MutStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(MutStmt) catch unreachable;
        new_stmt.* = MutStmt{
            .id_expr = self.id_expr.copy(allocator),
            .op = self.op,
            .assign_expr = self.assign_expr.copy(allocator),
            .id_kind = self.id_kind, // TODO figure out why self.id_kind.copy() causes problems????
        };
        return StmtNode{ .MUTATE = new_stmt };
    }
};

/// Used to store an GlobalStmt
/// GlobalStmt -> ("const"|"var") identifier (":" type)? "=" expression ";"
pub const GlobalStmt = struct {
    public: bool,
    mutable: bool,
    id: Token,
    kind: ?KindId,
    op: Token,
    expr: ?ExprNode,

    /// Initialize a GlobalStmt with an mutablity, identifier token, optional kind, and expr
    pub fn init(public: bool, mutable: bool, id: Token, kind: ?KindId, op: Token, expr: ?ExprNode) GlobalStmt {
        return GlobalStmt{
            .public = public,
            .mutable = mutable,
            .id = id,
            .kind = kind,
            .op = op,
            .expr = expr,
        };
    }

    pub fn copy(self: GlobalStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(GlobalStmt) catch unreachable;
        const new_expr = if (self.expr) |assign_expr| assign_expr.copy(allocator) else null;
        const new_kind = if (self.kind) |kind| kind.copy(allocator) else null;
        new_stmt.* = GlobalStmt{
            .public = self.public,
            .mutable = self.mutable,
            .id = self.id,
            .kind = new_kind,
            .op = self.op,
            .expr = new_expr,
        };
        return StmtNode{ .GLOBAL = new_stmt };
    }
};

/// Used to store a function stmt
/// FunctionStmt -> "fn" identifier '(' arglist? ')' type BlockStmt
/// arglist -> arg (',' arg)*
/// arg -> identifier ':' type
pub const FunctionStmt = struct {
    public: bool,
    op: Token,
    name: Token,
    arg_names: []Token,
    arg_kinds: []KindId,
    locals_size: u64,
    return_kind: KindId,
    body: StmtNode,

    /// Iniitalize a Function Statement
    pub fn init(public: bool, op: Token, name: Token, arg_names: []Token, arg_kinds: []KindId, return_kind: KindId, body: StmtNode) FunctionStmt {
        return FunctionStmt{
            .public = public,
            .op = op,
            .name = name,
            .arg_names = arg_names,
            .arg_kinds = arg_kinds,
            .locals_size = undefined,
            .return_kind = return_kind,
            .body = body,
        };
    }

    pub fn copy(self: FunctionStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(FunctionStmt) catch unreachable;
        const new_arg_kinds = allocator.alloc(KindId, self.arg_kinds.len) catch unreachable;
        for (0..new_arg_kinds.len) |i| {
            new_arg_kinds[i] = self.arg_kinds[i].copy(allocator);
        }
        new_stmt.* = FunctionStmt{
            .public = self.public,
            .op = self.op,
            .name = self.name,
            .arg_names = self.arg_names,
            .arg_kinds = new_arg_kinds,
            .locals_size = self.locals_size,
            .return_kind = self.return_kind.copy(allocator),
            .body = self.body.copy(allocator),
        };
        return StmtNode{ .FUNCTION = new_stmt };
    }

    /// Debug display
    fn display(self: FunctionStmt) void {
        std.debug.print("fn {s} (\n", .{self.name.lexeme});
        // Print args
        for (self.arg_names, self.arg_kinds) |name, kind| {
            std.debug.print("    {s}: {any},\n", .{ name.lexeme, kind });
        }
        std.debug.print(") {any} ", .{self.return_kind});
        self.body.display();
    }
};

/// Used to create a new KindId for a struct
/// StructStmt -> "struct" identifier '{' fieldlist '}'
/// FieldList -> (Field ';')+
/// Field -> identifier ':' KindId
pub const StructStmt = struct {
    public: bool,
    id: Token,
    field_names: []Token,
    field_kinds: []KindId,
    methods: []FunctionStmt,

    /// Initialize a structstmt
    pub fn init(public: bool, id: Token, field_names: []Token, field_kinds: []KindId, methods: []FunctionStmt) StructStmt {
        return StructStmt{
            .public = public,
            .id = id,
            .field_names = field_names,
            .field_kinds = field_kinds,
            .methods = methods,
        };
    }

    pub fn copy(self: StructStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(StructStmt) catch unreachable;
        const new_field_kinds = allocator.alloc(KindId, self.field_kinds.len) catch unreachable;
        for (0..new_field_kinds.len) |i| {
            new_field_kinds[i] = self.field_kinds[i].copy(allocator);
        }
        const new_methods = allocator.alloc(FunctionStmt, self.methods.len) catch unreachable;
        for (0..self.methods.len) |i| {
            new_methods[i] = self.methods[i].copy(allocator).FUNCTION.*;
        }
        new_stmt.* = StructStmt{
            .public = self.public,
            .id = self.id,
            .field_names = self.field_names,
            .field_kinds = new_field_kinds,
            .methods = new_methods,
        };
        return StmtNode{ .STRUCT = new_stmt };
    }
};

/// UnionStmt -> "union" Identifier '{' fieldlist '}'
/// FieldList -> (Field ';')+
/// Field -> identifier ':' KindId
pub const UnionStmt = struct {
    public: bool,
    id: Token,
    field_names: []Token,
    field_kinds: []KindId,

    pub fn init(public: bool, id: Token, field_names: []Token, field_kinds: []KindId) UnionStmt {
        return UnionStmt{
            .public = public,
            .id = id,
            .field_names = field_names,
            .field_kinds = field_kinds,
        };
    }

    pub fn copy(self: UnionStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(UnionStmt) catch unreachable;
        const new_field_kinds = allocator.alloc(KindId, self.field_kinds.len) catch unreachable;
        for (0..new_field_kinds.len) |i| {
            new_field_kinds[i] = self.field_kinds[i].copy(allocator);
        }
        new_stmt.* = UnionStmt{
            .public = self.public,
            .id = self.id,
            .field_names = self.field_names,
            .field_kinds = new_field_kinds,
        };
        return StmtNode{ .UNION = new_stmt };
    }

    pub fn display(self: *UnionStmt) void {
        if (self.public) {
            std.debug.print("pub ", .{});
        }
        std.debug.print("union {s} {{", .{self.id.lexeme});
        for (self.field_names, self.field_kinds) |name, kind| {
            std.debug.print("    {s}: {any};\n", .{ name.lexeme, kind });
        }
        std.debug.print("}}\n", .{});
    }
};

/// Used to store an DeclareStmt
/// DeclareStmt -> ("const"|"var") identifier (":" type)? "=" expression ";"
pub const DeclareStmt = struct {
    mutable: bool,
    id: Token,
    kind: ?KindId,
    op: Token,
    expr: ?ExprNode,
    stack_offset: u64,

    /// Initialize a DeclareStmt with an mutablity, identifier token, optional kind, and expr
    pub fn init(mutable: bool, id: Token, kind: ?KindId, op: Token, expr: ?ExprNode) DeclareStmt {
        return DeclareStmt{
            .mutable = mutable,
            .id = id,
            .kind = kind,
            .op = op,
            .expr = expr,
            .stack_offset = undefined,
        };
    }

    pub fn copy(self: DeclareStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(DeclareStmt) catch unreachable;
        const new_expr = if (self.expr) |assign_expr| assign_expr.copy(allocator) else null;
        const new_kind = if (self.kind) |kind| kind.copy(allocator) else null;
        new_stmt.* = DeclareStmt{
            .mutable = self.mutable,
            .id = self.id,
            .kind = new_kind,
            .op = self.op,
            .expr = new_expr,
            .stack_offset = self.stack_offset,
        };
        return StmtNode{ .DECLARE = new_stmt };
    }
};

/// Used to store an ExprStmt
/// exprstmt -> expression ";"
pub const ExprStmt = struct {
    expr: ExprNode,

    /// Initialize an expr stmt with an exprnode
    pub fn init(expr: ExprNode) ExprStmt {
        return ExprStmt{ .expr = expr };
    }

    pub fn copy(self: ExprStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(ExprStmt) catch unreachable;
        new_stmt.* = ExprStmt{
            .expr = self.expr.copy(allocator),
        };
        return StmtNode{ .EXPRESSION = new_stmt };
    }
};

/// Used to store a WhileStmt
/// whilestmt -> "while" '(' expression ')' statement ("loop " statemnt)?
pub const WhileStmt = struct {
    op: Token,
    conditional: ExprNode,
    body: StmtNode,
    loop_stmt: ?StmtNode,

    /// Initialize an expr stmt for while loop
    pub fn init(op: Token, conditional: ExprNode, body: StmtNode, loop_stmt: ?StmtNode) WhileStmt {
        return WhileStmt{
            .op = op,
            .conditional = conditional,
            .body = body,
            .loop_stmt = loop_stmt,
        };
    }

    pub fn copy(self: WhileStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(WhileStmt) catch unreachable;
        const new_loop_stmt = if (self.loop_stmt) |loop_stmt| loop_stmt.copy(allocator) else null;
        new_stmt.* = WhileStmt{
            .op = self.op,
            .conditional = self.conditional.copy(allocator),
            .body = self.body.copy(allocator),
            .loop_stmt = new_loop_stmt,
        };
        return StmtNode{ .WHILE = new_stmt };
    }
};

/// Used to store an IfStmt
/// ifstmt -> "if" '(' expression ')' statement ("else" statement)?
pub const IfStmt = struct {
    op: Token,
    conditional: ExprNode,
    then_branch: StmtNode,
    else_branch: ?StmtNode,

    /// Initialize an expr stmt for while loop
    pub fn init(op: Token, conditional: ExprNode, then_branch: StmtNode, else_branch: ?StmtNode) IfStmt {
        return IfStmt{
            .op = op,
            .conditional = conditional,
            .then_branch = then_branch,
            .else_branch = else_branch,
        };
    }

    pub fn copy(self: IfStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(IfStmt) catch unreachable;
        const new_else_branch = if (self.else_branch) |else_branch| else_branch.copy(allocator) else null;
        new_stmt.* = IfStmt{
            .op = self.op,
            .conditional = self.conditional.copy(allocator),
            .then_branch = self.then_branch.copy(allocator),
            .else_branch = new_else_branch,
        };
        return StmtNode{ .IF = new_stmt };
    }
};

/// Used to store a blockstmt
/// blockstmt -> '{' statement? '}'
pub const BlockStmt = struct {
    statements: []StmtNode,

    /// Initialize a block stmt
    pub fn init(statements: []StmtNode) BlockStmt {
        return BlockStmt{ .statements = statements };
    }

    pub fn copy(self: BlockStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(BlockStmt) catch unreachable;
        const new_statements = allocator.alloc(StmtNode, self.statements.len) catch unreachable;
        for (0..self.statements.len) |i| {
            new_statements[i] = self.statements[i].copy(allocator);
        }
        new_stmt.* = BlockStmt{ .statements = new_statements };
        return StmtNode{ .BLOCK = new_stmt };
    }
};

/// Used to store a continue stmt
/// continuestmt -> "continue" ';'
pub const ContinueStmt = struct {
    op: Token,

    /// Initialize a continue stmt
    pub fn init(op: Token) ContinueStmt {
        return ContinueStmt{ .op = op };
    }

    pub fn copy(self: *ContinueStmt, allocator: std.mem.Allocator) StmtNode {
        _ = allocator;
        return StmtNode{ .CONTINUE = self };
    }
};

/// Used to store a break stmt
/// breakstmt -> "break" ';'
pub const BreakStmt = struct {
    op: Token,

    /// Initialize a BreakStmt
    pub fn init(op: Token) BreakStmt {
        return BreakStmt{ .op = op };
    }

    pub fn copy(self: *BreakStmt, allocator: std.mem.Allocator) StmtNode {
        _ = allocator;
        return StmtNode{ .BREAK = self };
    }
};

/// Used to store a return stmt
/// returnStmt -> "return" expression? ';'
pub const ReturnStmt = struct {
    op: Token,
    expr: ?ExprNode,
    struct_ptr: ?usize = null,

    /// Initialize a ReturnStmt
    pub fn init(op: Token, expr: ?ExprNode) ReturnStmt {
        return ReturnStmt{
            .op = op,
            .expr = expr,
        };
    }

    pub fn copy(self: ReturnStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(ReturnStmt) catch unreachable;
        const new_expr = if (self.expr) |return_expr| return_expr.copy(allocator) else null;
        new_stmt.* = ReturnStmt{
            .op = self.op,
            .expr = new_expr,
            .struct_ptr = self.struct_ptr,
        };
        return StmtNode{ .RETURN = new_stmt };
    }
};

/// Used to store an enum
///
/// - enumStmt -> "enum" { variants_list }
/// - variants_list -> variant (, variant)?
/// - variant -> identifier
pub const EnumStmt = struct {
    public: bool,
    id: Token,
    variant_names: []Token,

    pub fn init(public: bool, id: Token, variants: []Token) EnumStmt {
        return EnumStmt{
            .public = public,
            .id = id,
            .variant_names = variants,
        };
    }

    pub fn copy(self: *EnumStmt, allocator: std.mem.Allocator) StmtNode {
        _ = allocator;
        return StmtNode{ .ENUM = self };
    }
};

/// Used to check integers and enums
///
/// Does not check for exhaustiveness
///
/// - switchStmt -> switch ( expr ) { branch (,branch)? }
/// - branch -> literalBranch | elseBranch | finalBranch
/// - literalBranch -> (Literal | EnumVariant) ("|" (Literal | EnumVariant))? => stmt
/// - elseBranch -> else => stmt,
/// - finalBranch -> final => stmt,
pub const SwitchStmt = struct {
    op: Token,
    value: ExprNode,
    literal_branch_values: [][]ExprNode,
    arrows: []Token,
    literal_branch_stmts: []StmtNode,
    else_branch: ?StmtNode,
    then_branch: ?StmtNode,

    pub fn init(op: Token, value: ExprNode, literal_branch_values: [][]ExprNode, arrows: []Token, literal_branch_stmts: []StmtNode, else_branch: ?StmtNode, then_branch: ?StmtNode) SwitchStmt {
        return SwitchStmt{
            .op = op,
            .value = value,
            .literal_branch_values = literal_branch_values,
            .arrows = arrows,
            .literal_branch_stmts = literal_branch_stmts,
            .else_branch = else_branch,
            .then_branch = then_branch,
        };
    }

    pub fn copy(self: SwitchStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(SwitchStmt) catch unreachable;
        const new_else_branch = if (self.else_branch) |else_branch| else_branch.copy(allocator) else null;
        const new_then_branch = if (self.then_branch) |then_branch| then_branch.copy(allocator) else null;
        const new_literal_branch_stmts = allocator.alloc(StmtNode, self.literal_branch_stmts.len) catch unreachable;
        const new_literal_branch_values = allocator.alloc([]ExprNode, self.literal_branch_values.len) catch unreachable;
        for (0..self.literal_branch_stmts.len) |i| {
            new_literal_branch_stmts[i] = self.literal_branch_stmts[i].copy(allocator);
            new_literal_branch_values[i] = allocator.alloc(ExprNode, self.literal_branch_values[i].len) catch unreachable;
            for (0..self.literal_branch_values[i].len) |l| {
                new_literal_branch_values[i][l] = self.literal_branch_values[i][l].copy(allocator);
            }
        }
        new_stmt.* = SwitchStmt{
            .op = self.op,
            .value = self.value.copy(allocator),
            .literal_branch_values = new_literal_branch_values,
            .arrows = self.arrows,
            .literal_branch_stmts = new_literal_branch_stmts,
            .else_branch = new_else_branch,
            .then_branch = new_then_branch,
        };
        return StmtNode{ .SWITCH = new_stmt };
    }
};

/// Used to defer a statement until the end of the current block
///
/// deferStmt -> defer statement
pub const DeferStmt = struct {
    op: Token,
    stmt: StmtNode,

    pub fn init(op: Token, stmt: StmtNode) DeferStmt {
        return DeferStmt{
            .op = op,
            .stmt = stmt,
        };
    }

    pub fn copy(self: DeferStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(DeferStmt) catch unreachable;
        new_stmt.* = DeferStmt{
            .op = self.op,
            .stmt = self.stmt.copy(allocator),
        };
        return StmtNode{ .DEFER = new_stmt };
    }
};

/// Sugar syntax for while loop
///
/// forStmt -> for (EXPR .. EXPR (, PTR)?) |IDENTIFIER (, IDENTIFIER)?| statement
pub const ForStmt = struct {
    op: Token,
    range_start_expr: ExprNode,
    range_end_expr: ExprNode,
    pointer_expr: ?ExprNode,
    range_id: Token,
    pointer_id: ?Token,
    body: StmtNode,
    inclusive: bool,
    range_id_offset: usize = undefined,
    range_end_id_offset: usize = undefined,
    pointer_id_offset: usize = undefined,

    pub fn init(
        op: Token,
        range_start_expr: ExprNode,
        range_end_expr: ExprNode,
        pointer_expr: ?ExprNode,
        range_id: Token,
        pointer_id: ?Token,
        body: StmtNode,
        inclusive: bool,
    ) ForStmt {
        return ForStmt{
            .op = op,
            .range_start_expr = range_start_expr,
            .range_end_expr = range_end_expr,
            .pointer_expr = pointer_expr,
            .range_id = range_id,
            .pointer_id = pointer_id,
            .body = body,
            .inclusive = inclusive,
        };
    }

    pub fn copy(self: ForStmt, allocator: std.mem.Allocator) StmtNode {
        const new_stmt = allocator.create(ForStmt) catch unreachable;
        const new_ptr_expr = if (self.pointer_expr) |ptr_expr| ptr_expr.copy(allocator) else null;
        new_stmt.* = ForStmt{
            .op = self.op,
            .range_start_expr = self.range_start_expr.copy(allocator),
            .range_end_expr = self.range_end_expr.copy(allocator),
            .pointer_expr = new_ptr_expr,
            .range_id = self.range_id,
            .pointer_id = self.pointer_id,
            .body = self.body.copy(allocator),
            .inclusive = self.inclusive,
            .range_id_offset = self.range_id_offset,
            .range_end_id_offset = self.range_end_id_offset,
            .pointer_id_offset = self.pointer_id_offset,
        };
        return StmtNode{ .FOR = new_stmt };
    }

    pub fn display(self: ForStmt) void {
        std.debug.print("for (", .{});
        self.range_start_expr.display();
        std.debug.print("..", .{});
        if (self.inclusive) {
            std.debug.print("=", .{});
        }
        self.range_end_expr.display();

        if (self.pointer_expr) |expr| {
            std.debug.print(", ", .{});
            expr.display();
        }

        std.debug.print(") |{s}", .{self.range_id.lexeme});
        if (self.pointer_id) |id| {
            std.debug.print(", {s}", .{id.lexeme});
        }
        std.debug.print("| ", .{});
        self.body.display();
    }
};

pub const GenericStmt = struct {
    op: Token,
    generic_names: []Token,
    body: StmtNode,

    pub fn init(op: Token, generic_names: []Token, body: StmtNode) GenericStmt {
        return GenericStmt{
            .op = op,
            .generic_names = generic_names,
            .body = body,
        };
    }

    pub fn display(self: GenericStmt) void {
        std.debug.print("<", .{});
        for (self.generic_names) |name| {
            std.debug.print("{s},", .{name.lexeme});
        }
        std.debug.print(">{{\n", .{});
        self.body.display();
        std.debug.print("}}\n", .{});
    }
};
