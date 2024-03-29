const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_options = b.addOptions();

    const vk_registry = b.option([]const u8, "vk_registry", "Path to the Vulkan registry") orelse b.pathFromRoot("vk.xml");
    const vk_enable_validation = b.option(bool, "vk_enable_validation", "Enable vulkan validation layers");
    const vk_verbose = b.option(bool, "vk_verbose", "Enable debug output");

    build_options.addOption(bool, "vk_enable_validation", vk_enable_validation orelse false);
    build_options.addOption(bool, "vk_verbose", vk_verbose orelse false);

    const vkzig_dep = b.dependency("vulkan_zig", .{
        .registry = vk_registry,
    });

    const mksv = b.addModule("mksv", .{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vulkan-zig", .module = vkzig_dep.module("vulkan-zig") },
        },
    });

    const exe = b.addExecutable(.{
        .name = "tests",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("mksv", mksv);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run executable");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
