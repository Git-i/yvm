const insts = @import("instructions.zig");
const Allocator = @import("std").mem.Allocator;
const ExecutionError = error {
    VM_ExecutionTerminated,
    VM_StackOverflow
};
pub const VM = struct {
    registers: [32]u64,
    stack: []u8,
    stack_off: usize,
    is_in_block: bool = false,
    block_bytes: usize = 0,
    pub fn new(alloc: Allocator, size: usize) !VM {
        var machine = VM{
            .registers = undefined,
            .stack_off = undefined,
            .stack = try alloc.alloc(u8, size)
        };
        machine.stack_off = 0;
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
            },
            .Alloca => {
                self.registers[data[1]] = @intFromPtr(&self.stack[self.stack_off]);
                self.stack_off += self.registers[data[2]];
                if(self.is_in_block) self.block_bytes += self.registers[data[2]];
                if (self.stack_off >= self.stack.len) {
                    return error.VM_StackOverflow;
                }
            },
            .Freea => {
                self.stack -= self.registers[data[1]];
            }
        }
    }
};