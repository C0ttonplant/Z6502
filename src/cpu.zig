const std = @import("std");

const cpu_6502 = @This();
const bus = @import("bus.zig");
pub var clockCount: u128 = 0;

// internal variables
pub var accumulator: u8 = 0;
pub var xReg: u8 = 0;
pub var yReg: u8 = 0;
pub var stackPtr: u8 = 0x0;
pub var ProgramCounter: u16 = 0;
pub var statusReg: StatusRegister = .{};

// helper variables
/// current working addres
pub var addressAbs: u16 = 0;
/// jump address
pub var addressRel: u16 = 0;
/// current executing opCode
pub var opCode: u8 = 0;
/// last fetched data
pub var fetched: u8 = 0;
/// cycles remaining for instruction
pub var cycles: u8 = 0;

/// iterate the cpu for one cycle
pub fn clock() void {
    if (cycles == 0) {
        opCode = read(ProgramCounter);

        // std.debug.print("{s}, {s}, op {x:0>2}, pc {x:0>4}, a {x:0>2}, x {x:0>2}, y {x:0>2}, SP {x:0>2}, cycles {d}\n", .{LOOKUP[opCode].Name, getAddrString(LOOKUP[opCode]), opCode, ProgramCounter, accumulator, xReg, yReg, stackPtr, clockCount});
        ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

        var instr: *Instruction = &LOOKUP[opCode];

        cycles = instr.Cycles;

        const additionalCycle1: u8 = instr.AddrMode();
        const additionalCycle2: u8 = instr.Operator();

        cycles += (additionalCycle1 & additionalCycle2);

        // std.time.sleep(100_000_000);
    }

    clockCount += 1;
    cycles -= 1;
}

/// reset cpu (does not clear memory)
pub fn reset() void {
    addressAbs = 0xFFFC;

    const lo: u16 = @as(u16, @intCast(read(addressAbs + 0))) << 0;
    const hi: u16 = @as(u16, @intCast(read(addressAbs + 1))) << 8;

    ProgramCounter = hi | lo;

    accumulator = 0;
    xReg = 0;
    yReg = 0;
    stackPtr = 0xFC;
    statusReg = .{ .U = true };

    addressAbs = 0;
    addressRel = 0;
    fetched = 0;

    cycles = 8;
}
/// interupt request
pub fn irq() void {
    if (statusReg.I) return;

    write(0x0100 + stackPtr, @truncate(ProgramCounter >> 8));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    write(0x0100 + stackPtr, @truncate(ProgramCounter));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    statusReg.B = false;
    statusReg.U = true;
    statusReg.I = true;

    write(0x0100 + stackPtr, @bitCast(statusReg));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    addressAbs = 0xFFFE;
    const lo: u16 = read(addressAbs);
    const hi: u16 = read(addressAbs + 1) << 8;
    ProgramCounter = hi | lo;

    cycles = 7;
}
/// non mutable interupt request
pub fn nmi() void {
    write(0x0100 + @as(u16, stackPtr), @truncate(ProgramCounter >> 8));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    write(0x0100 + @as(u16, stackPtr), @truncate(ProgramCounter));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    statusReg.B = false;
    statusReg.U = true;
    statusReg.I = true;

    write(0x0100 + @as(u16, stackPtr), @bitCast(statusReg));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    addressAbs = 0xFFFA;
    const lo: u16 = read(addressAbs);
    const hi: u16 = @as(u16, read(addressAbs + 1)) << 8;
    ProgramCounter = hi | lo;

    cycles = 8;
}
/// read from bus
pub fn read(addr: u16) u8 {
    return bus.read(addr, false);
}
/// write to bus
pub fn write(addr: u16, dat: u8) void {
    bus.write(addr, dat);
}
/// helper function to convert to BCD
fn toBCD(val: u8) u8 {
    // this function simply finds the nearest valid bcd value
    var top: u4 = @truncate(val >> 4);
    var bot: u4 = @truncate(val);

    top %= 10;

    if (bot > 9) {
        bot -= 10;
        top = (top + 1) % 10;
    }

    return @as(u8, @intCast(top)) << 4 | bot;
}

test "BCD" {
    try std.testing.expectEqual(0x10, toBCD(0x10));
    try std.testing.expectEqual(0x19, toBCD(0x19));
    try std.testing.expectEqual(0x20, toBCD(0x1A));
    try std.testing.expectEqual(0x25, toBCD(0x1F));
    try std.testing.expectEqual(0x65, toBCD(0xFF));
}

/// helper function to get the string of the addressing mode
pub fn getAddrString(instr: Instruction) []const u8 {
    if (instr.AddrMode == &IMM) return "IMM";
    if (instr.AddrMode == &IMP) return "IMP";
    if (instr.AddrMode == &REL) return "REL";
    if (instr.AddrMode == &IND) return "IND";
    if (instr.AddrMode == &IZX) return "IZX";
    if (instr.AddrMode == &IZY) return "IZY";
    if (instr.AddrMode == &ABS) return "ABS";
    if (instr.AddrMode == &ABX) return "ABX";
    if (instr.AddrMode == &ABY) return "ABY";
    if (instr.AddrMode == &ZP0) return "ZP0";
    if (instr.AddrMode == &ZPX) return "ZPX";
    if (instr.AddrMode == &ZPY) return "ZPY";
    return "XXX";
}

/// gets the correct data for the addressing mode
pub fn fetch() void {
    if (LOOKUP[opCode].AddrMode != &IMP) fetched = read(addressAbs);
}

// addresing modes

