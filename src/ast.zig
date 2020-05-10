const std = @import("std");
const lox = @import("lox.zig");

const Allocator = std.mem.Allocator;
const Value = lox.Interpreter.Value;
const Token = lox.Scanner.Token;

pub const Expr = union(enum) {
    Literal: Value,
    Binary: struct {
        operator: Token,
        l_expr: *Self,
        r_expr: *Self,
    },
    Unary: struct {
        operator: Token,
        expr: *Self,
    },
    Grouping: *Self,

    const Self = @This();

    /// Create a literal value expression
    pub fn literal(allocator: *Allocator, value: Value) !Self {
        const new_expr = try allocator.create(Self);
        new_expr.* = .{ .Literal = value };
        return new_expr;
    }

    /// Create a unary-operator expression
    pub fn unary(allocator: *Allocator, operator: Token, expr: *Self) !Self {
        const new_expr = try allocator.create(Self);
        new_expr.* = .{ .Unary = .{ .operator = operator, .expr = expr } };
        return new_expr;
    }

    /// Create a binary-operator expression
    pub fn binary(
        allocator: *Allocator,
        l_expr: *Self,
        operator: Token,
        r_expr: *Self,
    ) !Self {
        const new_expr = try allocator.create(Self);
        new_expr.* = .{
            .Binary = .{
                .operator = operator,
                .l_expr = l_expr,
                .r_expr = r_expr,
            },
        };
        return new_expr;
    }

    /// Create a grouped (parentheses) expression
    pub fn grouping(allocator: *Allocator, expr: *Self) !Self {
        const new_expr = try allocator.create(Self);
        new_expr.* = .{ .Grouping = expr };
        return new_expr;
    }

    /// Walk the syntax tree and deallocate nodes.
    pub fn deinit(self: *Self, allocator: *Allocator) void {
        switch (self.*) {
            .Literal => |value| value.deinit(allocator),
            .Unary => |u| u.expr.deinit(allocator),
            .Binary => |b| {
                b.l_expr.deinit(allocator);
                b.r_expr.deinit(allocator);
            },
            .Grouping => |e| e.deinit(allocator),
        }

        allocator.destroy(self);
    }

    /// Pretty-print an expression into a growable string (ArrayList(u8))
    pub fn pp(self: *const Self, buf: *std.ArrayList(u8)) error{OutOfMemory}!void {
        // I wrote this instead of a standard .format() because zig
        // chokes on recursive comptime stuff at this time :(
        const stream = buf.outStream();
        switch (self.*) {
            .Literal => |lit| switch (lit) {
                .Number => |n| try std.fmt.formatFloatDecimal(n, .{}, stream),
                // .Number => |n| try std.fmt.formatFloatDecimal(n, std.fmt.FormatOptions{}, stream),
                .String => |s| try buf.appendSlice(s),
                .Bool => |b| try buf.appendSlice(if (b) "true" else "false"),
                .Nil => try buf.appendSlice("nil"),
            },
            .Unary => |unary| {
                try buf.appendSlice("(");
            },
            .Binary => |b| {
                try buf.appendSlice("(");
                try buf.appendSlice(@tagName(b.operator.token_type));
                try buf.appendSlice(" ");
                try b.l_expr.pp(buf);
                try buf.appendSlice(" ");
                try b.r_expr.pp(buf);
                try buf.appendSlice(")");
            },
            .Grouping => |expr| {
                try buf.appendSlice("(group ");
                try expr.pp(buf);
                try buf.appendSlice(")");
            },
        }
    }
};
