const std = @import("std");
const vm = @import("vm.zig");
const insts = @import("instructions.zig");
pub fn main() !void {
    const opcode: [1]u32 = .{insts.buildInstruction(insts.OpCode.Load, 0, 10, 0)};
    var machine = vm.VM.new();
    try machine.execute(&opcode);
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, {s}!\n", .{"World"});
}