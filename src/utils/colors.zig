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
pub fn hsv_to_rgb(hsv: Hsv) u32 {
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
pub fn rgb2hex(r: u8, g: u8, b: u8) u32 {
    return (@as(u32, r) << 16) | (@as(u32, g) << 8) | @as(u32, b);
}
