
pub const VM = struct {
    registers: [32]i64,
    pc: usize,
    pub fn new() VM {
        const machine = VM{
            .registers = undefined,
            .pc = 0
        };
        @memset(machine.registers, 0);
        return machine;
    }
    pub fn execute(insts: []const u32) !void {
        for (insts) |instruction| {
            const decoded: *[4]u8 = &instruction;
            try executeInstruction(decoded);
        }
    }
    fn executeInstruction(data: *[4]u8) !void {

    }
};