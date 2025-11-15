const std = @import("std");
const bmp = @import("bmp");

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sgl = sokol.gl;
const sglue = sokol.glue;

const math = std.math;
const pi = std.math.pi;
const pi2 = std.math.pi/2.0;
const pi3 = std.math.pi*3.0/2.0;
const dr = 0.0174533;

var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
var allocator: std.mem.Allocator = gpa.allocator();

const state = struct {
    var pass_action: sg.PassAction = .{};
    var smp: sg.Sampler = .{};
    var brick_tex: sg.View = .{};
    var face_tex: sg.View = .{};
    const player = struct {
        var x: f32 = 5.0;
        var y: f32 = 5.0;
        var dx: f32 = 0.0;
        var dy: f32 = 1.0;
        var a: f32 = 3 * std.math.pi / 2.0;
    };
    const map = struct {
        const size = 10;
        var s: f32 = 8;
        var px: f32 = 0;
        var py: f32 = 0;
        var arr: [size*size]u8 =
        .{
            1,1,1,1,1,1,1,1,1,1,
            1,0,0,0,0,0,0,0,0,1,
            1,0,0,1,1,0,0,0,0,1,
            1,0,0,1,1,0,0,0,0,1,
            1,0,0,0,0,0,0,0,0,1,
            1,0,0,0,0,0,0,0,0,1,
            1,0,0,0,0,0,0,0,0,1,
            1,0,0,2,2,1,2,0,0,1,
            1,0,0,0,0,0,0,0,0,1,
            1,1,1,1,1,1,1,1,1,1,
        };
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
        .clear_value = .{ .r = 0.3, .g = 0.3, .b = 0.3, .a  = 1},
    };
}

export fn frame() void {
    const width: f32 = sapp.widthf();
    const height: f32 = sapp.heightf();

    const dif = width/2 - height;
    if(dif <= 0) {
        state.map.s = width / state.map.size / 2;
        state.map.px = 0.0;
        state.map.py = dif/2;
    } else {
        state.map.s = height / state.map.size;
        state.map.py = 0.0;
        state.map.px = -dif;
    }

    sgl.defaults();
    sgl.viewportf(0,0, width, height, true);
    sgl.ortho(0, width, height, 0, -1.0, 1.0);
    drawMap2D();
    drawPlayer();
    drawRays3D();

    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });
    sgl.draw();
    sg.endPass();
    sg.commit();
}

export fn input(ev: ?*const sapp.Event) void {
    const event = ev.?;
    if(event.type == .KEY_DOWN){
        switch(event.key_code){
            .W,
            .UP => {
                state.player.x += state.player.dx/3;
                state.player.y += state.player.dy/3;
            },
            .S,
            .DOWN => {
                state.player.x -= state.player.dx/3;
                state.player.y -= state.player.dy/3;
            },
            .A,
            .LEFT => {
                state.player.a -= 0.1;
                if (state.player.a < 0) state.player.a = 2 * std.math.pi;
                state.player.dx = std.math.cos(state.player.a);
                state.player.dy = std.math.sin(state.player.a);
            },
            .D,
            .RIGHT => {
                state.player.a += 0.1;
                if (state.player.a >= 2*std.math.pi) state.player.a = 0;
                state.player.dx = std.math.cos(state.player.a);
                state.player.dy = std.math.sin(state.player.a);
            },
            else => {}
        }
    }
}

export fn cleanup() void {
    sgl.shutdown();
    sg.shutdown();
}

pub fn drawPlayer() void {
    sgl.c3f(1.0, 1.0, 0.0);
    sgl.pointSize(10.0);

    sgl.beginPoints();
    const x = state.player.x * state.map.s - state.map.px;
    const y = state.player.y * state.map.s - state.map.py;
    sgl.v2f(x, y);
    sgl.end();

    sgl.beginPoints();
    sgl.v2f(x + state.player.dx*25, y + state.player.dy*25);
    sgl.end();
}

pub fn drawMap2D() void {
    for(0..state.map.size) |y| {
        for(0..state.map.size) |x| {
            if(state.map.arr[y*state.map.size + x] != 0){
                sgl.c3f(1.0, 1.0, 1.0);
            } else {
                sgl.c3f(0.0, 0.0, 0.0);
            }
            const x0: f32 = @as(f32,@floatFromInt(x)) * state.map.s - state.map.px;
            const y0: f32 = @as(f32,@floatFromInt(y)) * state.map.s - state.map.py;
            sgl.beginQuads();
            sgl.v2f(x0 + 1,               y0 + 1);
            sgl.v2f(x0 + state.map.s - 1, y0 + 1);
            sgl.v2f(x0 + state.map.s - 1, y0 + state.map.s - 1);
            sgl.v2f(x0 + 1,               y0 + state.map.s - 1);
            sgl.end();
        }
    }
}

