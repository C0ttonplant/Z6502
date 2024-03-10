const std = @import("std");
const fs = std.fs;

const cpu_6502 = @import("cpu.zig");
const bus = @import("bus.zig");

var program = @embedFile("test_printing.bin");

pub fn main() !void
{
    @memcpy(&bus.ram.data, program);

    std.debug.print("begin\n", .{});

    cpu_6502.reset();

    while (true)
    {
        cpu_6502.clock();
    }
}

fn dumpVirtualMemory() !void
{
    var cwd = fs.cwd();
    
    var f = try cwd.createFile("vMemory.bin", .{});
    defer f.close();

    try f.writeAll(&bus.ram.data);

    // for (0..0x10000) |i| 
    // {
    //     _ = try f.write(&[1]u8{cpu_6502.read(@intCast(i))});
    // }
}
