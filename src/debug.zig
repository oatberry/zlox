const std = @import("std");
const mem = std.mem;

const Chunk = @import("chunk.zig");
const OpCode = Chunk.OpCode;

pub fn disassembleChunk(chunk: *const Chunk, out_stream: var, name: []const u8) !void {
    try out_stream.print("== {} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.code.items.len) {
        offset = try disassembleInstruction(chunk, out_stream, offset);
    }
}

pub fn disassembleInstruction(chunk: *const Chunk, out_stream: var, offset: usize) !usize {
    try out_stream.print("{d:0>4} ", .{offset});
    if (offset > 0 and chunk.getLine(offset) == chunk.getLine(offset - 1)) {
        try out_stream.writeAll("   | ");
    } else {
        try out_stream.print("{d:>4} ", .{chunk.getLine(offset)});
    }

    // @intToEnum cannot fail since OpCode is a non-exhaustive enum.
    const byte = chunk.read(offset);
    switch (@intToEnum(OpCode, byte)) {
        .Constant => return constantInstruction(out_stream, "OP_CONSTANT", chunk, offset),
        .Return => return simpleInstruction(out_stream, "OP_RETURN", offset),
        _ => {
            try out_stream.print("Unknown opcode 0x{x:0>2}\n", .{byte});
            return offset + 1;
        },
    }
}

fn simpleInstruction(out_stream: var, name: []const u8, offset: usize) !usize {
    try out_stream.print("{}\n", .{name});
    return offset + 1;
}

fn constantInstruction(
    out_stream: var,
    name: []const u8,
    chunk: *const Chunk,
    offset: usize,
) !usize {
    const constant = chunk.readConstant(offset + 1);
    try out_stream.print("{s:<16} '{d}'\n", .{ name, constant });
    return offset + @sizeOf(usize) + 1;
}
