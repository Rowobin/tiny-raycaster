const std = @import("std");
const bmp = @import("bmp");

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgl = sokol.gl;
const sglue = sokol.glue;
const math = std.math;

var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
var allocator: std.mem.Allocator = gpa.allocator();

const state = struct {
    var pass_action: sg.PassAction = .{};
    var smp: sg.Sampler = .{};
    var pip3d: sgl.Pipeline = .{};
    var brick_tex: sg.View = .{};
    var face_tex: sg.View = .{};
    const cube = struct {
        var rot_x: f32 = 0.0;
        var rot_y: f32 = 0.0;
        var t_x: f32 = 0.0;
        var t_y: f32 = 0.0;
        var t_z: f32 = 0.0;
        var tex: sg.View = .{};
    };
};

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    sgl.setup(.{
        .logger = .{ .func = slog.func },
    });

    state.smp = sg.makeSampler(.{
       .min_filter = .NEAREST,
       .mag_filter = .NEAREST,
    });

    state.pip3d = sgl.makePipeline(.{
       .depth = .{
           .write_enabled = true,
           .compare = .LESS_EQUAL,
       } ,
       .cull_mode = .BACK,
    });

    const bmp23: bmp.BMPData = bmp.readBMP(allocator, "textures/brick.bmp") catch unreachable;
    defer allocator.free(bmp23.pixels);
    const img = sg.makeImage(.{
        .width = bmp23.width,
        .height = bmp23.height,
        .data = init: {
            var data = sg.ImageData{};
            data.mip_levels[0] = sg.asRange(bmp23.pixels);
            break :init data;
        },
    });
    state.brick_tex = sg.makeView(.{.texture = .{.image = img}});

    const face: bmp.BMPData = bmp.readBMP(allocator, "textures/sprite.bmp") catch unreachable;
    defer allocator.free(face.pixels);
    const img2 = sg.makeImage(.{
       .width = face.width,
       .height = face.height,
       .data = init: {
           var data = sg.ImageData{};
           data.mip_levels[0] = sg.asRange(face.pixels);
           break :init data;
       },
    });
    state.face_tex = sg.makeView(.{.texture = .{.image = img2}});

    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a  = 1},
    };
}

export fn frame() void {
    const dt: f32 = @floatCast(sapp.frameDuration() * 60);

    const dw = sapp.widthf();
    const dh = sapp.heightf();
    const x0 = (dw-dh)*0.5;
    const y0 = 0;

    sgl.viewportf(x0, y0, dh, dh, true);
    state.cube.rot_x += 1.0 * dt;
    state.cube.rot_y += 1.0 * dt;
    state.cube.t_x = 0.0;
    state.cube.t_y = 0.0;
    state.cube.t_z = 0.0;
    state.cube.tex = state.brick_tex;
    drawTexCube();

    sgl.viewportf(x0, y0, dh, dh, true);
    state.cube.t_x = 5.0;
    state.cube.t_y = 0.0;
    state.cube.t_z = 0.0;
    state.cube.tex = state.face_tex;
    drawTexCube();

    sgl.viewportf(x0, y0, dh, dh, true);
    state.cube.t_x = -5.0;
    state.cube.t_y = 0.0;
    state.cube.t_z = 0.0;
    state.cube.tex = state.brick_tex;
    drawTexCube();

    sgl.viewportf(x0, y0, dh, dh, true);
    state.cube.t_x = 0.0;
    state.cube.t_y = 5.0;
    state.cube.t_z = 0.0;
    state.cube.tex = state.face_tex;
    drawTexCube();

    sgl.viewportf(x0, y0, dh, dh, true);
    state.cube.t_x = 0.0;
    state.cube.t_y = -5.0;
    state.cube.t_z = 0.0;
    state.cube.tex = state.brick_tex;
    drawTexCube();

    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });
    sgl.draw();
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    sgl.shutdown();
    sg.shutdown();
}

