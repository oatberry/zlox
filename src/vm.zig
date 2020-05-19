const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const File = std.fs.File;

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

fn run(self: *Self) LoxError!void {
    while (true) {
        if (self.debug_mode) {
            // Dump stack
            std.debug.warn("          ", .{});
            for (self.chunk.constants.items) |constant| {
                std.debug.warn("[{}]", .{constant});
            }
            std.debug.warn("\n", .{});

            // show current instruction
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

            .Return => {
                const value = try self.pop();
                std.debug.warn("result: {}\n", .{value});
                return;
            },

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
