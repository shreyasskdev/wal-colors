const zigimg = @import("zigimg");
const std = @import("std");

const Hsv = struct { h: f32, s: f32, v: f32 };

pub fn rgb_to_hsv(color: u32) Hsv {
    const r_f = @as(f32, @floatFromInt((color >> 16) & 0xFF)) / 255.0;
    const g_f = @as(f32, @floatFromInt((color >> 8) & 0xFF)) / 255.0;
    const b_f = @as(f32, @floatFromInt(color & 0xFF)) / 255.0;

    const cmax = @max(@max(r_f, g_f), b_f);
    const cmin = @min(@min(r_f, g_f), b_f);
    const diff = cmax - cmin;

    var h: f32 = 0;
    if (diff != 0) {
        if (cmax == r_f) {
            h = 60 * @mod((g_f - b_f) / diff, 6);
        } else if (cmax == g_f) {
            h = 60 * (((b_f - r_f) / diff) + 2);
        } else { // cmax == b_f
            h = 60 * (((r_f - g_f) / diff) + 4);
        }
    }

    if (h < 0) {
        h += 360;
    }

    const s = if (cmax == 0) 0 else diff / cmax;
    const v = cmax;

    return .{ .h = h, .s = s, .v = v };
}

fn hsv_to_rgb(hsv: Hsv) u32 {
    const h = hsv.h;
    const s = hsv.s;
    const v = hsv.v;

    const c = v * s;
    const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
    const m = v - c;

    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;

    if (h >= 0 and h < 60) {
        r = c;
        g = x;
        b = 0;
    } else if (h >= 60 and h < 120) {
        r = x;
        g = c;
        b = 0;
    } else if (h >= 120 and h < 180) {
        r = 0;
        g = c;
        b = x;
    } else if (h >= 180 and h < 240) {
        r = 0;
        g = x;
        b = c;
    } else if (h >= 240 and h < 300) {
        r = x;
        g = 0;
        b = c;
    } else if (h >= 300 and h < 360) {
        r = c;
        g = 0;
        b = x;
    }

    const final_r = @as(u8, @intFromFloat((r + m) * 255.0));
    const final_g = @as(u8, @intFromFloat((g + m) * 255.0));
    const final_b = @as(u8, @intFromFloat((b + m) * 255.0));

    return rgb2hex(final_r, final_g, final_b);
}

pub fn findOptimalForegroundColor(background: u32, palette: []const zigimg.color.Rgba32) u32 {
    var best_color: u32 = 0;
    var best_score: f32 = -1.0;

    const bg_luminance = calculateRelativeLuminance(background);
    const bg_hsv = rgb_to_hsv(background);

    for (palette) |color| {
        const palette_color = rgb2hex(color.r, color.g, color.b);

        if (palette_color == background) continue;

        // --- Step 1: Check for minimum contrast ---
        const contrast = calculateContrastRatio(background, palette_color);
        if (contrast < 3.0) continue;

        const fg_hsv = rgb_to_hsv(palette_color);

        // --- Step 2: Calculate Hue Similarity ---
        // This is the most important part. It heavily penalizes different hues.
        const hue_diff = @abs(bg_hsv.h - fg_hsv.h);
        const hue_distance = @min(hue_diff, 360 - hue_diff);

        // Allow for some deviation. A hue distance of 0 is perfect (1.0).
        // A hue distance of 45 degrees or more is basically a different color family (0.0).
        const hue_similarity = @max(0, 1.0 - (hue_distance / 45.0));

        // If hues are too different, just discard this color immediately.
        if (hue_similarity == 0) continue;

        // --- Step 3: Scoring ---
        // The score is now primarily based on providing good contrast,
        // multiplied by how similar the hue is. This ensures we pick a
        // lighter/darker shade of blue, not a green.
        const score = contrast * hue_similarity;

        if (score > best_score) {
            best_score = score;
            best_color = palette_color;
        }
    }

    // Fallback: If no color meets the criteria (e.g., a grayscale image or low-contrast palette),
    // just pick the color with the absolute highest contrast, regardless of hue.
    if (best_color == 0) {
        var max_contrast: f32 = 0;
        for (palette) |color| {
            const palette_color = rgb2hex(color.r, color.g, color.b);
            if (palette_color == background) continue;

            const contrast = calculateContrastRatio(background, palette_color);
            if (contrast > max_contrast) {
                max_contrast = contrast;
                best_color = palette_color;
            }
        }
    }

    // Final safety net
    if (best_color == 0) {
        return if (bg_luminance < 0.5) 0xFFFFFF else 0x000000;
    }

    return best_color;
}

