const std = @import("std");
const zigimg = @import("zigimg");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = std.os.argv;
    const default_path: [:0]const u8 = "/home/shreyas/Pictures/Wallpapers/japanese_aesthetic_bck.png";

    const wal_path: [:0]const u8 = if (args.len < 2) default_path else std.mem.span(args[1]);

    //Image loading
    var image = try zigimg.Image.fromFilePath(allocator, wal_path);
    defer image.deinit();

    std.debug.print("Loaded image: {}x{} Format: {}", .{ image.width, image.height, image.pixelFormat() });

    // Quantiser
    var quantizer = zigimg.OctTreeQuantizer.init(allocator);
    defer quantizer.deinit();
    var it = image.iterator();
    while (it.next()) |color| {
        try quantizer.addColor(color);
    }

    var pallette_storage: [16]zigimg.color.Rgba32 = undefined;
    const pallette = quantizer.makePalette(16, pallette_storage[0..]);

    for (pallette) |color| {
        std.debug.print("{s}\n", .{u32_2_hexstr(rgb2hex(color.r, color.g, color.b))});
    }

    // historagram
    var color_counts = std.AutoHashMap(u32, usize).init(allocator);
    defer color_counts.deinit();

    var pixel_it = image.iterator();
    while (pixel_it.next()) |color| {
        // Convert f32 color values (0.0-1.0) to u8 values (0-255) for fun
        const r = @as(u8, @intFromFloat(color.r * 255.0));
        const g = @as(u8, @intFromFloat(color.g * 255.0));
        const b = @as(u8, @intFromFloat(color.b * 255.0));
        const hex = rgb2hex(r, g, b);

        const entry = try color_counts.getOrPut(hex);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    // Actual Frequent color
    var frequent_color: u32 = 0;
    var max_count: usize = 0;

    var color_it = color_counts.iterator();
    while (color_it.next()) |entry| {
        if (entry.value_ptr.* > max_count) {
            max_count = entry.value_ptr.*;
            frequent_color = entry.key_ptr.*;
        }
    }
    // std.debug.print("Actual background color: {s}\n", .{u32_2_hexstr(frequent_color)});

    // Closest Frequent/Background color
    const background_color = findClosestPalletteColor(frequent_color, pallette);
    std.debug.print("\nbackground color: {s}\n", .{u32_2_hexstr(background_color)});

    // Foregournd color
    const foreground_color = findHighContrastColor(background_color, pallette);
    std.debug.print("foregound color: {s}\n", .{u32_2_hexstr(foreground_color)});

    // Theme mode
    const theme_mode = determineTheme(background_color, foreground_color);
    std.debug.print("\nTheme mode: {s}\n", .{theme_mode});
}

fn findClosestPalletteColor(target: u32, pallette: []zigimg.color.Rgba32) u32 {
    const target_r = @as(i32, @intCast(target >> 16 & 0xFF));
    const target_g = @as(i32, @intCast(target >> 8 & 0xFF));
    const target_b = @as(i32, @intCast(target & 0xFF));

    var closest_color: u32 = 0;
    var min_distance: i32 = std.math.maxInt(i32);

    for (pallette) |color| {
        const r = @as(i32, color.r);
        const g = @as(i32, color.g);
        const b = @as(i32, color.b);

        // Calculate Euclidean distance
        const dr = r - target_r;
        const dg = g - target_g;
        const db = b - target_b;
        const distance = dr * dr + dg * dg + db * db;

        if (distance < min_distance) {
            min_distance = distance;
            closest_color = rgb2hex(@as(u8, @intCast(r)), @as(u8, @intCast(g)), @as(u8, @intCast(b)));
        }
    }

    return closest_color;
}

fn findHighContrastColor(background: u32, palette: []const zigimg.color.Rgba32) u32 {
    var best_color: u32 = 0;
    var best_contrast: f32 = 0.0;

    for (palette) |color| {
        const palette_color = rgb2hex(color.r, color.g, color.b);
        const contrast = calculateContrastRatio(background, palette_color);
        if (contrast > best_contrast) {
            best_contrast = contrast;
            best_color = palette_color;
        }
    }

    return best_color;
}
fn calculateContrastRatio(color1: u32, color2: u32) f32 {
    const lum1 = calculateLuminance(color1);
    const lum2 = calculateLuminance(color2);

    const lighter = @max(lum1, lum2);
    const darker = @min(lum1, lum2);

    return (lighter + 0.05) / (darker + 0.05);
}
fn calculateLuminance(color: u32) f32 {
    const r = @as(f32, @floatFromInt((color >> 16) & 0xFF)) / 255.0;
    const g = @as(f32, @floatFromInt((color >> 8) & 0xFF)) / 255.0;
    const b = @as(f32, @floatFromInt(color & 0xFF)) / 255.0;

    // Relative luminance formula
    return 0.299 * r + 0.587 * g + 0.114 * b;
}

fn rgb2hex(r: u8, g: u8, b: u8) u32 {
    return (@as(u32, r) << 16) | (@as(u32, g) << 8) | @as(u32, b);
}
fn u32_2_hexstr(hex: u32) [7]u8 {
    var buf: [7]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "#{x:0>6}", .{hex}) catch unreachable;
    return buf;
}

fn determineTheme(background_color: u32, foreground_color: u32) []const u8 {
    const bg_luminance = calculateLuminance(background_color);
    const fg_luminance = calculateLuminance(foreground_color);

    const bg_is_dark = bg_luminance < 0.5;
    const fg_is_light = fg_luminance > 0.5;

    // Additional checks for more robust detection
    const strong_bg_dark = bg_luminance < 0.3;
    const strong_bg_light = bg_luminance > 0.7;
    const strong_fg_dark = fg_luminance < 0.3;
    // const strong_fg_light = fg_luminance > 0.7;

    // Calculate the difference in luminance
    const luminance_diff = @abs(bg_luminance - fg_luminance);
    const good_contrast = luminance_diff > 0.3;

    // Determine theme based on multiple factors
    if (strong_bg_dark and (fg_is_light or good_contrast)) {
        return "dark";
    } else if (strong_bg_light and (strong_fg_dark or good_contrast)) {
        return "light";
    } else if (bg_is_dark and fg_is_light) {
        return "dark";
    } else if (!bg_is_dark and !fg_is_light) {
        return "light";
    } else {
        // Edge cases - use background as primary indicator
        if (bg_luminance < 0.4) {
            return "dark";
        } else if (bg_luminance > 0.6) {
            return "light";
        } else {
            return "mixed";
        }
    }
}
