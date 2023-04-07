const std = @import("std");
const builtin = @import("builtin");

const LibExeObjStep = std.build.LibExeObjStep;
const Builder = std.build.Builder;
const Target = std.build.Target;
const Pkg = std.build.Pkg;

const aftersun_pkg = std.build.Pkg{
    .name = "game",
    .source = .{ .path = "src/aftersun.zig" },
};

const zgpu = @import("src/deps/zig-gamedev/zgpu/build.zig");
const zmath = @import("src/deps/zig-gamedev/zmath/build.zig");
const zpool = @import("src/deps/zig-gamedev/zpool/build.zig");
const zglfw = @import("src/deps/zig-gamedev/zglfw/build.zig");
const zstbi = @import("src/deps/zig-gamedev/zstbi/build.zig");
const zgui = @import("src/deps/zig-gamedev/zgui/build.zig");
const zflecs = @import("src/deps/zig-gamedev/zflecs/build.zig");
//const flecs = @import("src/deps/zig-flecs/build.zig");

const content_dir = "assets/";
const src_path = "src/aftersun.zig";
const name = @import("src/aftersun.zig").name;

const ProcessAssetsStep = @import("src/tools/process_assets.zig").ProcessAssetsStep;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Fetch the latest Dawn/WebGPU binaries.
    // {
    //     var child = std.ChildProcess.init(&.{ "git", "submodule", "update", "--init", "--remote" }, b.allocator);
    //     child.cwd = thisDir();
    //     child.stderr = std.io.getStdErr();
    //     child.stdout = std.io.getStdOut();
    //     _ = child.spawnAndWait() catch {
    //         std.log.err("Failed to fetch git submodule. Please try to re-clone.", .{});
    //         return;
    //     };
    // }

    var exe = b.addExecutable(.{
        .name = name,
        .root_source_file = .{ .path = src_path },
        .optimize = optimize,
        .target = target,
    });

    exe.want_lto = false;
    if (exe.optimize == .ReleaseFast) {
        exe.strip = true;
        if (target.isWindows()) {
            exe.subsystem = .Windows;
        } else {
            exe.subsystem = .Posix;
        }
    }
    b.default_step.dependOn(&exe.step);

    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    const zmath_pkg = zmath.package(b, target, optimize, .{});
    const zglfw_pkg = zglfw.package(b, target, optimize, .{});
    const zpool_pkg = zpool.package(b, target, optimize, .{});
    const zgpu_pkg = zgpu.package(b, target, optimize, .{
        .options = .{ .uniforms_buffer_size = 4 * 1024 * 1024 },
        .deps = .{ .zpool = zpool_pkg.zpool, .zglfw = zglfw_pkg.zglfw },
    });
    const zgui_pkg = zgui.package(b, target, optimize, .{
        .options = .{
            .backend = .glfw_wgpu,
        },
    });
    const zflecs_pkg = zflecs.package(b, target, optimize, .{});

    const run_cmd = exe.run();
    const run_step = b.step("run", b.fmt("run {s}", .{name}));
    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);
    exe.addModule("zstbi", zstbi_pkg.zstbi);
    exe.addModule("zmath", zmath_pkg.zmath);
    exe.addModule("zpool", zpool_pkg.zpool);
    exe.addModule("zglfw", zglfw_pkg.zglfw);
    exe.addModule("zgpu", zgpu_pkg.zgpu);
    exe.addModule("zgui", zgui_pkg.zgui);
    //exe.addModule("flecs", flecs.module(b));
    exe.addModule("zflecs", zflecs_pkg.zflecs);

    zgpu_pkg.link(exe);
    zglfw_pkg.link(exe);
    zstbi_pkg.link(exe);
    zgui_pkg.link(exe);
    zflecs_pkg.link(exe);
    //flecs.link(exe, target);

    const assets = ProcessAssetsStep.init(b, "assets", "src/assets.zig", "src/animations.zig");
    const process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets.step);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = thisDir() ++ "/" ++ content_dir,
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    exe.step.dependOn(&install_content_step.step);
    exe.install();
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
