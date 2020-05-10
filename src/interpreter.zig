const Self = @This();

const std = @import("std");
const lox = @import("lox.zig");
const math = std.math;

const Allocator = std.mem.Allocator;
const Error = lox.Error;
const Expr = lox.ast.Expr;
const Token = lox.Scanner.Token;

allocator: *Allocator,
maybe_error: ?struct {
    message: []const u8,
    token: Token,
},

pub fn init(allocator: *Allocator) Self {
    return .{ .allocator = allocator, .maybe_error = null };
}

pub fn interpret(self: *Self, expr: *const Expr) !void {
    const value = self.evaluate(expr) catch |e| {
        switch (e) {
            Error.
        }
    }
}

pub fn evaluate(self: *Self, expr: *const Expr) Error!Value {
    return switch (expr.*) {
        .Literal => |lit| lit,
        .Binary => |binary| blk: {
            const left = try self.evaluate(binary.l_expr);
            const right = try self.evaluate(binary.r_expr);

            break :blk switch (binary.operator.token_type) {
                .EqualEqual => Value.boolean(left.isTruthy() == right.isTruthy()),
                .BangEqual => Value.boolean(left.isTruthy() != right.isTruthy()),

                .Less,
                .LessEqual,
                .Greater,
                .GreaterEqual,
                => self.doComparison(binary.operator, left, right),

                .Minus,
                .Star,
                .Slash,
                => self.doMath(binary.operator, left, right),

                .Plus => self.doPlus(binary.operator, left, right),
                .Comma => right,
            };
        },
        .Unary => |unary| blk: {
            const value = try self.evaluate(unary.expr);
            break :blk switch (unary.operator.token_type) {
                .Minus => self.doMath(unary.operator, Value.number(0), value),
                .Bang => !isTruthy(value),
            };
        },
        .Grouping => |e| self.evaluate(e),
    };
}

fn doMath(self: *Self, op: Token, a: Value, b: Value) Error!Value {
    const n1 = a.asNumber() orelse return self.typeError(op, a);
    const n2 = b.asNumber() orelse return self.typeError(op, b);
    return switch (op.token_type) {
        .Minus => Value.number(n1 - n2),
        .Star => Value.number(n1 * n2),
        .Slash => Value.number(math.divExact(f64, n1, n2)),
        else => self.err(op, "doMath() received an unexpected operator. This should not happen."),
    };
}

fn doComparison(allocator: *Allocator, op: Token, a: Value, b: Value) Error!Value {
    const n1 = asNumber(a) orelse return typeError(allocator, op, a);
    const n2 = asNumber(b) orelse return typeError(allocator, op, b);
    return switch (op.token_type) {
        .Less => Value.boolean(n1 < n2),
        .LessEqual => Value.boolean(n1 <= n2),
        .Greater => Value.boolean(n1 > n2),
        .GreaterEqual => Value.boolean(n1 >= n2),
        else => self.err(op, "doComparison() received an unexpected operator. This should not happen.",),
    };
}

fn doPlus(self: *Self, op: Token, a: Value, b: Value) Error!Value {
    return switch (a) {
        .Number => |n1| switch (b) {
            .Number => |n2| Value.number(n1 + n2),
            else => self.typeError(op, right),
        },
        .String => |s1| switch (right) {
            .String => |s2| Value.string(std.mem.concat(allocator, u8, &[_][]const u8{ s1, s2 })),
            else => self.typeError(op, right),
        },
        else => self.typeError(op, left),
    };
}

fn typeError(self: *Self, token: Token, got_value: Value) Error {
    const msg_parts = &[_][]const u8{
        "Operation '",
        @tagName(token.token_type),
        "' got an unexpected value of type '",
        @tagName(got_value),
        "'.",
    };
    const message = try std.mem.concat(allocator, u8, msg);
    defer allocator.free(message);
    _ = self.err(token, message);
    return Error.TypeError;
}

fn err(self: *Self, token: Token, message: []const u8) Error {
    self.maybe_error = .{ .message = message, .token = token };
    return Error.RuntimeError;
}

pub const Value = union(enum) {
    Number: f64,
    String: []const u8,
    Bool: bool,
    Nil,

    const Self = @This();

    pub fn number(n: f64) Self {
        return .{ .Number = n };
    }

    pub fn string(s: []const u8) Self {
        return .{ .String = s };
    }

    pub fn boolean(b: bool) Self {
        return .{ .Bool = b };
    }

    pub fn isTruthy(value: Self) bool {
        return switch (value) {
            .Nil => false,
            .Bool => |b| b,
            else => true,
        };
    }

    pub fn asNumber(value: Self) ?f64 {
        return switch (value) {
            .Number => |n| n,
            else => null,
        };
    }

    pub fn deinit(self: *Self, allocator: *Allocator) void {
        switch (self.*) {
            .String => |s| allocator.free(s),
            else => {},
        }
    }

    pub fn format(
        value: Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: var,
    ) !void {
        switch (value.*) {
            .Number => |n| try out_stream.print("{}", .{n}),
            .String => |s| try out_stream.writeAll(s),
            .Bool => |b| try out_stream.print("\"{}\"", .{b}),
            .Nil => try out_stream.writeAll("nil"),
        }
    }
};
