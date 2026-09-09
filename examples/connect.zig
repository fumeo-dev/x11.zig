const std = @import("std");
const x11 = @import("x11");

pub fn main(init: std.process.Init) !void {
    const tmpdir = init.environ_map.get("TMPDIR") orelse
        return error.MissingTmpDir;

    var socket_path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const socket_path = try std.fmt.bufPrint(
        &socket_path_buffer,
        "{s}/.X11-unix/X0",
        .{tmpdir},
    );

    var connection = try x11.Connection.open(
        init.gpa,
        init.io,
        .{ .unix = socket_path },
    );
    defer connection.close();

    std.debug.print("Connected to X server.\n", .{});
}
