    PROCESSOR 6502


; this rom is designed to only test official opcodes
; addressing modes other than immediate, absolute, and relative are not used
; 
; the output indicates which tests were passed until falure, if all test pass the program will break
; otherwise the program will get trapped
;
; expected output
;      01h 02h 03h 04h 05h 06h 07h 08h 09h 0Ah 0Bh 0Ch 0Dh 0Eh 0Fh
;     ____________________________________________________________
; 00h| 07h 03h 03h 0ch 06h 06h 04h 03h 03h 02h 04h 06h 0Dh -------


Start:
    .org $0000
    .word
    .org $02FE          ; output addr
    JSR test_Branch+2   ; 00h
    JSR test_AND+2      ; 01h
    JSR test_ASL+2      ; 02h
    JSR test_BIT+2      ; 03h
    JSR test_CMP+2      ; 04h
    JSR test_DEC+2      ; 05h
    JSR test_INC+2      ; 06h
    JSR test_EOR+2      ; 07h
    JSR test_LSR+2      ; 08h
    JSR test_ORA+2      ; 09h
    JSR test_PushPop+2  ; 0Ah
    JSR test_ROT+2      ; 0Bh
    JSR test_SBCADC+2   ; 0Ch
    JSR test_transfer+2 ; 0Dh
    BRK


test_Branch:
    LDA #$00
    BNE trap2
    BMI trap2
    LDA #$1
    STA $0000 ; test 1 passed

    LDA #$80
    BEQ trap2
    BPL trap2
    LDA #$2
    STA $0000 ; test 2 passed

    LDA #$00
    BEQ jmp1
    JMP trap2
jmp1:
    BPL jmp2
    JMP trap2
jmp2:
    LDA #$3
    STA $0000 ; test 3 passed

    LDA #$80
    BNE jmp3
    JMP trap2
jmp3:
    BMI jmp4
    JMP trap2
jmp4:
    LDA #$4
    STA $0000 ; test 4 passed

    LDA #$79
    ADC #$01
    BVS trap2
    BCS trap2
    LDA #$5
    STA $0000 ; test 5 passed

    LDA #$FF
    ADC #$01
    BVS trap2
    BCC trap2
    LDA #$6
    STA $0000 ; test 6 passed

    LDA #$10
    ADC #$01
    BVS trap2
    BCS trap2
    LDA #$7
    STA $0000 ; test 7 passed
    RTS


trap2:
    JMP trap + 2

test_AND:
    LDA #$44
    AND #$44
    BEQ trap
    BMI trap
    LDA #$1
    STA $0001 ; test 1 passed

    LDA #$30
    STA $01FF
    AND $01FF
    BEQ trap
    BMI trap
    LDA #$2
    STA $0001 ; test 2 passed

    LDA #$FF
    STA $01FF
    AND $01FF
    BEQ trap
    BPL trap
    LDA #$3
    STA $0001 ; test 3 passed
    RTS

test_ASL:
    LDA #$01
    ASL
    BCS trap
    BMI trap
    BEQ trap
    LDA #$1
    STA $0002 ; test 1 passed

    LDA #$80
    STA $01FF
    ASL $01FF
    BCC trap
    BNE trap
    BMI trap
    LDA #$2
    STA $0002 ; test 2 passed

    LDA #$40
    LDX #$01
    STA $01FF
    ASL $01FF
    BCS trap
    BEQ trap
    BPL trap
    LDA #$3
    STA $0002 ; test 3 passed
    RTS

trap:
    JMP trap + 2

test_BIT:
    LDA #$80
    STA $01FF
    BIT $01FF
    BPL trap
    BVS trap
    BEQ trap
    LDA #$1
    STA $0003 ; test 1 passed

    LDA #$40
    STA $01FF
    BIT $01FF
    BMI trap
    BVC trap
    BEQ trap
    LDA #$2
    STA $0003 ; test 2 passed

    LDA #$00
    STA $01FF
    BIT $01FF
    BMI trap
    BVS trap
    BNE trap
    LDA #$3
    STA $0003 ; test 3 passed
    RTS

test_CMP:
    LDA #$00
    CMP #$00
    BNE trap3
    BMI trap3
    BCC trap3
    LDA #$1
    STA $0004 ; test 1 passed

    LDA #$80
    CMP #$00
    BEQ trap3
    BPL trap3
    BCC trap3
    LDA #$2
    STA $0004 ; test 2 passed

    LDA #$80
    CMP #$80
    BNE trap3
    BMI trap3
    BCC trap3
    LDA #$3
    STA $0004 ; test 3 passed

    LDA #$00
    CMP #$80
    BEQ trap3
    BPL trap3
    BCS trap3
    LDA #$4
    STA $0004 ; test 4 passed
    BNE jmp5

trap3:
    JMP trap + 2
