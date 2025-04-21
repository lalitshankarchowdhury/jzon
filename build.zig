const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const jzon_obj = b.addStaticLibrary(.{
        .name = "yyjson",
        .target = target,
        .optimize = optimize,
    });
    jzon_obj.addCSourceFile(.{
        .file = b.path("yyjson/src/yyjson.c"),
    });
    jzon_obj.addIncludePath(b.path("yyjson/src"));
    jzon_obj.linkLibC();
    b.installArtifact(jzon_obj);
    const jzon_module = b.addModule("jzon", .{
        .root_source_file = b.path("src/root.zig"),
    });
    jzon_module.addIncludePath(b.path("yyjson/src"));
}
