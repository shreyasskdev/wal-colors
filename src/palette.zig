const zigimg = @import("zigimg");
const utils = @import("utils/utils.zig");
const colors = @import("utils/colors.zig");
const std = @import("std");

pub fn createTintedStatusColors(palette: []const zigimg.color.Rgba32) struct { green: u32, red: u32, yellow: u32, blue: u32, magenta: u32, cyan: u32 } {
    const base_green = colors.rgb2hex(34, 197, 94); // Green-500
    const base_red = colors.rgb2hex(239, 68, 68); // Red-500
    const base_yellow = colors.rgb2hex(245, 158, 11); // Yellow-500
    const base_blue = colors.rgb2hex(33, 150, 243); // Blue-500
    const base_magenta = colors.rgb2hex(225, 5, 170); // Magenta-500
    const base_cyan = colors.rgb2hex(0, 188, 212); // Cyan-500

    // Find the most saturated color in palette to use as tint source
    var tint_color: u32 = 0;
    var max_saturation: f32 = 0;

    for (palette) |color| {
        const palette_color = colors.rgb2hex(color.r, color.g, color.b);
        const hsv = colors.rgb_to_hsv(palette_color);
        if (hsv.s > max_saturation) {
            max_saturation = hsv.s;
            tint_color = palette_color;
        }
    }

    // If no saturated color found, use a mid-tone from palette
    if (tint_color == 0) {
        for (palette) |color| {
            const palette_color = colors.rgb2hex(color.r, color.g, color.b);
            const luminance = utils.calculateRelativeLuminance(palette_color);
            if (luminance > 0.2 and luminance < 0.8) {
                tint_color = palette_color;
                break;
            }
        }
    }

    return .{
        .green = utils.blendWithPalette(base_green, tint_color, 0.4),
        .red = utils.blendWithPalette(base_red, tint_color, 0.4),
        .yellow = utils.blendWithPalette(base_yellow, tint_color, 0.4),
        .blue = utils.blendWithPalette(base_blue, tint_color, 0.4),
        .magenta = utils.blendWithPalette(base_magenta, tint_color, 0.4),
        .cyan = utils.blendWithPalette(base_cyan, tint_color, 0.4),
    };
}
pub fn findOptimalForegroundColor(background: u32, palette: []const zigimg.color.Rgba32) u32 {
    var best_color: u32 = 0;
    var best_score: f32 = -1.0;

    const bg_luminance = utils.calculateRelativeLuminance(background);
    const bg_hsv = colors.rgb_to_hsv(background);

    for (palette) |color| {
        const palette_color = colors.rgb2hex(color.r, color.g, color.b);

        if (palette_color == background) continue;

        // --- Step 1: Check for minimum contrast ---
        const contrast = utils.calculateContrastRatio(background, palette_color);
        if (contrast < 3.0) continue;

        const fg_hsv = colors.rgb_to_hsv(palette_color);

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
            const palette_color = colors.rgb2hex(color.r, color.g, color.b);
            if (palette_color == background) continue;

            const contrast = utils.calculateContrastRatio(background, palette_color);
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
            closest_color = colors.rgb2hex(@as(u8, @intCast(r)), @as(u8, @intCast(g)), @as(u8, @intCast(b)));
        }
    }
    return closest_color;
}

pub fn adjustColorForContrastGentle(base_color: u32, background: u32, min_contrast: f32) u32 {
    var adjusted = base_color;
    var contrast = utils.calculateContrastRatio(background, adjusted);
    if (contrast >= min_contrast) return adjusted;
    const bg_luminance = utils.calculateRelativeLuminance(background);
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
        adjusted = colors.rgb2hex(@as(u8, @intCast(r)), @as(u8, @intCast(g)), @as(u8, @intCast(b)));
        contrast = utils.calculateContrastRatio(background, adjusted);
        attempts += 1;
    }
    if (utils.calculateContrastRatio(background, adjusted) < min_contrast) {
        return if (should_lighten) 0xFFFFFF else 0x000000;
    }
    return adjusted;
}

pub fn desaturateIfTooVibrant(color: u32, max_saturation: f32) u32 {
    const hsv = colors.rgb_to_hsv(color);
    if (hsv.s <= max_saturation) {
        return color;
    }
    const new_s = max_saturation;
    return colors.hsv_to_rgb(.{ .h = hsv.h, .s = new_s, .v = hsv.v });
}

pub fn determineTheme(background_color: u32, foreground_color: u32) []const u8 {
    const bg_luminance = utils.calculateRelativeLuminance(background_color);
    if (utils.calculateContrastRatio(background_color, foreground_color) < 3.0) {
        return "mixed";
    }
    return if (bg_luminance < 0.5) "dark" else "light";
}
