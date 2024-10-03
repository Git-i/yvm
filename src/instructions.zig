pub const OpCode = enum(u8) {
    /// Stops Execution
    Halt,
    /// Loads a value to a specified register
    /// - `p1`(reg): The register number
    /// - `p2`(val): The value to load
    Load,
    /// Allocate bytes on the stack
    /// - `p1`(reg): The allocated address
    /// - `p2`(reg): The number of bytes
    Alloca,
    /// Free bytes on the stack
    /// - `p1`(reg): Number of bytes to free
    Freea,
    /// Begin an automaitc memory block
    BBeg,
    /// End an automatic memory block
    BEnd,
    /// Store a value to the stack
    /// - `p1`(reg): register containing the value
    Store64,
    Store32,
    Store16,
    Store8
};

pub fn buildInstruction(code: OpCode,  p1: u8, p2: u8, p3: u8) u32 {
    var inst:u32 = 0;
    var inst_ptr: *[4]u8 = @ptrCast(&inst);
    inst_ptr[0] = @intFromEnum(code);
    inst_ptr[1] = p1;
    inst_ptr[2] = p2;
    inst_ptr[3] = p3;
    return inst;
}