jmp5:
    LDX #$00
    CPX #$00
    BNE trap3
    BMI trap3
    BCC trap3
    LDA #$5
    STA $0004 ; test 5 passed

    LDX #$80
    CPX #$00
    BEQ trap3
    BPL trap3
    BCC trap3
    LDA #$6
    STA $0004 ; test 6 passed

    LDX #$80
    CPX #$80
    BNE trap3
    BMI trap3
    BCC trap3
    LDA #$7
    STA $0004 ; test 7 passed

    LDX #$00
    CPX #$80
    BEQ trap3
    BPL trap3
    BCS trap3
    LDA #$8
    STA $0004 ; test 8 passed

    LDY #$00
    CPY #$00
    BNE trap3
    BMI trap3
    BCC trap3
    LDA #$9
    STA $0004 ; test 9 passed

    LDY #$80
    CPY #$00
    BEQ trap3
    BPL trap3
    BCC trap3
    LDA #$a
    STA $0004 ; test 10 passed

    LDY #$80
    CPY #$80
    BNE trap3
    BMI trap3
    BCC trap3
    LDA #$b
    STA $0004 ; test 11 passed

    LDY #$00
    CPY #$80
    BEQ trap3
    BPL trap3
    BCS trap3
    LDA #$c
    STA $0004 ; test 12 passed
    RTS

trap4:
    JMP trap3 + 2

test_DEC:
    LDA #$FF
    STA $01FF
dec1:
    DEC $01FF
    BNE dec1
    LDA $01FF
    CMP #$00
    BNE trap4
    LDA #$1
    STA $0005 ; test 1 passed

    LDA #$FF
    STA $01FF
dec2:
    DEC $01FF
    BMI dec2
    LDA $01FF
    CMP #$7F
    BNE trap4
    LDA #$2
    STA $0005 ; test 2 passed
    
    LDX #$FF
dec3:
    DEX
    BNE dec3
    CPX #$00
    BNE trap4
    LDA #$3
    STA $0005 ; test 3 passed

    LDX #$FF
dec4:
    DEX
    BMI dec4
    CPX #$7F
    BNE trap4
    LDA #$4
    STA $0005 ; test 4 passed

    LDY #$FF
dec5:
    DEY
    BNE dec5
    CPY #$00
    BNE trap4
    LDA #$5
    STA $0005 ; test 5 passed

    LDY #$FF
dec6:
    DEY
    BMI dec6
    CPY #$7F
    BNE trap4
    LDA #$6
    STA $0005 ; test 6 passed
    RTS

trap5:
    JMP trap4 + 2

test_INC:
    LDA #$01
    STA $01FF
inc1:
    INC $01FF
    BNE inc1
    LDA $01FF
    CMP #$00
    BNE trap5
    LDA #$1
    STA $0006 ; test 1 passed

    LDA #$01
    STA $01FF
inc2:
    INC $01FF
    BPL inc2
    LDA $01FF
    CMP #$80
    BNE trap5
    LDA #$2
    STA $0006 ; test 2 passed

    LDX #$01
inc3:
    INX 
    BNE inc3
    CPX #$00
    BNE trap5
    LDA #$3
    STA $0006 ; test 3 passed

    LDX #$01
inc4:
    INX 
    BPL inc4
    CPX #$80
    BNE trap5
    LDA #$4
    STA $0006 ; test 3 passed


    LDY #$01
inc5:
    INY 
    BNE inc5
    CPY #$00
    BNE trap5
    LDA #$5
    STA $0006 ; test 5 passed

    LDY #$01
inc6:
    INY 
    BPL inc6
    CPY #$80
    BNE trap5
    LDA #$6
    STA $0006 ; test 6 passed
    RTS

trap6:
    JMP trap5+2

test_EOR:
    LDA #$00
    EOR #$80
    BPL trap6
    BEQ trap6
    LDA #$1
    STA $0007 ; test 1 passed

    LDA #$80
    EOR #$80
    BMI trap6
    BNE trap6
    LDA #$2
    STA $0007 ; test 2 passed

    LDA #$B0
    EOR #$80
    BMI trap6
    BEQ trap6
    LDA #$3
    STA $0007 ; test 3 passed

    LDA #$B0
    EOR #$40
    BPL trap6
    BEQ trap6
    LDA #$4
    STA $0007 ; test 4 passed
    RTS

trap7:
    JMP trap6+2

test_LSR:
    LDA #$80
    LSR
    BEQ trap7
    BCS trap7
    BMI trap7
    LDA #$1
    STA $0008 ; test 1 passed

    LDA #$01
    STA $01FF
    LSR $01FF
    BNE trap7
    BCC trap7
    BMI trap7
    LDA #$2
    STA $0008 ; test 2 passed

    LDA #$81
    LDX #$01
    STA $01FF
    LSR $01FF
    BEQ trap7
    BCC trap7
    BMI trap7
    LDA #$3
    STA $0008 ; test 3 passed
    RTS

test_ORA:
    LDA #$80
    ORA #$80
    BEQ trap7
    BPL trap7
    LDA #$1
    STA $0009 ; test 1 passed

    LDA #$40
    LDX #$80
    STX $01FF
    ORA $01FF
    BEQ trap7
    BPL trap7
    LDA #$2
    STA $0009 ; test 2 passed

    LDA #$00
    LDX #$00
    STX $01FF
    LDX #$10
    ORA $01FF
    BNE trap7
    BMI trap7
    LDA #$3
    STA $0009 ; test 3 passed
    RTS

