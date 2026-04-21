const std = @import("std");
const cpu = @import("cpu.zig");
const bus = @import("bus.zig");

var shouldDump: bool = false;
var dumpPath: []const u8 = undefined;
var time: u64 = 0;

fn loadBin(io: std.Io, path: []const u8) !void {
    var f: std.Io.File = try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, path, .{});
    const len: u64 = try f.length(io);
    var b: [1024]u8 = std.mem.zeroes([1024]u8);

    var reader = f.reader(io, &b);
    _ = try reader.interface.readSliceAll(bus.sysRam.data[0x10000 - len ..]);
}

fn parseArgs(io: std.Io, args: std.process.Args) !void {
    if (args.vector.len == 1) {
        try std.Io.File.stdout().writeStreamingAll(io,
            \\Commands:
            \\  -b --bin [file]   The executable binary to run
            \\  -D --dump [file]  Dump memory to file
            \\  -n --nano [uint]  Time in nanoseconds per cpu clock
            \\  -d --debug        Print the processor status
            \\  -B --break        Stop execution apon hitting the BRK instruction
            \\
        );
        std.process.exit(0);
    }
    var i = args.iterate();
    _ = i.next();
    while (i.next()) |a| {
        if (std.mem.eql(u8, a, "--bin")) {
            try loadBin(io, i.next() orelse continue);
        } else if (std.mem.eql(u8, a, "-b")) {
            try loadBin(io, i.next() orelse continue);
        } else if (std.mem.eql(u8, a, "--dump")) {
            shouldDump = true;
            dumpPath = i.next() orelse continue;
        } else if (std.mem.eql(u8, a, "-D")) {
            shouldDump = true;
            dumpPath = i.next() orelse continue;
        } else if (std.mem.eql(u8, a, "--debug")) {
            cpu.debug = true;
        } else if (std.mem.eql(u8, a, "-d")) {
            cpu.debug = true;
        } else if (std.mem.eql(u8, a, "--break")) {
            cpu.exitOnBreak = true;
        } else if (std.mem.eql(u8, a, "-B")) {
            cpu.exitOnBreak = true;
        } else if (std.mem.eql(u8, a, "--nano")) {
            time = try std.fmt.parseInt(u64, i.next() orelse continue, 10);
        } else if (std.mem.eql(u8, a, "-n")) {
            time = try std.fmt.parseInt(u64, i.next() orelse continue, 10);
        } else {
            std.debug.print("Invalid argument {s}\n", .{a});
            std.process.exit(1);
        }
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    try parseArgs(io, init.minimal.args);

    cpu.reset();

    while (cpu.clock()) {
        if (time != 0) {
            try io.sleep(.{ .nanoseconds = time }, .real);
        }
    }

    if (shouldDump) {
        try bus.sysRam.dumpVirtualMemory(io, dumpPath);
    }
}
