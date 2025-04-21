const c = @cImport({
    @cInclude("yyjson.h");
});
const std = @import("std");

pub const JsonDoc = struct {
    doc: *c.yyjson_doc,

    pub fn deinit(self: *const JsonDoc) void {
        c.yyjson_doc_free(self.doc);
    }

    pub fn getRoot(self: *const JsonDoc) ?JsonValue {
        const json_root = c.yyjson_doc_get_root(self.doc) orelse return null;
        return JsonValue{ .value = json_root };
    }
};

pub const JsonType = enum(u32) {
    None = 0,
    Raw,
    Null,
    Boolean,
    Number,
    String,
    Array,
    Object,
};

pub const JsonValue = struct {
    value: *c.yyjson_val,

    pub fn getType(self: *const JsonValue) JsonType {
        const json_type = c.yyjson_get_type(self.value);
        return json_type;
    }

    pub fn getString(self: *const JsonValue) ?[]const u8 {
        const json_string = c.yyjson_get_str(self.value) orelse return null;
        return std.mem.span(json_string);
    }

    pub fn getNumber(self: *const JsonValue) f64 {
        const json_number = c.yyjson_get_num(self.value);
        return json_number;
    }

    pub fn getArrayLength(self: *const JsonValue) usize {
        const array_length = c.yyjson_arr_size(self.value);
        return array_length;
    }

    pub fn getArrayValueAt(self: *const JsonValue, idx: usize) ?JsonValue {
        const json_value = c.yyjson_arr_get(self.value, idx) orelse return null;
        return JsonValue{ .value = json_value };
    }

    pub fn getArrayItems(self: *const JsonValue, allocator: std.mem.Allocator) ?[]JsonValue {
        const values = try allocator.alloc(JsonValue, self.count);
        for (0..self.count) |i| {
            const array_value = c.yyjson_arr_get(self.array, i) orelse return null;
            const json_value = JsonValue{ .value = array_value };
            values[i] = json_value;
        }
        return values;
    }

    pub fn getBoolean(self: *const JsonValue) bool {
        const json_bool = c.yyjson_get_bool(self.value);
        return json_bool;
    }

    pub fn getValue(self: *const JsonValue, key: [:0]const u8) ?JsonValue {
        const json_value = c.yyjson_obj_get(self.value, key) orelse return null;
        return JsonValue{ .value = json_value };
    }

    pub fn getValueFromPath(self: *const JsonValue, keys: []const [:0]const u8) ?JsonValue {
        if (keys.len == 0) return null;
        var current = self.getValue(keys[0]);
        for (1..keys.len) |i| {
            current = current.?.getValue(keys[i]) orelse return null;
        }
        return current;
    }
};

pub const JsonError = error{ParseFailed};

pub fn parseFile(filename: [:0]const u8) !JsonDoc {
    var err: c.yyjson_read_err = c.yyjson_read_err{
        .code = undefined,
        .msg = undefined,
        .pos = undefined,
    };
    const doc = c.yyjson_read_file(filename, 0, null, &err) orelse return JsonError.ParseFailed;
    return JsonDoc{ .doc = doc };
}