/// implied mode
pub fn IMP() u8 {
    fetched = accumulator;
    return 0;
}
/// immediate mode
pub fn IMM() u8 {
    addressAbs = ProgramCounter;
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    return 0;
}
/// zero page
pub fn ZP0() u8 {
    addressAbs = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];
    addressAbs &= 0x00ff;
    return 0;
}
/// zero page x
pub fn ZPX() u8 {
    addressAbs = @addWithOverflow(read(ProgramCounter), xReg)[0];
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];
    addressAbs &= 0x00ff;
    return 0;
}
/// zero page y
pub fn ZPY() u8 {
    addressAbs = @addWithOverflow(read(ProgramCounter), yReg)[0];
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];
    addressAbs &= 0x00ff;
    return 0;
}
/// absolute
pub fn ABS() u8 {
    const lo: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    const hi: u16 = @as(u16, @intCast(read(ProgramCounter))) << 8;
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    addressAbs = hi | lo;

    return 0;
}
/// absolute x
pub fn ABX() u8 {
    const lo: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    const hi: u16 = @as(u16, @intCast(read(ProgramCounter))) << 8;
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    addressAbs = hi | lo;
    addressAbs = @addWithOverflow(addressAbs, xReg)[0];

    // returns extra cycle if the reg goes over the page
    if (addressAbs & 0xff00 != hi) return 1;

    return 0;
}
/// absolute y
pub fn ABY() u8 {
    const lo: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    const hi: u16 = @as(u16, @intCast(read(ProgramCounter))) << 8;
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    addressAbs = hi | lo;
    addressAbs = @addWithOverflow(addressAbs, yReg)[0];

    // returns extra cycle if the reg goes over the page
    if (addressAbs & 0xff00 != hi) return 1;

    return 0;
}
/// indirect
pub fn IND() u8 {
    const lo: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    const hi: u16 = @as(u16, read(ProgramCounter)) << 8;
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    const ptr: u16 = hi | lo;

    // simulate 6502 hardware bug
    if (lo == 0x00ff) {
        addressAbs = (@as(u16, read(ptr & 0xff00)) << 8) | read(ptr);
        return 0;
    }

    addressAbs = (@as(u16, read(@addWithOverflow(ptr, 1)[0])) << 8) | read(ptr);

    return 0;
}
/// indirect x
pub fn IZX() u8 {
    const t: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    const lo: u16 = read((t + xReg) & 0x00ff);
    const hi: u16 = read((t + xReg + 1) & 0x00ff);

    addressAbs = (hi << 8) | lo;
    return 0;
}
/// indirect y
pub fn IZY() u8 {
    const t: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    const lo: u16 = read(t & 0x00ff);
    const hi: u16 = read((t + 1) & 0x00ff);

    addressAbs = (hi << 8) | lo;

    addressAbs = @addWithOverflow(addressAbs, yReg)[0];

    if (addressAbs & 0xff00 != hi << 8) return 1;

    return 0;
}
/// relative
pub fn REL() u8 {
    addressRel = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    if (addressRel & 0x80 != 0) {
        addressRel |= 0xff00;
    } else {
        addressRel &= 0x00ff;
    }
    return 0;
}
//
// opCodes
//
/// logical and accumulator
pub fn AND() u8 {
    fetch();
    accumulator &= fetched;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 != 0;
    return 1;
}
/// add carry
pub fn ADC() u8 {
    fetch();

    const tmp: u16 = @as(u16, accumulator) + @as(u16, fetched) + @as(u16, @intFromBool(statusReg.C));
    const result: u16 = if (statusReg.D) toBCD(@truncate(tmp)) else @truncate(tmp);

    // TODO: test if this is the proper method for decimal mode
    statusReg.C = tmp > if (statusReg.D) @as(u8, 0x99) else 0xFF;
    statusReg.Z = result & 0x00ff == 0;
    statusReg.N = result & 0x0080 != 0;
    statusReg.V = ((~(accumulator ^ fetched) & (accumulator ^ tmp)) & 0x80) != 0;

    accumulator = @truncate(result);

    return 1;
}
/// logical shift left (carry <- data <- void)
pub fn ASL() u8 {
    fetch();
    const tmp: u16 = @as(u16, fetched) << 1;
    statusReg.C = fetched & 0x80 != 0;
    statusReg.Z = tmp & 0xff == 0;
    statusReg.N = tmp & 0x80 != 0;

    if (LOOKUP[opCode].AddrMode == &IMP) {
        accumulator = @truncate(tmp);
        return 0;
    }
    write(addressAbs, @truncate(tmp));
    return 0;
}
/// branch if carry clear
pub fn BCC() u8 {
    if (statusReg.C) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if (addressAbs & 0xff00 != ProgramCounter & 0xff00) {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
// branch if carry set
pub fn BCS() u8 {
    if (!statusReg.C) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if (addressAbs & 0xff00 != ProgramCounter & 0xff00) {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// branch if equal
pub fn BEQ() u8 {
    if (!statusReg.Z) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if (addressAbs & 0xff00 != ProgramCounter & 0xff00) {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// test bits
pub fn BIT() u8 {
    fetch();
    const result: u8 = accumulator & fetched;
    statusReg.Z = result == 0;
    statusReg.N = fetched & 0x80 != 0;
    statusReg.V = fetched & 0x40 != 0;
    return 0;
}
/// branch if minus
pub fn BMI() u8 {
    if (!statusReg.N) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if (addressAbs & 0xff00 != ProgramCounter & 0xff00) {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// branch if not equal
pub fn BNE() u8 {
    if (statusReg.Z) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if (addressAbs & 0xff00 != ProgramCounter & 0xff00) {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// branch if plus
pub fn BPL() u8 {
    if (statusReg.N) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if (addressAbs & 0xff00 != ProgramCounter & 0xff00) {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// break
pub fn BRK() u8 {
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    statusReg.I = true;

    write(0x0100 + @as(u16, stackPtr), @truncate(ProgramCounter >> 8));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];
    write(0x0100 + @as(u16, stackPtr), @truncate(ProgramCounter));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    statusReg.B = true;

    write(0x0100 + @as(u16, stackPtr), @bitCast(statusReg));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    statusReg.B = false;

    ProgramCounter = (@as(u16, read(0xFFFF)) << 8) | read(0xFFFE);

    std.process.exit(0);
    return 0;
}
/// branch if overflow clear
pub fn BVC() u8 {
    if (statusReg.V) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if (addressAbs & 0xff00 != ProgramCounter & 0xff00) {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// branch if overflow set
pub fn BVS() u8 {
    if (!statusReg.V) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if (addressAbs & 0xff00 != ProgramCounter & 0xff00) {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// clear carry
pub fn CLC() u8 {
    statusReg.C = false;
    return 0;
}
/// clear 'decimal mode' flag
pub fn CLD() u8 {
    statusReg.D = false;
    return 0;
}
/// clear 'no interupt' flag
pub fn CLI() u8 {
    statusReg.I = false;
    return 0;
}
/// clear overflow flag
pub fn CLV() u8 {
    statusReg.V = false;
    return 0;
}
/// compare accumulator
pub fn CMP() u8 {
    fetch();
    const result: u16 = @subWithOverflow(@as(u16, accumulator), @as(u16, fetched))[0];

    statusReg.C = accumulator >= fetched;
    statusReg.Z = result & 0x00ff == 0;
    statusReg.N = result & 0x0080 != 0;

    return 1;
}
/// compare xReg
pub fn CPX() u8 {
    fetch();
    const result: u16 = @subWithOverflow(@as(u16, xReg), @as(u16, fetched))[0];

    statusReg.C = xReg >= fetched;
    statusReg.Z = result & 0x00ff == 0;
    statusReg.N = result & 0x0080 != 0;
    return 0;
}
/// compare yReg
pub fn CPY() u8 {
    fetch();
    const result: u16 = @subWithOverflow(@as(u16, yReg), @as(u16, fetched))[0];

    statusReg.C = yReg >= fetched;
    statusReg.Z = result & 0x00ff == 0;
    statusReg.N = result & 0x0080 != 0;
    return 0;
}
/// decrement memory
pub fn DEC() u8 {
    fetch();

    const result: u8 = @subWithOverflow(fetched, 1)[0];
    write(addressAbs, result);

    statusReg.Z = result == 0;
    statusReg.N = result & 0x80 != 0;
    return 0;
}
/// decrement xReg
pub fn DEX() u8 {
    xReg = @subWithOverflow(xReg, 1)[0];

    statusReg.Z = xReg == 0;
    statusReg.N = xReg & 0x80 != 0;
    return 0;
}
/// decrement yReg
pub fn DEY() u8 {
    yReg = @subWithOverflow(yReg, 1)[0];

    statusReg.Z = yReg == 0;
    statusReg.N = yReg & 0x80 != 0;
    return 0;
}
/// bitwise xor
pub fn EOR() u8 {
    fetch();
    accumulator ^= fetched;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 != 0;
    return 1;
}
/// increment memory
pub fn INC() u8 {
    fetch();
    const result: u8 = @addWithOverflow(fetched, 1)[0];

    write(addressAbs, result);

    statusReg.Z = result == 0;
    statusReg.N = result & 0x80 != 0;
    return 0;
}
/// increment xReg
pub fn INX() u8 {
    xReg = @addWithOverflow(xReg, 1)[0];

    statusReg.Z = xReg == 0;
    statusReg.N = xReg & 0x80 != 0;
    return 0;
}
/// increment yReg
pub fn INY() u8 {
    yReg = @addWithOverflow(yReg, 1)[0];

    statusReg.Z = yReg == 0;
    statusReg.N = yReg & 0x80 != 0;
    return 0;
}
/// jump
pub fn JMP() u8 {

    // @import("root").dumpVirtualMemory() catch {};

    // std.process.exit(0);
    ProgramCounter = addressAbs;
    return 0;
}
/// jump to subroutine
pub fn JSR() u8 {
    ProgramCounter = @subWithOverflow(ProgramCounter, 1)[0];

    write(0x0100 + @as(u16, stackPtr), @truncate(ProgramCounter >> 8));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];
    write(0x0100 + @as(u16, stackPtr), @truncate(ProgramCounter));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    ProgramCounter = addressAbs;
    return 0;
}
/// load accumulator
pub fn LDA() u8 {
    fetch();

    accumulator = fetched;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 != 0;
    return 1;
}
/// load xReg
pub fn LDX() u8 {
    fetch();

    xReg = fetched;

    statusReg.Z = xReg == 0;
    statusReg.N = xReg & 0x80 != 0;
    return 1;
}
/// load yReg
pub fn LDY() u8 {
    fetch();

    yReg = fetched;

    statusReg.Z = yReg == 0;
    statusReg.N = yReg & 0x80 != 0;
    return 1;
}
/// logical shift right (void -> data -> carry)
pub fn LSR() u8 {
    fetch();
    statusReg.C = fetched & 1 == 1;

    const tmp: u8 = fetched >> 1;
    statusReg.Z = tmp == 0;
    statusReg.N = tmp & 0x80 != 0;

    if (LOOKUP[opCode].AddrMode == &IMP) {
        accumulator = tmp;
        return 0;
    }
    write(addressAbs, tmp);
    return 0;
}
/// no operation (does nothing)
pub fn NOP() u8 {
    switch (opCode) {
        0x1C, 0x3C, 0x5C, 0x7C, 0xDC, 0xFC => return 1,
        else => return 0,
    }
}
/// bitwise or accumulator
pub fn ORA() u8 {
    fetch();

    accumulator |= fetched;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 != 0;
    return 0;
}
/// push accumulator to stack
pub fn PHA() u8 {
    write(0x0100 + @as(u16, stackPtr), accumulator);
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    return 0;
}
/// push prossesor status to stack
pub fn PHP() u8 {
    statusReg.B = true;
    statusReg.U = true;
    write(0x0100 + @as(u16, stackPtr), @bitCast(statusReg));
    statusReg.B = false;
    statusReg.U = false;

    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    return 0;
}
/// pop accumulator from stack
pub fn PLA() u8 {
    stackPtr = @addWithOverflow(stackPtr, 1)[0];

    accumulator = read(0x0100 + @as(u16, stackPtr));
    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 != 0;

    return 0;
}
/// pop processor status from stack
pub fn PLP() u8 {
    stackPtr = @addWithOverflow(stackPtr, 1)[0];

    statusReg = @bitCast(read(0x0100 + @as(u16, stackPtr)));
    statusReg.U = true;

    return 0;
}
/// rotate bits left (carry <- data <- carry)
pub fn ROL() u8 {
    fetch();

    const tmp: u16 = (@as(u16, fetched) << 1) | @as(u16, @intFromBool(statusReg.C));

    statusReg.C = tmp & 0xff00 != 0;
    statusReg.Z = tmp & 0x00ff == 0;
    statusReg.N = tmp & 0x80 != 0;

    if (LOOKUP[opCode].AddrMode == &IMP) {
        accumulator = @truncate(tmp);
        return 0;
    }
    write(addressAbs, @truncate(tmp));
    return 0;
}
/// rotate bits right (carry -> data -> carry)
pub fn ROR() u8 {
    fetch();

    const tmp: u16 = (@as(u16, @intFromBool(statusReg.C)) << 7) | (fetched >> 1);

    statusReg.C = fetched & 1 == 1;
    statusReg.Z = tmp & 0x00ff == 0;
    statusReg.N = tmp & 0x80 != 0;

    if (LOOKUP[opCode].AddrMode == &IMP) {
        accumulator = @truncate(tmp);
        return 0;
    }
    write(addressAbs, @truncate(tmp));
    return 0;
}
/// return from interupt
pub fn RTI() u8 {
    stackPtr = @addWithOverflow(stackPtr, 1)[0];
    statusReg = @bitCast(read(0x0100 + @as(u16, stackPtr)));
    statusReg.B = false;
    statusReg.U = false;

    stackPtr = @addWithOverflow(stackPtr, 1)[0];
    ProgramCounter = read(0x0100 + @as(u16, stackPtr));

    stackPtr = @addWithOverflow(stackPtr, 1)[0];
    ProgramCounter |= @as(u16, read(0x0100 + @as(u16, stackPtr))) << 8;

    return 0;
}
/// return from subroutine
pub fn RTS() u8 {
    stackPtr = @addWithOverflow(stackPtr, 1)[0];
    ProgramCounter = read(0x0100 + @as(u16, stackPtr));

    stackPtr = @addWithOverflow(stackPtr, 1)[0];
    ProgramCounter |= @as(u16, read(0x0100 + @as(u16, stackPtr))) << 8;

    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];
    return 0;
}
/// carry subtract
pub fn SBC() u8 {
    fetch();

    const val: u16 = @as(u16, fetched) ^ 0x00ff;

    const tmp: u16 = @as(u16, accumulator) + val + @as(u16, @intFromBool(statusReg.C)) - if (statusReg.D) @as(u16, 0x66) else 0;
    const result: u8 = if (statusReg.D) toBCD(@truncate(tmp)) else @truncate(tmp);

    statusReg.C = tmp & 0xff00 != 0;
    statusReg.Z = result == 0;
    statusReg.N = result & 0x80 != 0;
    statusReg.V = ((tmp ^ accumulator) & (tmp ^ (val)) & 0x80) != 0;

    accumulator = result;

    return 1;
}
/// set carry flag
pub fn SEC() u8 {
    statusReg.C = true;
    return 0;
}
/// set 'decimal mode' flag
pub fn SED() u8 {
    statusReg.D = true;
    return 0;
}
/// set 'no interrupt' flag
pub fn SEI() u8 {
    statusReg.I = true;
    return 0;
}
/// store accumulator
pub fn STA() u8 {
    write(addressAbs, accumulator);
    return 0;
}
/// store xReg
pub fn STX() u8 {
    write(addressAbs, xReg);
    return 0;
}
/// store yReg
pub fn STY() u8 {
    write(addressAbs, yReg);
    return 0;
}
/// transfer accumulator to xReg
pub fn TAX() u8 {
    xReg = accumulator;

    statusReg.Z = xReg == 0;
    statusReg.N = xReg & 0x80 != 0;
    return 0;
}
/// transfer accumulator to yReg
pub fn TAY() u8 {
    yReg = accumulator;

    statusReg.Z = yReg == 0;
    statusReg.N = yReg & 0x80 != 0;
    return 0;
}
/// transfer stackPtr to xReg
pub fn TSX() u8 {
    xReg = stackPtr;

    statusReg.Z = xReg == 0;
    statusReg.N = xReg & 0x80 != 0;
    return 0;
}
/// transfer xReg to accumulator
pub fn TXA() u8 {
    accumulator = xReg;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 != 0;
    return 0;
}
/// transfer xReg to stackPtr
pub fn TXS() u8 {
    stackPtr = xReg;
    return 0;
}
/// transfer yReg to accumulator
pub fn TYA() u8 {
    accumulator = yReg;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 != 0;
    return 0;
}

// illegal opCodes, all are defined but unstable instructions may not be implemented

/// non implemented illegal opcode
pub fn XXX() u8 {
    return 0;
}
/// (illegal opcode), immediatly closes program
pub fn JAM() u8 {
    std.debug.print("Execution stopped by bad instruction: {x:0>2}\n", .{opCode});
    bus.sysRam.dumpVirtualMemory() catch {};
    std.process.exit(0);
    return 0;
}
/// (illegal opcode), logical and + LSR
pub fn ALR() u8 {
    fetch();

    accumulator &= fetched;
    statusReg.C = accumulator & 1 == 1;
    accumulator = accumulator >> 1;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 == 0x80;

    return 0;
}
/// (illegal opcode), logical and + set C as bit 7
pub fn ANC() u8 {
    fetch();

    accumulator &= fetched;

    statusReg.C = accumulator & 0x80 == 0x80;
    statusReg.N = accumulator & 0x80 == 0x80;
    statusReg.Z = accumulator == 0;

    return 0;
}
/// (unstable opcode),
pub fn ANE() u8 {
    return 0;
}
/// (illegal opcode), logical and + ROR
pub fn ARR() u8 {
    fetch();

    accumulator &= fetched;

    const vtmp: u8 = accumulator + fetched;

    const tmp: u16 = (@as(u16, @intFromBool(statusReg.C)) << 7) | (fetched >> 1);

    statusReg.C = fetched & 1 == 1;
    statusReg.Z = tmp & 0x00ff == 0;
    statusReg.N = tmp & 0x80 == 0x80;

    // TODO: more reaserch, this is simply a guess on what i think is supposed to happen
    statusReg.V = (~((accumulator ^ fetched) & (accumulator ^ vtmp)) & 0x80) != 0;

    accumulator = @truncate(tmp);

    return 0;
}
/// (illegal opcode), decrement memory, then compare
pub fn DCP() u8 {
    fetch();

    const result = @subWithOverflow(fetched, 1);
    write(addressAbs, result[0]);

    const cmp: u8 = @subWithOverflow(accumulator, result[0])[0];

    statusReg.C = cmp >= result[0] or result[1] == 1;
    statusReg.Z = cmp == 0;
    statusReg.N = cmp & 0x80 != 0;
    return 0;
}
/// (illegal opcode), increment memory, then sub carry
pub fn ISC() u8 {
    fetch();

    const inc: u8 = @addWithOverflow(fetched, 1)[0];
    write(addressAbs, inc);

    const val: u16 = @as(u16, inc) ^ 0x00ff;

    const tmp: u16 = @as(u16, accumulator) + val + @as(u16, @intFromBool(statusReg.C));
    const result: u8 = @truncate(tmp);

    statusReg.C = tmp & 0xff00 != 0;
    statusReg.Z = result == 0;
    statusReg.N = result & 0x80 != 0;
    statusReg.V = ((tmp ^ accumulator) & (tmp ^ (val)) & 0x80) != 0;

    accumulator = result;

    return 0;
}
/// (illegal opcode), logical and -> load accumulator, xReg and stackPtr
pub fn LAS() u8 {
    fetch();

    // this cant be right
    accumulator = stackPtr & fetched;
    xReg = accumulator;
    // this is wrong in so many ways
    stackPtr = accumulator;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 == 0x80;

    return 1;
}
/// (illegal opcode), load memory onto accumulator and xReg
pub fn LAX() u8 {
    fetch();

    accumulator = fetched;
    xReg = fetched;

    statusReg.Z = fetched == 0;
    statusReg.N = fetched & 0x80 == 0x80;
    return 1;
}
/// (unstable opcode)
pub fn LXA() u8 {
    return 0;
}
/// (illegal opcode), ROL -> memory, then logical and -> accumulator
pub fn RLA() u8 {
    fetch();

    const tmp: u16 = fetched << 1 | @as(u16, @intFromBool(statusReg.C));
    write(addressAbs, @truncate(tmp));

    accumulator &= @truncate(tmp);

    statusReg.C = fetched & 0x80 != 0;
    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 != 0;

    return 0;
}
/// (illegal opcode), ROR, then ADC
pub fn RRA() u8 {
    fetch();

    const tmp: u16 = (@as(u16, @intFromBool(statusReg.C)) << 7) | (fetched >> 1);

    statusReg.C = fetched & 1 == 1;

    const result: u16 = @as(u16, accumulator) + (tmp & 0x00ff) + @as(u16, @intFromBool(statusReg.C));

    statusReg.C = result & 0xff00 != 0;
    statusReg.Z = result & 0x00ff == 0;
    statusReg.N = result & 0x0080 != 0;
    statusReg.V = ((~(accumulator ^ (tmp & 0x00ff)) & (accumulator ^ (result & 0x00ff))) & 0x80) != 0;

    accumulator = @truncate(result);

    return 0;
}
/// (illegal opcode), accumulator & xReg -> memory
pub fn SAX() u8 {
    write(addressAbs, accumulator & xReg);
    return 0;
}
/// (illegal opcode), CMP and DEX, (accumulator & xReg) - value -> xReg
pub fn SBX() u8 {
    fetch();

    const result: u16 = @as(u16, @intCast(accumulator & xReg)) + ~(@addWithOverflow(fetched, 1)[0]);
    xReg = @truncate(result);

    statusReg.C = result > 0xff;
    statusReg.Z = xReg == 0;
    statusReg.N = xReg & 0x80 == 0x80;

    return 0;
}
/// (unstable opcode)
pub fn SHA() u8 {
    return 0;
}
/// (unstable opcode)
pub fn SHX() u8 {
    return 0;
}
/// (illegal opcode), arithmatic shift left, then accumulator | memory -> accumulator
pub fn SLO() u8 {
    fetch();

    statusReg.C = fetched & 0x80 == 0x80;
    const result: u8 = fetched << 1;

    write(addressAbs, result);

    accumulator |= result;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 == 0x80;

    return 0;
}
/// (illegal opcode), logical shift right, then accumulator ^ memory -> accumulator
pub fn SRE() u8 {
    fetch();

    statusReg.C = fetched & 1 == 1;
    const result: u8 = fetched >> 1;

    write(addressAbs, result);

    accumulator ^= result;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 == 0x80;

    return 0;
}
/// (unstable opcode)
pub fn TAS() u8 {
    return 0;
}
/// (illegal opcode), same as SBC
pub fn USB() u8 {
    fetch();

    const val: u16 = @as(u16, fetched) ^ 0x00ff;

    const tmp: u16 = @as(u16, accumulator) + val + @as(u16, @intFromBool(statusReg.C));
    const result: u8 = @truncate(tmp);

    statusReg.C = tmp & 0xff00 != 0;
    statusReg.Z = result == 0;
    statusReg.N = result & 0x80 != 0;
    statusReg.V = ((tmp ^ accumulator) & (tmp ^ (val)) & 0x80) != 0;

    accumulator = result;

    return 0;
}

const StatusRegister = packed struct {
    /// carry
    C: bool = false,
    /// zero
    Z: bool = false,
    /// disable interupts
    I: bool = false,
    /// decimal mode
    D: bool = false,
    /// break
    B: bool = false,
    /// unused
    U: bool = false,
    /// signed overflow
    V: bool = false,
    /// negative
    N: bool = false,
};

pub var LOOKUP: [0x100]Instruction =
    .{ //    00                                                                  01                                                                  02                                                                  03                                                                   04                                                                  05                                                                  06                                                                  07                                                                   08                                                                  09                                                                  0A                                                                  0B                                                                   0C                                                                  0D                                                                  0E                                                                  0F
        .{ .Name = "BRK", .Cycles = 7, .AddrMode = &IMP, .Operator = &BRK }, .{ .Name = "ORA", .Cycles = 6, .AddrMode = &IZX, .Operator = &ORA }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "SLO", .Cycles = 8, .AddrMode = &IZX, .Operator = &SLO }, .{ .Name = "NOP", .Cycles = 3, .AddrMode = &ZP0, .Operator = &NOP }, .{ .Name = "ORA", .Cycles = 3, .AddrMode = &ZP0, .Operator = &ORA }, .{ .Name = "ASL", .Cycles = 5, .AddrMode = &ZP0, .Operator = &ASL }, .{ .Name = "SLO", .Cycles = 5, .AddrMode = &ZP0, .Operator = &SLO }, .{ .Name = "PHP", .Cycles = 3, .AddrMode = &IMP, .Operator = &PHP }, .{ .Name = "ORA", .Cycles = 2, .AddrMode = &IMM, .Operator = &ORA }, .{ .Name = "ASL", .Cycles = 2, .AddrMode = &IMP, .Operator = &ASL }, .{ .Name = "ANC", .Cycles = 2, .AddrMode = &IMM, .Operator = &ANC }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &IMP, .Operator = &ABS }, .{ .Name = "ORA", .Cycles = 4, .AddrMode = &ABS, .Operator = &ORA }, .{ .Name = "ASL", .Cycles = 6, .AddrMode = &ABS, .Operator = &ASL }, .{ .Name = "SLO", .Cycles = 6, .AddrMode = &ABS, .Operator = &SLO },
        .{ .Name = "BPL", .Cycles = 2, .AddrMode = &REL, .Operator = &BPL }, .{ .Name = "ORA", .Cycles = 5, .AddrMode = &IZY, .Operator = &ORA }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "SLO", .Cycles = 8, .AddrMode = &IZY, .Operator = &SLO }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &ZPX, .Operator = &NOP }, .{ .Name = "ORA", .Cycles = 4, .AddrMode = &ZPX, .Operator = &ORA }, .{ .Name = "ASL", .Cycles = 6, .AddrMode = &ZPX, .Operator = &ASL }, .{ .Name = "SLO", .Cycles = 6, .AddrMode = &ZPX, .Operator = &SLO }, .{ .Name = "CLC", .Cycles = 2, .AddrMode = &IMP, .Operator = &CLC }, .{ .Name = "ORA", .Cycles = 4, .AddrMode = &ABY, .Operator = &ORA }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMP, .Operator = &NOP }, .{ .Name = "SLO", .Cycles = 7, .AddrMode = &ABY, .Operator = &SLO }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &IMP, .Operator = &ABX }, .{ .Name = "ORA", .Cycles = 4, .AddrMode = &ABX, .Operator = &ORA }, .{ .Name = "ASL", .Cycles = 7, .AddrMode = &ABX, .Operator = &ASL }, .{ .Name = "SLO", .Cycles = 7, .AddrMode = &ABX, .Operator = &SLO },
        .{ .Name = "JSR", .Cycles = 6, .AddrMode = &ABS, .Operator = &JSR }, .{ .Name = "AND", .Cycles = 6, .AddrMode = &IZX, .Operator = &AND }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "RLA", .Cycles = 8, .AddrMode = &IZX, .Operator = &RLA }, .{ .Name = "BIT", .Cycles = 3, .AddrMode = &ZP0, .Operator = &BIT }, .{ .Name = "AND", .Cycles = 3, .AddrMode = &ZP0, .Operator = &AND }, .{ .Name = "ROL", .Cycles = 5, .AddrMode = &ZP0, .Operator = &ROL }, .{ .Name = "RLA", .Cycles = 5, .AddrMode = &ZP0, .Operator = &RLA }, .{ .Name = "PLP", .Cycles = 4, .AddrMode = &IMP, .Operator = &PLP }, .{ .Name = "AND", .Cycles = 2, .AddrMode = &IMM, .Operator = &AND }, .{ .Name = "ROL", .Cycles = 2, .AddrMode = &IMP, .Operator = &ROL }, .{ .Name = "ANC", .Cycles = 2, .AddrMode = &IMM, .Operator = &ANC }, .{ .Name = "BIT", .Cycles = 4, .AddrMode = &ABS, .Operator = &BIT }, .{ .Name = "AND", .Cycles = 4, .AddrMode = &ABS, .Operator = &AND }, .{ .Name = "ROL", .Cycles = 6, .AddrMode = &ABS, .Operator = &ROL }, .{ .Name = "RLA", .Cycles = 6, .AddrMode = &ABS, .Operator = &RLA },
        .{ .Name = "BMI", .Cycles = 2, .AddrMode = &REL, .Operator = &BMI }, .{ .Name = "AND", .Cycles = 5, .AddrMode = &IZY, .Operator = &AND }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "RLA", .Cycles = 8, .AddrMode = &IZY, .Operator = &RLA }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &ZPX, .Operator = &NOP }, .{ .Name = "AND", .Cycles = 4, .AddrMode = &ZPX, .Operator = &AND }, .{ .Name = "ROL", .Cycles = 6, .AddrMode = &ZPX, .Operator = &ROL }, .{ .Name = "RLA", .Cycles = 6, .AddrMode = &ZPX, .Operator = &RLA }, .{ .Name = "SEC", .Cycles = 2, .AddrMode = &IMP, .Operator = &SEC }, .{ .Name = "AND", .Cycles = 4, .AddrMode = &ABY, .Operator = &AND }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMP, .Operator = &NOP }, .{ .Name = "RLA", .Cycles = 7, .AddrMode = &ABX, .Operator = &RLA }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &IMP, .Operator = &ABX }, .{ .Name = "AND", .Cycles = 4, .AddrMode = &ABX, .Operator = &AND }, .{ .Name = "ROL", .Cycles = 7, .AddrMode = &ABX, .Operator = &ROL }, .{ .Name = "RLA", .Cycles = 7, .AddrMode = &ABX, .Operator = &RLA },
        .{ .Name = "RTI", .Cycles = 6, .AddrMode = &IMP, .Operator = &RTI }, .{ .Name = "EOR", .Cycles = 6, .AddrMode = &IZX, .Operator = &EOR }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "SRE", .Cycles = 8, .AddrMode = &IZX, .Operator = &SRE }, .{ .Name = "NOP", .Cycles = 3, .AddrMode = &ZP0, .Operator = &NOP }, .{ .Name = "EOR", .Cycles = 3, .AddrMode = &ZP0, .Operator = &EOR }, .{ .Name = "LSR", .Cycles = 5, .AddrMode = &ZP0, .Operator = &LSR }, .{ .Name = "SRE", .Cycles = 5, .AddrMode = &ZP0, .Operator = &SRE }, .{ .Name = "PHA", .Cycles = 3, .AddrMode = &IMP, .Operator = &PHA }, .{ .Name = "EOR", .Cycles = 2, .AddrMode = &IMM, .Operator = &EOR }, .{ .Name = "LSR", .Cycles = 2, .AddrMode = &IMP, .Operator = &LSR }, .{ .Name = "ALR", .Cycles = 2, .AddrMode = &IMM, .Operator = &ALR }, .{ .Name = "JMP", .Cycles = 3, .AddrMode = &ABS, .Operator = &JMP }, .{ .Name = "EOR", .Cycles = 4, .AddrMode = &ABS, .Operator = &EOR }, .{ .Name = "LSR", .Cycles = 6, .AddrMode = &ABS, .Operator = &LSR }, .{ .Name = "SRE", .Cycles = 6, .AddrMode = &ABS, .Operator = &SRE },
        .{ .Name = "BVC", .Cycles = 2, .AddrMode = &REL, .Operator = &BVC }, .{ .Name = "EOR", .Cycles = 5, .AddrMode = &IZY, .Operator = &EOR }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "SRE", .Cycles = 8, .AddrMode = &IZY, .Operator = &SRE }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &ZPX, .Operator = &NOP }, .{ .Name = "EOR", .Cycles = 4, .AddrMode = &ZPX, .Operator = &EOR }, .{ .Name = "LSR", .Cycles = 6, .AddrMode = &ZPX, .Operator = &LSR }, .{ .Name = "SRE", .Cycles = 6, .AddrMode = &ZPX, .Operator = &SRE }, .{ .Name = "CLI", .Cycles = 2, .AddrMode = &IMP, .Operator = &CLI }, .{ .Name = "EOR", .Cycles = 4, .AddrMode = &ABY, .Operator = &EOR }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMP, .Operator = &NOP }, .{ .Name = "SRE", .Cycles = 7, .AddrMode = &ABY, .Operator = &SRE }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &IMP, .Operator = &ABX }, .{ .Name = "EOR", .Cycles = 4, .AddrMode = &ABX, .Operator = &EOR }, .{ .Name = "LSR", .Cycles = 7, .AddrMode = &ABX, .Operator = &LSR }, .{ .Name = "SRE", .Cycles = 7, .AddrMode = &ABX, .Operator = &SRE },
        .{ .Name = "RTS", .Cycles = 6, .AddrMode = &IMP, .Operator = &RTS }, .{ .Name = "ADC", .Cycles = 6, .AddrMode = &IZX, .Operator = &ADC }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "RRA", .Cycles = 8, .AddrMode = &IZX, .Operator = &RRA }, .{ .Name = "NOP", .Cycles = 3, .AddrMode = &ZP0, .Operator = &NOP }, .{ .Name = "ADC", .Cycles = 3, .AddrMode = &ZP0, .Operator = &ADC }, .{ .Name = "ROR", .Cycles = 5, .AddrMode = &ZP0, .Operator = &ROR }, .{ .Name = "RRA", .Cycles = 5, .AddrMode = &ZP0, .Operator = &RRA }, .{ .Name = "PLA", .Cycles = 4, .AddrMode = &IMP, .Operator = &PLA }, .{ .Name = "ADC", .Cycles = 2, .AddrMode = &IMM, .Operator = &ADC }, .{ .Name = "ROR", .Cycles = 2, .AddrMode = &IMP, .Operator = &ROR }, .{ .Name = "ARR", .Cycles = 2, .AddrMode = &IMM, .Operator = &ARR }, .{ .Name = "JMP", .Cycles = 5, .AddrMode = &IND, .Operator = &JMP }, .{ .Name = "ADC", .Cycles = 4, .AddrMode = &ABS, .Operator = &ADC }, .{ .Name = "ROR", .Cycles = 6, .AddrMode = &ABS, .Operator = &ROR }, .{ .Name = "RRA", .Cycles = 6, .AddrMode = &ABS, .Operator = &RRA },
        .{ .Name = "BVS", .Cycles = 2, .AddrMode = &REL, .Operator = &BVS }, .{ .Name = "ADC", .Cycles = 5, .AddrMode = &IZY, .Operator = &ADC }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "RRA", .Cycles = 8, .AddrMode = &IZY, .Operator = &RRA }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &ZPX, .Operator = &NOP }, .{ .Name = "ADC", .Cycles = 4, .AddrMode = &ZPX, .Operator = &ADC }, .{ .Name = "ROR", .Cycles = 6, .AddrMode = &ZPX, .Operator = &ROR }, .{ .Name = "RRA", .Cycles = 6, .AddrMode = &ZPX, .Operator = &RRA }, .{ .Name = "SEI", .Cycles = 2, .AddrMode = &IMP, .Operator = &SEI }, .{ .Name = "ADC", .Cycles = 4, .AddrMode = &ABY, .Operator = &ADC }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMP, .Operator = &NOP }, .{ .Name = "RRA", .Cycles = 7, .AddrMode = &ABY, .Operator = &RRA }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &IMP, .Operator = &ABX }, .{ .Name = "ADC", .Cycles = 4, .AddrMode = &ABX, .Operator = &ADC }, .{ .Name = "ROR", .Cycles = 7, .AddrMode = &ABX, .Operator = &ROR }, .{ .Name = "RRA", .Cycles = 7, .AddrMode = &ABX, .Operator = &RRA },
        .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMM, .Operator = &NOP }, .{ .Name = "STA", .Cycles = 6, .AddrMode = &IZX, .Operator = &STA }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMM, .Operator = &NOP }, .{ .Name = "SAX", .Cycles = 6, .AddrMode = &IZX, .Operator = &SAX }, .{ .Name = "STY", .Cycles = 3, .AddrMode = &ZP0, .Operator = &STY }, .{ .Name = "STA", .Cycles = 3, .AddrMode = &ZP0, .Operator = &STA }, .{ .Name = "STX", .Cycles = 3, .AddrMode = &ZP0, .Operator = &STX }, .{ .Name = "SAX", .Cycles = 3, .AddrMode = &ZP0, .Operator = &SAX }, .{ .Name = "DEY", .Cycles = 2, .AddrMode = &IMP, .Operator = &DEY }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMM, .Operator = &NOP }, .{ .Name = "TXA", .Cycles = 2, .AddrMode = &IMP, .Operator = &TXA }, .{ .Name = "ANE", .Cycles = 2, .AddrMode = &IMM, .Operator = &ANE }, .{ .Name = "STY", .Cycles = 4, .AddrMode = &ABS, .Operator = &STY }, .{ .Name = "STA", .Cycles = 4, .AddrMode = &ABS, .Operator = &STA }, .{ .Name = "STX", .Cycles = 4, .AddrMode = &ABS, .Operator = &STX }, .{ .Name = "SAX", .Cycles = 4, .AddrMode = &ABS, .Operator = &SAX },
        .{ .Name = "BCC", .Cycles = 2, .AddrMode = &REL, .Operator = &BCC }, .{ .Name = "STA", .Cycles = 6, .AddrMode = &IZY, .Operator = &STA }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "SHA", .Cycles = 6, .AddrMode = &IZY, .Operator = &SHA }, .{ .Name = "STY", .Cycles = 4, .AddrMode = &ZPX, .Operator = &STY }, .{ .Name = "STA", .Cycles = 4, .AddrMode = &ZPX, .Operator = &STA }, .{ .Name = "STX", .Cycles = 4, .AddrMode = &ZPY, .Operator = &STX }, .{ .Name = "SAX", .Cycles = 4, .AddrMode = &ZPY, .Operator = &SAX }, .{ .Name = "TYA", .Cycles = 2, .AddrMode = &IMP, .Operator = &TYA }, .{ .Name = "STA", .Cycles = 5, .AddrMode = &ABY, .Operator = &STA }, .{ .Name = "TXS", .Cycles = 2, .AddrMode = &IMP, .Operator = &TXS }, .{ .Name = "TAS", .Cycles = 5, .AddrMode = &ABY, .Operator = &TAS }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &IMP, .Operator = &ABX }, .{ .Name = "STA", .Cycles = 5, .AddrMode = &ABX, .Operator = &STA }, .{ .Name = "SHX", .Cycles = 1, .AddrMode = &ABY, .Operator = &SHX }, .{ .Name = "SHA", .Cycles = 5, .AddrMode = &ABY, .Operator = &SHA },
        .{ .Name = "LDY", .Cycles = 2, .AddrMode = &IMM, .Operator = &LDY }, .{ .Name = "LDA", .Cycles = 6, .AddrMode = &IZX, .Operator = &LDA }, .{ .Name = "LDX", .Cycles = 2, .AddrMode = &IMM, .Operator = &LDX }, .{ .Name = "LAX", .Cycles = 6, .AddrMode = &IZX, .Operator = &LAX }, .{ .Name = "LDY", .Cycles = 3, .AddrMode = &ZP0, .Operator = &LDY }, .{ .Name = "LDA", .Cycles = 3, .AddrMode = &ZP0, .Operator = &LDA }, .{ .Name = "LDX", .Cycles = 3, .AddrMode = &ZP0, .Operator = &LDX }, .{ .Name = "LAX", .Cycles = 3, .AddrMode = &ZP0, .Operator = &LAX }, .{ .Name = "TAY", .Cycles = 2, .AddrMode = &IMP, .Operator = &TAY }, .{ .Name = "LDA", .Cycles = 2, .AddrMode = &IMM, .Operator = &LDA }, .{ .Name = "TAX", .Cycles = 2, .AddrMode = &IMP, .Operator = &TAX }, .{ .Name = "LXA", .Cycles = 2, .AddrMode = &IMM, .Operator = &LXA }, .{ .Name = "LDY", .Cycles = 4, .AddrMode = &ABS, .Operator = &LDY }, .{ .Name = "LDA", .Cycles = 4, .AddrMode = &ABS, .Operator = &LDA }, .{ .Name = "LDX", .Cycles = 4, .AddrMode = &ABS, .Operator = &LDX }, .{ .Name = "LAX", .Cycles = 4, .AddrMode = &ABS, .Operator = &LAX },
        .{ .Name = "BCS", .Cycles = 2, .AddrMode = &REL, .Operator = &BCS }, .{ .Name = "LDA", .Cycles = 5, .AddrMode = &IZY, .Operator = &LDA }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "LAX", .Cycles = 5, .AddrMode = &IZY, .Operator = &LAX }, .{ .Name = "LDY", .Cycles = 4, .AddrMode = &ZPX, .Operator = &LDY }, .{ .Name = "LDA", .Cycles = 4, .AddrMode = &ZPX, .Operator = &LDA }, .{ .Name = "LDX", .Cycles = 4, .AddrMode = &ZPY, .Operator = &LDX }, .{ .Name = "LAX", .Cycles = 4, .AddrMode = &ZPY, .Operator = &LAX }, .{ .Name = "CLV", .Cycles = 2, .AddrMode = &IMP, .Operator = &CLV }, .{ .Name = "LDA", .Cycles = 4, .AddrMode = &ABY, .Operator = &LDA }, .{ .Name = "TSX", .Cycles = 2, .AddrMode = &IMP, .Operator = &TSX }, .{ .Name = "LAS", .Cycles = 4, .AddrMode = &ABY, .Operator = &LAS }, .{ .Name = "LDY", .Cycles = 4, .AddrMode = &ABX, .Operator = &LDY }, .{ .Name = "LDA", .Cycles = 4, .AddrMode = &ABX, .Operator = &LDA }, .{ .Name = "LDX", .Cycles = 4, .AddrMode = &ABY, .Operator = &LDX }, .{ .Name = "LAX", .Cycles = 4, .AddrMode = &ABY, .Operator = &LAX },
        .{ .Name = "CPY", .Cycles = 2, .AddrMode = &IMM, .Operator = &CPY }, .{ .Name = "CMP", .Cycles = 6, .AddrMode = &IZX, .Operator = &CMP }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMM, .Operator = &NOP }, .{ .Name = "DCP", .Cycles = 8, .AddrMode = &IZX, .Operator = &DCP }, .{ .Name = "CPY", .Cycles = 3, .AddrMode = &ZP0, .Operator = &CPY }, .{ .Name = "CMP", .Cycles = 3, .AddrMode = &ZP0, .Operator = &CMP }, .{ .Name = "DEC", .Cycles = 5, .AddrMode = &ZP0, .Operator = &DEC }, .{ .Name = "DCP", .Cycles = 5, .AddrMode = &ZP0, .Operator = &DCP }, .{ .Name = "INY", .Cycles = 2, .AddrMode = &IMP, .Operator = &INY }, .{ .Name = "CMP", .Cycles = 2, .AddrMode = &IMM, .Operator = &CMP }, .{ .Name = "DEX", .Cycles = 2, .AddrMode = &IMP, .Operator = &DEX }, .{ .Name = "SBX", .Cycles = 2, .AddrMode = &IMM, .Operator = &SBX }, .{ .Name = "CPY", .Cycles = 4, .AddrMode = &ABS, .Operator = &CPY }, .{ .Name = "CMP", .Cycles = 4, .AddrMode = &ABS, .Operator = &CMP }, .{ .Name = "DEC", .Cycles = 6, .AddrMode = &ABS, .Operator = &DEC }, .{ .Name = "DCP", .Cycles = 6, .AddrMode = &ABS, .Operator = &DCP },
        .{ .Name = "BNE", .Cycles = 2, .AddrMode = &REL, .Operator = &BNE }, .{ .Name = "CMP", .Cycles = 5, .AddrMode = &IZY, .Operator = &CMP }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "DCP", .Cycles = 8, .AddrMode = &IZY, .Operator = &DCP }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &ZPX, .Operator = &NOP }, .{ .Name = "CMP", .Cycles = 4, .AddrMode = &ZPX, .Operator = &CMP }, .{ .Name = "DEC", .Cycles = 6, .AddrMode = &ZPX, .Operator = &DEC }, .{ .Name = "DCP", .Cycles = 6, .AddrMode = &ZPX, .Operator = &DCP }, .{ .Name = "CLD", .Cycles = 2, .AddrMode = &IMP, .Operator = &CLD }, .{ .Name = "CMP", .Cycles = 4, .AddrMode = &ABY, .Operator = &CMP }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMP, .Operator = &NOP }, .{ .Name = "DCP", .Cycles = 7, .AddrMode = &ABY, .Operator = &DCP }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &IMP, .Operator = &ABX }, .{ .Name = "CMP", .Cycles = 4, .AddrMode = &ABX, .Operator = &CMP }, .{ .Name = "DEC", .Cycles = 7, .AddrMode = &ABX, .Operator = &DEC }, .{ .Name = "DCP", .Cycles = 7, .AddrMode = &ABX, .Operator = &DCP },
        .{ .Name = "CPX", .Cycles = 2, .AddrMode = &IMM, .Operator = &CPX }, .{ .Name = "SBC", .Cycles = 6, .AddrMode = &IZX, .Operator = &SBC }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMM, .Operator = &NOP }, .{ .Name = "ISC", .Cycles = 8, .AddrMode = &IZX, .Operator = &ISC }, .{ .Name = "CPX", .Cycles = 3, .AddrMode = &ZP0, .Operator = &CPX }, .{ .Name = "SBC", .Cycles = 3, .AddrMode = &ZP0, .Operator = &SBC }, .{ .Name = "INC", .Cycles = 5, .AddrMode = &ZP0, .Operator = &INC }, .{ .Name = "ISC", .Cycles = 5, .AddrMode = &ZP0, .Operator = &ISC }, .{ .Name = "INX", .Cycles = 2, .AddrMode = &IMP, .Operator = &INX }, .{ .Name = "SBC", .Cycles = 2, .AddrMode = &IMM, .Operator = &SBC }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMP, .Operator = &NOP }, .{ .Name = "USB", .Cycles = 2, .AddrMode = &IMM, .Operator = &USB }, .{ .Name = "CPX", .Cycles = 4, .AddrMode = &ABS, .Operator = &CPX }, .{ .Name = "SBC", .Cycles = 4, .AddrMode = &ABS, .Operator = &SBC }, .{ .Name = "INC", .Cycles = 6, .AddrMode = &ABS, .Operator = &INC }, .{ .Name = "ISC", .Cycles = 6, .AddrMode = &ABS, .Operator = &ISC },
        .{ .Name = "BEQ", .Cycles = 2, .AddrMode = &REL, .Operator = &BEQ }, .{ .Name = "SBC", .Cycles = 5, .AddrMode = &IZY, .Operator = &SBC }, .{ .Name = "JAM", .Cycles = 1, .AddrMode = &IMP, .Operator = &JAM }, .{ .Name = "ISC", .Cycles = 8, .AddrMode = &IZY, .Operator = &ISC }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &ZPX, .Operator = &NOP }, .{ .Name = "SBC", .Cycles = 4, .AddrMode = &ZPX, .Operator = &SBC }, .{ .Name = "INC", .Cycles = 6, .AddrMode = &ZPX, .Operator = &INC }, .{ .Name = "ISC", .Cycles = 6, .AddrMode = &ZPX, .Operator = &ISC }, .{ .Name = "SED", .Cycles = 2, .AddrMode = &IMP, .Operator = &SED }, .{ .Name = "SBC", .Cycles = 4, .AddrMode = &ABY, .Operator = &SBC }, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMP, .Operator = &NOP }, .{ .Name = "ISC", .Cycles = 7, .AddrMode = &ABY, .Operator = &ISC }, .{ .Name = "NOP", .Cycles = 4, .AddrMode = &IMP, .Operator = &ABX }, .{ .Name = "SBC", .Cycles = 4, .AddrMode = &ABX, .Operator = &SBC }, .{ .Name = "INC", .Cycles = 7, .AddrMode = &ABX, .Operator = &INC }, .{ .Name = "ISC", .Cycles = 7, .AddrMode = &ABX, .Operator = &ISC },
    };

