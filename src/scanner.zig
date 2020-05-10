const Self = @This();

const std = @import("std");
const lox = @import("lox.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Value = lox.Interpreter.Value;

/// Scanner struct
/// note: all zig files have an implicit top-level struct
allocator: *Allocator,
source: []const u8,
tokens: ArrayList(Token),
start: usize = 0, // index of start of current lexeme
current: usize = 0, // index of char we're considering
line: usize = 1, // what line `current` is on

pub fn init(allocator: *Allocator, source: []const u8) Self {
    return .{
        .allocator = allocator,
        .source = source,
        .tokens = ArrayList(Token).init(allocator),
    };
}

/// Convert the source text into a list of tokens.
pub fn scanTokens(self: *Self) ![]Token {
    while (!self.isAtEnd()) {
        self.start = self.current;
        try self.scanToken();
    }

    try self.tokens.append(Token.init(.Eof, "", null, self.line));
    return self.tokens.items;
}

/// Append a token onto the list.
fn addToken(self: *Self, ttype: TokenType, literal: ?Value) !void {
    const text = self.source[self.start..self.current];
    try self.tokens.append(Token.init(ttype, text, literal, self.line));
}

/// Attempt to scan in the next token.
fn scanToken(self: *Self) !void {
    const c = self.advance();
    switch (c) {
        '(' => try self.addToken(.LeftParen, null),
        ')' => try self.addToken(.RightParen, null),
        '{' => try self.addToken(.LeftBrace, null),
        '}' => try self.addToken(.RightBrace, null),
        ',' => try self.addToken(.Comma, null),
        '.' => try self.addToken(.Dot, null),
        '-' => try self.addToken(.Minus, null),
        '+' => try self.addToken(.Plus, null),
        ';' => try self.addToken(.Semicolon, null),
        '*' => try self.addToken(.Star, null),
        '!' => try self.addToken(if (self.match('=')) .BangEqual else .Bang, null),
        '=' => try self.addToken(if (self.match('=')) .EqualEqual else .Equal, null),
        '<' => try self.addToken(if (self.match('=')) .LessEqual else .Less, null),
        '>' => try self.addToken(if (self.match('=')) .GreaterEqual else .Greater, null),
        '/' => {
            if (self.match('/')) {
                // a comment goes until the end of the line
                while (self.peek() != '\n' and !self.isAtEnd())
                    _ = self.advance();
            } else {
                try self.addToken(.Slash, null);
            }
        },

        ' ', '\r', '\t' => {}, // ignore whitespace
        '\n' => self.line += 1,
        '"' => try self.string(),

        '0'...'9' => try self.number(),

        else => if (isAlpha(c)) {
            try self.indentifier();
        } else {
            self.err("Unexpected character.");
        },
    }
}

/// Tokenize a string.
fn string(self: *Self) !void {
    while (self.peek() != '"' and !self.isAtEnd()) {
        if (self.peek() == '\n') self.line += 1;
        _ = self.advance();
    }

    if (self.isAtEnd()) {
        self.err("Unterminated string.");
        return;
    }

    _ = self.advance(); // The closing ".
    const literal_src = self.source[self.start + 1 .. self.current - 1];
    // Instead of just storing the slice, we copy it so that we can
    // always assume that a Value.String has an allocated string in it.
    const literal_copy = try self.allocator.alloc(u8, literal_src.len);
    std.mem.copy(u8, literal_copy, literal_src);
    return self.addToken(.String, Value{ .String = literal_copy });
}

/// Tokenize a number.
fn number(self: *Self) !void {
    while (isDigit(self.peek())) _ = self.advance();

    // look for fractional part
    if (self.peek() == '.' and isDigit(self.peekNext())) {
        _ = self.advance(); // consume the '.'
        while (isDigit(self.peek())) _ = self.advance();
    }

    const n = std.fmt.parseFloat(f64, self.source[self.start..self.current]) catch |e| {
        self.err(@tagName(e));
        return Error.ParseError;
    };
    return self.addToken(.Number, Value{ .Number = n });
}

/// Tokenize an identifier.
fn indentifier(self: *Self) !void {
    while (isAlphaNumeric(self.peek())) _ = self.advance();

    const IdentPair = struct { keyword: []const u8, token: TokenType, literal: ?Value };
    const ident_pairs = &[_]IdentPair{
        .{ .keyword = "and", .token = .And, .literal = null },
        .{ .keyword = "class", .token = .Class, .literal = null },
        .{ .keyword = "else", .token = .Else, .literal = null },
        .{ .keyword = "false", .token = .False, .literal = .{ .Bool = false } },
        .{ .keyword = "for", .token = .For, .literal = null },
        .{ .keyword = "fun", .token = .Fun, .literal = null },
        .{ .keyword = "if", .token = .If, .literal = null },
        .{ .keyword = "nil", .token = .Nil, .literal = .Nil },
        .{ .keyword = "or", .token = .Or, .literal = null },
        .{ .keyword = "print", .token = .Print, .literal = null },
        .{ .keyword = "return", .token = .Return, .literal = null },
        .{ .keyword = "super", .token = .Super, .literal = null },
        .{ .keyword = "this", .token = .This, .literal = null },
        .{ .keyword = "true", .token = .True, .literal = .{ .Bool = true } },
        .{ .keyword = "var", .token = .Var, .literal = null },
        .{ .keyword = "while", .token = .While, .literal = null },
    };

    const ident = self.source[self.start..self.current];
    for (ident_pairs) |pair| {
        if (std.mem.eql(u8, ident, pair.keyword)) {
            return self.addToken(pair.token, pair.literal);
        }
    }
    return self.addToken(.Identifier, null);
}

/// Is a byte alphabetic or a number?
fn isAlphaNumeric(char: u8) bool {
    return isAlpha(char) or isDigit(char);
}

/// Is a byte alphabetic?
fn isAlpha(char: u8) bool {
    return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z') or char == '_';
}

/// Is a byte a digit?
fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

/// Determine whether we've reached the end of the source code.
fn isAtEnd(self: *Self) bool {
    return self.current >= self.source.len;
}

/// If the next byte matches `expected`, advance.
fn match(self: *Self, expected: u8) bool {
    if (self.isAtEnd()) return false;
    if (self.source[self.current] != expected) return false;

    self.current += 1;
    return true;
}

/// Advance and return the next byte.
fn advance(self: *Self) u8 {
    self.current += 1;
    return self.source[self.current - 1];
}

/// Look ahead to the next byte without consuming it.
fn peek(self: *Self) u8 {
    if (self.isAtEnd()) return 0;
    return self.source[self.current];
}

/// Look ahead 2 bytes without consuming either one.
fn peekNext(self: *Self) u8 {
    if (self.current + 1 >= self.source.len) return 0;
    return self.source[self.current + 1];
}

/// Report an error.
fn err(self: *Self, message: []const u8) void {
    lox.report(self.line, "", message);
}

/// A "word" from source code
pub const Token = struct {
    token_type: TokenType,
    lexeme: []const u8,
    literal: ?Value,
    line: usize,

    const Self = @This();

    pub fn init(token_type: TokenType, lexeme: []const u8, literal: ?Value, line: usize) Self {
        return .{
            .token_type = token_type,
            .lexeme = lexeme,
            .literal = literal,
            .line = line,
        };
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: var,
    ) !void {
        try out_stream.print("{} {}", .{ self.token_type, self.lexeme, self.literal });
    }
};

pub const TokenType = enum {
    // Single-character tokens.
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    Comma,
    Dot,
    Minus,
    Plus,
    Semicolon,
    Slash,
    Star,
    // One or two character tokens.
    Bang,
    BangEqual,
    Equal,
    EqualEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    // Literals.
    Identifier,
    String,
    Number,
    // Keywords.
    And,
    Class,
    Else,
    False,
    Fun,
    For,
    If,
    Nil,
    Or,
    Print,
    Return,
    Super,
    This,
    True,
    Var,
    While,
    Eof,
};
