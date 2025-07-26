const std = @import("std");

// Constants, types, and Symbol import
const Symbol = @import("symbols.zig");
const Value = Symbol.Value;
const KindId = Symbol.KindId;
// Token
const Token = @import("front_end/scanner.zig").Token;
/// StmtNode import
const StmtNode = @import("stmt.zig").StmtNode;

//**********************************************//
//          Expression Node
//**********************************************//

pub const ExprUnion = union(enum) {
    SCOPE: *ScopeExpr,
    IDENTIFIER: *IdentifierExpr,
    LITERAL: *LiteralExpr,
    NATIVE: *NativeExpr,
    CONVERSION: *ConversionExpr,
    DEREFERENCE: *DereferenceExpr,
    FIELD: *FieldExpr,
    CALL: *CallExpr,
    INDEX: *IndexExpr,
    UNARY: *UnaryExpr,
    ARITH: *ArithExpr,
    COMPARE: *CompareExpr,
    AND: *AndExpr,
    OR: *OrExpr,
    IF: *IfExpr,
    LAMBDA: *LambdaExpr,
    GENERIC: *GenericExpr,
};

/// Generic node for all expression types
pub const ExprNode = struct {
    result_kind: KindId,
    expr: ExprUnion,

    pub fn init(expr: ExprUnion) ExprNode {
        return ExprNode{
            .result_kind = KindId.VOID,
            .expr = expr,
        };
    }

    pub fn initWithKind(expr: ExprUnion, kind: KindId) ExprNode {
        return ExprNode{
            .result_kind = kind,
            .expr = expr,
        };
    }

    /// Deep copy an exprnode
    pub fn copy(self: ExprNode, allocator: std.mem.Allocator) ExprNode {
        const expr = switch (self.expr) {
            .SCOPE => |scopeExpr| scopeExpr.copy(allocator),
            .IDENTIFIER => |idExpr| idExpr.copy(allocator),
            .LITERAL => |litExpr| litExpr.copy(allocator),
            .NATIVE => |nativeExpr| nativeExpr.copy(allocator),
            .CONVERSION => |convExpr| {
                const expr = convExpr.copy(allocator);
                return ExprNode{ .result_kind = self.result_kind.copy(allocator), .expr = expr };
            },
            .DEREFERENCE => |derefExpr| derefExpr.copy(allocator),
            .FIELD => |fieldExpr| fieldExpr.copy(allocator),
            .CALL => |callExpr| callExpr.copy(allocator),
            .INDEX => |indexExpr| indexExpr.copy(allocator),
            .UNARY => |unaryExpr| unaryExpr.copy(allocator),
            .ARITH => |arithExpr| arithExpr.copy(allocator),
            .COMPARE => |compareExpr| compareExpr.copy(allocator),
            .AND => |andExpr| andExpr.copy(allocator),
            .OR => |orExpr| orExpr.copy(allocator),
            .IF => |ifExpr| ifExpr.copy(allocator),
            .LAMBDA => |lambdaExpr| lambdaExpr.copy(allocator),
            .GENERIC => |genericExpr| genericExpr.copy(allocator),
        };
        return ExprNode{ .result_kind = self.result_kind, .expr = expr };
    }

    /// Used to display an AST in polish notation
    pub fn display(self: ExprNode) void {
        switch (self.expr) {
            .SCOPE => |scopeExpr| {
                scopeExpr.scope.display();
                std.debug.print("::", .{});
                scopeExpr.operand.display();
            },
            .IDENTIFIER => |idExpr| {
                std.debug.print("{s}", .{idExpr.id.lexeme});
                if (idExpr.scope_kind == .ARG or idExpr.scope_kind == .LOCAL) {
                    std.debug.print("(at [rbp+{d}])", .{idExpr.stack_offset});
                }
            },
            .LITERAL => |litExpr| std.debug.print("{s}", .{litExpr.literal.lexeme}),
            .CONVERSION => |convExpr| {
                //std.debug.print("(", .{});
                convExpr.operand.display();
                //std.debug.print("->{any})", .{self.result_kind});
            },
            .NATIVE => |nativeExpr| {
                std.debug.print("{s}(", .{nativeExpr.name.lexeme});
                // Check if any args
                // Print each arg, seperated by ','
                for (nativeExpr.args) |arg| {
                    arg.display();
                    std.debug.print(",", .{});
                }
                std.debug.print(")", .{});
                //std.debug.print(")->{any}", .{self.result_kind});
            },
            .DEREFERENCE => |derefExpr| {
                derefExpr.operand.display();
                std.debug.print(".*", .{});
            },
            .FIELD => |fieldExpr| {
                fieldExpr.operand.display();
                std.debug.print(".{s}", .{fieldExpr.field_name.lexeme});
                if (fieldExpr.method_name == null) {
                    std.debug.print("(at [base+{d}])", .{fieldExpr.stack_offset});
                }
            },
            .CALL => |callExpr| {
                // Print caller expr
                callExpr.caller_expr.display();
                std.debug.print("(", .{});
                // Check if any args
                // Print each arg, seperated by ','
                for (callExpr.args) |arg| {
                    arg.display();
                    std.debug.print(",", .{});
                }
                std.debug.print(")", .{});
                //std.debug.print(")->{any}", .{self.result_kind});
            },
            .INDEX => |indexExpr| {
                std.debug.print("(", .{});
                indexExpr.lhs.display();
                std.debug.print("[", .{});
                indexExpr.rhs.display();
                std.debug.print("])", .{});
            },
            .UNARY => |unaryExpr| {
                std.debug.print("(", .{});
                std.debug.print("{s}", .{unaryExpr.op.lexeme});
                unaryExpr.operand.display();
                std.debug.print(")", .{});
            },
            .ARITH => |arithExpr| {
                std.debug.print("(", .{});
                arithExpr.lhs.display();
                std.debug.print("{s}", .{arithExpr.op.lexeme});
                arithExpr.rhs.display();
                std.debug.print(")", .{});
            },
            .COMPARE => |compareExpr| {
                std.debug.print("(", .{});
                compareExpr.lhs.display();
                std.debug.print("{s}", .{compareExpr.op.lexeme});
                compareExpr.rhs.display();
                std.debug.print(")", .{});
            },
            .AND => |andExpr| {
                std.debug.print("(", .{});
                andExpr.lhs.display();
                std.debug.print(" and ", .{});
                andExpr.rhs.display();
                std.debug.print(")", .{});
            },
            .OR => |orExpr| {
                std.debug.print("(", .{});
                orExpr.lhs.display();
                std.debug.print(" or ", .{});
                orExpr.rhs.display();
                std.debug.print(")", .{});
            },
            .IF => |ifExpr| {
                std.debug.print("(", .{});
                ifExpr.conditional.display();
                std.debug.print("?", .{});
                ifExpr.then_branch.display();
                std.debug.print(":", .{});
                ifExpr.else_branch.display();
                std.debug.print(")", .{});
            },
            .LAMBDA => |lambdaExpr| lambdaExpr.display(),
            .GENERIC => |genericExpr| genericExpr.display(),
        }
    }
};

