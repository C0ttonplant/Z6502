    processor 6502
    ;
    .org $0000
    .word
    .org $7FFE
    ;
Start:
    JSR .test
    STY $0002
    BRK
    ;
.test:
    LDA #$15
    LDX #$16
    LDY #$17
    STA $0000
    STX $0001
    RTS 
    ;
    .org $FFFA
    .word $8000
    .word $8000