pub fn drawRays3D() void {
    var rx: f32 = 0.0; var ry: f32 = 0.0; var rmp: usize = 0; var disT: f32 = 0.0; var xo: f32 = 0.0; var yo: f32 = 0.0;
    const rays = 240; var ra: f32 = state.player.a - dr*30;
    if(ra > 2*pi) ra -= 2*pi;
    if(ra < 0) ra += 2*pi;
    for(0..rays) |r| {

        // Check Horizontal Lines
        var disH: f32 = 1000000; var hx: f32 = 0; var hy: f32 = 0; var hmp: usize = 0; var dof: u32 = 0; const aTan: f32 = -1/std.math.tan(ra);
        if(ra > pi){ // looking up
            ry = @floor(state.player.y) - 0.0001; rx = (state.player.y - ry) * aTan + state.player.x;
            yo = -1.0; xo = -yo * aTan;
        }
        if (ra < pi) { // looking down
            ry = @floor(state.player.y) + 1.0; rx = (state.player.y - ry) * aTan + state.player.x;
            yo = 1.0; xo = -yo * aTan;
        }
        if(ra == 0 or ra == pi){ // looking left/right
            rx = state.player.x; ry = state.player.y; dof = state.map.size;
        }
        while(dof < state.map.size) {
            if (rx < 0 or ry < 0 or rx >= state.map.size or ry >= state.map.size) break;
            const mx: u32 = @intFromFloat(rx); const my: u32 = @intFromFloat(ry); const mp: u32 = my * state.map.size + mx;
            if(state.map.arr[mp] != 0){ // hit wall
                hx = rx; hy = ry; hmp = mp; dof = state.map.size;
                disH = std.math.sqrt(std.math.pow(f32, hx - state.player.x, 2) + std.math.pow(f32, hy - state.player.y, 2));
            } else {
                rx += xo; ry += yo; dof += 1;
            }
        }

        // Check Vertical Lines
        var disV: f32 = 1000000;
        var vx: f32 = 0.0; var vy: f32 = 0.0; var vmp: usize = 0; dof = 0;
        const nTan: f32 = -std.math.tan(ra);
        if(ra > pi2 and ra < pi3){ // looking left
            rx = @floor(state.player.x) - 0.0001; ry = (state.player.x - rx) * nTan + state.player.y;
            xo = -1.0; yo = -xo * nTan;
        }
        if (ra < pi2 or ra > pi3) { // looking right
            rx = @floor(state.player.x) + 1.0; ry = (state.player.x - rx) * nTan + state.player.y;
            xo = 1.0; yo = -xo * nTan;
        }
        if(ra == pi2 or ra == pi3){ // looking up/down
            rx = state.player.x; ry = state.player.y; dof = state.map.size;
        }
        while(dof < state.map.size) {
            if (rx < 0 or ry < 0 or rx >= state.map.size or ry >= state.map.size) break;
            const mx: u32 = @intFromFloat(rx); const my: u32 = @intFromFloat(ry); const mp: u32 = my * state.map.size + mx;
            if(state.map.arr[mp] != 0){ // hit wall
                vx = rx; vy = ry; vmp = mp; dof = state.map.size;
                disV = std.math.sqrt(std.math.pow(f32, vx - state.player.x, 2) + std.math.pow(f32, vy - state.player.y, 2));
            } else {
                rx += xo; ry += yo; dof += 1;
            }
        }

        var cmultr: f32 = 1.0; var cmultg: f32 = 1.0; var cmultb: f32 = 1.0;

        if(disV < disH){
            ry = vy; rx = vx; rmp = vmp; disT = disV;
            cmultr = 1.0; cmultg = 1.0; cmultb = 1.0;
        }
        else {
            ry = hy; rx = hx; rmp = hmp; disT = disH;
            cmultr = 0.7; cmultg = 0.7; cmultb = 0.7;
        }

        ra += dr * ((30.0 / @as(f32, @floatFromInt(rays))) * 2); if(ra > 2*pi) ra -= 2*pi; if(ra < 0) ra += 2*pi;

        // draw 3D walls
        var ca = state.player.a - ra; if(ca > 2 * pi) ca -= 2 * pi; if(ca < 0) ca += 2*pi;
        disT = disT * std.math.cos(ca); // fix fish eye

        const mapWidth = state.map.s * state.map.size; const lineWidth = mapWidth / rays;
        var lineHeight = mapWidth/disT; if(lineHeight > mapWidth) lineHeight = mapWidth;
        const heightOffset = mapWidth/2.0 - lineHeight/2.0;

        switch(state.map.arr[rmp]){
            1 =>{
                sgl.c3f(0.9*cmultr, 0.0*cmultg, 0.0*cmultb);
            },
            2 =>{
                sgl.c3f(0.0*cmultr, 0.0*cmultg, 0.9*cmultb);
            },
            else => {}
        }
        const x0 = @as(f32, @floatFromInt(r)) * lineWidth + mapWidth - state.map.px; const x1 = x0 + lineWidth;
        const y0 = 0.0 - state.map.py + heightOffset; const y1 = y0 + lineHeight;

        sgl.beginPoints();
        sgl.v2f(rx * state.map.s - state.map.px, ry * state.map.s - state.map.py);
        sgl.end();

        sgl.beginQuads();
        sgl.v2f(x0, y0);
        sgl.v2f(x1, y0);
        sgl.v2f(x1, y1);
        sgl.v2f(x0, y1);
        sgl.end();
    }
}

pub fn main() !void {
    defer _ = gpa.deinit();

    sapp.run(.{
       .init_cb = init,
       .frame_cb = frame,
       .cleanup_cb = cleanup,
       .event_cb = input,
       .sample_count = 4,
       .icon = .{ .sokol_default = true},
       .window_title = "tiny raycaster",
       .logger = .{ .func = slog.func },
    });
}
