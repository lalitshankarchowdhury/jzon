const std = @import("std");
const jzon = @import("jzon.zig");

pub fn main() !void {
    const root_value = try jzon.parse_file("test.json");
    defer root_value.deinit();
    const para = root_value
        .get("glossary").?.get("GlossDiv").?.get("GlossList").?.get("GlossEntry").?.get("GlossDef").?.get("para") orelse return error.MissingField;
    std.debug.print("{s}\n", .{para.string() orelse ""});
}
