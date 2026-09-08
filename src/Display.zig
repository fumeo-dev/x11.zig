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
