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
    ENUM: *EnumStmt,
    SWITCH: *SwitchStmt,

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
};

/// Used to store a function stmt
/// FunctionStmt -> "fn" identifier '(' arglist? ')' type BlockStmt
/// arglist -> arg (',' arg)*
/// arg -> identifier ':' type
pub const FunctionStmt = struct {
    /// Used to store an argument
    pub const Arg = struct {
        name: Token,
        kind: KindId,
    };
    // Fields
    public: bool,
    op: Token,
    name: Token,
    arg_names: []Token,
    arg_kinds: []KindId,
    locals_size: u64,
    return_kind: KindId,
    body: StmtNode,
    scope_count: u16 = 0,

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
};

/// Used to store an ExprStmt
/// exprstmt -> expression ";"
pub const ExprStmt = struct {
    expr: ExprNode,

    /// Initialize an expr stmt with an exprnode
    pub fn init(expr: ExprNode) ExprStmt {
        return ExprStmt{ .expr = expr };
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
};

/// Used to store a blockstmt
/// blockstmt -> '{' statement? '}'
pub const BlockStmt = struct {
    statements: []StmtNode,

    /// Initialize a block stmt
    pub fn init(statements: []StmtNode) BlockStmt {
        return BlockStmt{ .statements = statements };
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
};

/// Used to store a break stmt
/// breakstmt -> "break" ';'
pub const BreakStmt = struct {
    op: Token,

    /// Initialize a BreakStmt
    pub fn init(op: Token) BreakStmt {
        return BreakStmt{ .op = op };
    }
};

/// Used to store a return stmt
/// returnStmt -> "return" expression? ';'
pub const ReturnStmt = struct {
    op: Token,
    expr: ?ExprNode,

    /// Initialize a ReturnStmt
    pub fn init(op: Token, expr: ?ExprNode) ReturnStmt {
        return ReturnStmt{
            .op = op,
            .expr = expr,
        };
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
};