pub fn findClosestPaletteColor(target: u32, palette: []const zigimg.color.Rgba32) u32 {
    const target_r = @as(i32, @intCast(target >> 16 & 0xFF));
    const target_g = @as(i32, @intCast(target >> 8 & 0xFF));
    const target_b = @as(i32, @intCast(target & 0xFF));
    var closest_color: u32 = 0;
    var min_distance: i32 = std.math.maxInt(i32);
    for (palette) |color| {
        const r = @as(i32, color.r);
        const g = @as(i32, color.g);
        const b = @as(i32, color.b);
        const dr = r - target_r;
        const dg = g - target_g;
        const db = b - target_b;
        // Euclidian distance
        const distance = dr * dr + dg * dg + db * db;
        if (distance < min_distance) {
            min_distance = distance;
            closest_color = rgb2hex(@as(u8, @intCast(r)), @as(u8, @intCast(g)), @as(u8, @intCast(b)));
        }
    }
    return closest_color;
}

pub fn adjustColorForContrastGentle(base_color: u32, background: u32, min_contrast: f32) u32 {
    var adjusted = base_color;
    var contrast = calculateContrastRatio(background, adjusted);
    if (contrast >= min_contrast) return adjusted;
    const bg_luminance = calculateRelativeLuminance(background);
    const should_lighten = bg_luminance < 0.5;
    if (base_color == background or base_color == 0) {
        return if (should_lighten) 0xFFFFFF else 0x000000;
    }
    var attempts: usize = 0;
    const max_attempts = 15;
    while (contrast < min_contrast and attempts < max_attempts) {
        var r = @as(i32, @intCast((adjusted >> 16) & 0xFF));
        var g = @as(i32, @intCast((adjusted >> 8) & 0xFF));
        var b = @as(i32, @intCast(adjusted & 0xFF));
        const contrast_deficit = min_contrast - contrast;
        const step = @min(@max(@as(i32, @intFromFloat(contrast_deficit * 25.0)), 3), 12);
        if (should_lighten) {
            r = @min(r + step, 255);
            g = @min(g + step, 255);
            b = @min(b + step, 255);
        } else {
            r = @max(r - step, 0);
            g = @max(g - step, 0);
            b = @max(b - step, 0);
        }
        adjusted = rgb2hex(@as(u8, @intCast(r)), @as(u8, @intCast(g)), @as(u8, @intCast(b)));
        contrast = calculateContrastRatio(background, adjusted);
        attempts += 1;
    }
    if (calculateContrastRatio(background, adjusted) < min_contrast) {
        return if (should_lighten) 0xFFFFFF else 0x000000;
    }
    return adjusted;
}

fn calculateContrastRatio(color1: u32, color2: u32) f32 {
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
pub fn desaturateIfTooVibrant(color: u32, max_saturation: f32) u32 {
    const hsv = rgb_to_hsv(color);
    if (hsv.s <= max_saturation) {
        return color;
    }
    const new_s = max_saturation;
    return hsv_to_rgb(.{ .h = hsv.h, .s = new_s, .v = hsv.v });
}

pub fn rgb2hex(r: u8, g: u8, b: u8) u32 {
    return (@as(u32, r) << 16) | (@as(u32, g) << 8) | @as(u32, b);
}

pub fn u32_2_hexstr(hex: u32) [7]u8 {
    var buf: [7]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "#{x:0>6}", .{hex}) catch unreachable;
    return buf;
}

pub fn determineTheme(background_color: u32, foreground_color: u32) []const u8 {
    const bg_luminance = calculateRelativeLuminance(background_color);
    if (calculateContrastRatio(background_color, foreground_color) < 3.0) {
        return "mixed";
    }
    return if (bg_luminance < 0.5) "dark" else "light";
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

pub fn createTintedStatusColors(palette: []const zigimg.color.Rgba32) struct {
    success: u32,
    err: u32,
    warning: u32,
} {
    const base_success = rgb2hex(34, 197, 94); // Green-500
    const base_error = rgb2hex(239, 68, 68); // Red-500
    const base_warning = rgb2hex(245, 158, 11); // Yellow-500

    // Find the most saturated color in palette to use as tint source
    var tint_color: u32 = 0;
    var max_saturation: f32 = 0;

    for (palette) |color| {
        const palette_color = rgb2hex(color.r, color.g, color.b);
        const hsv = rgb_to_hsv(palette_color);
        if (hsv.s > max_saturation) {
            max_saturation = hsv.s;
            tint_color = palette_color;
        }
    }

    // If no saturated color found, use a mid-tone from palette
    if (tint_color == 0) {
        for (palette) |color| {
            const palette_color = rgb2hex(color.r, color.g, color.b);
            const luminance = calculateRelativeLuminance(palette_color);
            if (luminance > 0.2 and luminance < 0.8) {
                tint_color = palette_color;
                break;
            }
        }
    }

    return .{
        .success = blendWithPalette(base_success, tint_color, 0.4),
        .err = blendWithPalette(base_error, tint_color, 0.4),
        .warning = blendWithPalette(base_warning, tint_color, 0.4),
    };
}

fn blendWithPalette(base_color: u32, tint_color: u32, blend_factor: f32) u32 {
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

    return rgb2hex(@as(u8, @intFromFloat(@min(final_r, 255))), @as(u8, @intFromFloat(@min(final_g, 255))), @as(u8, @intFromFloat(@min(final_b, 255))));
}
