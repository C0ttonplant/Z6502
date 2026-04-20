*   = $8000
    
Start:
    LDX #$FF
loop:
    INX
    LDY str,X
    STY printAddr
    BNE loop
    LDY #$A
    STY printAddr
    BRK

printAddr = $00F0
str: .text "hello, world!", 0

*   = $FFFC
    .word Start 
    .word Start 
