//! Performs the X11 connection setup handshake.

const Handshake = @This();

const std = @import("std");
const Connection = @import("Connection.zig");

const Allocator = std.mem.Allocator;
const Endian = std.builtin.Endian;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

/// Describes an X11 connection setup request.
pub const Request = struct {
    /// Byte order used by the client.
    byte_order: Endian = .native,

    /// X11 protocol major version.
    protocol_major: u16 = 11,

    /// X11 protocol minor version.
    protocol_minor: u16 = 0,

    /// Authorization protocol name.
    authorization_protocol_name: []const u8 = "",

    /// Authorization protocol data.
    authorization_protocol_data: []const u8 = "",
};

/// Contains the X11 server's connection setup response.
pub const Response = struct {
    allocator: Allocator,

    /// Result of the connection setup.
    status: Status,

    /// X11 protocol major version.
    protocol_major: ?u16 = null,

    /// X11 protocol minor version.
    protocol_minor: ?u16 = null,

    /// Failure or authentication reason.
    reason: ?[]u8 = null,

    /// X server release number.
    release_number: ?u32 = null,

    /// Base resource identifier allocated to the client.
    resource_id_base: ?u32 = null,

    /// Resource identifier mask allocated to the client.
    resource_id_mask: ?u32 = null,

    /// Size of the server's motion history buffer.
    motion_buffer_size: ?u32 = null,

    /// Maximum request length supported by the server.
    maximum_request_length: ?u16 = null,

    /// Byte order used for images.
    image_byte_order: ?Endian = null,

    /// Bit order used for bitmaps.
    bitmap_bit_order: ?Endian = null,

    /// Bitmap scanline unit size.
    bitmap_scanline_unit: ?u8 = null,

    /// Bitmap scanline padding.
    bitmap_scanline_pad: ?u8 = null,

    /// Minimum valid keycode.
    min_keycode: ?u8 = null,

    /// Maximum valid keycode.
    max_keycode: ?u8 = null,

    /// Name of the X server vendor.
    vendor: ?[]u8 = null,

    /// Pixmap formats supported by the X server.
    pixmap_formats: ?[]Format = null,

    /// Screens provided by the X server.
    roots: ?[]Screen = null,

    /// Describes the result of the connection setup.
    pub const Status = enum(u8) {
        failed = 0,
        success = 1,
        authenticate = 2,
    };

    /// Describes a pixmap format supported by the X server.
    pub const Format = struct {
        /// Drawable depth of the format.
        depth: u8,

        /// Number of bits used to represent each pixel.
        bits_per_pixel: u8,

        /// Scanline padding in bits.
        scanline_pad: u8,
    };

    /// Describes a screen provided by the X server.
    pub const Screen = struct {
        /// Root window identifier.
        root: u32,

        /// Width of the screen in pixels.
        width_in_pixels: u16,

        /// Height of the screen in pixels.
        height_in_pixels: u16,

        /// Width of the screen in millimeters.
        width_in_millimeters: u16,

        /// Height of the screen in millimeters.
        height_in_millimeters: u16,

        /// Depth of the root window.
        root_depth: u8,

        /// Root visual identifier.
        root_visual: u32,

        /// Default colormap identifier.
        default_colormap: u32,

        /// White pixel value.
        white_pixel: u32,

        /// Black pixel value.
        black_pixel: u32,

        /// Minimum number of installed colormaps.
        min_installed_maps: u16,

        /// Maximum number of installed colormaps.
        max_installed_maps: u16,

        /// Backing store behavior supported by the screen.
        backing_stores: BackingStores,

        /// Whether the screen supports save-under.
        save_unders: bool,

        /// Currently enabled input event masks.
        current_input_masks: u32,

        /// Depths and visuals supported by the screen.
        allowed_depths: []Depth,
    };

    /// Describes a depth supported by a screen.
    pub const Depth = struct {
        /// Depth value.
        depth: u8,

        /// Visual types available at this depth.
        visuals: []VisualType,
    };

    /// Describes a visual type supported by a screen.
    pub const VisualType = struct {
        /// Visual identifier.
        visual_id: u32,

        /// Visual class.
        class: VisualClass,

        /// Number of bits used for each RGB component.
        bits_per_rgb_value: u8,

        /// Number of colormap entries.
        colormap_entries: u16,

        /// Red component mask.
        red_mask: u32,

        /// Green component mask.
        green_mask: u32,

        /// Blue component mask.
        blue_mask: u32,
    };

    /// Describes when the screen supports backing stores.
    pub const BackingStores = enum(u8) {
        never = 0,
        when_mapped = 1,
        always = 2,
    };

    /// Describes the class of a visual.
    pub const VisualClass = enum(u8) {
        static_gray = 0,
        gray_scale = 1,
        static_color = 2,
        pseudo_color = 3,
        true_color = 4,
        direct_color = 5,
    };

    /// Releases memory owned by the response.
    pub fn deinit(self: *Response) void {
        if (self.reason) |reason| {
            self.allocator.free(reason);
        }

        if (self.vendor) |vendor| {
            self.allocator.free(vendor);
        }

        if (self.pixmap_formats) |formats| {
            self.allocator.free(formats);
        }

        if (self.roots) |roots| {
            freeScreens(self.allocator, roots);
            self.allocator.free(roots);
        }
    }
};

