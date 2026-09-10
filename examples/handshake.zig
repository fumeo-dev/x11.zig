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

    var response = try x11.Handshake.perform(
        init.gpa,
        .{},
        &connection,
    );
    defer response.deinit();

    switch (response.status) {
        .success => std.debug.print(
            "Connected to X server (protocol {}.{}).\n",
            .{
                response.protocol_major.?,
                response.protocol_minor.?,
            },
        ),
        .failed, .authenticate => std.debug.print(
            "X11 connection setup failed: {s}\n",
            .{response.reason orelse "unknown reason"},
        ),
    }
}