//**********************************************//
//          Literal/Identifier nodes
//**********************************************//

/// Used to access a variable or a constant
pub const IdentifierExpr = struct {
    id: Token,
    scope_kind: Symbol.ScopeKind = undefined,
    stack_offset: u64 = undefined,
    lexical_scope: []const u8,

    pub fn copy(self: IdentifierExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(IdentifierExpr) catch unreachable;
        new_expr.* = self;
        return ExprUnion{ .IDENTIFIER = new_expr };
    }
};

/// Used to access a variable or a constant
pub const LiteralExpr = struct {
    value: Value,
    literal: Token,

    pub fn copy(self: LiteralExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(LiteralExpr) catch unreachable;
        new_expr.* = self;
        return ExprUnion{ .LITERAL = new_expr };
    }
};

//**********************************************//
//          Type conversion nodes
//**********************************************//
/// Used to convert between types
pub const ConversionExpr = struct {
    op: Token,
    operand: ExprNode,

    pub fn init(op: Token, operand: ExprNode) ConversionExpr {
        return ConversionExpr{
            .op = op,
            .operand = operand,
        };
    }

    pub fn copy(self: ConversionExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(ConversionExpr) catch unreachable;
        new_expr.* = ConversionExpr{
            .op = self.op,
            .operand = self.operand.copy(allocator),
        };
        return ExprUnion{ .CONVERSION = new_expr };
    }
};

