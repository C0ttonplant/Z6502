const std = @import("std");

const cpu_6502 = @This();
const bus = @import("bus.zig");
pub var clockCount: u128 = 0;

// internal variables
pub var accumulator: u8 = 0;
pub var xReg: u8 = 0;
pub var yReg: u8 = 0;
pub var stackPtr: u8 = 0;
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
pub fn clock() void
{
    if(cycles != 0 )
    {
        clockCount += 1;
        cycles -= 1;
        return;
    }

    opCode = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    var instr: *Instruction = &LOOKUP[(opCode & 0xf0) >> 4][opCode & 0x0f];

    cycles = instr.Cycles;

    var additionalCycle1: u8 = instr.AddrMode();
    var additionalCycle2: u8 = instr.Operator();

    cycles += (additionalCycle1 & additionalCycle2);

    clockCount += 1;
    
    //std.debug.print("{s}, op {x}, pc {x}, a {x}, x {x}, y {x}, cycles {d}\n", .{cpu_6502.LOOKUP[(cpu_6502.opCode & 0xf0) >> 4][cpu_6502.opCode & 0x0f].Name, cpu_6502.opCode, cpu_6502.ProgramCounter, cpu_6502.accumulator, cpu_6502.xReg, cpu_6502.yReg, cpu_6502.clockCount});
    //std.time.sleep(1_000_000_000);
    
    cycles -= 1;
}
/// reset cpu (does not clear memory)
pub fn reset() void
{
    accumulator = 0;
    xReg = 0;
    yReg = 0;
    stackPtr = 0xFD;
    statusReg = .{};

    addressAbs = 0xFFFC;

    var lo: u16 = @as(u16, @intCast(read(addressAbs + 0))) << 0;
    var hi: u16 = @as(u16, @intCast(read(addressAbs + 1))) << 8;

    ProgramCounter = hi | lo;

    addressAbs = 0;
    addressRel = 0;
    fetched = 0;

    cycles = 8;
}
/// interupt request
pub fn irq() void
{
    if(statusReg.I) return;
    
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
    var lo: u16 = read(addressAbs);
    var hi: u16 = read(addressAbs + 1) << 8;
    ProgramCounter = hi | lo;

    cycles = 7;
}
/// non mutable interupt request
pub fn nmi() void
{
    write(0x0100 + stackPtr, @truncate(ProgramCounter >> 8));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    write(0x0100 + stackPtr, @truncate(ProgramCounter));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    statusReg.B = false;
    statusReg.U = true;
    statusReg.I = true;

    write(0x0100 + stackPtr, @bitCast(statusReg));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    addressAbs = 0xFFFA;
    var lo: u16 = read(addressAbs);
    var hi: u16 = read(addressAbs + 1) << 8;
    ProgramCounter = hi | lo;

    cycles = 8;
}
/// read from bus
pub fn read(addr: u16) u8
{
    return bus.read(addr, false);
}
/// write to bus
pub fn write(addr: u16, dat: u8) void
{
    bus.write(addr, dat);
}
/// helper function to convert to bcd
fn toBCD(val: u8) u8
{
    var top: u4 = @truncate(val >> 4);
    var bot: u4 = @truncate(val);

    if(bot > 9) 
    {
        // 8 E - 9
        //13 5
        var tmp: u4 = bot - 9;
        top += bot - tmp;
        bot = tmp;
    }
}


// addresing modes

