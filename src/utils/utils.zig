const zigimg = @import("zigimg");
const std = @import("std");
const colors = @import("colors.zig");

pub fn calculateContrastRatio(color1: u32, color2: u32) f32 {
    const lum1 = calculateRelativeLuminance(color1);
    const lum2 = calculateRelativeLuminance(color2);
    const lighter = @max(lum1, lum2);
    const darker = @min(lum1, lum2);
    return (lighter + 0.05) / (darker + 0.05);
}

pub fn calculateRelativeLuminance(color: u32) f32 {
    const r = @as(f32, @floatFromInt((color >> 16) & 0xFF)) / 255.0;
    const g = @as(f32, @floatFromInt((color >> 8) & 0xFF)) / 255.0;
    const b = @as(f32, @floatFromInt(color & 0xFF)) / 255.0;

    // WSGC stadart for relative luminace with gamma correction
    const r_lin = if (r <= 0.03928) r / 12.92 else std.math.pow(f32, (r + 0.055) / 1.055, 2.4);
    const g_lin = if (g <= 0.03928) g / 12.92 else std.math.pow(f32, (g + 0.055) / 1.055, 2.4);
    const b_lin = if (b <= 0.03928) b / 12.92 else std.math.pow(f32, (b + 0.055) / 1.055, 2.4);
    return 0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin;
}

pub fn u32_2_hexstr(hex: u32) [7]u8 {
    var buf: [7]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "#{x:0>6}", .{hex}) catch unreachable;
    return buf;
}

pub fn printColorSwatch(writer: anytype, color: u32, label: []const u8) !void {
    const r = (color >> 16) & 0xFF;
    const g = (color >> 8) & 0xFF;
    const b = color & 0xFF;
    try writer.print("\x1b[48;2;{d};{d};{d}m", .{ r, g, b });
    try writer.print("    ", .{});
    try writer.print("\x1b[0m", .{});
    try writer.print(" {s}\n", .{label});
}

pub fn blendWithPalette(base_color: u32, tint_color: u32, blend_factor: f32) u32 {
    const base_r = @as(f32, @floatFromInt((base_color >> 16) & 0xFF));
    const base_g = @as(f32, @floatFromInt((base_color >> 8) & 0xFF));
    const base_b = @as(f32, @floatFromInt(base_color & 0xFF));

    const tint_r = @as(f32, @floatFromInt((tint_color >> 16) & 0xFF));
    const tint_g = @as(f32, @floatFromInt((tint_color >> 8) & 0xFF));
    const tint_b = @as(f32, @floatFromInt(tint_color & 0xFF));

    // Blend colors
    const final_r = base_r * (1.0 - blend_factor) + tint_r * blend_factor;
    const final_g = base_g * (1.0 - blend_factor) + tint_g * blend_factor;
    const final_b = base_b * (1.0 - blend_factor) + tint_b * blend_factor;

    return colors.rgb2hex(@as(u8, @intFromFloat(@min(final_r, 255))), @as(u8, @intFromFloat(@min(final_g, 255))), @as(u8, @intFromFloat(@min(final_b, 255))));
}

