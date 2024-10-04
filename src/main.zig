const std = @import("std");
const vm = @import("vm.zig");
const insts = @import("instructions.zig");
pub fn main() !void {
    const opcode: [2]u32 = .{ insts.buildInstruction(insts.OpCode.Load, 0, 10, 0), insts.buildInstruction(insts.OpCode.Alloca, 1, 0, 0) };
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var machine = try vm.VM.init(arena.allocator(), 1024 * 1024 * 2);
    try machine.execute(&opcode);
}
