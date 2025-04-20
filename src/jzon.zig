const c = @cImport({
    @cInclude("parson.h");
});
const std = @import("std");

pub const JsonValue = struct {
    value: *c.JSON_Value,
    type: JsonType,

    pub fn deinit(self: *const JsonValue) void {
        c.json_value_free(self.value);
    }

    pub fn getString(self: *const JsonValue) ?[]const u8 {
        const json_string = c.json_value_get_string(self.value) orelse return null;
        return std.mem.span(json_string);
    }

    pub fn getNumber(self: *const JsonValue) f64 {
        const json_number = c.json_value_get_number(self.value);
        return json_number;
    }

    pub fn getObject(self: *const JsonValue) ?JsonObject {
        const json_object = c.json_value_get_object(self.value) orelse return null;
        return JsonObject{ .object = json_object };
    }

    pub fn getArray(self: *const JsonValue) ?JsonArray {
        const json_array = c.json_value_get_array(self.value) orelse return null;
        const json_array_count = c.json_array_get_count(json_array);
        return JsonArray{ .array = json_array, .count = json_array_count };
    }

    pub fn getBoolean(self: *const JsonValue) bool {
        const json_boolean = c.json_value_get_boolean(self.value);
        return json_boolean != 0;
    }

    pub fn getValue(self: *const JsonValue, key: [:0]const u8) ?JsonValue {
        if (self.type != JsonType.Object) {
            return null;
        }
        const json_object = c.json_value_get_object(self.value) orelse return null;
        const obj = JsonObject{ .object = json_object };
        return obj.getValue(key) orelse return null;
    }

    pub fn getValueFromPath(self: *const JsonValue, keys: []const [:0]const u8) ?JsonValue {
        if (self.type != JsonType.Object) {
            return null;
        }
        const json_object = c.json_value_get_object(self.value) orelse return null;
        const obj = JsonObject{ .object = json_object };
        return obj.getValueFromPath(keys) orelse return null;
    }
};

pub const JsonType = enum(u32) {
    Null = 0,
    String = 1,
    Number = 2,
    Object = 3,
    Array = 4,
    Boolean = 5,
};

pub const JsonObject = struct {
    object: *c.JSON_Object,

    pub fn getValue(self: *const JsonObject, key: [:0]const u8) ?JsonValue {
        const json_value = c.json_object_get_value(self.object, key) orelse return null;
        const json_value_type = c.json_value_get_type(json_value);
        if (json_value_type == -1) {
            return null;
        }
        return JsonValue{ .value = json_value, .type = @as(JsonType, @enumFromInt(json_value_type - 1)) };
    }

    pub fn getValueFromPath(self: *const JsonObject, keys: []const [:0]const u8) ?JsonValue {
        if (keys.len == 0) return null;
        var current = self.getValue(keys[0]);
        for (1..keys.len) |i| {
            const obj = current.?.getObject() orelse return null;
            current = obj.getValue(keys[i]);
        }
        return current;
    }
};

pub const JsonArray = struct {
    array: *c.JSON_Array,
    count: u64,

    pub fn valueAt(self: *const JsonArray, index: usize) ?JsonValue {
        const json_value = c.json_array_get_value(self.array, index) orelse return null;
        const json_value_type = c.json_value_get_type(json_value);
        if (json_value_type == -1) {
            return null;
        }
        return JsonValue{ .value = json_value, .type = @as(JsonType, @enumFromInt(json_value_type - 1)) };
    }

    pub fn getItems(self: *const JsonArray, allocator: std.mem.Allocator) ?[]JsonValue {
        const values = try allocator.alloc(JsonValue, self.count);
        for (0..self.count) |i| {
            const json_value = c.json_array_get_value(self.array, i) orelse return null;
            const json_value_type = c.json_value_get_type(json_value);
            if (json_value_type == -1) {
                return null;
            }
            const value = JsonValue{ .value = json_value, .type = @as(JsonType, @enumFromInt(json_value_type - 1)) };
            values[i] = value;
        }
        return values;
    }
};

pub const JsonError = error{ ParseFailed, TypeError, KeyError };

pub fn parseFile(filename: [:0]const u8) !JsonValue {
    const json_value = c.json_parse_file(filename.ptr) orelse return JsonError.ParseFailed;
    const json_value_type = c.json_value_get_type(json_value);
    if (json_value_type == -1) {
        return JsonError.TypeError;
    }
    return JsonValue{ .value = json_value, .type = @as(JsonType, @enumFromInt(json_value_type - 1)) };
}
