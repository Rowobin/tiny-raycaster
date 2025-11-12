const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const bmp_mod = b.addModule("bmp", .{
        .root_source_file = b.path("src/bmp.zig"),
        .target = target,
    });

    const dep_sokol = b.dependency("sokol", .{
       .target = target,
       .optimize = optimize
    });

    const exe = b.addExecutable(.{
        .name = "foo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "bmp", .module = bmp_mod},
                .{ .name = "sokol", .module = dep_sokol.module("sokol")}
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