pub fn drawTexCube() void {
    sgl.defaults();
    sgl.loadPipeline(state.pip3d);

    sgl.enableTexture();
    sgl.texture(state.cube.tex, state.smp);

    sgl.matrixModeProjection();
    sgl.perspective(sgl.asRadians(45.0), 1.0, 0.1, 100.0);

    sgl.matrixModeModelview();
    sgl.lookat(0, 0, 24, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0);
    sgl.translate(state.cube.t_x, state.cube.t_y, state.cube.t_z);
    sgl.rotate(sgl.asRadians(state.cube.rot_x), 1.0, 0.0, 0.0);
    sgl.rotate(sgl.asRadians(state.cube.rot_y), 0.0, 1.0, 0.0);
    drawCube();
}

pub fn drawCube() void {
    // Set cube color to white
    sgl.c3f(1.0, 1.0, 1.0);

    // Front face (z = -1)
    sgl.beginQuads();
    sgl.v3fT2f(-1.0, 1.0, -1.0, 0.0, 1.0);
    sgl.v3fT2f(1.0, 1.0, -1.0, 1.0, 1.0);
    sgl.v3fT2f(1.0, -1.0, -1.0, 1.0, 0.0);
    sgl.v3fT2f(-1.0, -1.0, -1.0, 0.0, 0.0);
    sgl.end();

    // Back face (z = 1)
    sgl.beginQuads();
    sgl.v3fT2f(-1.0, -1.0, 1.0, 0.0, 0.0);
    sgl.v3fT2f(1.0, -1.0, 1.0, 1.0, 0.0);
    sgl.v3fT2f(1.0, 1.0, 1.0, 1.0, 1.0);
    sgl.v3fT2f(-1.0, 1.0, 1.0, 0.0, 1.0);
    sgl.end();

    // Left face (x = -1)
    sgl.beginQuads();
    sgl.v3fT2f(-1.0, -1.0, 1.0, 0.0, 0.0);
    sgl.v3fT2f(-1.0, 1.0, 1.0, 0.0, 1.0);
    sgl.v3fT2f(-1.0, 1.0, -1.0, 1.0, 1.0);
    sgl.v3fT2f(-1.0, -1.0, -1.0, 1.0, 0.0);
    sgl.end();

    // Right face (x = 1)
    sgl.beginQuads();
    sgl.v3fT2f(1.0, -1.0, 1.0, 0.0, 0.0);
    sgl.v3fT2f(1.0, -1.0, -1.0, 1.0, 0.0);
    sgl.v3fT2f(1.0, 1.0, -1.0, 1.0, 1.0);
    sgl.v3fT2f(1.0, 1.0, 1.0, 0.0, 1.0);
    sgl.end();

    // Bottom face (y = -1)
    sgl.beginQuads();
    sgl.v3fT2f(1.0, -1.0, -1.0, 0.0, 0.0);
    sgl.v3fT2f(1.0, -1.0, 1.0, 1.0, 0.0);
    sgl.v3fT2f(-1.0, -1.0, 1.0, 1.0, 1.0);
    sgl.v3fT2f(-1.0, -1.0, -1.0, 0.0, 1.0);
    sgl.end();

    // Top face (y = 1)
    sgl.beginQuads();
    sgl.v3fT2f(-1.0, 1.0, -1.0, 0.0, 1.0);
    sgl.v3fT2f(-1.0, 1.0, 1.0, 1.0, 1.0);
    sgl.v3fT2f(1.0, 1.0, 1.0, 1.0, 0.0);
    sgl.v3fT2f(1.0, 1.0, -1.0, 0.0, 0.0);
    sgl.end();
}

pub fn main() !void {
    defer _ = gpa.deinit();

    sapp.run(.{
       .init_cb = init,
       .frame_cb = frame,
       .cleanup_cb = cleanup,
       .width = 512,
       .height = 512,
       .sample_count = 4,
       .icon = .{ .sokol_default = true},
       .window_title = "sgl texture cube zig",
       .logger = .{ .func = slog.func },
    });
}
