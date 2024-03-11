    PROCESSOR 6502

    .org $0000
    .word
    .org $7FFE

Start:
    LDA #"A"
    STA $f0
    .word $02

    .org $FFFA
    .word $8000
    .word $8000