/// Performs the X11 connection setup handshake.
pub fn perform(
    allocator: Allocator,
    request: Request,
    connection: *Connection,
) !Response {
    const reader = connection.reader();
    const writer = connection.writer();

    try writeRequest(writer, request);
    try writer.flush();

    const status = try readStatus(reader);

    return switch (status) {
        .failed => readFailed(allocator, reader, request.byte_order),
        .authenticate => readAuthenticate(allocator, reader),
        .success => readSuccess(allocator, reader, request.byte_order),
    };
}

fn writeRequest(writer: *Writer, request: Request) !void {
    const endian = request.byte_order;

    const name = request.authorization_protocol_name;
    const data = request.authorization_protocol_data;

    const name_len = try castLength(name.len, error.AuthNameTooLong);
    const data_len = try castLength(data.len, error.AuthDataTooLong);

    try writer.writeByte(switch (endian) {
        .big => 'B',
        .little => 'l',
    });
    try writer.writeByte(0);

    try writer.writeInt(u16, request.protocol_major, endian);
    try writer.writeInt(u16, request.protocol_minor, endian);
    try writer.writeInt(u16, name_len, endian);
    try writer.writeInt(u16, data_len, endian);
    try writer.writeInt(u16, 0, endian);

    try writePadded(writer, name);
    try writePadded(writer, data);
}

fn castLength(length: usize, comptime err: anytype) !u16 {
    return std.math.cast(u16, length) orelse return err;
}

fn writePadded(writer: *Writer, bytes: []const u8) !void {
    try writer.writeAll(bytes);
    try writer.splatByteAll(0, padding(bytes.len));
}

fn padding(length: usize) usize {
    return (4 - (length & 3)) & 3;
}

fn skipPadding(reader: *Reader, length: usize) !void {
    try reader.discardAll(padding(length));
}

fn readStatus(reader: *Reader) !Response.Status {
    return switch (try reader.takeByte()) {
        0 => .failed,
        1 => .success,
        2 => .authenticate,
        else => error.InvalidResponse,
    };
}

fn readFailed(
    allocator: Allocator,
    reader: *Reader,
    endian: Endian,
) !Response {
    const reason_len = try reader.takeByte();
    const protocol_major = try reader.takeInt(u16, endian);
    const protocol_minor = try reader.takeInt(u16, endian);

    try reader.discardAll(2);

    const reason = try allocator.alloc(u8, reason_len);
    errdefer allocator.free(reason);

    try reader.readSliceAll(reason);
    try skipPadding(reader, reason.len);

    return .{
        .allocator = allocator,
        .status = .failed,
        .protocol_major = protocol_major,
        .protocol_minor = protocol_minor,
        .reason = reason,
    };
}