pub const Instruction = struct {
    Name: []const u8 = "XXX",
    Operator: *const fn () u8 = &XXX,
    AddrMode: *const fn () u8 = &IMP,
    Cycles: u8 = 1,
};

//      ‐0          ‐1            ‐2      ‐3            ‐4           ‐5            ‐6            ‐7            ‐8              ‐9             ‐A           ‐B             ‐C            ‐D             ‐E             ‐F
// 0‐   BRK impl    ORA X,ind     JAM     SLO X,ind     NOP zpg      ORA zpg       ASL zpg       SLO zpg       PHP impl        ORA #          ASL A        ANC #          NOP abs       ORA abs        ASL abs        SLO abs
// 1‐   BPL rel     ORA ind,Y     JAM     SLO ind,Y     NOP zpg,X    ORA zpg,X     ASL zpg,X     SLO zpg,X     CLC impl        ORA abs,Y      NOP impl     SLO abs,Y      NOP abs,X     ORA abs,X      ASL abs,X      SLO abs,X
// 2‐   JSR abs     AND X,ind     JAM     RLA X,ind     BIT zpg      AND zpg       ROL zpg       RLA zpg       PLP impl        AND #          ROL A        ANC #          BIT abs       AND abs        ROL abs        RLA abs
// 3‐   BMI rel     AND ind,Y     JAM     RLA ind,Y     NOP zpg,X    AND zpg,X     ROL zpg,X     RLA zpg,X     SEC impl        AND abs,Y      NOP impl     RLA abs,Y      NOP abs,X     AND abs,X      ROL abs,X      RLA abs,X
// 4‐   RTI impl    EOR X,ind     JAM     SRE X,ind     NOP zpg      EOR zpg       LSR zpg       SRE zpg       PHA impl        EOR #          LSR A        ALR #          JMP abs       EOR abs        LSR abs        SRE abs
// 5‐   BVC rel     EOR ind,Y     JAM     SRE ind,Y     NOP zpg,X    EOR zpg,X     LSR zpg,X     SRE zpg,X     CLI impl        EOR abs,Y      NOP impl     SRE abs,Y      NOP abs,X     EOR abs,X      LSR abs,X      SRE abs,X
// 6‐   RTS impl    ADC X,ind     JAM     RRA X,ind     NOP zpg      ADC zpg       ROR zpg       RRA zpg       PLA impl        ADC #          ROR A        ARR #          JMP ind       ADC abs        ROR abs        RRA abs
// 7‐   BVS rel     ADC ind,Y     JAM     RRA ind,Y     NOP zpg,X    ADC zpg,X     ROR zpg,X     RRA zpg,X     SEI impl        ADC abs,Y      NOP impl     RRA abs,Y      NOP abs,X     ADC abs,X      ROR abs,X      RRA abs,X
// 8‐   NOP #       STA X,ind     NOP #   SAX X,ind     STY zpg      STA zpg       STX zpg       SAX zpg       DEY impl        NOP #          TXA impl     ANE #          STY abs       STA abs        STX abs        SAX abs
// 9‐   BCC rel     STA ind,Y     JAM     SHA ind,Y     STY zpg,X    STA zpg,X     STX zpg,Y     SAX zpg,Y     TYA impl        STA abs,Y      TXS impl     TAS abs,Y      SHY abs,X     STA abs,X      SHX abs,Y      SHA abs,Y
// A‐   LDY #       LDA X,ind     LDX #   LAX X,ind     LDY zpg      LDA zpg       LDX zpg       LAX zpg       TAY impl        LDA #          TAX impl     LXA #          LDY abs       LDA abs        LDX abs        LAX abs
// B‐   BCS rel     LDA ind,Y     JAM     LAX ind,Y     LDY zpg,X    LDA zpg,X     LDX zpg,Y     LAX zpg,Y     CLV impl        LDA abs,Y      TSX impl     LAS abs,Y      LDY abs,X     LDA abs,X      LDX abs,Y      LAX abs,Y
// C‐   CPY #       CMP X,ind     NOP #   DCP X,ind     CPY zpg      CMP zpg       DEC zpg       DCP zpg       INY impl        CMP #          DEX impl     SBX #          CPY abs       CMP abs        DEC abs        DCP abs
// D‐   BNE rel     CMP ind,Y     JAM     DCP ind,Y     NOP zpg,X    CMP zpg,X     DEC zpg,X     DCP zpg,X     CLD impl        CMP abs,Y      NOP impl     DCP abs,Y      NOP abs,X     CMP abs,X      DEC abs,X      DCP abs,X
// E‐   CPX #       SBC X,ind     NOP #   ISC X,ind     CPX zpg      SBC zpg       INC zpg       ISC zpg       INX impl        SBC #          NOP impl     USBC #         CPX abs       SBC abs        INC abs        ISC abs
// F‐   BEQ rel     SBC ind,Y     JAM     ISC ind,Y     NOP zpg,X    SBC zpg,X     INC zpg,X     ISC zpg,X     SED impl        SBC abs,Y      NOP impl     ISC abs,Y      NOP abs,X     SBC abs,X      INC abs,X      ISC abs,X
