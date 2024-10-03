const insts = @import("instructions.zig");
const Allocator = @import("std").mem.Allocator;
const ExecutionError = error {
    VM_ExecutionTerminated
};
pub const VM = struct {
    registers: [32]i64,
    stack: *u8,
    pub fn new(alloc: Allocator) VM {
        var machine = VM{
            .registers = undefined,
            .stack = alloc.alloc(u8, 1024 * 1024 * 2) //2mb stack
        };
        @memset(&machine.registers, 0);
        return machine;
    }
    pub fn execute(self: *VM, instructions: []const u32) !void {
        for (instructions) |instruction| {
            const decoded: *const [4]u8 = @ptrCast(&instruction);
            self.executeInstruction(decoded) catch |err| {
                if(err == error.VM_ExecutionTerminated) {
                    return;
                }
                return err;
            };
        }
    }
    fn executeInstruction(self: *VM, data: *const [4]u8) !void {
        const as_enum: insts.OpCode = @enumFromInt(data[0]);
        switch (as_enum) {
            .Halt => {
               return error.VM_ExecutionTerminated;
            },
            .Load => {
                const as_16_bits: *const u16 = @ptrCast(@alignCast(&data[2]));
                self.registers[data[1]] = as_16_bits.*;
            }
        }
    }
};