fn readAuthenticate(
    allocator: Allocator,
    reader: *Reader,
) !Response {
    const reason_len = try reader.takeByte();

    try reader.discardAll(7);

    const reason = try allocator.alloc(u8, reason_len);
    errdefer allocator.free(reason);

    try reader.readSliceAll(reason);
    try skipPadding(reader, reason.len);

    return .{
        .allocator = allocator,
        .status = .authenticate,
        .reason = reason,
    };
}

fn readSuccess(
    allocator: Allocator,
    reader: *Reader,
    endian: Endian,
) !Response {
    try reader.discardAll(1);

    const protocol_major = try reader.takeInt(u16, endian);
    const protocol_minor = try reader.takeInt(u16, endian);

    try reader.discardAll(2);

    const release_number = try reader.takeInt(u32, endian);
    const resource_id_base = try reader.takeInt(u32, endian);
    const resource_id_mask = try reader.takeInt(u32, endian);
    const motion_buffer_size = try reader.takeInt(u32, endian);

    const vendor_len = try reader.takeInt(u16, endian);
    const maximum_request_length = try reader.takeInt(u16, endian);

    const root_count = try reader.takeByte();
    const format_count = try reader.takeByte();

    const image_byte_order = try readEndian(reader);
    const bitmap_bit_order = try readEndian(reader);

    const bitmap_scanline_unit = try reader.takeByte();
    const bitmap_scanline_pad = try reader.takeByte();

    const min_keycode = try reader.takeByte();
    const max_keycode = try reader.takeByte();

    try reader.discardAll(4);

    const vendor = try allocator.alloc(u8, vendor_len);
    errdefer allocator.free(vendor);

    try reader.readSliceAll(vendor);
    try skipPadding(reader, vendor.len);

    const formats = try readPixmapFormats(
        allocator,
        reader,
        format_count,
    );
    errdefer allocator.free(formats);

    const roots = try readScreens(
        allocator,
        reader,
        endian,
        root_count,
    );
    errdefer {
        freeScreens(allocator, roots);
        allocator.free(roots);
    }

    return .{
        .allocator = allocator,
        .status = .success,

        .protocol_major = protocol_major,
        .protocol_minor = protocol_minor,
        .release_number = release_number,
        .resource_id_base = resource_id_base,
        .resource_id_mask = resource_id_mask,
        .motion_buffer_size = motion_buffer_size,
        .maximum_request_length = maximum_request_length,
        .image_byte_order = image_byte_order,
        .bitmap_bit_order = bitmap_bit_order,
        .bitmap_scanline_unit = bitmap_scanline_unit,
        .bitmap_scanline_pad = bitmap_scanline_pad,
        .min_keycode = min_keycode,
        .max_keycode = max_keycode,
        .vendor = vendor,
        .pixmap_formats = formats,
        .roots = roots,
    };
}

fn readPixmapFormats(
    allocator: Allocator,
    reader: *Reader,
    count: usize,
) ![]Response.Format {
    const formats = try allocator.alloc(Response.Format, count);
    errdefer allocator.free(formats);

    for (formats) |*format| {
        format.* = .{
            .depth = try reader.takeByte(),
            .bits_per_pixel = try reader.takeByte(),
            .scanline_pad = try reader.takeByte(),
        };

        try reader.discardAll(5);
    }

    return formats;
}

fn readScreens(
    allocator: Allocator,
    reader: *Reader,
    endian: Endian,
    count: usize,
) ![]Response.Screen {
    const screens = try allocator.alloc(Response.Screen, count);
    var initialized: usize = 0;

    errdefer {
        freeScreens(allocator, screens[0..initialized]);
        allocator.free(screens);
    }

    for (screens) |*screen| {
        screen.* = try readScreen(
            allocator,
            reader,
            endian,
        );
        initialized += 1;
    }

    return screens;
}

