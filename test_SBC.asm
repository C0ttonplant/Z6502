    processor 6502
 
    .org $0000
    .word
    .org $7FFE

Start:
    LDA #$FF
    STA $0000
    LDA #$00
    STA $0001
    SBC $0000
    STA $0002
    LDA $0000
    SBC $0001
    STA $0003
    BRK
    
    .org $FFFA
    .word $8000
    .word $8000