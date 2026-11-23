        processor 6502
; Lesson 1. Make a steady NTSC frame before adding any game objects.

; Start with the smallest useful result: a stable picture.
; Read Start, Frame, and the two visible loops in that order.
; A is the accumulator, the register used here to load and write values.
; X is a second 8-bit register used as a counter and an address offset.
; LDA #2 loads the literal byte 2. LDA $02 would read address $02.
; STA sends the byte in A to an address. $ introduces hexadecimal.
; The CPU also records flags such as Z (zero) and N (negative).
; Branches inspect those flags, so a compare and branch work together
; like an if statement. The 2600 CPU executes 6502 code but uses the
; TIA to generate its picture, one scanline at a time.
VSYNC   = $00
VBLANK  = $01
WSYNC   = $02
COLUBK  = $09

; ORG places the following machine code at a chosen address.
; A 4 KiB cartridge is assembled here into the $F000-$FFFF range.
        ORG $F000
; The reset vector at the bottom of this file points here. A label is
; an address the assembler fills in. Execution starts at Start and
; continues down the file until a branch, jump, or return redirects it.
Start
        sei                     ; Mask interrupts during startup.
        cld                     ; Select binary arithmetic for ADC and SBC.
        lda #0                  ; A = 0, the value we will write repeatedly.
        ldx #$2C                ; X = 44, the highest address we clear.
; A still contains zero. Clear each TIA write address from $2C down
; to $00. These addresses control hardware: a write can trigger an
; action, so treat them differently from ordinary variables in RAM.
ClearTIA
        sta $00,x               ; Write A to address $00 + X.
        dex                     ; X = (X - 1) & 0xFF. Updates Z and N.
        bpl ClearTIA            ; Repeat until X wraps from $00 to $FF.
        lda #2
        sta VBLANK
        sta WSYNC

; Think of this as the outer while True loop. VBLANK is already set.
; The three WSYNC writes hold VSYNC active for three scanlines.
; WSYNC stalls the CPU until the scanline boundary; the stored byte
; does not matter. The TIA keeps running while the CPU waits.
Frame
        lda #2                  ; Binary 00000010: only bit 1 is on.
        sta VSYNC               ; Bit 1 starts vertical sync.
        sta WSYNC
        sta WSYNC
        sta WSYNC
        lda #0
        sta VSYNC

        ldx #37
; VBLANK is still active while we wait 37 lines. X is a counter.
; DEX/BNE is like decrementing x and looping while x != 0.
; A is still zero after the loop, ready to clear VBLANK.
BlankLine
        sta WSYNC
        dex
        bne BlankLine           ; DEX set Z only if X reached zero.

        sta VBLANK
        lda #$04
        sta COLUBK
        ldx #96
; Draw 96 lines using the current COLUBK color. The TIA keeps the
; color written to COLUBK until we write a different value.
TopLine
        sta WSYNC
        dex
        bne TopLine
        lda #$86
        sta COLUBK
        ldx #96
; Use a second color for the other 96 visible lines. Altering
; only the split point is safe if the two counts still total 192.
BottomLine
        sta WSYNC
        dex
        bne BottomLine

        lda #2
        sta VBLANK
        ldx #30
; Count 30 hidden scanlines. Each DEX sets Z if X becomes zero,
; and BNE repeats only when Z is clear. JMP Frame starts over.
Overscan
        sta WSYNC
        dex
        bne Overscan
        jmp Frame

; Three 16-bit vector slots occupy the last six bytes of the ROM.
; The middle slot is the reset vector at $FFFC. .word writes the
; little-endian address of Start into each slot.
        ORG $FFFA
        .word Start
        .word Start
        .word Start
