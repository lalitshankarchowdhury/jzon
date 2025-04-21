# jzon

`jzon` is a dead simple JSON library for Zig. By leveraging the excellent `yyjson` library, `jzon` delivers a 3-4x speedup on parsing tasks.

## Usage

```zig
const std = @import("std");
const jzon = @import("jzon");

pub fn main() !void {
    // Parse the JSON file
    const filename = "data.json";
    const doc = try jzon.parseFile(filename);
    defer doc.deinit();

    // Get the root value (typically an object or array)
    const root = try doc.getRoot();

    // Access a string value in the root object
    const name = root.getObject("name").?.getString() orelse "";
    std.debug.print("Name: {s}\n", .{name});

    // Access and modify array values
    const array = root.getObject("items");
    std.debug.print("Items before: {}\n", .{array.?.getArrayLength()});

    // Set an array of numbers
    try array.?.setArray(&doc, &[_]f64{ 10.5, 20.3, 30.7 });

    // Replace existing item in array (or append if index out of range)
    try array.?.setArrayItemAt(&doc, 4, 99.0);
    try array.?.setArrayItemAt(&doc, 5, "99.0");
    try array.?.setArrayItemAt(&doc, 6, 99);
    try array.?.setArrayItemAt(&doc, 7, true);
    try array.?.setArrayItemAt(&doc, 8, null);
    std.debug.print("Items after: {}\n", .{array.?.getArrayLength()});

    // Access a nested object and modify it
    const address = root.getObject("address");
    try address.?.setObject(&doc, "street", "Zig street 123");
    const street_name = address.?.getObject("street").?.getString() orelse "";
    std.debug.print("Updated address: {s}\n", .{street_name});

    // Create an object
    try address.?.setObject(&doc, "street_int", 123);
    try address.?.setObject(&doc, "street_float", 123.0);
    try address.?.setObject(&doc, "street_bool", true);
    try address.?.setObject(&doc, "street_null", null);

    try jzon.writeFile(filename, &doc);
}
```