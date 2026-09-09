const std = @import("std");

const Example = struct {
    name: []const u8,
    file: []const u8,
};

const examples = [_]Example{
    .{
        .name = "connect",
        .file = "connect.zig",
    },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const x11 = b.addModule("x11", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_module = x11,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);

    const examples_step = b.step("examples", "Build examples");

    for (examples) |example| {
        const executable = addExample(b, x11, target, optimize, example);

        examples_step.dependOn(&executable.step);
    }
}

fn addExample(
    b: *std.Build,
    x11: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    example: Example,
) *std.Build.Step.Compile {
    const executable = b.addExecutable(.{
        .name = example.name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(
                b.fmt("examples/{s}", .{example.file}),
            ),
            .target = target,
            .optimize = optimize,
        }),
    });

    executable.root_module.addImport("x11", x11);

    const run = b.addRunArtifact(executable);

    const run_step = b.step(
        b.fmt("run-{s}", .{example.name}),
        b.fmt("Run the {s} example", .{example.name}),
    );

    run_step.dependOn(&run.step);

    return executable;
}