/// implied mode
pub fn IMP() u8
{

    fetched = accumulator;
    return 0;
}
/// immediate mode
pub fn IMM() u8
{
    addressAbs = ProgramCounter;
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    return 0;
}
/// zero page
pub fn ZP0() u8
{
    addressAbs = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];
    addressAbs &= 0x00ff;
    return 0;
}
/// zero page x
pub fn ZPX() u8
{
    addressAbs = @addWithOverflow(read(ProgramCounter), xReg)[0];
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];
    addressAbs &= 0x00ff;
    return 0;
}
/// zero page y
pub fn ZPY() u8
{
    addressAbs = @addWithOverflow(read(ProgramCounter), yReg)[0];
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];
    addressAbs &= 0x00ff;
    return 0;
}
/// absolute
pub fn ABS() u8
{
    var lo: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    var hi: u16 = @as(u16, @intCast(read(ProgramCounter))) << 8;
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    addressAbs = hi | lo;

    return 0;
}
/// absolute x
pub fn ABX() u8
{
    var lo: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    var hi: u16 = @as(u16, @intCast(read(ProgramCounter))) << 8;
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    addressAbs = hi | lo;
    addressAbs = @addWithOverflow(addressAbs, xReg)[0];

    // returns extra cycle if the reg goes over the page
    if(addressAbs & 0xff00 != hi) return 1;

    return 0;
}
/// absolute y
pub fn ABY() u8
{
    var lo: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    var hi: u16 = @as(u16, @intCast(read(ProgramCounter))) << 8;
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    addressAbs = hi | lo;
    addressAbs = @addWithOverflow(addressAbs, yReg)[0];

    // returns extra cycle if the reg goes over the page
    if(addressAbs & 0xff00 != hi) return 1;

    return 0;
}
/// indirect
pub fn IND() u8
{
    var lo: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    var hi: u16 = @as(u16, read(ProgramCounter)) << 8;
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    var ptr: u16 = hi | lo;

    // simulate 6502 hardware bug
    if(lo == 0x00ff)
    {
        addressAbs = (@as(u16, @intCast(read(ptr & 0xff00))) << 8) | read(ptr);
        return 0;
    }

    addressAbs = (@as(u16, @intCast(read(@addWithOverflow(ptr, 1)[0]))) << 8) | read(ptr);

    return 0;
}
/// indirect x
pub fn IZX() u8
{
    var t: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    var lo: u16 = read(@addWithOverflow(t, @as(u16, @intCast(xReg)))[0]) & 0x00ff;
    var hi: u16 = read(@addWithOverflow(@addWithOverflow(t, @as(u16, @intCast(xReg)))[0], 1)[0]) & 0x00ff;   
    
    addressAbs = @as(u16, hi << 8) | lo;
    return 0;
}
/// indirect y
pub fn IZY() u8
{
    var t: u16 = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    var lo: u16 = read(t & 0x00ff);
    var hi: u16 = read(@addWithOverflow(t, 1)[0] & 0x00ff);   
    
    addressAbs = @as(u16, hi << 8) | lo;

    addressAbs = @addWithOverflow(addressAbs, yReg)[0];

    if(addressAbs & 0xff00 != hi << 8) return 1;

    return 0;
}
/// relative
pub fn REL() u8
{
    addressRel = read(ProgramCounter);
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    if(addressRel & 0x80 != 0)
    {
        addressRel |= 0xff00; 
    }
    else 
    {
        addressRel &= 0x00ff;
    }
    return 0;
}
//
// opCodes
//
pub fn fetch() u8
{
    if(LOOKUP[(opCode & 0xf0) >> 4][opCode & 0x0f].AddrMode != &IMP) fetched = read(addressAbs);

    return fetched;
}
/// logical and accumulator
pub fn AND() u8 
{
    _ = fetch();
    accumulator &= fetched;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 == 0x80;
    return 1;
}
/// add carry
pub fn ADC() u8 
{
    _ = fetch();

    var result: u16 = @as(u16, @intCast(accumulator)) + @as(u16, @intCast(fetched)) + @as(u16, @intFromBool(statusReg.C));

    statusReg.C = result > 0xff;
    statusReg.Z = result & 0x00ff == 0;
    statusReg.N = result & 0x0080 == 0x80;
    statusReg.V = ((~(accumulator ^ fetched) & (accumulator ^ result)) & 0x80) != 0;

    accumulator = @truncate(result);

    return 1;
}
/// logical shift left (carry <- data <- void)
pub fn ASL() u8 
{
    _ = fetch();
    var tmp: u16 = fetched << 1;
    statusReg.C = tmp & 0xff00 != 0;
    statusReg.Z = tmp & 0x00ff == 0;
    statusReg.Z = tmp & 0x0080 == 0x80;

    if(LOOKUP[(opCode & 0xf0) >> 4][opCode & 0x0f].AddrMode == &IMP)
    {
        accumulator = @truncate(tmp);
        return 0;
    }
    write(addressAbs, @truncate(tmp));
    return 0;
}
/// branch if carry clear
pub fn BCC() u8 
{
    if(statusReg.C) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if(addressAbs & 0xff00 != ProgramCounter & 0xff00)
    {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
// branch if carry set
pub fn BCS() u8 
{
    if(!statusReg.C) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if(addressAbs & 0xff00 != ProgramCounter & 0xff00)
    {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// branch if equal
pub fn BEQ() u8 
{
    if(!statusReg.Z) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if(addressAbs & 0xff00 != ProgramCounter & 0xff00)
    {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// test bits
pub fn BIT() u8 
{
    _ = fetch();
    var result: u8 = accumulator & fetched;
    statusReg.Z = result == 0;
    statusReg.N = result & 0x80 == 0x80;
    // TODO: figure out wth is going on here
    statusReg.V = result & 0x40 == 0x40;
    return 0;
}
/// branch if minus
pub fn BMI() u8 
{
    if(!statusReg.N) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if(addressAbs & 0xff00 != ProgramCounter & 0xff00)
    {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// branch if not equal
pub fn BNE() u8 
{
    if(statusReg.Z) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if(addressAbs & 0xff00 != ProgramCounter & 0xff00)
    {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// branch if plus
pub fn BPL() u8 
{
    if(statusReg.N) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if(addressAbs & 0xff00 != ProgramCounter & 0xff00)
    {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// break
pub fn BRK() u8 
{
    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0];

    statusReg.I = true;

    write(0x0100 + @as(u16, @intCast(stackPtr)), @truncate(ProgramCounter >> 8));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];
    write(0x0100 + @as(u16, @intCast(stackPtr)), @truncate(ProgramCounter));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    statusReg.B = true;

    write(0x0100 + @as(u16, @intCast(stackPtr)), @bitCast(statusReg));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    statusReg.B = false;

    ProgramCounter = (@as(u16, @intCast(read(0xFFFF))) << 8) | read(0xFFFE);

    return 0;
}
/// branch if overflow clear
pub fn BVC() u8 
{
    if(!statusReg.V) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if(addressAbs & 0xff00 != ProgramCounter & 0xff00)
    {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// branch if overflow set
pub fn BVS() u8 
{
    if(statusReg.V) return 0;

    // branch instructions directly add clock cycles
    cycles += 1;

    addressAbs = @addWithOverflow(ProgramCounter, addressRel)[0];

    if(addressAbs & 0xff00 != ProgramCounter & 0xff00)
    {
        cycles += 1;
    }

    ProgramCounter = addressAbs;

    return 0;
}
/// clear carry
pub fn CLC() u8 
{
    statusReg.C = false;
    return 0;
}
/// clear 'decimal mode' flag
pub fn CLD() u8 
{
    statusReg.D = false;
    return 0;
}
/// clear 'no interupt' flag
pub fn CLI() u8 
{
    statusReg.I = false;
    return 0;
}
/// clear overflow flag
pub fn CLV() u8 
{
    statusReg.V = false;
    return 0;
}
/// compare accumulator
pub fn CMP() u8 
{
    _ = fetch();
    var result: u16 = @subWithOverflow(@as(u16, @intCast(accumulator)), @as(u16, @intCast(fetched)))[0];

    statusReg.C = accumulator >= fetched;
    statusReg.Z = result & 0x00ff == 0;
    statusReg.N = result & 0x0080 == 0x0080;
    return 1;
}
/// compare xReg
pub fn CPX() u8 
{
    _ = fetch();
    var result: u16 = @subWithOverflow(@as(u16, @intCast(xReg)), @as(u16, @intCast(fetched)))[0];

    statusReg.C = xReg >= fetched;
    statusReg.Z = result & 0x00ff == 0;
    statusReg.N = result & 0x0080 == 0x0080;
    return 0;
}
/// compare yReg
pub fn CPY() u8 
{
    _ = fetch();
    var result: u16 = @subWithOverflow(@as(u16, @intCast(yReg)), @as(u16, @intCast(fetched)))[0];

    statusReg.C = yReg >= fetched;
    statusReg.Z = result & 0x00ff == 0;
    statusReg.N = result & 0x0080 == 0x0080;
    return 0;
}
/// decrement memory
pub fn DEC() u8 
{
    _ = fetch();
    var result: u8 = @subWithOverflow(fetched, 1)[0];
    write(addressAbs, result);


    statusReg.Z = result & 0x00ff == 0;
    statusReg.N = result & 0x0080 == 0x0080;
    return 0;
}
/// decrement xReg
pub fn DEX() u8 
{
    xReg = @subWithOverflow(xReg, 1)[0];

    statusReg.Z = xReg & 0xff == 0;
    statusReg.N = xReg & 0x80 == 0x80;
    return 0;
}
/// decrement yReg
pub fn DEY() u8 
{
    yReg = @subWithOverflow(yReg, 1)[0];

    statusReg.Z = yReg & 0xff == 0;
    statusReg.N = yReg & 0x80 == 0x80;
    return 0;
}
/// bitwise xor
pub fn EOR() u8 
{
    _ = fetch();
    accumulator ^= fetched;

    statusReg.Z = accumulator & 0xff == 0;
    statusReg.N = accumulator & 0x80 == 0x80;
    return 1;
}
/// increment memory
pub fn INC() u8 
{
    _ = fetch();
    var result: u8 = @addWithOverflow(fetched, 1)[0];

    write(addressAbs, result);

    statusReg.Z = result & 0xff == 0;
    statusReg.N = result & 0x80 == 0x80;
    return 0;
}
/// increment xReg
pub fn INX() u8 
{
    xReg = @addWithOverflow(xReg, 1)[0];

    statusReg.Z = xReg & 0xff == 0;
    statusReg.N = xReg & 0x80 == 0x80;
    return 0;
}
/// increment yReg
pub fn INY() u8 
{
    yReg = @addWithOverflow(yReg, 1)[0];

    statusReg.Z = yReg & 0xff == 0;
    statusReg.N = yReg & 0x80 == 0x80;
    return 0;
}
/// jump
pub fn JMP() u8 
{
    ProgramCounter = addressAbs;
    return 0;
}
/// jump to subroutine
pub fn JSR() u8 
{
    ProgramCounter = @subWithOverflow(ProgramCounter, 1)[0];

    write(0x0100 + @as(u16, @intCast(stackPtr)), @truncate(ProgramCounter >> 8));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];
    write(0x0100 + @as(u16, @intCast(stackPtr)), @truncate(ProgramCounter));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    ProgramCounter = addressAbs;
    return 0;
}
/// load accumulator
pub fn LDA() u8 
{
    _ = fetch();

    accumulator = fetched;

    statusReg.Z = accumulator & 0xff == 0;
    statusReg.N = accumulator & 0x80 == 0x80;
    return 1;
}
/// load xReg
pub fn LDX() u8 
{
    _ = fetch();

    xReg = fetched;

    statusReg.Z = xReg & 0xff == 0;
    statusReg.N = xReg & 0x80 == 0x80;
    return 1;
}
/// load yReg
pub fn LDY() u8 
{
    _ = fetch();

    yReg = fetched;

    statusReg.Z = yReg & 0xff == 0;
    statusReg.N = yReg & 0x80 == 0x80;
    return 1;
}
/// logical shift right (void -> data -> carry)
pub fn LSR() u8 
{
    _ = fetch();
    statusReg.C = fetched & 1 == 1;

    var tmp: u8 = fetched >> 1;
    statusReg.Z = tmp == 0;
    statusReg.N = tmp & 0x80 == 0x80;

    if(LOOKUP[(opCode & 0xf0) >> 4][opCode & 0x0f].AddrMode == &IMP)
    {
        accumulator = tmp;
        return 0;
    }
    write(addressAbs, tmp);
    return 0;
}
/// no operation (does nothing)
pub fn NOP() u8 
{
    switch (opCode) 
    {
        0x1C,0x3C,0x5C,0x7C,0xDC,0xFC => return 1,
        else => return 0,
    }
}
/// bitwise or accumulator
pub fn ORA() u8 
{
    _ = fetch();

    accumulator |= fetched;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator == 0x80;
    return 0;
}
/// push accumulator to stack
pub fn PHA() u8 
{
    write(0x0100 + @as(u16, @intCast(stackPtr)), accumulator);
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    return 0;
}
/// push prossesor status to stack
pub fn PHP() u8 
{
    statusReg.B = true;
    statusReg.U = true;
    write(0x0100 + @as(u16, @intCast(stackPtr)), @bitCast(statusReg));
    stackPtr = @subWithOverflow(stackPtr, 1)[0];

    statusReg.B = false;
    statusReg.U = false;
    return 0;
}
/// pop accumulator from stack
pub fn PLA() u8 
{
    stackPtr = @addWithOverflow(stackPtr, 1)[0];

    accumulator = read(0x0100 + @as(u16, @intCast(stackPtr)));
    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 == 0x80;

    return 0;
}
/// pop processor status from stack
pub fn PLP() u8 
{
    stackPtr = @addWithOverflow(stackPtr, 1)[0];

    statusReg = @bitCast(read(0x0100 + @as(u16, @intCast(stackPtr))));
    statusReg.U = true;

    return 0;
}
/// rotate bits left (carry <- data <- carry)
pub fn ROL() u8 
{
    _ = fetch();

    var tmp: u16 = fetched << 1 | @as(u16, @intFromBool(statusReg.C));

    statusReg.C = tmp & 0xff00 != 0;
    statusReg.Z = tmp & 0x00ff == 0;
    statusReg.N = tmp & 0x80 == 0x80;

    if(LOOKUP[(opCode & 0xf0) >> 4][opCode & 0x0f].AddrMode == &IMP)
    {
        accumulator = @truncate(tmp);
        return 0;
    }
    write(addressAbs, @truncate(tmp));
    return 0;
}
/// rotate bits right (carry -> data -> carry)
pub fn ROR() u8 
{
    _ = fetch();

    var tmp: u16 = (@as(u16, @intFromBool(statusReg.C)) << 7) | (fetched >> 1);

    statusReg.C = fetched & 1 == 1;
    statusReg.Z = tmp & 0x00ff == 0;
    statusReg.N = tmp & 0x80 == 0x80;

    if(LOOKUP[(opCode & 0xf0) >> 4][opCode & 0x0f].AddrMode == &IMP)
    {
        accumulator = @truncate(tmp);
        return 0;
    }
    write(addressAbs, @truncate(tmp));
    return 0;
}
/// return from interupt
pub fn RTI() u8 
{
    stackPtr = @addWithOverflow(stackPtr, 1)[0];
    statusReg = @bitCast(read(0x0100 + @as(u16, @intCast(stackPtr))));
    statusReg.B = false;
    statusReg.U = false;

    stackPtr = @addWithOverflow(stackPtr, 1)[0]; 
    ProgramCounter = read(0x0100 + @as(u16, @intCast(stackPtr)));

    stackPtr = @addWithOverflow(stackPtr, 1)[0]; 
    ProgramCounter |= @as(u16, @intCast(read(0x0100 + @as(u16, @intCast(stackPtr))))) << 8;

    return 0;
}
/// return from subroutine
pub fn RTS() u8 
{
    stackPtr = @addWithOverflow(stackPtr, 1)[0]; 
    ProgramCounter = read(0x0100 + @as(u16, @intCast(stackPtr)));

    stackPtr = @addWithOverflow(stackPtr, 1)[0]; 
    ProgramCounter |= @as(u16, @intCast(read(0x0100 + @as(u16, @intCast(stackPtr))))) << 8;

    ProgramCounter = @addWithOverflow(ProgramCounter, 1)[0]; 
    return 0;
}
/// carry subtract
pub fn SBC() u8 
{
    _ = fetch();

    var result1 = @addWithOverflow(accumulator, @addWithOverflow(~(fetched), 1)[0]);
    var result2 = @addWithOverflow(result1[0], @as(u8, @intFromBool(statusReg.C)));

    var result = result2[0];
    statusReg.C = result1[1] & result2[1] == 1;
    statusReg.Z = result == 0;
    statusReg.N = result & 0x80 == 0x80;
    statusReg.V = (~(accumulator ^ fetched) & (accumulator ^ result) & 0x80) != 0;

    accumulator = result;

    return 1;
}
/// set carry flag
pub fn SEC() u8 
{
    statusReg.C = true;
    return 0;
}
/// set 'decimal mode' flag
pub fn SED() u8 
{
    statusReg.D = true;
    return 0;
}
/// set 'no interrupt' flag
pub fn SEI() u8 
{
    statusReg.I = true;
    return 0;
}
/// store accumulator
pub fn STA() u8 
{
    write(addressAbs, accumulator);
    return 0;
}
/// store xReg
pub fn STX() u8 
{
    write(addressAbs, xReg);
    return 0;
}
/// store yReg
pub fn STY() u8 
{
    write(addressAbs, yReg);
    return 0;
}
/// transfer accumulator to xReg
pub fn TAX() u8 
{
    xReg = accumulator;

    statusReg.Z = xReg == 0;
    statusReg.N = xReg & 0x80 == 0x80;
    return 0;
}
/// transfer accumulator to yReg
pub fn TAY() u8 
{
    yReg = accumulator;

    statusReg.Z = yReg == 0;
    statusReg.N = yReg & 0x80 == 0x80;
    return 0;
}
/// transfer stackPtr to xReg
pub fn TSX() u8 
{
    xReg = stackPtr;

    statusReg.Z = xReg == 0;
    statusReg.N = xReg & 0x80 == 0x80;
    return 0;
}
/// transfer xReg to accumulator
pub fn TXA() u8 
{
    accumulator = xReg;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 == 0x80;
    return 0;
}
/// transfer xReg to stackPtr
pub fn TXS() u8 
{
    stackPtr = xReg;
    return 0;
}
/// transfer yReg to accumulator
pub fn TYA() u8 
{
    accumulator = yReg;

    statusReg.Z = accumulator == 0;
    statusReg.N = accumulator & 0x80 == 0x80;
    return 0;
}
/// non implemented illegal opcode
pub fn XXX() u8
{
    return 0;
}



const StatusRegister = packed struct 
{
    /// carry
    C: bool = false, 
    /// zero
    Z: bool = false, 
    /// disable interupts
    I: bool = false, 
    /// decimal mode
    /// TODO: implement
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


pub var LOOKUP: [0x10][0x10]Instruction = 
.{//    00                                                                  01                                                                  02                                                                  03   04                                                                  05                                                                  06                                                                  07   08                                                                  09                                                                  0A                                                                  0B   0C                                                                  0D                                                                  0E                                                                  0F
    .{ .{ .Name = "BRK", .Cycles = 7, .AddrMode = &IMP, .Operator = &BRK}, .{ .Name = "ORA", .Cycles = 6, .AddrMode = &IZX, .Operator = &ORA}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "ORA", .Cycles = 3, .AddrMode = &ZP0, .Operator = &ORA}, .{ .Name = "ASL", .Cycles = 5, .AddrMode = &ZP0, .Operator = &ASL}, .{}, .{ .Name = "PHP", .Cycles = 3, .AddrMode = &IMP, .Operator = &PHP}, .{ .Name = "ORA", .Cycles = 2, .AddrMode = &IMM, .Operator = &ORA}, .{ .Name = "ASL", .Cycles = 2, .AddrMode = &IMP, .Operator = &ASL}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "ORA", .Cycles = 4, .AddrMode = &ABS, .Operator = &ORA}, .{ .Name = "ASL", .Cycles = 6, .AddrMode = &ABS, .Operator = &ASL}, .{} },
    .{ .{ .Name = "BPL", .Cycles = 2, .AddrMode = &REL, .Operator = &BPL}, .{ .Name = "ORA", .Cycles = 5, .AddrMode = &IZY, .Operator = &ORA}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "ORA", .Cycles = 4, .AddrMode = &ZPX, .Operator = &ORA}, .{ .Name = "ASL", .Cycles = 6, .AddrMode = &ZPX, .Operator = &ASL}, .{}, .{ .Name = "CLC", .Cycles = 2, .AddrMode = &IMP, .Operator = &CLC}, .{ .Name = "ORA", .Cycles = 4, .AddrMode = &ABY, .Operator = &ORA}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "ORA", .Cycles = 4, .AddrMode = &ABX, .Operator = &ORA}, .{ .Name = "ASL", .Cycles = 7, .AddrMode = &ABX, .Operator = &ASL}, .{} },
    .{ .{ .Name = "JSR", .Cycles = 6, .AddrMode = &ABS, .Operator = &JSR}, .{ .Name = "AND", .Cycles = 6, .AddrMode = &IZX, .Operator = &AND}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "BIT", .Cycles = 3, .AddrMode = &ZP0, .Operator = &BIT}, .{ .Name = "AND", .Cycles = 3, .AddrMode = &ZP0, .Operator = &AND}, .{ .Name = "ROL", .Cycles = 5, .AddrMode = &ZP0, .Operator = &ROL}, .{}, .{ .Name = "PLP", .Cycles = 4, .AddrMode = &IMP, .Operator = &PLP}, .{ .Name = "AND", .Cycles = 2, .AddrMode = &IMM, .Operator = &AND}, .{ .Name = "ROL", .Cycles = 2, .AddrMode = &IMP, .Operator = &ROL}, .{}, .{ .Name = "BIT", .Cycles = 4, .AddrMode = &ABS, .Operator = &BIT}, .{ .Name = "AND", .Cycles = 4, .AddrMode = &ABS, .Operator = &AND}, .{ .Name = "ROL", .Cycles = 6, .AddrMode = &ABS, .Operator = &ROL}, .{} },
    .{ .{ .Name = "BMI", .Cycles = 2, .AddrMode = &REL, .Operator = &BMI}, .{ .Name = "AND", .Cycles = 5, .AddrMode = &IZY, .Operator = &AND}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "AND", .Cycles = 4, .AddrMode = &ZPX, .Operator = &AND}, .{ .Name = "ROL", .Cycles = 6, .AddrMode = &ZPX, .Operator = &ROL}, .{}, .{ .Name = "SEC", .Cycles = 2, .AddrMode = &IMP, .Operator = &SEC}, .{ .Name = "AND", .Cycles = 4, .AddrMode = &ABY, .Operator = &AND}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "AND", .Cycles = 4, .AddrMode = &ABX, .Operator = &AND}, .{ .Name = "ROL", .Cycles = 7, .AddrMode = &ABX, .Operator = &ROL}, .{} },
    .{ .{ .Name = "RTI", .Cycles = 6, .AddrMode = &IMP, .Operator = &RTI}, .{ .Name = "EOR", .Cycles = 6, .AddrMode = &IZX, .Operator = &EOR}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "EOR", .Cycles = 3, .AddrMode = &ZP0, .Operator = &EOR}, .{ .Name = "LSR", .Cycles = 5, .AddrMode = &ZP0, .Operator = &LSR}, .{}, .{ .Name = "PHA", .Cycles = 3, .AddrMode = &IMP, .Operator = &PHA}, .{ .Name = "EOR", .Cycles = 2, .AddrMode = &IMM, .Operator = &EOR}, .{ .Name = "LSR", .Cycles = 2, .AddrMode = &IMP, .Operator = &LSR}, .{}, .{ .Name = "JMP", .Cycles = 3, .AddrMode = &ABS, .Operator = &JMP}, .{ .Name = "EOR", .Cycles = 4, .AddrMode = &ABS, .Operator = &EOR}, .{ .Name = "LSR", .Cycles = 6, .AddrMode = &ABS, .Operator = &LSR}, .{} },
    .{ .{ .Name = "BVC", .Cycles = 2, .AddrMode = &REL, .Operator = &BVC}, .{ .Name = "EOR", .Cycles = 5, .AddrMode = &IZY, .Operator = &EOR}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "EOR", .Cycles = 4, .AddrMode = &ZPX, .Operator = &EOR}, .{ .Name = "LSR", .Cycles = 6, .AddrMode = &ZPX, .Operator = &LSR}, .{}, .{ .Name = "CLI", .Cycles = 2, .AddrMode = &IMP, .Operator = &CLI}, .{ .Name = "EOR", .Cycles = 4, .AddrMode = &ABY, .Operator = &EOR}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "EOR", .Cycles = 4, .AddrMode = &ABX, .Operator = &EOR}, .{ .Name = "LSR", .Cycles = 7, .AddrMode = &ABX, .Operator = &LSR}, .{} },
    .{ .{ .Name = "RTS", .Cycles = 6, .AddrMode = &IMP, .Operator = &RTS}, .{ .Name = "ADC", .Cycles = 6, .AddrMode = &IZX, .Operator = &ADC}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "ADC", .Cycles = 3, .AddrMode = &ZP0, .Operator = &ADC}, .{ .Name = "ROR", .Cycles = 5, .AddrMode = &ZP0, .Operator = &ROR}, .{}, .{ .Name = "PLA", .Cycles = 4, .AddrMode = &IMP, .Operator = &PLA}, .{ .Name = "ADC", .Cycles = 2, .AddrMode = &IMM, .Operator = &ADC}, .{ .Name = "ROR", .Cycles = 2, .AddrMode = &IMP, .Operator = &ROR}, .{}, .{ .Name = "JMP", .Cycles = 5, .AddrMode = &IND, .Operator = &JMP}, .{ .Name = "ADC", .Cycles = 4, .AddrMode = &ABS, .Operator = &ADC}, .{ .Name = "ROR", .Cycles = 6, .AddrMode = &ABS, .Operator = &ROR}, .{} },
    .{ .{ .Name = "BVS", .Cycles = 2, .AddrMode = &REL, .Operator = &BVS}, .{ .Name = "ADC", .Cycles = 5, .AddrMode = &IZY, .Operator = &ADC}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "ADC", .Cycles = 4, .AddrMode = &ZPX, .Operator = &ADC}, .{ .Name = "ROR", .Cycles = 6, .AddrMode = &ZPX, .Operator = &ROR}, .{}, .{ .Name = "SEI", .Cycles = 2, .AddrMode = &IMP, .Operator = &SEI}, .{ .Name = "ADC", .Cycles = 4, .AddrMode = &ABY, .Operator = &ADC}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "ADC", .Cycles = 4, .AddrMode = &ABX, .Operator = &ADC}, .{ .Name = "ROR", .Cycles = 7, .AddrMode = &ABX, .Operator = &ROR}, .{} },
    .{ .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMM, .Operator = &NOP}, .{ .Name = "STA", .Cycles = 6, .AddrMode = &IZX, .Operator = &STA}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "STY", .Cycles = 3, .AddrMode = &ZP0, .Operator = &STY}, .{ .Name = "STA", .Cycles = 3, .AddrMode = &ZP0, .Operator = &STA}, .{ .Name = "STX", .Cycles = 3, .AddrMode = &ZP0, .Operator = &STX}, .{}, .{ .Name = "DEY", .Cycles = 2, .AddrMode = &IMP, .Operator = &DEY}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "TXA", .Cycles = 2, .AddrMode = &IMP, .Operator = &TXA}, .{}, .{ .Name = "STY", .Cycles = 4, .AddrMode = &ABS, .Operator = &STY}, .{ .Name = "STA", .Cycles = 4, .AddrMode = &ABS, .Operator = &STA}, .{ .Name = "STX", .Cycles = 4, .AddrMode = &ABS, .Operator = &STX}, .{} },
    .{ .{ .Name = "BCC", .Cycles = 2, .AddrMode = &REL, .Operator = &BCC}, .{ .Name = "STA", .Cycles = 6, .AddrMode = &IZY, .Operator = &STA}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "STY", .Cycles = 4, .AddrMode = &ZPX, .Operator = &STY}, .{ .Name = "STA", .Cycles = 4, .AddrMode = &ZPX, .Operator = &STA}, .{ .Name = "STX", .Cycles = 4, .AddrMode = &ZPX, .Operator = &STX}, .{}, .{ .Name = "TYA", .Cycles = 2, .AddrMode = &IMP, .Operator = &TYA}, .{ .Name = "STA", .Cycles = 5, .AddrMode = &ABY, .Operator = &STA}, .{ .Name = "TXS", .Cycles = 2, .AddrMode = &IMP, .Operator = &TXS}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "STA", .Cycles = 5, .AddrMode = &ABX, .Operator = &STA}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{} },
    .{ .{ .Name = "LDY", .Cycles = 2, .AddrMode = &IMM, .Operator = &LDY}, .{ .Name = "LDA", .Cycles = 6, .AddrMode = &IZX, .Operator = &LDA}, .{ .Name = "LDX", .Cycles = 2, .AddrMode = &IMM, .Operator = &LDX}, .{}, .{ .Name = "LDY", .Cycles = 3, .AddrMode = &ZP0, .Operator = &LDY}, .{ .Name = "LDA", .Cycles = 3, .AddrMode = &ZP0, .Operator = &LDA}, .{ .Name = "LDX", .Cycles = 3, .AddrMode = &ZP0, .Operator = &LDX}, .{}, .{ .Name = "TAY", .Cycles = 2, .AddrMode = &IMP, .Operator = &TAY}, .{ .Name = "LDA", .Cycles = 2, .AddrMode = &IMM, .Operator = &LDA}, .{ .Name = "TAX", .Cycles = 2, .AddrMode = &IMP, .Operator = &TAX}, .{}, .{ .Name = "LDY", .Cycles = 4, .AddrMode = &ABS, .Operator = &LDY}, .{ .Name = "LDA", .Cycles = 4, .AddrMode = &ABS, .Operator = &LDA}, .{ .Name = "LDX", .Cycles = 4, .AddrMode = &ABS, .Operator = &LDX}, .{} },
    .{ .{ .Name = "BCS", .Cycles = 2, .AddrMode = &REL, .Operator = &BCS}, .{ .Name = "LDA", .Cycles = 5, .AddrMode = &IZY, .Operator = &LDA}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "LDY", .Cycles = 4, .AddrMode = &ZPX, .Operator = &LDY}, .{ .Name = "LDA", .Cycles = 4, .AddrMode = &ZPX, .Operator = &LDA}, .{ .Name = "LDX", .Cycles = 4, .AddrMode = &ZPX, .Operator = &LDX}, .{}, .{ .Name = "CLV", .Cycles = 2, .AddrMode = &IMP, .Operator = &CLV}, .{ .Name = "LDA", .Cycles = 4, .AddrMode = &ABY, .Operator = &LDA}, .{ .Name = "TSX", .Cycles = 2, .AddrMode = &IMP, .Operator = &TSX}, .{}, .{ .Name = "LDY", .Cycles = 4, .AddrMode = &ABX, .Operator = &LDY}, .{ .Name = "LDA", .Cycles = 4, .AddrMode = &ABX, .Operator = &LDA}, .{ .Name = "LDX", .Cycles = 4, .AddrMode = &ABY, .Operator = &LDX}, .{} },
    .{ .{ .Name = "CPY", .Cycles = 2, .AddrMode = &IMM, .Operator = &CPY}, .{ .Name = "CMP", .Cycles = 6, .AddrMode = &IZX, .Operator = &CMP}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "CPY", .Cycles = 3, .AddrMode = &ZP0, .Operator = &CPY}, .{ .Name = "CMP", .Cycles = 3, .AddrMode = &ZP0, .Operator = &CMP}, .{ .Name = "DEC", .Cycles = 5, .AddrMode = &ZP0, .Operator = &DEC}, .{}, .{ .Name = "INY", .Cycles = 2, .AddrMode = &IMP, .Operator = &INY}, .{ .Name = "CMP", .Cycles = 2, .AddrMode = &IMM, .Operator = &CMP}, .{ .Name = "DEX", .Cycles = 2, .AddrMode = &IMP, .Operator = &DEX}, .{}, .{ .Name = "CPY", .Cycles = 4, .AddrMode = &ABS, .Operator = &CPY}, .{ .Name = "CMP", .Cycles = 4, .AddrMode = &ABS, .Operator = &CMP}, .{ .Name = "DEC", .Cycles = 6, .AddrMode = &ABS, .Operator = &DEC}, .{} },
    .{ .{ .Name = "BNE", .Cycles = 2, .AddrMode = &REL, .Operator = &BNE}, .{ .Name = "CMP", .Cycles = 5, .AddrMode = &IZY, .Operator = &CMP}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "CMP", .Cycles = 4, .AddrMode = &ZPX, .Operator = &CMP}, .{ .Name = "DEC", .Cycles = 6, .AddrMode = &ZPX, .Operator = &DEC}, .{}, .{ .Name = "CLD", .Cycles = 2, .AddrMode = &IMP, .Operator = &CLD}, .{ .Name = "CMP", .Cycles = 4, .AddrMode = &ABY, .Operator = &CMP}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "CMP", .Cycles = 4, .AddrMode = &ABX, .Operator = &CMP}, .{ .Name = "DEC", .Cycles = 7, .AddrMode = &ABX, .Operator = &DEC}, .{} },
    .{ .{ .Name = "CPX", .Cycles = 2, .AddrMode = &IMM, .Operator = &CPX}, .{ .Name = "SBC", .Cycles = 6, .AddrMode = &IZX, .Operator = &SBC}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "CPX", .Cycles = 3, .AddrMode = &ZP0, .Operator = &CPX}, .{ .Name = "SBC", .Cycles = 3, .AddrMode = &ZP0, .Operator = &SBC}, .{ .Name = "INC", .Cycles = 5, .AddrMode = &ZP0, .Operator = &INC}, .{}, .{ .Name = "INX", .Cycles = 2, .AddrMode = &IMP, .Operator = &INX}, .{ .Name = "SBC", .Cycles = 2, .AddrMode = &IMM, .Operator = &SBC}, .{ .Name = "NOP", .Cycles = 2, .AddrMode = &IMP, .Operator = &NOP}, .{}, .{ .Name = "CPX", .Cycles = 4, .AddrMode = &ABS, .Operator = &CPX}, .{ .Name = "SBC", .Cycles = 4, .AddrMode = &ABS, .Operator = &SBC}, .{ .Name = "INC", .Cycles = 6, .AddrMode = &ABS, .Operator = &INC}, .{} },
    .{ .{ .Name = "BEQ", .Cycles = 2, .AddrMode = &REL, .Operator = &BEQ}, .{ .Name = "SBC", .Cycles = 5, .AddrMode = &IZY, .Operator = &SBC}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "SBC", .Cycles = 4, .AddrMode = &ZPX, .Operator = &SBC}, .{ .Name = "INC", .Cycles = 6, .AddrMode = &ZPX, .Operator = &INC}, .{}, .{ .Name = "SED", .Cycles = 2, .AddrMode = &IMP, .Operator = &SED}, .{ .Name = "SBC", .Cycles = 4, .AddrMode = &ABY, .Operator = &SBC}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{}, .{ .Name = "XXX", .Cycles = 1, .AddrMode = &IMP, .Operator = &XXX}, .{ .Name = "SBC", .Cycles = 4, .AddrMode = &ABX, .Operator = &SBC}, .{ .Name = "INC", .Cycles = 7, .AddrMode = &ABX, .Operator = &INC}, .{} },
};



