const Self = @This();

const std = @import("std");
const lox = @import("lox.zig");

const Allocator = std.mem.Allocator;
const Expr = lox.ast.Expr;
const Error = lox.Error;
const Token = lox.Scanner.Token;
const TokenType = lox.Scanner.TokenType;
const Value = lox.Interpreter.Value;

allocator: *Allocator,
tokens: []Token,
current: usize = 0,

pub fn init(allocator: *Allocator, tokens: []Token) Self {
    return .{ .allocator = allocator, .tokens = tokens };
}

pub fn parse(self: *Self) ?*Expr {
    return self.expression() catch |_| return null;
}

fn expression(self: *Self) Error!*Expr {
    return self.comma();
}

fn comma(self: *Self) Error!*Expr {
    var expr: *Expr = try self.equality();

    while (self.match(&[_]TokenType{.Comma})) {
        const operator: Token = self.previous();
        const right_operand: *Expr = try self.equality();

        expr = try Expr.binary(self.allocator, expr, operator, right_operand);
    }

    return expr;
}

fn equality(self: *Self) Error!*Expr {
    var expr: *Expr = try self.comparison();

    while (self.match(&[_]TokenType{ .BangEqual, .EqualEqual })) {
        const operator: Token = self.previous();
        const right_operand: *Expr = try self.comparison();

        expr = try Expr.binary(self.allocator, expr, operator, right_operand);
    }

    return expr;
}

fn comparison(self: *Self) Error!*Expr {
    var expr: *Expr = try self.addition();

    while (self.match(&[_]TokenType{ .Greater, .GreaterEqual, .Less, .LessEqual })) {
        const operator: Token = self.previous();
        const right_operand: *Expr = try self.addition();

        expr = try Expr.binary(self.allocator, expr, operator, right_operand);
    }
    return expr;
}

fn addition(self: *Self) Error!*Expr {
    var expr: *Expr = try self.multiplication();

    while (self.match(&[_]TokenType{ .Minus, .Plus })) {
        const operator: Token = self.previous();
        const right_operand: *Expr = try self.multiplication();

        expr = try Expr.binary(self.allocator, expr, operator, right_operand);
    }
    return expr;
}

fn multiplication(self: *Self) Error!*Expr {
    var expr: *Expr = try self.unary();

    while (self.match(&[_]TokenType{ .Slash, .Star })) {
        const operator: Token = self.previous();
        const right_operand: *Expr = try self.unary();

        expr = try Expr.binary(self.allocator, expr, operator, right_operand);
    }
    return expr;
}

fn unary(self: *Self) Error!*Expr {
    if (self.match(&[_]TokenType{ .Bang, .Minus })) {
        const operator: Token = self.previous();
        const right: *Expr = try self.unary();
        return Expr.unary(self.allocator, operator, right);
    }
    return self.primary();
}

fn primary(self: *Self) Error!*Expr {
    if (self.match(&[_]TokenType{ .True, .False, .Nil, .Number, .String })) {
        const token = self.previous();
        const value = token.literal.?;
        return Expr.literal(self.allocator, value);
    }

    if (self.match(&[_]TokenType{.LeftParen})) {
        const expr = try self.expression();
        _ = try self.consume(.RightParen, "Expect ')' after expression.");
        return Expr.grouping(self.allocator, expr);
    }

    return self.err(self.peek(), "Expect expression.");
}

fn consume(self: *Self, token_type: TokenType, message: []const u8) Error!Token {
    if (self.check(token_type)) return self.advance();

    return self.err(self.peek(), message);
}

fn match(self: *Self, types: []const TokenType) bool {
    for (types) |token_type| {
        if (self.check(token_type)) {
            _ = self.advance();
            return true;
        }
    }
    return false;
}

fn check(self: *Self, token_type: TokenType) bool {
    if (self.isAtEnd()) return false;
    return self.peek().token_type == token_type;
}

fn advance(self: *Self) Token {
    if (!self.isAtEnd()) self.current += 1;
    return self.previous();
}

fn isAtEnd(self: *Self) bool {
    return self.peek().token_type == .Eof;
}

fn peek(self: *Self) Token {
    return self.tokens[self.current];
}

fn previous(self: *Self) Token {
    return self.tokens[self.current - 1];
}

fn synchronize(self: *Self) void {
    _ = self.advance();
    while (!self.isAtEnd()) {
        if (self.previous().token_type == .Semicolon) return;

        switch (self.peek().token_type) {
            .Class, .Fun, .Var, .For, .If, .While, .Print, .Return => return,
            else => {},
        }

        _ = self.advance();
    }
}

fn err(self: *Self, token: Token, message: []const u8) Error {
    if (token.token_type == TokenType.Eof) {
        lox.report(token.line, " at end", message);
    } else {
        const location_parts = [_][]const u8{ " at '", token.lexeme, "'" };
        const location = try std.mem.concat(self.allocator, u8, &location_parts);
        defer self.allocator.free(location);
        lox.report(token.line, location, message);
    }

    return Error.ParseError;
}
