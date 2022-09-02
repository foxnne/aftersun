const std = @import("std");
const builtin = @import("builtin");

const LibExeObjStep = std.build.LibExeObjStep;
const Builder = std.build.Builder;
const Target = std.build.Target;
const Pkg = std.build.Pkg;

const zgpu = @import("src/deps/zig-gamedev/zgpu/build.zig");
const zmath = @import("src/deps/zig-gamedev/zmath/build.zig");
const zpool = @import("src/deps/zig-gamedev/zpool/build.zig");
const flecs = @import("src/deps/zig-flecs/build.zig");

const content_dir = "assets/";

const ProcessAssetsStep = @import("src/tools/process_assets.zig").ProcessAssetsStep;

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});

    var exe = createExe(b, target, "run", "src/aftersun.zig");
    b.default_step.dependOn(&exe.step);

    const assets = ProcessAssetsStep.init(b, "assets", "src/assets.zig", "src/animations.zig");

    const process_assets_step = b.step("process-assets", "generates struct for all assets");
    process_assets_step.dependOn(&assets.step);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = thisDir() ++ "/" ++ content_dir,
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    exe.step.dependOn(&install_content_step.step);

    // only mac and linux get the update_flecs command
    if (!target.isWindows()) {
        const update_flecs = b.addSystemCommand(&[_][]const u8{ "zsh", ".vscode/update_flecs.sh" });
        const update_flecs_step = b.step("update-flecs", b.fmt("updates Flecs.h/c and runs translate-c", .{}));
        update_flecs_step.dependOn(&update_flecs.step);
    }
}

fn createExe(b: *Builder, target: std.zig.CrossTarget, name: []const u8, source: []const u8) *std.build.LibExeObjStep {
    var exe = b.addExecutable(name, source);
    exe.setBuildMode(b.standardReleaseOptions());

    exe.want_lto = false;
    if (b.is_release) {
        if (target.isWindows()) {
            exe.subsystem = .Windows;
        }

        if (builtin.os.tag == .macos and builtin.cpu.arch == std.Target.Cpu.Arch.aarch64) {
            exe.subsystem = .Posix;
        }
    }

    const aftersun_pkg = std.build.Pkg{
        .name = "game",
        .source = .{ .path = "src/aftersun.zig" },
    };

    const zgpu_options = zgpu.BuildOptionsStep.init(b, .{});
    const zgpu_pkg = zgpu.getPkg(&.{ zgpu_options.getPkg(), zpool.pkg });

    exe.install();

    const run_cmd = exe.run();
    const exe_step = b.step("run", b.fmt("run {s}.zig", .{name}));
    run_cmd.step.dependOn(b.getInstallStep());
    exe_step.dependOn(&run_cmd.step);
    exe.addPackage(aftersun_pkg);
    exe.addPackage(zgpu_pkg);
    exe.addPackage(zmath.pkg);
    exe.addPackage(flecs.getPkg());

    zgpu.link(exe, zgpu_options);
    flecs.link(exe, target);

    return exe;
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