//**********************************************//
//          Call nodes
//**********************************************//
/// Used to call a native function
pub const NativeExpr = struct {
    name: Token,
    args: []ExprNode,
    arg_kinds: []KindId,

    pub fn init(name: Token, args: []ExprNode) NativeExpr {
        return NativeExpr{
            .name = name,
            .args = args,
            .arg_kinds = null,
        };
    }

    pub fn copy(self: NativeExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(NativeExpr) catch unreachable;
        const new_args = allocator.alloc(ExprNode, self.args.len) catch unreachable;
        for (0..new_args.len) |i| {
            new_args[i] = self.args[i].copy(allocator);
        }
        new_expr.* = NativeExpr{
            .name = self.name,
            .args = new_args,
            .arg_kinds = self.arg_kinds,
        };
        return ExprUnion{ .NATIVE = new_expr };
    }
};

/// Used to call a user defined function
pub const CallExpr = struct {
    caller_expr: ExprNode,
    op: Token,
    args: []ExprNode,
    chain: bool = false,
    non_chain_ptr: ?[]const u8 = null,
    non_chain_ptr_offset: usize = 0,

    pub fn init(caller_expr: ExprNode, op: Token, args: []ExprNode) CallExpr {
        return CallExpr{
            .caller_expr = caller_expr,
            .op = op,
            .args = args,
        };
    }

    pub fn copy(self: CallExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(CallExpr) catch unreachable;
        const new_args = allocator.alloc(ExprNode, self.args.len) catch unreachable;
        for (0..new_args.len) |i| {
            new_args[i] = self.args[i].copy(allocator);
        }
        new_expr.* = CallExpr{
            .caller_expr = self.caller_expr.copy(allocator),
            .op = self.op,
            .args = new_args,
            .chain = self.chain,
            .non_chain_ptr = self.non_chain_ptr,
            .non_chain_ptr_offset = self.non_chain_ptr_offset,
        };
        return ExprUnion{ .CALL = new_expr };
    }
};

//**********************************************//
//          Access nodes
//**********************************************//

/// Scope through the stm
pub const ScopeExpr = struct {
    scope: ExprNode,
    op: Token,
    operand: ExprNode,

    pub fn init(scope: ExprNode, op: Token, operand: ExprNode) ScopeExpr {
        return ScopeExpr{
            .scope = scope,
            .op = op,
            .operand = operand,
        };
    }

    pub fn copy(self: ScopeExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(ScopeExpr) catch unreachable;
        new_expr.* = ScopeExpr{
            .scope = self.scope.copy(allocator),
            .op = self.op,
            .operand = self.operand.copy(allocator),
        };
        return ExprUnion{ .SCOPE = new_expr };
    }
};

/// Operation for accessing a struct field
pub const FieldExpr = struct {
    operand: ExprNode,
    field_name: Token,
    op: Token,
    stack_offset: u64 = undefined,
    method_name: ?[]const u8 = null,

    /// Make a new FieldExpr
    pub fn init(operand: ExprNode, field_name: Token, op: Token) FieldExpr {
        return FieldExpr{
            .operand = operand,
            .field_name = field_name,
            .op = op,
        };
    }

    pub fn copy(self: FieldExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(FieldExpr) catch unreachable;
        new_expr.* = FieldExpr{
            .operand = self.operand.copy(allocator),
            .field_name = self.field_name,
            .op = self.op,
            .stack_offset = self.stack_offset,
            .method_name = self.method_name,
        };
        return ExprUnion{ .FIELD = new_expr };
    }
};

