pub const OpCode = enum(u8) {
    /// Stops Execution
    Halt,
    /// Loads a value to a specified register
    /// - `p0`: The register number
    /// - `p1`: The value to load
    Load,
    /// Allocate bytes on the stack
    /// - `p0`: The allocated address
    /// - `p1`: The number of bytes
    Alloca,
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