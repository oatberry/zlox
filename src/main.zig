const std = @import("std");
const process = std.process;
const Allocator = std.mem.Allocator;

const VM = @import("vm.zig");

pub fn main() !u8 {
    const allocator = std.heap.page_allocator;

    const args: [][]u8 = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    var exit_code: u8 = 0;

    if (args.len == 1) {
        try repl(allocator);
    } else if (args.len == 2) {
        exit_code = try runFile(allocator, args[1]);
    } else {
        std.debug.warn("Usage: {} [path]\n", .{args[0]});
        exit_code = 1;
    }

    return exit_code;
}

fn repl(allocator: *Allocator) !void {
    var vm = VM.init(allocator);
    defer vm.deinit();

    const stderr = std.io.getStdErr().outStream();
    const stdin = std.io.getStdIn().inStream();

    try stderr.writeAll(" /// zlox ///\n");
    while (true) {
        try stderr.writeAll(">>> ");
        const input = stdin.readUntilDelimiterAlloc(allocator, '\n', 4096) catch |err| {
            switch (err) {
                error.EndOfStream => return,
                else => return err,
            }
        };
        defer allocator.free(input);

        vm.interpret(input) catch |err| {
            std.debug.warn("Error: VM returned error: {}", .{@errorName(err)});
        };
    }
}

fn runFile(allocator: *Allocator, filename: []const u8) !u8 {
    const source = readFile(allocator, filename) catch |err| {
        std.debug.warn("Could not open {}: {}", .{ filename, @errorName(err) });
        return 74;
    };
    defer allocator.free(source);

    var vm = VM.init(allocator);
    defer vm.deinit();

    vm.interpret(source) catch |err| switch (err) {
        error.CompileError => return 65,
        error.RuntimeError => return 70,
        else => return err,
    };
    return 0;
}

fn readFile(allocator: *Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    _ = try file.read(buffer);
    return buffer;
}
