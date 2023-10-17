const std = @import("std");
const builtin = @import("builtin");

const zmath = @import("src/deps/zig-gamedev/zmath/build.zig");
const zstbi = @import("src/deps/zig-gamedev/zstbi/build.zig");
const zflecs = @import("src/deps/zig-gamedev/zflecs/build.zig");

const mach_core = @import("mach_core");
const mach_gpu_dawn = @import("mach_gpu_dawn");
const xcode_frameworks = @import("xcode_frameworks");

const content_dir = "assets/";
const src_path = "src/aftersun.zig";

const ProcessAssetsStep = @import("src/tools/process_assets.zig").ProcessAssetsStep;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    const zmath_pkg = zmath.package(b, target, optimize, .{});
    const zflecs_pkg = zflecs.package(b, target, optimize, .{});

    const mach_core_dep = b.dependency("mach_core", .{
        .target = target,
        .optimize = optimize,
    });

    const app = try mach_core.App.init(b, mach_core_dep.builder, .{
        .name = "aftersun",
        .src = src_path,
        .target = target,
        .deps = &[_]std.build.ModuleDependency{
            .{ .name = "zstbi", .module = zstbi_pkg.zstbi },
            .{ .name = "zmath", .module = zmath_pkg.zmath },
            .{ .name = "zflecs", .module = zflecs_pkg.zflecs },
        },
        .optimize = optimize,
    });

    const run_step = b.step("run", "Run aftersun");
    run_step.dependOn(&app.run.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = src_path },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addModule("zstbi", zstbi_pkg.zstbi);
    unit_tests.addModule("zmath", zmath_pkg.zmath);
    unit_tests.addModule("zflecs", zflecs_pkg.zflecs);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    app.compile.addModule("zstbi", zstbi_pkg.zstbi);
    app.compile.addModule("zmath", zmath_pkg.zmath);
    app.compile.addModule("zflecs", zflecs_pkg.zflecs);

    zstbi_pkg.link(app.compile);
    zmath_pkg.link(app.compile);
    zflecs_pkg.link(app.compile);

    const assets = ProcessAssetsStep.init(b, "assets", "src/assets.zig", "src/animations.zig");
    const process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets.step);
    app.compile.step.dependOn(&assets.step);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = .{ .path = thisDir() ++ "/" ++ content_dir },
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    app.compile.step.dependOn(&install_content_step.step);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}

comptime {
    const min_zig = std.SemanticVersion.parse("0.11.0") catch unreachable;
    if (builtin.zig_version.order(min_zig) == .lt) {
        @compileError(std.fmt.comptimePrint("Your Zig version v{} does not meet the minimum build requirement of v{}", .{ builtin.zig_version, min_zig }));
    }
}
