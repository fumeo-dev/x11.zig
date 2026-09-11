//! Represents an initialized X11 client session.

const Client = @This();

const std = @import("std");
const Connection = @import("Connection.zig");
const Display = @import("Display.zig").Display;
const Handshake = @import("Handshake.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

connection: Connection,
setup: Handshake.Response,

/// Opens and initializes an X11 client session.
pub fn open(allocator: Allocator, io: Io, display: Display) !Client {
    var connection = try Connection.open(
        allocator,
        io,
        display,
    );
    errdefer connection.close();

    const setup = try Handshake.perform(
        allocator,
        .{},
        &connection,
    );

    return .{
        .connection = connection,
        .setup = setup,
    };
}

/// Closes the client session and releases all resources owned by it.
pub fn close(self: *Client) void {
    self.setup.deinit();
    self.connection.close();
}
