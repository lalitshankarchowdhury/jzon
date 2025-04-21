const std = @import("std");
const jzon = @import("jzon.zig");
const jzon2 = @import("jzon2.zig");

pub fn main() !void {
    const filename = "twitter.json";

    // Benchmark parameters
    const warmup_runs = 3;
    const measure_runs = 100;
    var total_parse_ns_jzon: u64 = 0;
    var total_parse_ns_jzon2: u64 = 0;
    var total_access_ns_jzon: u64 = 0;
    var total_access_ns_jzon2: u64 = 0;

    for (0..warmup_runs + measure_runs) |run| {
        // --- jzon parse benchmark ---
        const parse_start_jzon = std.time.nanoTimestamp();
        const root_value = try jzon.parseFile(filename);
        const parse_end_jzon = std.time.nanoTimestamp();
        defer root_value.deinit();

        // --- jzon2 parse benchmark ---
        const parse_start_jzon2 = std.time.nanoTimestamp();
        const root_doc = try jzon2.parseFile(filename);
        const root_value2 = root_doc.getRoot() orelse return error.RootError;
        const parse_end_jzon2 = std.time.nanoTimestamp();
        defer root_doc.deinit();

        if (run >= warmup_runs) {
            total_parse_ns_jzon += @as(u64, @intCast(parse_end_jzon - parse_start_jzon));
            total_parse_ns_jzon2 += @as(u64, @intCast(parse_end_jzon2 - parse_start_jzon2));
        }

        const access_start_jzon = std.time.nanoTimestamp();
        const path = [_][:0]const u8{"statuses"};
        const statuses = root_value.getValueFromPath(&path) orelse return error.MissingField;
        const array = statuses.getArray() orelse return error.TypeError;
        for (0..array.count) |i| {
            const user_name_path = [_][:0]const u8{ "user", "screen_name" };
            const text = array.valueAt(i).?.getValueFromPath(&user_name_path) orelse return error.MissingField;
            _ = text.getString() orelse return error.TypeError;
        }
        const access_end_jzon = std.time.nanoTimestamp();

        const access_start_jzon2 = std.time.nanoTimestamp();
        const array2 = root_value2.getValueFromPath(&path) orelse return error.MissingField;
        for (0..array2.getArrayLength()) |i| {
            const user_name_path = [_][:0]const u8{ "user", "screen_name" };
            const text = array2.getArrayValueAt(i).?.getValueFromPath(&user_name_path) orelse return error.MissingField;
            _ = text.getString() orelse return error.TypeError;
        }
        const access_end_jzon2 = std.time.nanoTimestamp();

        if (run >= warmup_runs) {
            total_access_ns_jzon += @as(u64, @intCast(access_end_jzon - access_start_jzon));
            total_access_ns_jzon2 += @as(u64, @intCast(access_end_jzon2 - access_start_jzon2));
        }
    }

    const avg_parse_ns_jzon = total_parse_ns_jzon / measure_runs;
    const avg_access_ns_jzon = total_access_ns_jzon / measure_runs;
    const avg_parse_ns_jzon2 = total_parse_ns_jzon2 / measure_runs;
    const avg_access_ns_jzon2 = total_access_ns_jzon2 / measure_runs;

    std.debug.print("\nBenchmark Results (twitter.json):\n", .{});
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("Jzon parse time:     {d:.2} us\n", .{@as(f64, @floatFromInt(avg_parse_ns_jzon)) / 1000});
    std.debug.print("Jzon access time:    {d:.2} us\n", .{@as(f64, @floatFromInt(avg_access_ns_jzon)) / 1000});
    std.debug.print("Jzon2 parse time:     {d:.2} us\n", .{@as(f64, @floatFromInt(avg_parse_ns_jzon2)) / 1000});
    std.debug.print("Jzon2 access time:    {d:.2} us\n", .{@as(f64, @floatFromInt(avg_access_ns_jzon2)) / 1000});
    std.debug.print("Total operations:    {d} statuses processed\n", .{(try get_statuses_count(filename)) * measure_runs});
}

fn get_statuses_count(filename: [:0]const u8) !usize {
    const root_value = try jzon.parseFile(filename);
    defer root_value.deinit();
    const path = [_][:0]const u8{"statuses"};
    const para = root_value.getValueFromPath(&path) orelse return error.MissingField;
    const array = para.getArray() orelse return error.TypeError;
    return array.count;
}
