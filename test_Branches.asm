    PROCESSOR 6502

    .org $0000
    .word
    .org $7FFE
    
Start:
    LDA #$00
    STA $0000
    CMP $0000
    BNE trap
    LDA #$10
    CMP $0000
    BEQ trap
    BMI trap
    LDA #$FF
    BPL trap
    BCC trap
    ADC #2
    BCC trap
    BVC trap
    LDA #$10
    ADC #1
    BCS trap
    BVC trap
    BRK

trap:
    JMP trap

    .org $FFFA
    .word $8000
    .word $8000