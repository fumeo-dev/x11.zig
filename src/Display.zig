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
