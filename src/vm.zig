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

debugMode: bool = false, // print diagnostics while running?

const InterpretResult = enum {
    Ok,
    CompileError,
    RuntimeError,
};

pub fn init(chunk: *Chunk, allocator: *Allocator) Self {
    return .{ .chunk = chunk, .stack = ArrayList(Value).init(allocator) };
}

const DebugMode = enum { Debug, NoDebug };

pub fn interpret(chunk: *Chunk, debugMode: DebugMode, allocator: *Allocator) !InterpretResult {
    var vm = Self.init(chunk, allocator);
    vm.debugMode = debugMode == .Debug;
    return vm.run();
}

fn run(self: *Self) !InterpretResult {
    while (true) {
        if (self.debugMode) {
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
            },
            .Return => {
                const value = try self.pop();
                std.debug.warn("result: {}\n", .{value});
                return .Ok;
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
        return .RuntimeError;
    };
}
