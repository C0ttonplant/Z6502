const bus = @This();

const std = @import("std");
const cpu_6502 = @import("cpu.zig");

pub var ram: ram16k = .{};

/// write data onto bus
pub fn write(addr: u16, dat: u8) void
{
    if(addr == 0xf0)
    {
        std.debug.print("{c}", .{dat});
    }
    ram.write(addr, dat);
}

/// read data from bus
pub fn read(addr: u16, readOnly: bool) u8
{
    _ = readOnly;
    return switch (addr) 
    {
        // add modules here
        0...0xffff => ram.read(addr),
    };
}


pub const ram16k = struct 
{
    startOffset: u16 = 0,
    data: [0x10000]u8 = [_]u8{0} ** 0x10000,

    /// read from memory onto bus
    pub fn read(self: *ram16k, addr: u16) u8
    {
        if(addr < self.startOffset or addr > 0xFFFF) return 0;
        return self.data[addr];
    }

    /// write from bus onto memory
    pub fn write(self: *ram16k, addr: u16, dat: u8) void
    {

        if(addr < self.startOffset or addr > 0xFFFF) return;
        self.data[addr] = dat;
    }
};