test_PushPop:
    LDA #$80
    PHA

    PHP
    LDA #$00
    PLP
    BEQ trap7
    BPL trap7
    LDA #$1
    STA $000A ; test 1 passed

    PLA 
    CMP #$80
    BNE trap7
    BMI trap7
    LDA #$2
    STA $000A ; test 2 passed
    RTS

trap8:
    jmp trap7+2

test_ROT:
    CLC
    LDA #$80
    ROR
    BEQ trap8
    BMI trap8
    BCS trap8
    LDX #$1
    STX $000B ; test 1 passed

    ROL
    BEQ trap8
    BPL trap8
    BCS trap8
    LDX #$2
    STX $000B ; test 2 passed

    CLC
    LDA #$01
    ROR
    BNE trap8
    BMI trap8
    BCC trap8
    LDX #$3
    STX $000B ; test 3 passed

    ROL
    PHP
    CMP #$01
    BNE trap8
    BMI trap8
    PLP
    BCS trap8
    LDX #$4
    STX $000B ; test 4 passed
    RTS

trap9:
    JMP trap8+2

test_SBCADC:
    LDA #$01
    ADC #$FF
    BNE trap9
    BMI trap9
    BVS trap9
    BCC trap9
    LDX #$1
    STX $000C ; test 1 passed

    LDA #$01
    ADC #$79
    BEQ trap9
    BMI trap9
    BVS trap9
    BCS trap9
    LDX #$2
    STX $000C ; test 2 passed

    LDA #$FE
    ADC #$01
    BEQ trap9
    BPL trap9
    BVS trap9
    BCS trap9
    LDX #$3
    STX $000C ; test 3 passed

    LDA #$01
    SBC #$00
    BNE trap9
    BMI trap9
    BVS trap9
    BCC trap9
    LDX #$4
    STX $000C ; test 4 passed

    LDA #$01
    SBC #$80
    BEQ trap9
    BPL trap9
    BVC trap9
    BCS trap9
    LDX #$5
    STX $000C ; test 5 passed

    LDA #$01
    SBC #$01
    BEQ trap9
    BPL trap9
    BVS trap9
    BCS trap9
    LDX #$6
    STX $000C ; test 6 passed
    RTS

trap10:
    JMP trap9

test_transfer:
    LDA #$80
    TAX
    BEQ trap10
    BPL trap10
    STX $01FF
    LDA $01FF
    CMP #$80
    BNE trap10
    LDX #$1
    STX $000D ; test 1 passed

    LDA #$00
    TAX
    BNE trap10
    BMI trap10
    STX $01FF
    LDA $01FF
    CMP #$00
    BNE trap10
    LDX #$2
    STX $000D ; test 2 passed
    
    LDA #$80
    TAX
    BEQ trap10
    BPL trap10
    STX $01FF
    LDA $01FF
    CMP #$80
    BNE trap10
    LDX #$3
    STX $000D ; test 3 passed

    LDA #$80
    TAY
    BEQ trap10
    BPL trap10
    STY $01FF
    LDA $01FF
    CMP #$80
    BNE trap10
    LDX #$4
    STX $000D ; test 4 passed

    LDA #$00
    TAY
    BNE trap10
    BMI trap10
    STY $01FF
    LDA $01FF
    CMP #$00
    BNE trap10
    LDX #$5
    STX $000D ; test 5 passed
    
    LDA #$80
    TAY
    BEQ trap10
    BPL trap10
    STY $01FF
    LDA $01FF
    CMP #$80
    BNE trap10
    LDX #$6
    STX $000D ; test 6 passed
    BNE jmp6

trap11:
    JMP trap10+2

jmp6:
    LDX #$80
    TXA
    BEQ trap11
    BPL trap11
    CMP #$80
    BNE trap11
    LDX #$7
    STX $000D ; test 7 passed

    LDX #$00
    TXA
    BNE trap11
    BMI trap11
    CMP #$00
    BNE trap11
    LDA #$8
    STA $000D ; test 8 passed
    
    LDX #$80
    TXA
    BEQ trap11
    BPL trap11
    CMP #$80
    BNE trap11
    LDA #$9
    STA $000D ; test 9 passed

    LDY #$80
    TYA
    BEQ trap11
    BPL trap11
    CMP #$80
    BNE trap11
    LDX #$A
    STX $000D ; test 10 passed

    LDY #$00
    TYA
    BNE trap11
    BMI trap11
    CMP #$00
    BNE trap11
    LDA #$B
    STA $000D ; test 11 passed
    
    LDY #$80
    TYA
    BEQ trap11
    BPL trap11
    CMP #$80
    BNE trap11
    LDA #$C
    STA $000D ; test 12 passed

    TSX
    TXA
    CMP #$FA
    BNE trap11
    TXS
    LDA #$D
    STA $000D ; test 13 passed
    RTS

end:
    .org $FFFA
    .word $0300
    .word $0300