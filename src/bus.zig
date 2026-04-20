const bus = @This();
const ram = @import("ram.zig");
const std = @import("std");

pub const sysRam = ram.ram(0, 0xffff);

/// write data onto bus
pub fn write(addr: u16, dat: u8) void {
    switch (addr) {
        0...0xEF => sysRam.write(addr, dat),
        0xF0 => std.debug.print("{c}", .{dat}),
        0xF1...0xFFFF => sysRam.write(addr, dat),
    }
}

/// read data from bus
pub fn read(addr: u16, readOnly: bool) u8 {
    _ = readOnly;
    return switch (addr) {
        // add devices here
        0...0xffff => sysRam.read(addr),
    };
}
