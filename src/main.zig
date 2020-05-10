const std = @import("std");
const lox = @import("lox.zig");

const Allocator = std.mem.Allocator;

pub fn main() anyerror!void {
    // using an Arena Allocator on recommendation of the language ref??
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const args: [][]u8 = try std.process.argsAlloc(allocator);

    if (args.len > 2) {
        std.debug.warn("Usage: jlox [script]\n", .{});
        std.process.exit(1);
    } else if (args.len == 2) {
        const script_file = args[1];
        runFile(allocator, script_file) catch |err| {
            if (lox.had_error) return std.process.exit(65);
            if (lox.had_runtime_error) return std.process.exit(70);
        };
    } else {
        try runPrompt(allocator);
    }
}

fn runFile(allocator: *Allocator, path: []u8) !void {
    const script: []u8 = try readFile(allocator, path);
    defer allocator.free(script);
    return lox.run(allocator, script);
}

fn readFile(allocator: *Allocator, path: []u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    _ = try file.read(buffer);
    return buffer;
}

fn runPrompt(allocator: *Allocator) !void {
    const stderr = std.io.getStdErr().outStream();
    const stdin = std.io.getStdIn().inStream();

    while (true) {
        try stderr.writeAll("zlox > ");
        const input = try stdin.readUntilDelimiterAlloc(allocator, '\n', 4096);
        defer allocator.free(input);
        lox.run(allocator, input) catch |err| {
            if (err == error.OutOfMemory) {
                return err;
            } else {
                std.debug.warn("Interpreter returned error: {}\n", .{@tagName(err)});
            }
        };
        lox.had_error = false;
    }
}
