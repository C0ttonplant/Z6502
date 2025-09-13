const std = @import("std");
const fs = std.fs;

/// create a ram device
/// `offsetStart` and `offsetEnd` are inclusive
pub fn ram(offsetStart: u16, offsetEnd: u16) type {
    if (offsetEnd <= offsetStart) @compileError("The starting address of ram must be smaller than the ending address");

    // add one to the difference for correct array length
    const length: u32 = @as(u32, @intCast(offsetEnd - offsetStart)) + 1;

    // returning a struct allows for comptime arrays with custom length
    comptime return struct {
        pub const startOffset: u16 = offsetStart;
        pub const endOffset: u16 = offsetEnd;
        pub const len = length;
        pub var data = [_]u8{0} ** length;

        /// read from memory onto bus
        pub fn read(addr: u16) u8 {
            if (addr <= startOffset or addr >= endOffset) return 0;
            return data[addr - startOffset];
        }

        /// write from bus onto memory
        pub fn write(addr: u16, dat: u8) void {
            if (addr < startOffset or addr > endOffset) return;
            data[addr - startOffset] = dat;
        }

        pub fn dumpVirtualMemory() !void {
            var cwd = fs.cwd();

            var f = try cwd.createFile("vMemory.bin", .{});
            defer f.close();

            try f.writeAll(&data);

            // for (0..0x10000) |i|
            // {
            //     _ = try f.write(&[1]u8{cpu_6502.read(@intCast(i))});
            // }
        }
    };
}
