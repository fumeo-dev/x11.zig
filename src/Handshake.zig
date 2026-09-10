const Handshake = @This();

const std = @import("std");
const Connection = @import("Connection.zig");

const Allocator = std.mem.Allocator;
const Endian = std.builtin.Endian;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

pub const Request = struct {
    byte_order: Endian = .native,
    protocol_major: u16 = 11,
    protocol_minor: u16 = 0,
    authorization_protocol_name: []const u8 = "",
    authorization_protocol_data: []const u8 = "",
};

pub const Response = struct {
    allocator: Allocator,
    status: Status,

    protocol_major: ?u16 = null,
    protocol_minor: ?u16 = null,

    reason: ?[]u8 = null,

    release_number: ?u32 = null,
    resource_id_base: ?u32 = null,
    resource_id_mask: ?u32 = null,
    motion_buffer_size: ?u32 = null,
    maximum_request_length: ?u16 = null,

    image_byte_order: ?Endian = null,
    bitmap_bit_order: ?Endian = null,
    bitmap_scanline_unit: ?u8 = null,
    bitmap_scanline_pad: ?u8 = null,

    min_keycode: ?u8 = null,
    max_keycode: ?u8 = null,

    vendor: ?[]u8 = null,
    pixmap_formats: ?[]Format = null,
    roots: ?[]Screen = null,

    pub const Status = enum(u8) {
        failed = 0,
        success = 1,
        authenticate = 2,
    };

    pub const Format = struct {
        depth: u8,
        bits_per_pixel: u8,
        scanline_pad: u8,
    };

    pub const Screen = struct {
        root: u32,
        width_in_pixels: u16,
        height_in_pixels: u16,
        width_in_millimeters: u16,
        height_in_millimeters: u16,
        root_depth: u8,
        root_visual: u32,
        default_colormap: u32,
        white_pixel: u32,
        black_pixel: u32,
        min_installed_maps: u16,
        max_installed_maps: u16,
        backing_stores: BackingStores,
        save_unders: bool,
        current_input_masks: u32,
        allowed_depths: []Depth,
    };

    pub const Depth = struct {
        depth: u8,
        visuals: []VisualType,
    };

    pub const VisualType = struct {
        visual_id: u32,
        class: VisualClass,
        bits_per_rgb_value: u8,
        colormap_entries: u16,
        red_mask: u32,
        green_mask: u32,
        blue_mask: u32,
    };

    pub const BackingStores = enum(u8) {
        never = 0,
        when_mapped = 1,
        always = 2,
    };

    pub const VisualClass = enum(u8) {
        static_gray = 0,
        gray_scale = 1,
        static_color = 2,
        pseudo_color = 3,
        true_color = 4,
        direct_color = 5,
    };

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