/// Operation for dereferencing a pointer
pub const DereferenceExpr = struct {
    operand: ExprNode,
    op: Token,

    /// Make a new Dereference Expr
    pub fn init(operand: ExprNode, op: Token) DereferenceExpr {
        return DereferenceExpr{
            .operand = operand,
            .op = op,
        };
    }

    pub fn copy(self: DereferenceExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(DereferenceExpr) catch unreachable;
        new_expr.* = DereferenceExpr{
            .operand = self.operand.copy(allocator),
            .op = self.op,
        };
        return ExprUnion{ .DEREFERENCE = new_expr };
    }
};

/// Operation for accessing an index
pub const IndexExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,
    // Marked true if evaluation order was swapped
    reversed: bool,

    /// Make a new Index Expression
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token, reversed: bool) IndexExpr {
        return IndexExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
            .reversed = reversed,
        };
    }

    pub fn copy(self: IndexExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(IndexExpr) catch unreachable;
        new_expr.* = IndexExpr{
            .lhs = self.lhs.copy(allocator),
            .rhs = self.rhs.copy(allocator),
            .op = self.op,
            .reversed = self.reversed,
        };
        return ExprUnion{ .INDEX = new_expr };
    }
};

//**********************************************//
//          Unary node
//**********************************************//

/// Operation on one operand and one operator
pub const UnaryExpr = struct {
    operand: ExprNode,
    op: Token,

    pub fn init(operand: ExprNode, op: Token) UnaryExpr {
        return UnaryExpr{
            .operand = operand,
            .op = op,
        };
    }

    pub fn copy(self: UnaryExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(UnaryExpr) catch unreachable;
        new_expr.* = UnaryExpr{
            .operand = self.operand.copy(allocator),
            .op = self.op,
        };
        return ExprUnion{ .UNARY = new_expr };
    }
};

//**********************************************//
//          Binary nodes
//**********************************************//

/// Arithmatic operation on two operands and one operator.
/// +-*/%
pub const ArithExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,
    // Marked true if evaluation order was swapped
    reversed: bool,

    /// Make a new Arithmatic Expr with a void return type
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token, reversed: bool) ArithExpr {
        return ArithExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
            .reversed = reversed,
        };
    }

    pub fn copy(self: ArithExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(ArithExpr) catch unreachable;
        new_expr.* = ArithExpr{
            .lhs = self.lhs.copy(allocator),
            .rhs = self.rhs.copy(allocator),
            .op = self.op,
            .reversed = self.reversed,
        };
        return ExprUnion{ .ARITH = new_expr };
    }
};

/// Compare operation on two operands and one operator.
/// ==,!=,>,>=,<,<=
pub const CompareExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,
    // Marked true if evaluation order was swapped
    reversed: bool,

    /// Make a new compare Expr with a void return type
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token, reversed: bool) CompareExpr {
        return CompareExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
            .reversed = reversed,
        };
    }

    pub fn copy(self: CompareExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(CompareExpr) catch unreachable;
        new_expr.* = CompareExpr{
            .lhs = self.lhs.copy(allocator),
            .rhs = self.rhs.copy(allocator),
            .op = self.op,
            .reversed = self.reversed,
        };
        return ExprUnion{ .COMPARE = new_expr };
    }
};

//**********************************************//
//          Logical nodes
//**********************************************//

/// Logic operation on two operands and one operator.
/// and or
pub const AndExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,

    /// Make a new Logic Expr with a void return type
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token) AndExpr {
        return AndExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
        };
    }

    pub fn copy(self: AndExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(AndExpr) catch unreachable;
        new_expr.* = AndExpr{
            .lhs = self.lhs.copy(allocator),
            .rhs = self.rhs.copy(allocator),
            .op = self.op,
        };
        return ExprUnion{ .AND = new_expr };
    }
};

