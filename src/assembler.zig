const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const word_steam = struct { source: []const u8 };

fn assemble(source: []const u8, alloc: Allocator) ArrayList(u32) {
    var list = ArrayList(u32).init(alloc);
    const stream = word_steam{ .source = source };
    return list;
}