fn readScreen(
    allocator: Allocator,
    reader: *Reader,
    endian: Endian,
) !Response.Screen {
    const root = try reader.takeInt(u32, endian);
    const default_colormap = try reader.takeInt(u32, endian);
    const white_pixel = try reader.takeInt(u32, endian);
    const black_pixel = try reader.takeInt(u32, endian);
    const current_input_masks = try reader.takeInt(u32, endian);

    const width_in_pixels = try reader.takeInt(u16, endian);
    const height_in_pixels = try reader.takeInt(u16, endian);
    const width_in_millimeters = try reader.takeInt(u16, endian);
    const height_in_millimeters = try reader.takeInt(u16, endian);

    const min_installed_maps = try reader.takeInt(u16, endian);
    const max_installed_maps = try reader.takeInt(u16, endian);

    const root_visual = try reader.takeInt(u32, endian);

    const backing_stores = try readBackingStores(reader);
    const save_unders = try reader.takeByte() != 0;
    const root_depth = try reader.takeByte();
    const depth_count = try reader.takeByte();

    const allowed_depths = try readDepths(
        allocator,
        reader,
        endian,
        depth_count,
    );

    return .{
        .root = root,
        .width_in_pixels = width_in_pixels,
        .height_in_pixels = height_in_pixels,
        .width_in_millimeters = width_in_millimeters,
        .height_in_millimeters = height_in_millimeters,
        .root_depth = root_depth,
        .root_visual = root_visual,
        .default_colormap = default_colormap,
        .white_pixel = white_pixel,
        .black_pixel = black_pixel,
        .min_installed_maps = min_installed_maps,
        .max_installed_maps = max_installed_maps,
        .backing_stores = backing_stores,
        .save_unders = save_unders,
        .current_input_masks = current_input_masks,
        .allowed_depths = allowed_depths,
    };
}

fn readDepths(
    allocator: Allocator,
    reader: *Reader,
    endian: Endian,
    count: usize,
) ![]Response.Depth {
    const depths = try allocator.alloc(Response.Depth, count);
    var initialized: usize = 0;

    errdefer {
        freeDepths(allocator, depths[0..initialized]);
        allocator.free(depths);
    }

    for (depths) |*depth| {
        depth.* = try readDepth(
            allocator,
            reader,
            endian,
        );
        initialized += 1;
    }

    return depths;
}

fn readDepth(
    allocator: Allocator,
    reader: *Reader,
    endian: Endian,
) !Response.Depth {
    const depth = try reader.takeByte();

    try reader.discardAll(1);

    const visual_count = try reader.takeInt(u16, endian);

    try reader.discardAll(4);

    const visuals = try readVisualTypes(
        allocator,
        reader,
        endian,
        visual_count,
    );

    return .{
        .depth = depth,
        .visuals = visuals,
    };
}

fn readVisualTypes(
    allocator: Allocator,
    reader: *Reader,
    endian: Endian,
    count: usize,
) ![]Response.VisualType {
    const visuals = try allocator.alloc(Response.VisualType, count);
    errdefer allocator.free(visuals);

    for (visuals) |*visual| {
        visual.* = try readVisualType(
            reader,
            endian,
        );
    }

    return visuals;
}

fn readVisualType(
    reader: *Reader,
    endian: Endian,
) !Response.VisualType {
    const visual_id = try reader.takeInt(u32, endian);

    const class = try readVisualClass(reader);

    const bits_per_rgb_value = try reader.takeByte();
    const colormap_entries = try reader.takeInt(u16, endian);

    const red_mask = try reader.takeInt(u32, endian);
    const green_mask = try reader.takeInt(u32, endian);
    const blue_mask = try reader.takeInt(u32, endian);

    try reader.discardAll(4);

    return .{
        .visual_id = visual_id,
        .class = class,
        .bits_per_rgb_value = bits_per_rgb_value,
        .colormap_entries = colormap_entries,
        .red_mask = red_mask,
        .green_mask = green_mask,
        .blue_mask = blue_mask,
    };
}

