const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const compile = @import("compiler.zig").compile;
const debug = @import("debug.zig");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig").Value;
const OpCode = Chunk.OpCode;

/// VM struct
chunk: Chunk, // bytecode
ip: usize = 0, // current bytecode offset
stack: ArrayList(Value), // working value stack
debug_mode: bool = false, // print diagnostics while running?

pub const LoxError = error{
    OutOfMemory,
    CompileError,
    RuntimeError,
};

pub fn init(allocator: *Allocator) Self {
    const chunk = Chunk.init(allocator);
    return .{ .chunk = chunk, .stack = ArrayList(Value).init(allocator) };
}

pub fn deinit(self: *Self) void {
    self.chunk.deinit();
    self.stack.deinit();
}

pub fn interpret(self: *Self, source: []const u8) !void {
    self.chunk.reset();
    try compile(source, &self.chunk);
}

pub fn run(self: *Self) LoxError!?Value {
    while (true) {
        // If we've hit the end of the bytecode, no value is returned.
        if (self.ip >= self.chunk.code.items.len)
            return null;

        // When in debug mode, print the stack and disassemble the current instruction.
        if (self.debug_mode) {
            std.debug.warn("          ", .{});
            for (self.chunk.constants.items) |constant| {
                std.debug.warn("[{}]", .{constant});
            }
            std.debug.warn("\n", .{});

            _ = debug.disassembleInstruction(
                &self.chunk,
                std.io.getStdErr().outStream(),
                self.ip,
            ) catch 0;
        }

        const instruction = @intToEnum(OpCode, self.chunk.read(self.ip));
        self.ip += 1;

        switch (instruction) {
            .Constant => {
                const constant = self.chunk.readConstant(self.ip);
                try self.push(constant);
                self.ip += @sizeOf(usize); // the constant takes up same size as a `usize`
            },

            .Add => try self.binaryOp(add),
            .Subtract => try self.binaryOp(sub),
            .Multiply => try self.binaryOp(mul),
            .Divide => try self.binaryOp(div),

            .Negate => try self.push(-(try self.pop())),

            // need `try` since it looks like `!T` can't be coerced to `!?T`
            .Return => return try self.pop(),

            _ => std.debug.warn(
                "Unknown instruction: 0x{x:0>2}\n",
                .{@enumToInt(instruction)},
            ),
        }
    }
}

fn add(a: Value, b: Value) Value {
    return a + b;
}

fn sub(a: Value, b: Value) Value {
    return a - b;
}

fn mul(a: Value, b: Value) Value {
    return a * b;
}

fn div(a: Value, b: Value) Value {
    return a / b;
}

fn binaryOp(self: *Self, mathFn: fn (a: Value, b: Value) Value) !void {
    const b = try self.pop();
    const a = try self.pop();
    const result = mathFn(a, b);
    try self.push(result);
}

fn push(self: *Self, value: Value) !void {
    return self.stack.append(value);
}

fn pop(self: *Self) !Value {
    return self.stack.popOrNull() orelse {
        std.debug.warn("Error: stack underflow\n", .{});
        return LoxError.RuntimeError;
    };
}

const testing = std.testing;

test "OP_CONSTANT" {
    const allocator = testing.allocator;
    var vm = Self.init(allocator);
    var chunk = &vm.chunk;
    defer vm.deinit();

    try chunk.writeConst(1.2, 0);
    testing.expectEqual(@as(?Value, null), try vm.run());
    testing.expectEqualSlices(Value, &[_]Value{1.2}, vm.stack.items);
}

test "OP_RETURN" {
    const allocator = testing.allocator;
    var vm = Self.init(allocator);
    var chunk = &vm.chunk;
    defer vm.deinit();

    try chunk.writeConst(1.2, 0);
    try chunk.writeOp(.Return, 0);
    testing.expectEqual(@as(?Value, 1.2), try vm.run());
}

test "arithmetic" {
    const allocator = testing.allocator;
    var vm = Self.init(allocator);
    var chunk = &vm.chunk;
    defer vm.deinit();

    // (-1.3 + 3.14) * 2 / 3
    try chunk.writeConst(1.2, 0);
    try chunk.writeOp(.Negate, 0);
    try chunk.writeConst(3.14, 0);
    try chunk.writeOp(.Add, 0);
    try chunk.writeConst(2, 0);
    try chunk.writeOp(.Multiply, 0);
    try chunk.writeConst(3, 0);
    try chunk.writeOp(.Divide, 0);
    try chunk.writeOp(.Return, 0);
    testing.expectEqual(@as(?Value, 1.2933333333333334), try vm.run());
}
