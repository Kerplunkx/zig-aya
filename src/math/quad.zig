const Vec2 = @import("vec2.zig").Vec2;
const Rect = @import("rect.zig").Rect;

pub const Quad = struct {
    img_w: i32,
    img_h: i32,
    positions: [4]Vec2 = undefined,
    uvs: [4]Vec2 = undefined,

    pub fn init(x: f32, y: f32, width: f32, height: f32, img_w: i32, img_h: i32) Quad {
        var q = Quad{
            .img_w = img_w,
            .img_h = img_h,
        };
        q.setViewport(x, y, width, height);

        return q;
    }

    pub fn setViewport(self: *@This(), x: f32, y: f32, width: f32, height: f32) void {
        self.positions[0] = Vec2{ .x = 0, .y = 0 }; // tl
        self.positions[1] = Vec2{ .x = width, .y = 0 }; // tr
        self.positions[2] = Vec2{ .x = width, .y = height }; // br
        self.positions[3] = Vec2{ .x = 0, .y = height }; // bl

        // squeeze texcoords in by 128th of a pixel to avoid bleed
        const w_tol = (1.0 / @intToFloat(f32, self.img_w)) / 128.0;
        const h_tol = (1.0 / @intToFloat(f32, self.img_h)) / 128.0;

        const inv_w = 1.0 / @intToFloat(f32, self.img_w);
        const inv_h = 1.0 / @intToFloat(f32, self.img_h);

        self.uvs[0] = Vec2{ .x = x * inv_w + w_tol, .y = y * inv_h + h_tol };
        self.uvs[1] = Vec2{ .x = (x + width) * inv_w - w_tol, .y = y * inv_h + h_tol };
        self.uvs[2] = Vec2{ .x = (x + width) * inv_w - w_tol, .y = (y + height) * inv_h - h_tol };
        self.uvs[3] = Vec2{ .x = x * inv_w + w_tol, .y = (y + height) * inv_h - h_tol };
    }

    pub fn setImageDimensions(self: *@This(), w: i32, h: i32) void {
        self.img_w = w;
        self.img_h = h;
    }

    pub fn setViewportRect(self: *@This(), viewport: Rect) void {
        self.setViewport(viewport.x, viewport.y, viewport.w, viewport.h);
    }
};

test "quad tests" {
    var q1 = Quad.init(0, 0, 50, 50, 600, 400);
    q1.setImageDimensions(600, 400);
    q1.setViewportRect(.{ .x = 0, .y = 0, .w = 50, .h = 0 });
}
