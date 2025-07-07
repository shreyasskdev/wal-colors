const std = @import("std");
const zigimg = @import("zigimg");
const utils = @import("utils/utils.zig");
const colors = @import("utils/colors.zig");
const palettelib = @import("palette.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const default_path = "/home/shreyas/Pictures/Wallpapers/japanese_aesthetic.png";
    const wal_path = if (args.len < 2) default_path else args[1];
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    // Load image
    var image = zigimg.Image.fromFilePath(allocator, wal_path) catch |err| {
        try stderr.print("Failed to load image: {}\n", .{err});
        return;
    };
    defer image.deinit();

    try stdout.print("Loaded image: {}x{} Format: {}\n", .{ image.width, image.height, image.pixelFormat() });

    // Quantiser
    var quantizer = zigimg.OctTreeQuantizer.init(allocator);
    defer quantizer.deinit();

    var it = image.iterator();
    while (it.next()) |color| {
        try quantizer.addColor(color);
    }

    // Palette
    var palette_storage: [16]zigimg.color.Rgba32 = undefined;
    const palette = quantizer.makePalette(16, &palette_storage);

    try stdout.print("--- Generated Palette ---\n", .{});
    for (palette) |color| {
        const hex_color = colors.rgb2hex(color.r, color.g, color.b);
        const hex_string = utils.u32_2_hexstr(hex_color);
        try utils.printColorSwatch(stdout, hex_color, &hex_string);
    }

    var palette_counts = std.AutoHashMap(u32, usize).init(allocator);
    defer palette_counts.deinit();

    var pixel_it = image.iterator();
    while (pixel_it.next()) |pixel_color| {
        const r = @as(u8, @intFromFloat(pixel_color.r * 255.0));
        const g = @as(u8, @intFromFloat(pixel_color.g * 255.0));
        const b = @as(u8, @intFromFloat(pixel_color.b * 255.0));
        const pixel_hex = colors.rgb2hex(r, g, b);
        const closest_palette_color = palettelib.findClosestPaletteColor(pixel_hex, palette);
        const entry = try palette_counts.getOrPut(closest_palette_color);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    var dominant_color: u32 = 0;
    var max_count: usize = 0;
    var color_it = palette_counts.iterator();
    while (color_it.next()) |entry| {
        if (entry.value_ptr.* > max_count) {
            max_count = entry.value_ptr.*;
            dominant_color = entry.key_ptr.*;
        }
    }

    // Debug
    const background_color = dominant_color;
    const bg_luminance = utils.calculateRelativeLuminance(background_color);
    var adjusted_background = background_color;
    if (bg_luminance > 0.1) {
        adjusted_background = palettelib.desaturateIfTooVibrant(background_color, 0.3);
    }
    const foreground_color = palettelib.findOptimalForegroundColor(adjusted_background, palette);
    const adjusted_foreground = palettelib.adjustColorForContrastGentle(foreground_color, adjusted_background, 4.5);
    const status_colors = palettelib.createTintedStatusColors(palette);
    const theme_mode = palettelib.determineTheme(adjusted_background, adjusted_foreground);

    try stdout.print("\n--- Selected Theme Colors ---\n", .{});
    try utils.printColorSwatch(stdout, background_color, "Background");
    try stdout.print("{s}\n", .{utils.u32_2_hexstr(background_color)});
    try utils.printColorSwatch(stdout, adjusted_background, "Adjusted Background");
    try stdout.print("{s}\n", .{utils.u32_2_hexstr(adjusted_background)});
    try utils.printColorSwatch(stdout, foreground_color, "Foreground");
    try stdout.print("{s}\n", .{utils.u32_2_hexstr(foreground_color)});
    try utils.printColorSwatch(stdout, adjusted_foreground, "Adjusted Foreground");
    try stdout.print("{s}\n", .{utils.u32_2_hexstr(adjusted_foreground)});

    try stdout.print("\n--- Status Colors ---\n", .{});
    try utils.printColorSwatch(stdout, status_colors.green, "Green");
    try stdout.print("{s}\n", .{utils.u32_2_hexstr(status_colors.green)});
    try utils.printColorSwatch(stdout, status_colors.red, "Red");
    try stdout.print("{s}\n", .{utils.u32_2_hexstr(status_colors.red)});
    try utils.printColorSwatch(stdout, status_colors.yellow, "Yellow");
    try stdout.print("{s}\n", .{utils.u32_2_hexstr(status_colors.yellow)});
    try utils.printColorSwatch(stdout, status_colors.blue, "Blue");
    try stdout.print("{s}\n", .{utils.u32_2_hexstr(status_colors.blue)});
    try utils.printColorSwatch(stdout, status_colors.magenta, "Magenta");
    try stdout.print("{s}\n", .{utils.u32_2_hexstr(status_colors.magenta)});
    try utils.printColorSwatch(stdout, status_colors.cyan, "Cyan");
    try stdout.print("{s}\n", .{utils.u32_2_hexstr(status_colors.cyan)});

    try stdout.print("Theme mode: {s}\n", .{theme_mode});
    try utils.apply_color_to_terminal(stdout, adjusted_background, adjusted_foreground, status_colors);
}
