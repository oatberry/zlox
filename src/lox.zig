const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const ast = @import("ast.zig");
pub const Interpreter = @import("interpreter.zig");
pub const Parser = @import("parser.zig");
pub const Scanner = @import("scanner.zig");

pub const Error = error{
    DivisionByZero,
    OutOfMemory,
    Overflow,
    ParseError,
    RuntimeError,
    TypeError,
    UnexpectedRemainder,
};

pub var had_error = false;
pub var had_runtime_error = false;

pub fn report(line: usize, where: []const u8, message: []const u8) void {
    std.debug.warn("[line {}] Error{}: {}\n", .{ line, where, message });
    had_error = true;
}

pub fn run(interpreter: *Interpreter, source: []u8) Error!void {
    var scanner = Scanner.init(interpreter.allocator, source);
    const tokens = try scanner.scanTokens();
    defer interpreter.allocator.free(tokens);

    var parser = Parser.init(interpreter.allocator, tokens);
    const expr = parser.parse();
    defer if (expr) |e| e.deinit(interpreter.allocator);

    if (had_error) return;

    if (expr) |e| {
        interpreter.
            std.debug.warn("{}\n", .{pretty_str.items});
    }
}