pub const OrExpr = struct {
    lhs: ExprNode,
    rhs: ExprNode,
    op: Token,

    /// Make a new Logic Expr with a void return type
    pub fn init(lhs: ExprNode, rhs: ExprNode, op: Token) OrExpr {
        return OrExpr{
            .lhs = lhs,
            .rhs = rhs,
            .op = op,
        };
    }

    pub fn copy(self: OrExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(OrExpr) catch unreachable;
        new_expr.* = OrExpr{
            .lhs = self.lhs.copy(allocator),
            .rhs = self.rhs.copy(allocator),
            .op = self.op,
        };
        return ExprUnion{ .OR = new_expr };
    }
};

//**********************************************//
//          Ternary node
//**********************************************//

/// Operation on three operands and two operators
pub const IfExpr = struct {
    conditional: ExprNode,
    then_branch: ExprNode,
    else_branch: ExprNode,
    if_token: Token,

    /// Make a new If Expr with a void return type
    pub fn init(if_token: Token, conditional: ExprNode, then_branch: ExprNode, else_branch: ExprNode) IfExpr {
        return IfExpr{
            .if_token = if_token,
            .conditional = conditional,
            .then_branch = then_branch,
            .else_branch = else_branch,
        };
    }

    pub fn copy(self: IfExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(IfExpr) catch unreachable;
        new_expr.* = IfExpr{
            .conditional = self.conditional.copy(allocator),
            .then_branch = self.then_branch.copy(allocator),
            .else_branch = self.else_branch.copy(allocator),
            .if_token = self.if_token,
        };
        return ExprUnion{ .IF = new_expr };
    }
};

/// Lambda
pub const LambdaExpr = struct {
    op: Token,
    arg_names: []Token,
    arg_kinds: []KindId,
    ret_kind: KindId,
    body: StmtNode,

    pub fn init(op: Token, arg_names: []Token, arg_kinds: []KindId, ret_kind: KindId, body: StmtNode) LambdaExpr {
        return LambdaExpr{
            .op = op,
            .arg_names = arg_names,
            .arg_kinds = arg_kinds,
            .ret_kind = ret_kind,
            .body = body,
        };
    }

    pub fn copy(self: LambdaExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(LambdaExpr) catch unreachable;
        const new_arg_kinds = allocator.alloc(KindId, self.arg_kinds.len) catch unreachable;
        for (0..new_arg_kinds.len) |i| {
            new_arg_kinds[i] = self.arg_kinds[i].copy(allocator);
        }
        new_expr.* = LambdaExpr{
            .op = self.op,
            .arg_names = self.arg_names,
            .arg_kinds = new_arg_kinds,
            .ret_kind = self.ret_kind.copy(allocator),
            .body = self.body.copy(allocator),
        };
        return ExprUnion{ .LAMBDA = new_expr };
    }

    pub fn display(self: LambdaExpr) void {
        std.debug.print("|", .{});
        for (self.arg_names) |arg| {
            std.debug.print("{s},", .{arg.lexeme});
        }
        std.debug.print("| ", .{});
        self.body.display();
    }
};

/// Used to create a generic scope for generic functions
pub const GenericExpr = struct {
    op: Token,
    kinds: []KindId,
    operand: Token,

    pub fn copy(self: GenericExpr, allocator: std.mem.Allocator) ExprUnion {
        const new_expr = allocator.create(GenericExpr) catch unreachable;
        const new_kinds = allocator.alloc(KindId, self.kinds.len) catch unreachable;
        for (0..new_kinds.len) |i| {
            new_kinds[i] = self.kinds[i].copy(allocator);
        }
        new_expr.* = GenericExpr{
            .op = self.op,
            .kinds = new_kinds,
            .operand = self.operand,
        };
        return ExprUnion{ .GENERIC = new_expr };
    }

    /// Make a new generic expr with a void return type
    pub fn init(op: Token, kinds: []KindId, operand: Token) GenericExpr {
        return GenericExpr{
            .op = op,
            .kinds = kinds,
            .operand = operand,
        };
    }

    pub fn display(self: GenericExpr) void {
        std.debug.print("<", .{});
        for (self.kinds) |kind| {
            std.debug.print("{any},", .{kind});
        }
        std.debug.print(">{s}", .{self.operand.lexeme});
    }
};
