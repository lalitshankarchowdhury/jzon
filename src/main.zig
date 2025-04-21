const std = @import("std");
const jzon2 = @import("jzon2.zig");

pub fn main() !void {
    const filename = "test.json";
    const root_doc = try jzon2.parseFile(filename);
    defer root_doc.deinit();
    const root_value = root_doc.getRoot() orelse return error.RootError;
    const array = root_value.getObject("array") orelse return error.KeyError;
    std.debug.print("{}\n", .{array.getArrayLength()});
    try array.setArray(&root_doc, &[10]f64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });
    const new_items = [_][:0]const u8{ "Lalit", "Shankar", "Chowdhury" };
    try array.setArray(&root_doc, &new_items);
    try array.setArray(&root_doc, &[1]bool{true});
    try array.setArrayItemAt(&root_doc, true, 100);
    std.debug.print("{}\n", .{array.getArrayLength()});
    try jzon2.writeFile(filename, &root_doc);
}
