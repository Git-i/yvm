const std = @import("std");
const inst = @import("vm.zig");
pub fn main() !void {
    const lol = inst.VM.new();
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, {s}!\n", .{"World"});
}