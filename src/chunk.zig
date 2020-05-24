const Self = @This();

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const debug = @import("debug.zig");
const Value = @import("value.zig").Value;

/// Chunk struct
code: ArrayList(u8),
constants: ArrayList(Value),
lines: ArrayList(usize),

pub const OpCode = enum(u8) {
    Constant,
    Add,
    Subtract,
    Multiply,
    Divide,
    Negate,
    Return,
    _, // makes enum non-exhaustive.
};

pub fn init(allocator: *Allocator) Self {
    return .{
        .code = ArrayList(u8).init(allocator),
        .constants = ArrayList(Value).init(allocator),
        .lines = ArrayList(usize).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.code.deinit();
    self.constants.deinit();
    self.lines.deinit();
}

pub fn reset(self: *Self) void {
    self.code.items.len = 0;
    self.constants.items.len = 0;
    self.lines.items.len = 0;
}

/// Read a byte from an offset into the bytecode.
pub fn read(self: *const Self, offset: usize) u8 {
    return self.code.items[offset];
}

/// Given an offset into the bytecode, read the bytes there into a usize and
/// index into the constants list with it.
pub fn readConstant(self: *const Self, offset: usize) Value {
    // Make a buffer of bytes with the size of a usize
    var const_index_bytes: [@sizeOf(usize)]u8 = undefined;
    // Copy the index bytes from the chunk code into the buffer
    mem.copy(
        u8,
        &const_index_bytes,
        self.code.items[(offset)..(offset + @sizeOf(usize))],
    );
    const const_idx = mem.bytesToValue(usize, &const_index_bytes);
    // Read the constant from the constants list
    return self.constants.items[const_idx];
}

/// Given a bytecode offset, get the corresponding line number.
pub fn getLine(self: *const Self, offset: usize) usize {
    return self.lines.items[offset];
}

/// Append an OpCode onto the bytecode, with some line number data.
pub fn writeOp(self: *Self, op: OpCode, line: usize) !void {
    return self.writeByte(@enumToInt(op), line);
}

/// Append a slice of bytes onto the bytecode, with some line number data.
pub fn writeBytes(self: *Self, bytes: []const u8, line: usize) !void {
    try self.code.appendSlice(bytes);
    for (bytes) |_| {
        try self.lines.append(line);
    }
}

/// Add a constant value to the constant pool, and then write a constant
/// instruction to the bytecode.
pub fn writeConst(self: *Self, value: Value, line: usize) !void {
    try self.constants.append(value);
    try self.writeOp(.Constant, line);
    const idx: usize = self.constants.items.len - 1;
    try self.writeBytes(mem.asBytes(&idx), line);
}

/// Append a byte to the bytecode, with some line number data.
pub fn writeByte(self: *Self, byte: u8, line: usize) !void {
    try self.code.append(byte);
    try self.lines.append(line);
}

/// Disassemble the chunk into human-readable text on an OutStream.
pub const disassemble = debug.disassembleChunk;

test "OP_CONSTANT disassembly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var chunk = Self.init(allocator);
    var buffer = ArrayList(u8).init(allocator);

    try chunk.writeConst(1.2, 123);
    try chunk.writeOp(.Return, 123);
    try chunk.disassemble(buffer.outStream(), "test chunk");

    const expected =
        \\== test chunk ==
        \\0000  123 OP_CONSTANT      '1.2'
        \\0009    | OP_RETURN
        \\
    ;
    std.testing.expectEqualSlices(u8, expected, buffer.items);
}