fn readBackingStores(reader: *Reader) !Response.BackingStores {
    return switch (try reader.takeByte()) {
        0 => .never,
        1 => .when_mapped,
        2 => .always,
        else => error.InvalidResponse,
    };
}

fn readVisualClass(reader: *Reader) !Response.VisualClass {
    return switch (try reader.takeByte()) {
        0 => .static_gray,
        1 => .gray_scale,
        2 => .static_color,
        3 => .pseudo_color,
        4 => .true_color,
        5 => .direct_color,
        else => error.InvalidResponse,
    };
}

fn readEndian(reader: *Reader) !Endian {
    return switch (try reader.takeByte()) {
        0 => .little,
        1 => .big,
        else => error.InvalidResponse,
    };
}

fn freeScreens(allocator: Allocator, screens: []Response.Screen) void {
    for (screens) |screen| {
        freeDepths(allocator, screen.allowed_depths);
        allocator.free(screen.allowed_depths);
    }
}

fn freeDepths(allocator: Allocator, depths: []Response.Depth) void {
    for (depths) |depth| {
        allocator.free(depth.visuals);
    }
}

test "encodes the setup request" {
    var buffer: [12]u8 = undefined;
    var writer = Writer.fixed(&buffer);

    try writeRequest(&writer, .{
        .byte_order = .little,
    });

    try std.testing.expectEqualSlices(u8, &[_]u8{
        'l', 0,
        11,  0,
        0,   0,
        0,   0,
        0,   0,
        0,   0,
    }, writer.buffered());
}

test "encodes the setup request with authorization" {
    const name = "MIT-MAGIC-COOKIE-1";
    const data = "abcd";

    var buffer: [36]u8 = undefined;
    var writer = Writer.fixed(&buffer);

    try writeRequest(&writer, .{
        .byte_order = .little,
        .authorization_protocol_name = name,
        .authorization_protocol_data = data,
    });

    // zig fmt: off
    try std.testing.expectEqualSlices(u8, &[_]u8{
        'l', 0,
        11,  0,
        0,   0,
        18,  0,
        4,   0,
        0,   0,

        'M', 'I', 'T', '-',
        'M', 'A', 'G', 'I',
        'C', '-', 'C', 'O',
        'O', 'K', 'I', 'E',
        '-',
        '1',
        0,

        'a', 'b', 'c', 'd',
    }, writer.buffered());
    // zig fmt: on
}

test "rejects an authorization protocol name that is too long" {
    const name = [_]u8{0} ** 65536;

    var buffer: [12]u8 = undefined;
    var writer = Writer.fixed(&buffer);

    try std.testing.expectError(
        error.AuthNameTooLong,
        writeRequest(&writer, .{
            .byte_order = .little,
            .authorization_protocol_name = &name,
        }),
    );
}

test "rejects authorization data that is too long" {
    const data = [_]u8{0} ** 65536;

    var buffer: [12]u8 = undefined;
    var writer = Writer.fixed(&buffer);

    try std.testing.expectError(
        error.AuthDataTooLong,
        writeRequest(&writer, .{
            .byte_order = .little,
            .authorization_protocol_data = &data,
        }),
    );
}

test "reads a failed setup response" {
    // zig fmt: off
    const bytes = [_]u8{
        6,
        11, 0,
        0, 0,
        0, 0,
        'd', 'e', 'n', 'i', 'e', 'd',
        0, 0,
    };
    // zig fmt: on

    var reader = Reader.fixed(&bytes);

    var response = try readFailed(
        std.testing.allocator,
        &reader,
        .little,
    );
    defer response.deinit();

    try std.testing.expectEqual(
        Response.Status.failed,
        response.status,
    );
    try std.testing.expectEqual(
        @as(?u16, 11),
        response.protocol_major,
    );
    try std.testing.expectEqual(
        @as(?u16, 0),
        response.protocol_minor,
    );
    try std.testing.expectEqualSlices(
        u8,
        "denied",
        response.reason.?,
    );
}

