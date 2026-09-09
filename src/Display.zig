const std = @import("std");

/// Describes how an X server can be reached.
pub const Display = union(enum) {
    /// A Unix-domain socket endpoint.
    unix: []const u8,

    /// A TCP endpoint.
    tcp: Tcp,

    pub const Tcp = struct {
        /// The host to connect to.
        host: []const u8,

        /// The port to connect to.
        port: u16,
    };
};
