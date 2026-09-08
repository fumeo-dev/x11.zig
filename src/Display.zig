const std = @import("std");

/// Describes how an X server can be reached.
pub const Display = union(enum) {
    /// A Unix-domain socket endpoint.
    unix: Unix,

    /// A TCP endpoint.
    tcp: Tcp,

    pub const Unix = union(enum) {
        /// An X display number.
        number: u16,

        /// An explicit Unix socket path.
        path: []const u8,
    };

    pub const Tcp = struct {
        /// The host to connect to.
        host: []const u8,

        /// An X display number.
        number: u16,
    };
};

test "unix display number" {
    const display: Display = .{
        .unix = .{ .number = 0 },
    };

    try std.testing.expectEqual(
        @as(u16, 0),
        display.unix.number,
    );
}

test "unix display path" {
    const display: Display = .{
        .unix = .{ .path = "/tmp/.X11-unix/X0" },
    };

    try std.testing.expectEqualStrings(
        "/tmp/.X11-unix/X0",
        display.unix.path,
    );
}

test "tcp display" {
    const display: Display = .{
        .tcp = .{
            .host = "localhost",
            .number = 0,
        },
    };

    try std.testing.expectEqualStrings(
        "localhost",
        display.tcp.host,
    );
    try std.testing.expectEqual(
        @as(u16, 0),
        display.tcp.number,
    );
}