test "reads an authenticate setup response" {
    // zig fmt: off
    const bytes = [_]u8{
        10,
        0, 0, 0, 0, 0, 0, 0,
        'n', 'e', 'e', 'd', ' ', 'a', 'u', 't', 'h', '!',
        0, 0,
    };
    // zig fmt: on

    var reader = Reader.fixed(&bytes);

    var response = try readAuthenticate(
        std.testing.allocator,
        &reader,
    );
    defer response.deinit();

    try std.testing.expectEqual(
        Response.Status.authenticate,
        response.status,
    );
    try std.testing.expectEqualSlices(
        u8,
        "need auth!",
        response.reason.?,
    );
}

test "reads a successful setup response" {
    // zig fmt: off
    const bytes = [_]u8{
        0,
        11, 0,
        0, 0,
        0, 0,

        1, 0, 0, 0,
        0, 0, 0, 0,
        0xff, 0xff, 0xff, 0xff,
        0, 0, 0, 0,

        4, 0,
        8, 0,
        1,
        1,
        0,
        1,
        32,
        32,
        8,
        8,
        8,
        255,
        0, 0, 0, 0,

        'T', 'E', 'S', 'T',
        0, 0, 0, 0,

        24,
        32,
        32,
        0, 0, 0, 0, 0,

        24,
        0,
        1, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,

        0x10, 0x00, 0x00, 0x00,
        0x08, 0x00,
        0x10, 0x00,

        0,
        1,
        24,

        0x33, 0x22, 0x11, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0xff, 0xff, 0xff, 0xff,
        0x00, 0x00, 0x00, 0x00,

        8,
        0,
        1, 0,
        0, 0, 0, 0,

        0x20, 0x00, 0x00, 0x00,
        4,
        8,
        0x00, 0x00,
        0x00, 0x00,

        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,

        0, 0, 0, 0,
    };
    // zig fmt: on

    var reader = Reader.fixed(&bytes);

    var response = try readSuccess(
        std.testing.allocator,
        &reader,
        .little,
    );
    defer response.deinit();

    try std.testing.expectEqual(
        Response.Status.success,
        response.status,
    );
    try std.testing.expectEqual(
        @as(?u16, 11),
        response.protocol_major,
    );
    try std.testing.expectEqual(
        @as(?u16, 0),
        response.protocol_minor,
    );
    try std.testing.expectEqual(
        @as(?u32, 1),
        response.release_number,
    );
    try std.testing.expectEqual(
        @as(?u32, 0),
        response.resource_id_base,
    );
    try std.testing.expectEqual(
        @as(?u32, 0xffffffff),
        response.resource_id_mask,
    );
    try std.testing.expectEqual(
        @as(?u32, 0),
        response.motion_buffer_size,
    );
    try std.testing.expectEqual(
        @as(?u16, 8),
        response.maximum_request_length,
    );
    try std.testing.expectEqual(
        .little,
        response.image_byte_order.?,
    );
    try std.testing.expectEqual(
        .big,
        response.bitmap_bit_order.?,
    );
    try std.testing.expectEqual(
        @as(?u8, 32),
        response.bitmap_scanline_unit,
    );
    try std.testing.expectEqual(
        @as(?u8, 32),
        response.bitmap_scanline_pad,
    );
    try std.testing.expectEqual(
        @as(?u8, 8),
        response.min_keycode,
    );
    try std.testing.expectEqual(
        @as(?u8, 8),
        response.max_keycode,
    );

    try std.testing.expectEqualSlices(
        u8,
        "TEST",
        response.vendor.?,
    );

    const formats = response.pixmap_formats.?;
    try std.testing.expectEqual(
        @as(usize, 1),
        formats.len,
    );
    try std.testing.expectEqual(
        @as(u8, 24),
        formats[0].depth,
    );
    try std.testing.expectEqual(
        @as(u8, 32),
        formats[0].bits_per_pixel,
    );
    try std.testing.expectEqual(
        @as(u8, 32),
        formats[0].scanline_pad,
    );

    const roots = response.roots.?;
    try std.testing.expectEqual(
        @as(usize, 1),
        roots.len,
    );

    const screen = roots[0];

    try std.testing.expectEqual(
        @as(u32, 0x00000001),
        screen.root,
    );
    try std.testing.expectEqual(
        @as(u16, 16),
        screen.width_in_pixels,
    );
    try std.testing.expectEqual(
        @as(u16, 8),
        screen.height_in_pixels,
    );
    try std.testing.expectEqual(
        @as(u16, 16),
        screen.width_in_millimeters,
    );
    try std.testing.expectEqual(
        @as(u16, 8),
        screen.height_in_millimeters,
    );
    try std.testing.expectEqual(
        @as(u8, 24),
        screen.root_depth,
    );
    try std.testing.expectEqual(
        @as(u32, 0x00112233),
        screen.root_visual,
    );
    try std.testing.expectEqual(
        @as(u32, 0),
        screen.default_colormap,
    );
    try std.testing.expectEqual(
        @as(u32, 0xffffffff),
        screen.white_pixel,
    );
    try std.testing.expectEqual(
        @as(u32, 0),
        screen.black_pixel,
    );
    try std.testing.expectEqual(
        @as(u16, 8),
        screen.min_installed_maps,
    );
    try std.testing.expectEqual(
        @as(u16, 16),
        screen.max_installed_maps,
    );
    try std.testing.expectEqual(
        Response.BackingStores.never,
        screen.backing_stores,
    );
    try std.testing.expect(screen.save_unders);

    try std.testing.expectEqual(
        @as(u32, 0),
        screen.current_input_masks,
    );

    try std.testing.expectEqual(
        @as(usize, 1),
        screen.allowed_depths.len,
    );

    const depth = screen.allowed_depths[0];

    try std.testing.expectEqual(
        @as(u8, 8),
        depth.depth,
    );
    try std.testing.expectEqual(
        @as(usize, 1),
        depth.visuals.len,
    );

    const visual = depth.visuals[0];

    try std.testing.expectEqual(
        @as(u32, 0x00000020),
        visual.visual_id,
    );
    try std.testing.expectEqual(
        Response.VisualClass.static_gray,
        visual.class,
    );
    try std.testing.expectEqual(
        @as(u8, 4),
        visual.bits_per_rgb_value,
    );
    try std.testing.expectEqual(
        @as(u16, 8),
        visual.colormap_entries,
    );
    try std.testing.expectEqual(
        @as(u32, 0),
        visual.red_mask,
    );
    try std.testing.expectEqual(
        @as(u32, 0),
        visual.green_mask,
    );
    try std.testing.expectEqual(
        @as(u32, 0),
        visual.blue_mask,
    );
}

test "rejects an invalid setup response status" {
    const bytes = [_]u8{3};
    var reader = Reader.fixed(&bytes);

    try std.testing.expectError(
        error.InvalidResponse,
        readStatus(&reader),
    );
}

test "rejects an invalid backing stores value" {
    const bytes = [_]u8{3};
    var reader = Reader.fixed(&bytes);

    try std.testing.expectError(
        error.InvalidResponse,
        readBackingStores(&reader),
    );
}

test "rejects an invalid visual class value" {
    const bytes = [_]u8{6};
    var reader = Reader.fixed(&bytes);

    try std.testing.expectError(
        error.InvalidResponse,
        readVisualClass(&reader),
    );
}

test "rejects an invalid byte order value" {
    const bytes = [_]u8{2};
    var reader = Reader.fixed(&bytes);

    try std.testing.expectError(
        error.InvalidResponse,
        readEndian(&reader),
    );
}