pub fn apply_color_to_terminal(writer: anytype, background_color: u32, foreground_color: u32, status_colors: anytype) !void {

    // Extract RGB values from hex colors
    const bg_r = @as(u8, @intCast((background_color >> 16) & 0xFF));
    const bg_g = @as(u8, @intCast((background_color >> 8) & 0xFF));
    const bg_b = @as(u8, @intCast(background_color & 0xFF));

    const fg_r = @as(u8, @intCast((foreground_color >> 16) & 0xFF));
    const fg_g = @as(u8, @intCast((foreground_color >> 8) & 0xFF));
    const fg_b = @as(u8, @intCast(foreground_color & 0xFF));

    // Set terminal colors using OSC (Operating System Command) sequences
    // These will temporarily change the terminal's color scheme

    // Set background color (color 0)
    try writer.print("\x1b]11;rgb:{X:0>2}{X:0>2}/{X:0>2}{X:0>2}/{X:0>2}{X:0>2}\x1b\\", .{ bg_r, bg_r, bg_g, bg_g, bg_b, bg_b });

    // Set foreground color (color 7)
    try writer.print("\x1b]10;rgb:{X:0>2}{X:0>2}/{X:0>2}{X:0>2}/{X:0>2}{X:0>2}\x1b\\", .{ fg_r, fg_r, fg_g, fg_g, fg_b, fg_b });

    // Set ANSI colors 0-15 for status colors
    // Color 0 (black) - background
    try writer.print("\x1b]4;0;rgb:{X:0>2}{X:0>2}/{X:0>2}{X:0>2}/{X:0>2}{X:0>2}\x1b\\", .{ bg_r, bg_r, bg_g, bg_g, bg_b, bg_b });

    // Color 1 (red) - error/red status
    const red_r = @as(u8, @intCast((status_colors.red >> 16) & 0xFF));
    const red_g = @as(u8, @intCast((status_colors.red >> 8) & 0xFF));
    const red_b = @as(u8, @intCast(status_colors.red & 0xFF));
    try writer.print("\x1b]4;1;rgb:{X:0>2}{X:0>2}/{X:0>2}{X:0>2}/{X:0>2}{X:0>2}\x1b\\", .{ red_r, red_r, red_g, red_g, red_b, red_b });

    // Color 2 (green) - success/green status
    const green_r = @as(u8, @intCast((status_colors.green >> 16) & 0xFF));
    const green_g = @as(u8, @intCast((status_colors.green >> 8) & 0xFF));
    const green_b = @as(u8, @intCast(status_colors.green & 0xFF));
    try writer.print("\x1b]4;2;rgb:{X:0>2}{X:0>2}/{X:0>2}{X:0>2}/{X:0>2}{X:0>2}\x1b\\", .{ green_r, green_r, green_g, green_g, green_b, green_b });

    // Color 3 (yellow) - warning/yellow status
    const yellow_r = @as(u8, @intCast((status_colors.yellow >> 16) & 0xFF));
    const yellow_g = @as(u8, @intCast((status_colors.yellow >> 8) & 0xFF));
    const yellow_b = @as(u8, @intCast(status_colors.yellow & 0xFF));
    try writer.print("\x1b]4;3;rgb:{X:0>2}{X:0>2}/{X:0>2}{X:0>2}/{X:0>2}{X:0>2}\x1b\\", .{ yellow_r, yellow_r, yellow_g, yellow_g, yellow_b, yellow_b });

    // Color 4 (blue) - info/blue status
    const blue_r = @as(u8, @intCast((status_colors.blue >> 16) & 0xFF));
    const blue_g = @as(u8, @intCast((status_colors.blue >> 8) & 0xFF));
    const blue_b = @as(u8, @intCast(status_colors.blue & 0xFF));
    try writer.print("\x1b]4;4;rgb:{X:0>2}{X:0>2}/{X:0>2}{X:0>2}/{X:0>2}{X:0>2}\x1b\\", .{ blue_r, blue_r, blue_g, blue_g, blue_b, blue_b });

    // Color 5 (magenta) - debug/magenta status
    const magenta_r = @as(u8, @intCast((status_colors.magenta >> 16) & 0xFF));
    const magenta_g = @as(u8, @intCast((status_colors.magenta >> 8) & 0xFF));
    const magenta_b = @as(u8, @intCast(status_colors.magenta & 0xFF));
    try writer.print("\x1b]4;5;rgb:{X:0>2}{X:0>2}/{X:0>2}{X:0>2}/{X:0>2}{X:0>2}\x1b\\", .{ magenta_r, magenta_r, magenta_g, magenta_g, magenta_b, magenta_b });

    // Color 6 (cyan) - accent/cyan status
    const cyan_r = @as(u8, @intCast((status_colors.cyan >> 16) & 0xFF));
    const cyan_g = @as(u8, @intCast((status_colors.cyan >> 8) & 0xFF));
    const cyan_b = @as(u8, @intCast(status_colors.cyan & 0xFF));
    try writer.print("\x1b]4;6;rgb:{X:0>2}{X:0>2}/{X:0>2}{X:0>2}/{X:0>2}{X:0>2}\x1b\\", .{ cyan_r, cyan_r, cyan_g, cyan_g, cyan_b, cyan_b });

    // Color 7 (white) - foreground
    try writer.print("\x1b]4;7;rgb:{X:0>2}{X:0>2}/{X:0>2}{X:0>2}/{X:0>2}{X:0>2}\x1b\\", .{ fg_r, fg_r, fg_g, fg_g, fg_b, fg_b });
}
