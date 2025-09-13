const std = @import("std");
const fs = std.fs;

const cpu_6502 = @import("cpu.zig");
const bus = @import("bus.zig");

var program = @embedFile("test_official.bin");

pub fn main() !void {
    @memcpy(&bus.sysRam.data, program);

    std.debug.print("begin\n", .{});

    cpu_6502.reset();

    while (true) {
        cpu_6502.clock();
    }
}
