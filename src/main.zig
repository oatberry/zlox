const std = @import("std");
const lox = @import("lox.zig");

pub fn main() anyerror!void {
    // using an Arena Allocator on recommendation of the language ref??
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const args: [][]u8 = try std.process.argsAlloc(allocator);
}
