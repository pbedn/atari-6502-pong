        processor 6502
; Lesson 2. Position and draw two paddles and read both joysticks.

; New here: RAM variables, two controller inputs, and three TIA objects.
; Follow Frame to ReadJoysticks, then PositionX, then Court. The update
; changes positions in RAM, while the drawing loop reads those positions.
; Think of these as update(state) and draw(state), with an important
; difference from Python: both have to fit within real scanline timing.
; Syntax: # means literal, $ means hex, and label,x means address + X.
VSYNC = $00
VBLANK = $01
WSYNC = $02
COLUP0 = $06
COLUP1 = $07
COLUPF = $08
COLUBK = $09
CTRLPF = $0A
PF0 = $0D
PF1 = $0E
PF2 = $0F
RESP0 = $10
GRP0 = $1B
GRP1 = $1C
ENAM0 = $1D
ENABL = $1F
HMP0 = $20
HMOVE = $2A
SWCHA = $0280
INTIM = $0284
TIM64T = $0296

; SEG.U and ds reserve RAM addresses for bytes. They emit no ROM data.
; Unlike assigning a Python variable, reserving a byte does not initialize it.
        SEG.U RAM
        ORG $80
row ds 1                 ; logical court row, each lasting two physical scanlines
gfx0 ds 1                ; left paddle mask prepared for the next logical row
gfx1 ds 1                ; right paddle mask prepared for the next logical row
netEnable ds 1           ; 0 or 2 for the net missile in the next row
p0y ds 1                 ; top row of the left paddle
p1y ds 1                 ; top row of the right paddle

        SEG CODE
; ORG places the following machine code at a chosen address.
; A 4 KiB cartridge is assembled here into the $F000-$FFFF range.
        ORG $F000
; The reset vector at the bottom of this file points here. A label is
; an address the assembler fills in. Execution starts at Start and
; continues down the file until a branch, jump, or return redirects it.
Start
        sei
        cld
        ; Set the stack pointer before JSR. The top of the stack maps to RIOT
        ; RAM on the 2600. JSR stores the return address there.
        ldx #$FF
        txs
        lda #0
        ldx #$2C
; A still contains zero. Clear each TIA write address from $2C down
; to $00. These addresses control hardware: a write can trigger an
; action, so treat them differently from ordinary variables in RAM.
ClearTIA
        sta $00,x
        dex
        bpl ClearTIA
        lda #38
        sta p0y
        sta p1y
        lda #2
        sta VBLANK
        sta WSYNC

; Think of this as the outer while True loop. VBLANK is already set.
; The three WSYNC writes hold VSYNC active for three scanlines.
; WSYNC stalls the CPU until the scanline boundary; the stored byte
; does not matter. The TIA keeps running while the CPU waits.
Frame
        lda #2
        sta VSYNC
        sta WSYNC
        sta WSYNC
        sta WSYNC
        lda #0
        sta VSYNC
        ; 43 timer ticks at 64 CPU cycles each set the blanking deadline,
        ; leaving time for input, movement, and positioning.
        lda #43
        sta TIM64T
        jsr ReadJoysticks
        ; The TIA color byte packs hue and luminance. $0E is white.
        lda #$0E
        sta COLUP0
        sta COLUP1
        sta COLUPF
        lda #$11
        sta CTRLPF
        lda #0
        sta row
        sta gfx0
        sta gfx1
        sta netEnable
        ldx #0
        lda #19
        jsr PositionX
        ldx #1
        lda #139
        jsr PositionX
        ldx #2
        lda #83
        jsr PositionX
        ; At the start of the next scanline, apply all fine offsets together.
        sta WSYNC
        sta HMOVE
; Wait until INTIM reads zero, then align to the next scanline.
; LDA sets the Z flag from the byte it reads, so BNE is a loop while
; the timer is nonzero. STA does not modify A, so the same zero
; written to WSYNC can then clear VBLANK.
WaitBlank
        lda INTIM
        bne WaitBlank
        sta WSYNC
        sta VBLANK

; Reserve the same 22 lines the later scoreboard uses.
        ldx #22
; The full game uses these 22 visible lines for its scoreboard.
; Keep them black in this lesson so the height of the court matches.
PictureTop
        sta WSYNC
        dex
        bne PictureTop

