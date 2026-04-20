const std = @import("std");
const fs = std.fs;

const cpu_6502 = @import("cpu.zig");
const bus = @import("bus.zig");

fn loadBin(io: std.Io, path: []const u8) !void {
    var f: std.Io.File = try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, path, .{});
    const len: u64 = try f.length(io);
    var b: [1024]u8 = std.mem.zeroes([1024]u8);

    var reader = f.reader(io, &b);
    _ = try reader.interface.readSliceAll(bus.sysRam.data[0x10000 - len ..]);
}

fn parseArgs(io: std.Io, args: std.process.Args) !void {
    var i = args.iterate();
    _ = i.next();
    while (i.next()) |a| {
        if (std.mem.eql(u8, a, "--bin")) {
            try loadBin(io, i.next() orelse continue);
        } else if (std.mem.eql(u8, a, "-b")) {
            try loadBin(io, i.next() orelse continue);
        } else if (std.mem.eql(u8, a, "--dump")) {
            bus.sysRam.dumpVirtualMemory(io, i.next() orelse continue) catch {};
        } else if (std.mem.eql(u8, a, "-D")) {
            bus.sysRam.dumpVirtualMemory(io, i.next() orelse continue) catch {};
        } else if (std.mem.eql(u8, a, "--debug")) {
            cpu_6502.debug = true;
        } else if (std.mem.eql(u8, a, "-d")) {
            cpu_6502.debug = true;
        } else if (std.mem.eql(u8, a, "--break")) {
            cpu_6502.exitOnBreak = true;
        } else if (std.mem.eql(u8, a, "-B")) {
            cpu_6502.exitOnBreak = true;
        } else {
            std.debug.print("Invalid argument {s}\n", .{a});
            std.process.exit(1);
        }
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    try parseArgs(io, init.minimal.args);

    std.debug.print("begin\n", .{});

    cpu_6502.reset();

    while (true) {
        cpu_6502.clock();
    }
}
