    PROCESSOR 6502

    .org $0000
    .word
    .org $7FFE
    
Start:
    LDX #$1
    ASL
loop:
    INX
    LDY str,X
    STY printAddr
    BNE loop
    LDY #$A
    STY printAddr
    BRK

printAddr = #$00f0
str: .byte "hello, world!", 0

    .org $fffa
    .word $8000
    .word $8000