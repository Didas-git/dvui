const std = @import("std");

const Color = @This();

r: u16 = 0,
g: u16 = 0,
b: u16 = 0,
a: u16 = 0xFFFF,

const u16_max = std.math.maxInt(u16);
const u8_max = std.math.maxInt(u8);

pub fn to8Bit(self: Color) struct { r: u8, g: u8, b: u8, a: u8 } {
    return .{
        .r = @intCast(self.r / u16_max * u8_max),
        .g = @intCast(self.g / u16_max * u8_max),
        .b = @intCast(self.b / u16_max * u8_max),
        .a = @intCast(self.a / u16_max * u8_max),
    };
}

// TODO: Support more bit depths ( 16bit, 18bit, and other extensions)
fn fromNumberGeneric(comptime T: type, value: T, has_alpha: bool) Color {
    const type_info = @typeInfo(T);
    if (type_info != .int) @compileError("Invalid type");
    if (type_info.int.signedness != .unsigned) @compileError("Only unsigned integers can be converted into a color");

    const u12_max = std.math.maxInt(u12);

    switch (type_info.int.bits) {
        8 => {
            const u3_max = std.math.maxInt(u3);
            const u2_max = std.math.maxInt(u2);

            const color: packed struct(u8) { r: u3, g: u3, b: u2 } = @bitCast(value);
            return .{
                .r = (color.r * u8_max / u3_max) << 8,
                .g = (color.g * u8_max / u3_max) << 8,
                .b = (color.b * u8_max / u2_max) << 8,
            };
        },
        // Nimble RGB
        12 => {
            const u4_max = std.math.maxInt(u4);
            const color: packed struct(u12) { r: u4, g: u4, b: u4 } = @bitCast(value);
            return .{
                .r = (color.r * u8_max / u4_max) << 8,
                .g = (color.g * u8_max / u4_max) << 8,
                .b = (color.b * u8_max / u4_max) << 8,
            };
        },
        // Nimble RGB with alpha
        16 => {
            const u4_max = std.math.maxInt(u4);
            const color: packed struct(u16) { r: u4, g: u4, b: u4, a: u4 } = @bitCast(value);
            return .{
                .r = (color.r * u8_max / u4_max) << 8,
                .g = (color.g * u8_max / u4_max) << 8,
                .b = (color.b * u8_max / u4_max) << 8,
                .a = (color.a * u8_max / u4_max) << 8,
            };
        },
        // True color (RGB)
        24 => {
            const color: packed struct(u24) { r: u8, g: u8, b: u8 } = @bitCast(value);
            return .{
                .r = color.r << 8,
                .g = color.g << 8,
                .b = color.b << 8,
            };
        },
        // True color with alpha (RGBA)
        32 => {
            const color: packed struct(u32) { r: u8, g: u8, b: u8, a: u8 } = @bitCast(value);
            return .{
                .r = color.r << 8,
                .g = color.g << 8,
                .b = color.b << 8,
                .a = color.a << 8,
            };
        },
        36 => {
            const color: packed struct(u36) { r: u12, g: u12, b: u12 } = @bitCast(value);
            return .{
                .r = color.r * u16_max / u12_max,
                .g = color.g * u16_max / u12_max,
                .b = color.b * u16_max / u12_max,
            };
        },
        48 => {
            if (has_alpha) {
                const color: packed struct(u48) { r: u12, g: u12, b: u12, a: u12 } = @bitCast(value);
                return .{
                    .r = color.r * u16_max / u12_max,
                    .g = color.g * u16_max / u12_max,
                    .b = color.b * u16_max / u12_max,
                    .a = color.a * u16_max / u12_max,
                };
            }

            const color: packed struct(u48) { r: u16, g: u16, b: u16 } = @bitCast(value);
            return .{
                .r = color.r,
                .g = color.g,
                .b = color.b,
            };
        },
        64 => {
            const color: packed struct(u64) { r: u16, g: u16, b: u16, a: u16 } = @bitCast(value);
            return .{
                .r = color.r,
                .g = color.g,
                .b = color.b,
                .a = color.a,
            };
        },
        else => @compileError("Unsupported integer size"),
    }
}

pub fn fromHex(hex_color: []const u8) !Color {
    const hex = if (hex_color[0] == '#')
        hex_color[1..]
    else if (hex_color[0] == '0' and hex_color[1] == 'x')
        hex_color[2..]
    else
        hex_color;

    switch (hex.len) {
        // Packed RGB (0xFE == 0xFFFFAA)
        2 => {
            const code = try std.fmt.parseInt(u8, hex, 16);
            return fromNumberGeneric(u8, code, false);
        },
        // #RGB
        3 => {
            const code = try std.fmt.parseInt(u12, hex, 16);
            return fromNumberGeneric(u12, code, false);
        },
        // #RGBA
        4 => {
            const code = try std.fmt.parseInt(u16, hex, 16);
            return fromNumberGeneric(u16, code, true);
        },
        // #RR_GG_BB
        6 => {
            const code = try std.fmt.parseInt(u24, hex, 16);
            return fromNumberGeneric(u24, code, false);
        },
        // #RR_GG_BB_AA
        8 => {
            const code = try std.fmt.parseInt(u32, hex, 16);
            return fromNumberGeneric(u32, code, true);
        },
        // #RRR_GGG_BBB
        9 => {
            const code = try std.fmt.parseInt(u36, hex, 16);
            return fromNumberGeneric(u36, code, false);
        },
        // #RRRR_GGGG_BBBB
        12 => {
            // TODO: What about #RRR_GGG_BBB_AAA ?
            const code = try std.fmt.parseInt(u48, hex, 16);
            return fromNumberGeneric(u48, code, false);
        },
        // #RRRR_GGGG_BBBB_AAAA
        16 => {
            const code = try std.fmt.parseInt(u64, hex, 16);
            return fromNumberGeneric(u64, code, false);
        },
        else => return error.InvalidHexStringLength,
    }
}

/// #RRRRGGGGBBBB
const FullHexString = [13]u8;
pub fn toFullHexString(self: Color) FullHexString {
    var result: FullHexString = undefined;
    _ = std.fmt.bufPrint(&result, "#{x:0>4}{x:0>4}{x:0>4}", .{ self.r, self.g, self.b }) catch unreachable;
    return result;
}

/// #RRGGBB
pub const HexString = [7]u8;
pub fn toHexString(self: Color) HexString {
    const color = self.to8Bit();
    var result: HexString = undefined;
    _ = std.fmt.bufPrint(&result, "#{x:0>2}{x:0>2}{x:0>2}", .{ color.r, color.g, color.b }) catch unreachable;
    return result;
}
