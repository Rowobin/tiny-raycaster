// script for reading 24 and 32 bit .bmp files
const std = @import("std");

const ReadBMPError = error {
    InvalidHeaderSize,
    UnsupportedBitCount,
    UnsupportedCompression,
};

pub const BMPData = struct {
    width: i32,
    height: i32,
    pixels: []u32
};

const BMPHeader = packed struct {
    signature: u16,
    file_size: u32,
    reserved: u32,
    offset: u32
};

const BMPInfoHeader = packed struct {
    size: u32,
    width: i32,
    height: i32,
    planes: u16,
    bpp: u16,
    compression: u32,
    image_size: u32,
    xpixels: u32,
    ypixel: u32,
    colors_used: u32,
    colors_important: u32
};

pub fn readBMP(allocator: std.mem.Allocator, path: []const u8) !BMPData {
    std.debug.print("Attempting to read .bmp file: {s}\n", .{path});

    // Open file
    const file = try std.fs.cwd().openFile(path, .{.mode = .read_only});
    defer file.close();

    // Read all bytes from file
    const file_size: usize = file.getEndPos() catch |err| { return err; };
    const all_bytes: []u8 = allocator.alloc(u8, file_size) catch |err| { return err; };
    defer allocator.free(all_bytes);
    _ = try file.read(all_bytes);

    // Read Header
    const file_header: *align(1)BMPHeader = std.mem.bytesAsValue(BMPHeader, all_bytes[0..@sizeOf(BMPHeader)]);
    std.debug.print("File size: {d}(bytes)\n", .{file_header.file_size});

    // Read Info Header
    const header_end: usize = @bitSizeOf(BMPHeader)/8;
    var info_header_end: usize = header_end + @bitSizeOf(BMPInfoHeader)/8;
    const file_info_header: *align(1)BMPInfoHeader = std.mem.bytesAsValue(BMPInfoHeader, all_bytes[header_end..info_header_end]);

    // Script only supports 24-bit and 32-bit .bmp files
    if(file_info_header.size != 40 and file_info_header.size != 56){
        return error.InvalidHeaderSize;
    }
    std.debug.print("Info Header size: {d}\n", .{file_info_header.size});

    if(file_info_header.bpp != 24 and file_info_header.bpp != 32){
        return error.UnsupportedBitCount;
    }
    std.debug.print("Bit-count: {d}\n", .{file_info_header.bpp});

    if(file_info_header.compression != 0 and file_info_header.compression != 3){
        return error.UnsupportedCompression;
    }
    std.debug.print("Compression: {d}\n", .{file_info_header.compression});

    // Get pixel data
    const bytes_per_pixel: u16 = file_info_header.bpp/8;
    const row_size: i32 = @divFloor(file_info_header.width * bytes_per_pixel  + 3, 4) * 4;
    const real_height: i32 = if(file_info_header.height > 0) file_info_header.height else -file_info_header.height;
    const pixels_data_size: usize = @as(u64, @intCast(row_size)) * @as(u64, @intCast(real_height));
    const pixels_num: usize = if(file_info_header.image_size != 0)
            file_info_header.image_size/bytes_per_pixel
        else
            @as(u64, @intCast(file_info_header.width)) * @as(u64, @intCast(real_height));
    std.debug.print("Image size: {d}\n", .{pixels_num});

    info_header_end = header_end + file_info_header.size;
    const pixels_data_end = info_header_end + pixels_data_size;
    const pixels_data: []u8 = all_bytes[info_header_end..pixels_data_end];
    const pixels: []u32 = allocator.alloc(u32, pixels_num) catch |err| { return err; };

    var pixel_index: usize = 0;
    var row: usize = 0;
    while(row < real_height) : (row+=1) {
        const row_offset = row * @as(u32, @intCast(row_size));
        var col: usize = 0;
        while(col < file_info_header.width) : (col+=1) {
            const col_offet = row_offset + col * bytes_per_pixel;
            const a: u32 = if(bytes_per_pixel == 4) @as(u32, pixels_data[col_offet+3]) << 24 else 0xFF << 24;
            const r: u32 = @as(u32, pixels_data[col_offet+2]);
            const g: u32 = @as(u32, pixels_data[col_offet+1]) << 8;
            const b: u32 = @as(u32, pixels_data[col_offet]) << 16;
            pixels[pixel_index] = a | b | g | r;
            pixel_index += 1;
        }
    }

    std.debug.print("Height: {d}\nWidth: {d}\n", .{real_height, file_info_header.width});
    const return_data = BMPData{
        .width = file_info_header.width,
        .height = real_height,
        .pixels = pixels
    };
    return return_data;
}
