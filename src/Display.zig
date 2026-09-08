const std = @import("std");

pub const Display = union(enum) {
    unix: Unix,
    tcp: Tcp,

    pub const Unix = union(enum) {
        number: u16,
        path: []const u8,
    };

    pub const Tcp = struct {
        host: []const u8,
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
