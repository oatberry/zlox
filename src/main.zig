const std = @import("std");
const io = std.io;

const VM = @import("vm.zig");
const Chunk = @import("chunk.zig");
const OpCode = Chunk.OpCode;

pub fn main() anyerror!void {
    // using an Arena Allocator on recommendation of the language ref??
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const args: [][]u8 = try std.process.argsAlloc(allocator);

    var chunk = Chunk.init(allocator);

    try chunk.writeConst(1.2, 123);
    try chunk.writeOp(.Negate, 123);
    try chunk.writeOp(.Return, 124);

    var vm = VM.init(&chunk, allocator);
    vm.debug_mode = true;
    const result = vm.run() catch |err| {
        switch (err) {
            error.CompileError => std.debug.warn("Compile Error: {}\n", .{@tagName(vm.error_code)}),
            error.RuntimeError => std.debug.warn("Runtime Error: {}\n", .{@tagName(vm.error_code)}),
            else => return err,
        }
        return;
    };

    std.debug.warn("VM returned: {}\n", .{result});
}
