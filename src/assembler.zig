const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const insts = @import("instructions.zig");

const assembly_error = error {InvalidParameters, NonRegisterArgFound, InvalidInstructions, InvalidNumber};

const word_steam = struct {
    source: []const u8,
    position: usize = 0,
    fn is_separating_char(char: u8) bool {
        return char == ' ' or char == ';' or char == '\n';
    }
    fn next_word(self: *word_steam) []const u8 {
        if(self.is_end()) return "";

        if(self.source[self.position] == ';' or self.source[self.position] == '\n') {
            self.advance_position(self.position + 1);
            return ";";
        }
        var next_space: usize = self.position;
        while (next_space < self.source.len and !is_separating_char(self.source[next_space])) {
            next_space += 1;
        }
        const begin = self.position;
        const end = next_space;

        self.advance_position(next_space);

        return self.source[begin..end];
    }
    fn advance_position(self: *word_steam, start: usize) void {
        self.position = start;
        while (self.position < self.source.len and self.source[self.position] == ' ') {
            self.position += 1;
        }
    }
    fn is_end(self: word_steam) bool {
        return self.position >= self.source.len;
    }
};

/// Assembled provided assembly for the virtual machine\
/// The assembly must be in the form:\
/// `OP_CODE param1 param2 ... (<new line>/';')`
fn assemble(source: []const u8, alloc: Allocator) !ArrayList(u32) {
    var list = ArrayList(u32).init(alloc);
    var stream = word_steam{ .source = source };
    var current_instruction: [4][]const u8 = undefined;
    var inst_index: u32 = 0;
    while(!stream.is_end()) {
        const word = stream.next_word();
        if (inst_index == 3 and !std.mem.eql(u8, word, ";")){
            return error.InvalidParameters;
        }
        if(std.mem.eql(u8, word, ";")) {
            try list.append(try assemble_instruction(current_instruction, inst_index));
            inst_index = 0;
            continue;
        }
        current_instruction[inst_index] = word;
        inst_index = (inst_index + 1) % 4;
    }
    if (inst_index > 0) try list.append(try assemble_instruction(current_instruction, inst_index));
    return list;
}

fn assert_is_register(text: []const u8) !u8 {
    if (text[0] != '#') return error.NonRegisterArgFound;
    var out_reg: u8 = 0;
    const n_digits = text.len - 1;
    for (1.., text[1..]) |idx, i| {
        if(!(i >= '0' or i <= '9')) return error.NonRegisterArgFound;
        const digit = i - '0';
        out_reg += @intCast(digit * std.math.pow(usize,10, n_digits - idx));
    }
    return out_reg;
}
fn assert_is_number(comptime t: type, text: []const u8) !t {
    var out_num: t = 0;
    const n_digits = text.len;
    for (0.., text[0..]) |idx, i| {
        if(!(i >= '0' or i <= '9')) return error.InvalidNumber;
        const digit = i - '0';
        out_num += @intCast(digit * std.math.pow(usize,10, n_digits - idx - 1));
    }
    return out_num;
}
fn assemble_instruction(list: [4][]const u8, param_count: u32) !u32 {
    if(param_count == 0 or param_count > 4) return error.InvalidParameters;

    const op_code = list[0];
    if(std.mem.eql(u8, op_code, "halt")) {
        if(param_count != 1) return error.InvalidParameters;
        return insts.buildInstruction(insts.OpCode.Halt, 0, 0, 0);
    }
    if(std.mem.eql(u8, op_code, "load")) {
        if(param_count != 3) return error.InvalidParameters;
        const as_u16 = try assert_is_number(u16, list[2]);
        const as_u8_arr: [*]const u8 = @ptrCast(&as_u16);
        return insts.buildInstruction(insts.OpCode.Load,
            try assert_is_register(list[1]),
            as_u8_arr[0], as_u8_arr[1]);
    }
    return error.InvalidInstructions;
}

test "register asssert" {
    std.debug.print("{}\n",.{try assert_is_register("#55")});
}
test "test assembly" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const l = try assemble("load #0 90", arena.allocator());
    std.debug.print("{any}", .{l.items});
}
