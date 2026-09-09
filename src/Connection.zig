//! Represents a live connection to an X server.

const Connection = @This();

const std = @import("std");
const Display = @import("Display.zig").Display;

const Allocator = std.mem.Allocator;
const Io = std.Io;

const HostName = Io.net.HostName;
const Stream = Io.net.Stream;
const UnixAddress = Io.net.UnixAddress;

const buffer_size = 4096;

allocator: Allocator,
io: Io,

reader_buffer: []u8,
writer_buffer: []u8,

stream_reader: Stream.Reader,
stream_writer: Stream.Writer,

/// Opens a connection to an X server.
pub fn open(allocator: Allocator, io: Io, display: Display) !Connection {
    const stream = switch (display) {
        .unix => |path| try openUnix(io, path),
        .tcp => |tcp| try openTcp(io, tcp),
    };
    errdefer stream.close(io);

    const reader_buffer = try allocator.alloc(u8, buffer_size);
    errdefer allocator.free(reader_buffer);

    const writer_buffer = try allocator.alloc(u8, buffer_size);
    errdefer allocator.free(writer_buffer);

    return .{
        .allocator = allocator,
        .io = io,

        .reader_buffer = reader_buffer,
        .writer_buffer = writer_buffer,

        .stream_reader = stream.reader(io, reader_buffer),
        .stream_writer = stream.writer(io, writer_buffer),
    };
}

/// Closes the connection and releases all resources owned by it.
pub fn close(self: *Connection) void {
    self.stream_reader.stream.close(self.io);

    self.allocator.free(self.reader_buffer);
    self.allocator.free(self.writer_buffer);
}

/// Returns the reader for the connection's X11 stream.
pub fn reader(self: *Connection) *Io.Reader {
    return &self.stream_reader.interface;
}

/// Returns the writer for the connection's X11 stream.
pub fn writer(self: *Connection) *Io.Writer {
    return &self.stream_writer.interface;
}

fn openUnix(io: Io, path: []const u8) !Stream {
    const address = try UnixAddress.init(path);
    return address.connect(io);
}

fn openTcp(io: Io, display: Display.Tcp) !Stream {
    const host = try HostName.init(display.host);
    return host.connect(io, display.port, .{ .mode = .stream });
}
