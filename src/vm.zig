const insts = @import("instructions.zig");
const Allocator = @import("std").mem.Allocator;
const ArrayList = @import("std").ArrayList;
const ExecutionError = error {
    VM_ExecutionTerminated,
    VM_StackOverflow
};
pub const VM = struct {
    registers: [32]u64 = undefined,
    stack: []u8,
    stack_off: usize = 0,
    block_bytes: ArrayList(usize) = undefined,
    pub fn init(alloc: Allocator, size: usize) !VM {
        var machine = VM{
            .stack = try alloc.alloc(u8, size)
        };
        machine.block_bytes = ArrayList(usize).init(alloc);
        @memset(&machine.registers, 0);
        return machine;
    }
    pub fn deinit(self: *VM) void {
        self.block_bytes.deinit();
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
                const blocks = self.block_bytes.items;
                if(blocks.len > 0) blocks[blocks.len - 1] += self.registers[data[2]];
                if (self.stack_off >= self.stack.len) {
                    return error.VM_StackOverflow;
                }
            },
            .Freea => {
                self.stack_off -= self.registers[data[1]];
            },
            .BBeg => {
                try self.block_bytes.append(0);
            },
            .BEnd => {
                const blocks = self.block_bytes.items;
                self.stack_off -= blocks[blocks.len - 1];
                if(blocks.len <= 0) self.block_bytes.pop();
            }
        }
    }
};