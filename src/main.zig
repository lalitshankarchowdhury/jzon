const std = @import("std");
const jzon = @import("jzon.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const filename = "twitter.json";

    // Load entire file into memory for std.json benchmark
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    const file_size = (try file.stat()).size;
    const file_data = try allocator.alloc(u8, file_size);
    defer allocator.free(file_data);
    _ = try file.readAll(file_data);

    // Benchmark parameters
    const warmup_runs = 10;
    const measure_runs = 100;
    var total_parse_ns_jzon: u64 = 0;
    var total_access_ns_jzon: u64 = 0;
    var total_parse_ns_builtin: u64 = 0;

    for (0..warmup_runs + measure_runs) |run| {
        // --- jzon parse benchmark ---
        const parse_start_jzon = std.time.nanoTimestamp();
        const root_value = try jzon.parseFile(filename);
        const parse_end_jzon = std.time.nanoTimestamp();

        // --- builtin std.json parse benchmark ---
        const parse_start_builtin = std.time.nanoTimestamp();
        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, file_data, .{});
        const parse_end_builtin = std.time.nanoTimestamp();
        parsed.deinit();

        if (run >= warmup_runs) {
            total_parse_ns_jzon += @as(u64, @intCast(parse_end_jzon - parse_start_jzon));
            total_parse_ns_builtin += @as(u64, @intCast(parse_end_builtin - parse_start_builtin));
        }

        // --- jzon access benchmark ---
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

        if (run >= warmup_runs) {
            total_access_ns_jzon += @as(u64, @intCast(access_end_jzon - access_start_jzon));
        }

        root_value.deinit();
    }

    const avg_parse_ns_jzon = total_parse_ns_jzon / measure_runs;
    const avg_access_ns_jzon = total_access_ns_jzon / measure_runs;
    const avg_parse_ns_builtin = total_parse_ns_builtin / measure_runs;

    std.debug.print("\nBenchmark Results (twitter.json):\n", .{});
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("Jzon parse time:     {d:.2} us\n", .{@as(f64, @floatFromInt(avg_parse_ns_jzon)) / 1000});
    std.debug.print("Jzon access time:    {d:.2} us\n", .{@as(f64, @floatFromInt(avg_access_ns_jzon)) / 1000});
    std.debug.print("Builtin parse time:  {d:.2} us\n", .{@as(f64, @floatFromInt(avg_parse_ns_builtin)) / 1000});
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
