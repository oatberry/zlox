const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const debug = @import("debug.zig");
const Chunk = @import("chunk.zig");
const Value = @import("value.zig").Value;
const OpCode = Chunk.OpCode;

/// VM struct
chunk: *Chunk, // bytecode
ip: usize = 0, // current bytecode offset
stack: ArrayList(Value), // working value stack
debug_mode: bool = false, // print diagnostics while running?
error_code: enum {
    Ok,
    StackUnderflow,
} = .Ok,

pub const LoxError = error{
    OutOfMemory,
    CompileError,
    RuntimeError,
};

pub fn init(chunk: *Chunk, allocator: *Allocator) Self {
    return .{ .chunk = chunk, .stack = ArrayList(Value).init(allocator) };
}

pub fn deinit(self: *Self) void {
    self.chunk.deinit();
    self.stack.deinit();
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
                self.chunk,
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

fn push(self: *Self, value: Value) !void {
    return self.stack.append(value);
}

fn pop(self: *Self) !Value {
    return self.stack.popOrNull() orelse {
        std.debug.warn("Error: stack underflow\n", .{});
        self.error_code = .StackUnderflow;
        return LoxError.RuntimeError;
    };
}

const testing = std.testing;

test "OP_CONSTANT" {
    const allocator = testing.allocator;
    var chunk = Chunk.init(allocator);
    var vm = Self.init(&chunk, allocator);
    defer vm.deinit();

    try chunk.writeConst(1.2, 0);
    testing.expectEqual(@as(?Value, null), try vm.run());
    testing.expectEqualSlices(
        Value,
        &[_]Value{1.2},
        vm.stack.items,
    );
}

test "OP_NEGATIVE" {
    const allocator = testing.allocator;
    var chunk = Chunk.init(allocator);
    var vm = Self.init(&chunk, allocator);
    defer vm.deinit();

    const inf = std.math.inf(f64);
    const nan = std.math.nan(f64);

    try chunk.writeConst(1.2, 0);
    try chunk.writeOp(.Negate, 0);
    try chunk.writeConst(0, 0);
    try chunk.writeOp(.Negate, 0);
    try chunk.writeConst(-inf, 0);
    try chunk.writeOp(.Negate, 0);
    testing.expectEqual(@as(?Value, null), try vm.run());
    testing.expectEqualSlices(
        Value,
        &[_]Value{ -1.2, 0, inf },
        vm.stack.items,
    );
}

test "OP_RETURN" {
    const allocator = testing.allocator;
    var chunk = Chunk.init(allocator);
    var vm = Self.init(&chunk, allocator);
    defer vm.deinit();

    try chunk.writeConst(1.2, 0);
    try chunk.writeOp(.Return, 0);
    testing.expectEqual(@as(?Value, 1.2), try vm.run());
}
