// build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create modules
    const main_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
    });

    const ws_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/ws.zig" },
    });

    // Add test step
    const main_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "test.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.root_module.addImport("main", main_module);
    main_tests.root_module.addImport("ws", ws_module);

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // Add example executable
    const example_exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{ .cwd_relative = "example.zig" },
        .target = target,
        .optimize = optimize,
    });
    example_exe.root_module.addImport("main", main_module);
    example_exe.root_module.addImport("ws", ws_module);
    
    // Add install step for example
    b.installArtifact(example_exe);

    // Add run step for example
    const run_example_cmd = b.addRunArtifact(example_exe);
    const run_example_step = b.step("example", "Run the example");
    run_example_step.dependOn(&run_example_cmd.step);
}
