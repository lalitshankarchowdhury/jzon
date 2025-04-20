const std = @import("std");
const jzon = @import("jzon.zig");

pub fn main() !void {
    const filename = "twitter.json";

    // Warm up filesystem cache and allocator
    _ = try jzon.parse_file(filename);

    // Benchmark parameters
    const warmup_runs = 10;
    const measure_runs = 100;
    var total_parse_ns: u64 = 0;
    var total_access_ns: u64 = 0;

    // Benchmark loop
    for (0..warmup_runs + measure_runs) |run| {
        // Parse benchmark
        const parse_start = std.time.nanoTimestamp();
        const root_value = try jzon.parse_file(filename);
        const parse_end = std.time.nanoTimestamp();

        // Only measure after warmup
        if (run >= warmup_runs) {
            total_parse_ns += @as(u64, @intCast(parse_end - parse_start));
        }

        // Field access benchmark
        const access_start = std.time.nanoTimestamp();
        const path = [_][:0]const u8{"statuses"};
        const para = root_value.getPath(&path) orelse return error.MissingField;
        const array = para.array() orelse return error.TypeError;

        for (0..array.count) |i| {
            const user_name_path = [_][:0]const u8{ "user", "screen_name" };
            const text = array.at(i).?.getPath(&user_name_path) orelse return error.MissingField;
            _ = text.string() orelse return error.TypeError;
        }
        const access_end = std.time.nanoTimestamp();

        if (run >= warmup_runs) {
            total_access_ns += @as(u64, @intCast(access_end - access_start));
        }

        root_value.deinit();
    }

    // Calculate averages
    const avg_parse_ns = total_parse_ns / measure_runs;
    const avg_access_ns = total_access_ns / measure_runs;

    // Print results
    std.debug.print("\nBenchmark Results (twitter.json):\n", .{});
    std.debug.print("--------------------------------\n", .{});
    std.debug.print("Average parse time:  {d:.2} us\n", .{@as(f64, @floatFromInt(avg_parse_ns)) / 1000});
    std.debug.print("Average access time: {d:.2} us\n", .{@as(f64, @floatFromInt(avg_access_ns)) / 1000});
    std.debug.print("Total operations:    {d} statuses processed\n", .{(try get_statuses_count(filename)) * measure_runs});
}

// Helper to count statuses without full parsing
fn get_statuses_count(filename: [:0]const u8) !usize {
    const root_value = try jzon.parse_file(filename);
    defer root_value.deinit();
    const path = [_][:0]const u8{"statuses"};
    const para = root_value.getPath(&path) orelse return error.MissingField;
    const array = para.array() orelse return error.TypeError;
    return array.count;
}