CourtStart
; The 170 court lines are paired into 85 logical rows. While drawing one
; row, prepare the sprites for the next and commit them after WSYNC.
; TIA has no framebuffer. Write the masks computed for this row
; early enough for the TIA to use them. It keeps the same register
; values through the two physical lines of each logical row.
Court
        lda gfx0
        sta GRP0
        lda gfx1
        sta GRP1
        lda netEnable
        sta ENAM0
        ; Advance the row and prepare the next drawing masks. SEC means no
        ; incoming borrow for SBC. Above the paddle, the difference wraps to a
        ; large unsigned byte. CMP #11 accepts 0..10. LDA #0 sets Z and N but
        ; preserves C for the following BCS.
        inc row
        lda row
        sec
        sbc p0y
        cmp #11
        lda #0
        bcs LeftGraphic
        lda #$C0
; A is either $00 (hide the sprite) or $C0 (binary 11000000).
; Store it for the next row, then do the same test for the right
; paddle. This is like preparing the next iteration's local values.
LeftGraphic
        sta gfx0
        lda row
        sec
        sbc p1y
        cmp #11
        lda #0
        bcs RightGraphic
        lda #$C0
; WSYNC moves us to the second physical line of the current row.
; The graphics registers still contain the current masks, giving
; the CPU a second scanline for the remaining bookkeeping.
RightGraphic
        sta gfx1
        sta WSYNC
        ; Missile 0 is one color clock wide. Two logical rows per dash.
        lda row
        and #3
        cmp #2
        lda #0
        bcs NetGraphic
        lda #2
; Save the net state for the next row. CMP sets C when row >= 85.
; STA WSYNC leaves flags unchanged, so BCC can still use that test
; after the hardware wait. A falling-through branch ends the court.
NetGraphic
        sta netEnable
        lda row
        cmp #85
        sta WSYNC
        bcc Court
; Turn on VBLANK and remove the current shapes from the TIA.
; The next frame can then start its visible section with a clean
; picture, even if something was drawn on the last row.
EndPicture
        lda #2
        sta VBLANK
        lda #0
        sta GRP0
        sta GRP1
        sta ENAM0
        sta PF0
        sta PF1
        sta PF2
        ldx #30
; Count 30 hidden scanlines. Each DEX sets Z if X becomes zero,
; and BNE repeats only when Z is clear. JMP Frame starts over.
Overscan
        sta WSYNC
        dex
        bne Overscan
        jmp Frame

; A is the horizontal coordinate and X identifies the TIA object.
; Think of this as position_x(a, x), with A and X as arguments.
; X selects player 0, player 1, missile 0, or the ball. JSR puts a
; return address on the stack and RTS resumes at the caller.
; SEC sets C so the first SBC subtracts 15 with no extra borrow.
PositionX
        sec
        sta WSYNC
; The taken SBC/BCS loop costs five CPU cycles per iteration.
; That moves the beam 15 color clocks. After the first borrow, the
; low bits of A encode the remainder for the fine correction.
; EOR adjusts that encoding and four ASLs put it in the high nibble.
; HMP0,x stores the correction; RESP0,x strobes the coarse position
; at the beam's current location. HMOVE later applies the correction.
Coarse
        sbc #15
        bcs Coarse
        eor #7
        asl
        asl
        asl
        asl
        sta HMP0,x
        sta RESP0,x
        rts

; SWCHA is an active-low hardware input. The Python equivalent of
; AND #$10 / BNE is "if (switches & 0x10) != 0: skip this move".
; CMP sets Z if A equals the limit, and BEQ skips the decrement.
ReadJoysticks
        lda SWCHA
        and #$10
        bne P0Down
        lda p0y
        cmp #4
        beq P0Down
        dec p0y
; This is the alternate direction on player 0. Increasing Y moves
; down because row zero is at the top of the visible court.
P0Down
        lda SWCHA
        and #$20
        bne P1Up
        lda p0y
        cmp #70
        beq P1Up
        inc p0y
P1Up
        lda SWCHA
        and #$01
        bne P1Down
        lda p1y
        cmp #4
        beq P1Down
        dec p1y
; Check the other direction for player 1. The right joystick uses
; the low four bits of SWCHA; player 0 uses the high four bits.
P1Down
        lda SWCHA
        and #$02
        bne ControlsDone
        lda p1y
        cmp #70
        beq ControlsDone
        inc p1y
ControlsDone
        rts

; Three 16-bit vector slots occupy the last six bytes of the ROM.
; The middle slot is the reset vector at $FFFC. .word writes the
; little-endian address of Start into each slot.
        ORG $FFFA
        .word Start
        .word Start
        .word Start
