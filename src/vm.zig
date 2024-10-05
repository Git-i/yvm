const insts = @import("instructions.zig");
const Allocator = @import("std").mem.Allocator;
const ArrayList = @import("std").ArrayList;
const ExecutionError = error{ VM_ExecutionTerminated, VM_StackOverflow, VM_StackUnderflow, VM_PrematureBEnd, VM_InvalidSize, VM_InvalidAccess };
pub const VM = struct {
    registers: [32]u64 = undefined,
    stack: []u8,
    stack_off: usize = 0,
    block_bytes: ArrayList(usize) = undefined,
    pc: usize = 0,
    pub fn init(alloc: Allocator, size: usize) !VM {
        var machine = VM{ .stack = try alloc.alloc(u8, size) };
        machine.block_bytes = ArrayList(usize).init(alloc);
        @memset(&machine.registers, 0);
        return machine;
    }
    pub fn deinit(self: *VM) void {
        self.block_bytes.deinit();
    }
    /// Execute a stream of instructions with the vm.
    /// After this is called, the vm's state is bad as it modifies the program counter
    pub fn execute(self: *VM, instructions: []const u32) !void {
        while (self.pc < instructions.len) {
            const decoded: *const [4]u8 = @ptrCast(&instructions[self.pc]);
            self.executeInstruction(decoded) catch |err| {
                if (err == error.VM_ExecutionTerminated) {
                    return;
                }
                return err;
            };
            self.pc += 4;
        }
    }
    /// Execute a single instruction
    pub fn executeSingle(self: *VM, insruction: u32) !void {
        try self.executeInstruction(@ptrCast(&insruction));
    }
    fn validate_memory_address(self: VM, addr: usize, size: usize) !void {
        const stack_ptr = @intFromPtr(self.stack.ptr);
        if (addr < stack_ptr or addr + size > (stack_ptr + self.stack_off)) {
            return error.VM_InvalidAccess;
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
                self.inst_load(data[1], as_16_bits.*);
            },
            .Alloca => {
                try self.inst_alloca(data[1], data[2]);
            },
            .Freea => {
                self.stack_off -= self.registers[data[1]];
            },
            .BBeg => {
                try self.block_bytes.append(0);
            },
            .BEnd => {
                const blocks = self.block_bytes.items;
                if (blocks.len > 0) {
                    self.stack_off -= self.block_bytes.pop();
                    return;
                }
                return error.VM_PrematureBEnd;
            },
            .StoreN => {
                try self.inst_storen(data[1], data[2], data[3]);
            },
            .IAdd64 => {
                @as(*i64, @ptrCast(&self.registers[data[1]])).* =
                    @as(*i64, @ptrCast(&self.registers[data[2]])).* +
                    @as(*i64, @ptrCast(&self.registers[data[3]])).*;
            },
            .UAdd64 => {
                self.registers[data[1]] =
                    self.registers[data[2]] +
                    self.registers[data[3]];
            },
            .FAdd64 => {
                @as(*f64, @ptrCast(&self.registers[data[1]])).* =
                    @as(*f64, @ptrCast(&self.registers[data[2]])).* +
                    @as(*f64, @ptrCast(&self.registers[data[3]])).*;
            },
            .IAdd32 => {
                @as(*i32, @ptrCast(self.reg_32(data[1]))).* =
                    @as(*i32, @ptrCast(self.reg_32(data[2]))).* +
                    @as(*i32, @ptrCast(self.reg_32(data[3]))).*;
            },
            .UAdd32 => {
                self.reg_32(data[1]).* =
                    self.reg_32(data[2]).* +
                    self.reg_32(data[3]).*;
            },
            .FAdd32 => {
                @as(*f32, @ptrCast(self.reg_32(data[1]))).* =
                    @as(*f32, @ptrCast(self.reg_32(data[2]))).* +
                    @as(*f32, @ptrCast(self.reg_32(data[3]))).*;
            },
            else => {},
        }
    }
    fn reg_32(self: *VM, reg_idx: u8) *u32 {
        return @ptrFromInt(@intFromPtr(&self.registers[reg_idx]) + 4);
    }
    fn inst_load(self: *VM, reg_idx: u8, value: u16) void {
        self.registers[reg_idx] = value;
    }
    fn inst_alloca(self: *VM, out_reg_idx: u8, size_reg_idx: u8) !void {
        const size = self.registers[size_reg_idx];
        self.registers[out_reg_idx] = @intFromPtr(&self.stack[self.stack_off]);
        self.stack_off += size;

        const blocks = self.block_bytes.items;
        if (blocks.len > 0) blocks[blocks.len - 1] += size;
        if (self.stack_off >= self.stack.len) {
            return error.VM_StackOverflow;
        }
    }
    fn inst_storen(self: *VM, n: u8, value_reg_idx: u8, addr_reg_idx: u8) !void {
        const addr_u = self.registers[addr_reg_idx];
        try self.validate_memory_address(addr_u, n / 8);
        switch (n) {
            64 => {
                const addr: *u64 = @ptrFromInt(addr_u);
                addr.* = self.registers[value_reg_idx];
            },
            32 => {
                const addr: *u32 = @ptrFromInt(addr_u);
                const value_ptr: *u32 = @ptrFromInt(@intFromPtr(&self.registers[value_reg_idx]) + 4); // get the last 4 bits
                addr.* = value_ptr.*;
            },
            16 => {
                const addr: *u16 = @ptrFromInt(addr_u);
                const value_ptr: *u16 = @ptrFromInt(@intFromPtr(&self.registers[value_reg_idx]) + 6);
                addr.* = value_ptr.*;
            },
            8 => {
                const addr: *u8 = @ptrFromInt(addr_u);
                const value_ptr: *u8 = @ptrFromInt(@intFromPtr(&self.registers[value_reg_idx]) * 7);
                addr.* = value_ptr.*;
            },
            else => {
                return error.VM_InvalidSize;
            },
        }
    }
};

test "test blocks" {
    const std = @import("std");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var vm = try VM.init(arena.allocator(), 1024 * 1024 * 2);
    defer vm.deinit();
    var inst = insts.buildInstruction(insts.OpCode.BBeg, 0, 0, 0);
    try vm.executeInstruction(@ptrCast(&inst));

    inst = insts.buildInstruction(insts.OpCode.Load, 0, 128, 0);
    try vm.executeInstruction(@ptrCast(&inst));
    try std.testing.expect(vm.registers[0] == 128);

    inst = insts.buildInstruction(insts.OpCode.Alloca, 1, 0, 0);
    try vm.executeInstruction(@ptrCast(&inst));
    try std.testing.expect(vm.stack_off == 128);

    inst = insts.buildInstruction(insts.OpCode.BEnd, 0, 0, 0);
    try vm.executeInstruction(@ptrCast(&inst));
    try std.testing.expect(vm.stack_off == 0);
}

test "test store_n" {
    const std = @import("std");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var vm = try VM.init(arena.allocator(), 1024);
    defer vm.deinit();
    vm.registers[0] = 8;
    try vm.executeSingle(insts.buildInstruction(insts.OpCode.Alloca, 1, 0, 0));
    try vm.executeSingle(insts.buildInstruction(insts.OpCode.StoreN, 64, 0, 1));
    const val: *u64 = @ptrFromInt(@intFromPtr(vm.stack.ptr));
    std.debug.print("value: {}\n", .{val.*});
}