pub const Instruction = struct 
{
    Name: []const u8 = "XXX",
    Operator: *const fn() u8 = &XXX,
    AddrMode: *const fn() u8 = &IMP,
    Cycles: u8 = 1,

};

//   00      01            02      03  04          05          06          07  08      09          0A     0B   0C      0D          0E          0F
// 00 BRK i   ORA (ind,x)   XXX     XXX XXX         ORA zp      ASL zp      XXX PHP i   ORA #       ASL A  XXX  XXX     ORA a       ASL a       XXX  
// 10 BPL r   ORA (ind),y   XXX     XXX XXX         ORA zp,x    ASL zp,x    XXX CLC i   ORA a,y     XXX    XXX  XXX     ORA a,x     ASL a,x     XXX  
// 20 JSR a   AND (ind,x)   XXX     XXX BIT zp      AND zp      ROL zp      XXX PLP i   AND #       ROL A  XXX  BIT a   AND a       ROL a       XXX  
// 30 BMI r   AND (ind),y   XXX     XXX XXX         AND zp,x    ROL zp,x    XXX SEC i   AND a,y     XXX    XXX  XXX     AND a,x     ROL a,x     XXX  
// 40 RTI i   EOR (ind,x)   XXX     XXX XXX         EOR zp      LSR zp      XXX PHA i   EOR #       LSR A  XXX  JMP a   EOR a       LSR a       XXX  
// 50 BVC r   EOR (ind),y   XXX     XXX XXX         EOR zp,x    LSR zp,x    XXX CLI i   EOR a,y     XXX    XXX  XXX     EOR a,x     LSR a,x     XXX  
// 60 RTS i   ADC (ind,x)   XXX     XXX XXX         ADC zp      ROR zp      XXX PLA i   ADC #       ROR A  XXX  JMP (a) ADC a       ROR a       XXX  
// 70 BVS r   ADC (ind),y   XXX     XXX XXX         ADC zp,x    ROR zp,x    XXX SEI i   ADC a,y     XXX    XXX  XXX     ADC a,x     ROR a,x     XXX  
// 80 XXX     STA (ind,x)   XXX     XXX STY zp      STA zp      STX zp      XXX DEY i   XXX #       TXA i  XXX  STY a   STA a       STX a       XXX  
// 90 BCC r   STA (ind),y   XXX     XXX STY zp,x    STA zp,x    STX zp,y    XXX TYA i   STA a,y     TXS i  XXX  XXX     STA a,x     XXX         -
// A0 LDY #   LDA (ind,x)   LDX #   XXX LDY zp      LDA zp      LDX zp      XXX TAY i   LDA #       TAX i  XXX  LDY a   LDA a       LDX a       XXX  
// B0 BCS r   LDA (ind),y   XXX     XXX LDY zp,x    LDA zp,x    LDX zp,y    XXX CLV i   LDA a,y     TSX i  XXX  LDY a,x LDA a,x     LDX a,y     XXX  
// C0 CPY #   CMP (ind,x)   XXX     XXX CPY zp      CMP zp      DEC zp      XXX INY i   CMP #       DEX i  XXX  CPY a   CMP a       DEC a       XXX  
// D0 BNE r   CMP (ind),y   XXX     XXX XXX         CMP zp,x    DEC zp,x    XXX CLD i   CMP a,y     XXX    XXX  XXX     CMP a,x     DEC a,x     XXX  
// E0 CPX #   SBC (ind,x)   XXX     XXX CPX zp      SBC zp      INC zp      XXX INX i   SBC #       NOP i  XXX  CPX a   SBC a       INC a       XXX  
// F0 BEQ r   SBC (ind),y   XXX     XXX XXX         SBC zp,x    INC zp,x    XXX SED i   SBC a,y     XXX    XXX  XXX     SBC a,x     INC a,x     XXX  