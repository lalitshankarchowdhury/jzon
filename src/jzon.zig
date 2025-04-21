const c = @cImport({
    @cInclude("yyjson.h");
});
const std = @import("std");

pub const JsonDoc = struct {
    doc: *c.yyjson_mut_doc,

    pub fn deinit(self: *const JsonDoc) void {
        c.yyjson_mut_doc_free(self.doc);
    }

    pub fn getRoot(self: *const JsonDoc) ?JsonValue {
        const json_root = c.yyjson_mut_doc_get_root(self.doc) orelse return null;
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
    value: *c.yyjson_mut_val,

    pub fn getType(self: *const JsonValue) JsonType {
        const json_type = c.yyjson_mut_get_type(self.value);
        return json_type;
    }

    pub fn getRawString(self: *const JsonValue) ?[]const u8 {
        const json_string = c.yyjson_mut_get_raw(self.value) orelse return null;
        return std.mem.span(json_string);
    }

    pub fn getString(self: *const JsonValue) ?[]const u8 {
        const json_string = c.yyjson_mut_get_str(self.value) orelse return null;
        return std.mem.span(json_string);
    }

    pub fn getNumber(self: *const JsonValue) f64 {
        const json_number = c.yyjson_mut_get_num(self.value);
        return json_number;
    }

    pub fn getArrayLength(self: *const JsonValue) usize {
        const array_length = c.yyjson_mut_arr_size(self.value);
        return array_length;
    }

    pub fn getArrayValueAt(self: *const JsonValue, idx: usize) ?JsonValue {
        const json_value = c.yyjson_mut_arr_get(self.value, idx) orelse return null;
        return JsonValue{ .value = json_value };
    }

    pub fn getArrayItems(self: *const JsonValue, allocator: std.mem.Allocator) ![]JsonValue {
        const count = self.getArrayLength();
        const values = try allocator.alloc(JsonValue, count);
        for (0..count) |i| {
            const val = c.yyjson_mut_arr_get(self.value, i) orelse return error.ReadFailed;
            values[i] = JsonValue{ .value = val };
        }
        return values;
    }

    pub fn getBool(self: *const JsonValue) bool {
        const json_bool = c.yyjson_mut_get_bool(self.value);
        return json_bool;
    }

    pub fn getObject(self: *const JsonValue, key: [:0]const u8) ?JsonValue {
        const json_value = c.yyjson_mut_obj_get(self.value, key) orelse return null;
        return JsonValue{ .value = json_value };
    }

    pub fn getObjectFromPath(self: *const JsonValue, keys: []const [:0]const u8) ?JsonValue {
        if (keys.len == 0) return null;
        var current = self.getObject(keys[0]);
        for (1..keys.len) |i| {
            current = current.?.getObject(keys[i]) orelse return null;
        }
        return current;
    }

    pub fn setNull(self: *const JsonValue) !void {
        const ret = c.yyjson_mut_set_null(self.value);
        if (!ret) {
            return JsonError.SetValueFailed;
        }
    }

    pub fn setRawString(self: *const JsonValue, raw_str: []u8) !void {
        const ret = c.yyjson_mut_set_raw(self.value, raw_str, raw_str.len);
        if (!ret) {
            return JsonError.SetValueFailed;
        }
    }

    pub fn setString(self: *const JsonValue, raw_str: [:0]u8) !void {
        const ret = c.yyjson_mut_set_str(self.value, raw_str);
        if (!ret) {
            return JsonError.SetValueFailed;
        }
    }

    pub fn setNumber(self: *const JsonValue, number: f64) !void {
        const ret = c.yyjson_mut_set_double(self.value, number);
        if (!ret) {
            return JsonError.SetValueFailed;
        }
    }

    pub fn setBool(self: *const JsonValue, flag: bool) !void {
        const ret = c.yyjson_mut_set_bool(self.value, flag);
        if (!ret) {
            return JsonError.SetValueFailed;
        }
    }

    fn setArrayItemAt_(self: *const JsonValue, idx: usize, val: *c.yyjson_mut_val) JsonError!void {
        if (idx >= self.getArrayLength()) {
            if (!c.yyjson_mut_arr_append(self.value, val)) return JsonError.ArrayValueAddFailed;
        } else {
            if (c.yyjson_mut_arr_replace(self.value, idx, val) == null) return JsonError.ArrayValueSetFailed;
        }
    }

    pub fn setArrayItemAt(self: *const JsonValue, doc: *const JsonDoc, idx: usize, item: anytype) !void {
        const type_of = @TypeOf(item);
        if (type_of == f64) {
            try self.setArrayItemAt_(idx, c.yyjson_mut_double(doc.doc, item));
        } else if (type_of == bool) {
            try self.setArrayItemAt_(idx, c.yyjson_mut_bool(doc.doc, item));
        } else if (type_of == @TypeOf(null)) {
            try self.setArrayItemAt_(idx, c.yyjson_mut_null(doc.doc));
        } else if (@TypeOf("", item) == [:0]const u8) {
            try self.setArrayItemAt_(idx, c.yyjson_mut_str(doc.doc, item));
        } else {
            return JsonError.TypeError;
        }
    }

    pub fn setArray(self: *const JsonValue, doc: *const JsonDoc, items: anytype) !void {
        switch (@TypeOf(items)) {
            *const [items.len]f64 => { // Number array
                for (0..items.len) |i| {
                    try self.setArrayItemAt(doc, i, items[i]);
                }
            },
            *const [items.len]bool => { // Boolean array
                for (0..items.len) |i| {
                    try self.setArrayItemAt(doc, i, items[i]);
                }
            },
            *const [items.len][:0]const u8 => { // String array
                for (0..items.len) |i| {
                    try self.setArrayItemAt(doc, i, items[i]);
                }
            },
            else => {
                return JsonError.TypeError;
            },
        }
    }

    fn setObject_(self: *const JsonValue, key: *c.yyjson_mut_val, val: *c.yyjson_mut_val) !void {
        if (!c.yyjson_mut_obj_put(self.value, key, val)) {
            return JsonError.ObjectInsertFailed;
        }
    }

    pub fn setObject(self: *const JsonValue, doc: *const JsonDoc, key: [:0]const u8, item: anytype) !void {
        const type_of = @TypeOf(item);
        if (type_of == f64) {
            try self.setObject_(
                c.yyjson_mut_str(doc.doc, key),
                c.yyjson_mut_double(doc.doc, item),
            );
        } else if (type_of == bool) {
            try self.setObject_(
                c.yyjson_mut_str(doc.doc, key),
                c.yyjson_mut_bool(doc.doc, item),
            );
        } else if (type_of == @TypeOf(null)) {
            try self.setObject_(
                c.yyjson_mut_str(doc.doc, key),
                c.yyjson_mut_null(doc.doc),
            );
        } else if (@TypeOf("", item) == [:0]const u8) {
            try self.setObject_(
                c.yyjson_mut_str(doc.doc, key),
                c.yyjson_mut_str(doc.doc, item),
            );
        } else {
            return JsonError.TypeError;
        }
    }
};

pub const JsonError = error{ ReadFailed, WriteFailed, MutableConversionFailed, SetValueFailed, TypeError, ArrayValueAddFailed, ArrayValueSetFailed, ObjectInsertFailed };

pub fn parseFile(filename: [:0]const u8) !JsonDoc {
    var err: c.yyjson_read_err = c.yyjson_read_err{
        .code = undefined,
        .msg = undefined,
        .pos = undefined,
    };
    const doc = c.yyjson_read_file(filename, c.YYJSON_READ_INSITU, null, &err) orelse return JsonError.ReadFailed;
    const mut_doc = c.yyjson_doc_mut_copy(doc, null) orelse return JsonError.MutableConversionFailed;
    c.yyjson_doc_free(doc);
    return JsonDoc{ .doc = mut_doc };
}

pub fn writeFile(filename: [:0]const u8, doc: *const JsonDoc) !void {
    var err: c.yyjson_write_err = c.yyjson_write_err{
        .code = undefined,
        .msg = undefined,
    };
    if (!c.yyjson_mut_write_file(filename, doc.doc, c.YYJSON_WRITE_PRETTY, null, &err)) {
        return JsonError.WriteFailed;
    }
}
