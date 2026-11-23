        processor 6502
; Pong 1972 | NTSC, 4 KiB cartridge

; New here: a mode selector and a computer-controlled right paddle.
; Read UpdateMenu, StartMatch, and MoveComputer first. The same register
; and flag instructions used for collisions also implement menu choices.
; Think of mode as a small integer enum. It selects an input update
; and a drawing path. The court and scoring use the earlier lessons.
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
AUDC0 = $15
AUDF0 = $17
AUDV0 = $19
GRP0 = $1B
GRP1 = $1C
ENAM0 = $1D
ENABL = $1F
HMP0 = $20
HMOVE = $2A
CXCLR = $2C
INPT4 = $0C
SWCHA = $0280
SWCHB = $0282
INTIM = $0284
TIM64T = $0296

; SEG.U and ds reserve RAM addresses for bytes. They emit no ROM data.
; Unlike assigning a Python variable, reserving a byte does not initialize it.
        SEG.U RAM
        ORG $80
score0 ds 1              ; points for player 0 (left)
score1 ds 1              ; points for player 1 (right)
winner ds 1              ; 0 during play, 1 for left win, 2 for right win
sound ds 1               ; remaining frames of the current sound cue
row ds 1                 ; logical court row, each lasting two physical scanlines
gfx0 ds 1                ; left paddle mask prepared for the next logical row
gfx1 ds 1                ; right paddle mask prepared for the next logical row
enable0 ds 1             ; 0 or 2 for the ball in the next row
enable1 ds 1             ; reserved RAM byte from the game snapshot
netEnable ds 1           ; 0 or 2 for the net missile in the next row
leftDigitBase ds 1       ; left digit's starting index in the glyph table
rightDigitBase ds 1      ; right digit's starting index in the glyph table
clock ds 1               ; frame counter, wrapping from 255 to 0
rallyHits ds 1           ; paddle hits since the last serve
p0y ds 1                 ; top row of the left paddle
p1y ds 1                 ; top row of the right paddle
ballx ds 1               ; horizontal position supplied to the TIA positioning routine
bally ds 1               ; top logical row of the ball
dx ds 1                  ; horizontal velocity, 1 or $FF (-1)
dy ds 1                  ; vertical velocity, 1, 0, or $FF (-1)
delay ds 1               ; frames to wait before moving the served ball
mode ds 1                ; 0 = menu, 1 = computer, 2 = two players
menuChoice ds 1          ; highlighted option, 1 or 2
menuFireLock ds 1        ; nonzero until Fire has been released
cpuTarget ds 1           ; target Y for the computer paddle's center

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
        ldx #127
; For x in range(128): write(0x80 + x, 0), in reverse order.
; STA $80,x adds X to the base address. DEX wraps 0 to $FF.
; BPL tests the negative flag set by DEX, so the loop stops at $FF.
ClearRAM
        sta $80,x
        dex
        bpl ClearRAM
        ldx #$2C
; A still contains zero. Clear each TIA write address from $2C down
; to $00. These addresses control hardware: a write can trigger an
; action, so treat them differently from ordinary variables in RAM.
ClearTIA
        sta $00,x
        dex
        bpl ClearTIA
        lda #2
        sta VBLANK
        jsr ResetGame
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
        ; Advance the byte-sized frame counter, then update the game.
        ; Clock is used for blinking and spacing out movement steps.
        inc clock
        jsr Update
        ; The TIA color byte packs hue and luminance. $0E is white.
        lda #$0E
        sta COLUP0
        sta COLUP1
        sta COLUPF
        lda #0
        sta COLUBK
        lda #1
        sta CTRLPF
        ; Pick glyphs during blanking so the visible loop only needs fast
        ; lookups. Bit 5 of clock toggles every 32 frames.
        lda score0
        ldx winner
        cpx #1
        bne PackLeft
        ldx clock
        txa
        and #$20
        beq BlinkLeft
        lda score0
        bne PackLeft
; Glyph 12 is blank. Substitute it for the winner's score on
; alternating periods, leaving the real score in RAM untouched.
BlinkLeft
        lda #12
; Three ASLs multiply the small glyph index by eight: each glyph
; occupies eight bytes, seven rows plus one padding byte.
PackLeft
        asl
        asl
        asl
        sta leftDigitBase
        lda score1
        ldx winner
        cpx #2
        bne PackRight
        ldx clock
        txa
        and #$20
        beq BlinkRight
        lda score1
        bne PackRight
; The right score uses the same blink selection when player 1 won.
BlinkRight
        lda #12
; Convert the glyph number to an offset into RightDigits.
PackRight
        asl
        asl
        asl
        sta rightDigitBase
        lda #0
        sta row
        sta gfx0
        sta gfx1
        sta enable0
        sta enable1
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
        ldx #4
        lda ballx
        jsr PositionX
        ; At the start of the next scanline, apply all fine offsets together.
        sta WSYNC
        sta HMOVE
        sta CXCLR
        ; Choose a picture before WSYNC so this branch cannot delay the
        ; first visible line's register writes.
        lda mode
        bne WaitBlank
        jmp WaitMenuBlank
; Wait until INTIM reads zero, then align to the next scanline.
; LDA sets the Z flag from the byte it reads, so BNE is a loop while
; the timer is nonzero. STA does not modify A, so the same zero
; written to WSYNC can then clear VBLANK.
WaitBlank
        lda INTIM
        bne WaitBlank
        sta WSYNC
        sta VBLANK

; Each of the seven numeral rows is three scanlines high. Switch PF2
; data after the beam has passed the left copy.
        ; 21 score lines, one separator, and 85 pairs of court lines:
        ; 21 + 1 + 170 = 192 visible lines.
        ldx #20
; X is the physical line counter, and the ROM table maps it to
; one of seven glyph rows. Add the chosen glyph's start index,
; then use TAY and LDA table,y to read a pixel mask. This is like
; glyph_bytes[score * 8 + row]. The first PF2 write draws the left
; score. The NOPs buy time before rewriting PF2 for the right score.
ScoreLine
        lda ScoreLineRows,x
        clc
        adc leftDigitBase
        tay
        lda LeftDigits,y
        sta PF2
        nop
        nop
        nop
        nop
        nop
        lda ScoreLineRows,x
        clc
        adc rightDigitBase
        tay
        lda RightDigits,y
        sta PF2
        sta WSYNC
        dex
        bpl ScoreLine

; One black line separates the scoreboard from the court.
        lda #0
        sta PF2
        sta WSYNC
        lda #$11
        sta CTRLPF              ; reflect the playfield, two-clock ball
        jmp CourtStart
        ORG $F200
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
        lda enable0
        sta ENABL
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
        ; Same unsigned range trick as the paddles, now with height 2.
        lda row
        sec
        sbc bally
        cmp #2
        lda #0
        bcs BallGraphic
        lda #2
; ENABL uses bit 1 as an on/off switch, so the cached value is
; either 2 or 0. The ball's X position was set during blanking.
BallGraphic
        sta enable0
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
        sta ENABL
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

; A = x coordinate, X = TIA object index (players, missiles, then ball).
; Coarse steps are five CPU cycles, or fifteen color clocks.
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

; Reset the software state here. The hardware Reset switch is
; also read by Update each frame, so this path can run again later.
ResetGame
        lda #0
        sta mode
        lda #1
        sta menuChoice
        sta menuFireLock
; This entry point clears match state while preserving mode.
; The menu can call it to begin a fresh game in the chosen mode.
StartMatch
        lda #0
        sta score0
        sta score1
        sta winner
        sta sound
        sta AUDV0
        lda #1
        sta dx
        sta dy
        jmp Serve

; SWCHB bit 0 is the active-low Reset switch. LSR moves that bit
; into C. BCS skips reset if the switch is released. JMP ResetGame
; reuses this routine's return address; it makes no extra call frame.
Update
        lda SWCHB
        lsr
        bcs TickAudio
        jmp ResetGame
TickAudio
        lda mode
        bne MatchAudio
        jmp UpdateMenu
MatchAudio
        lda sound
        beq CheckWinner
        dec sound
        bne CheckWinner
        lda #0
        sta AUDV0
; A zero winner means keep playing. A nonzero winner freezes the
; match logic, while Frame still draws the court and blinking score.
CheckWinner
        lda winner
        beq Play
        rts

; A gives the pitch. Start a short cue.
; A is the pitch argument. These stores configure one TIA audio
; channel. The same value used as volume starts a frame countdown
; in sound; the audio update path turns off volume when it reaches 0.
Tone
        sta AUDF0
        lda #4
        sta AUDC0
        lda #7
        sta AUDV0
        sta sound
        rts

; Update player 0 every frame. AND isolates one bit of SWCHA.
; Direction bits read zero when pressed, so BNE skips a released
; direction. CMP tests a coordinate without changing it.
; The limit checks keep the byte from wrapping past the court.
Play
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
        lda mode
        cmp #1
        bne HumanRight
        jsr MoveComputer
        jmp BallUpdate
HumanRight
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
        bne BallUpdate
        lda p1y
        cmp #70
        beq BallUpdate
        inc p1y
; During a serve, delay counts down once per frame and the ball
; stays put. RTS returns all the way to the frame update caller.
BallUpdate

        lda delay
        beq RallyPace
        dec delay
        rts
; Before three returns, skip every fourth frame. AND #3 gets the
; low two bits of clock, equivalent to clock % 4. After three
; returns, move each frame. Each actual step still covers one unit
; in X, so the equality-based collision tests cannot skip a paddle.
RallyPace
        lda rallyHits
        cmp #3
        bcs MoveBall
        lda clock
        and #3
        beq WaitForStep
; Bytes wrap modulo 256. CLC makes ADC compute just A + velocity.
; For Python integers this is (position + velocity) & 0xFF.
; The byte $FF acts like -1, because adding 255 wraps to one less.
MoveBall
        lda bally
        clc
        adc dy
        sta bally
        cmp #1
        beq FlipY
        cmp #82
        bne MoveX
; Negate the velocity as (~dy + 1) & 0xFF. EOR #$FF flips every
; bit and ADC #1 completes the two's complement negation.
FlipY
        lda dy
        eor #$FF
        clc
        adc #1
        sta dy
; Update X with the same arithmetic. LDX dx sets N from bit 7
; of dx. BMI takes the left-moving case, and A still holds the new
; horizontal coordinate for the edge and paddle comparisons.
MoveX
        lda ballx
        clc
        adc dx
        sta ballx
        ldx dx
        bmi GoingLeft
        cmp #137
        beq HitRight
        cmp #157
        bcs PointLeft
        rts
; Only check the left paddle while the ball heads left, so the
; same collision cannot immediately reverse the ball a second time.
GoingLeft
        cmp #21
        beq HitLeft
        cmp #2
        bcc PointRight
        rts
; Compute (ballY + 1 - paddleY) & 0xFF. The +1 allows the bottom
; row of the two-row ball to overlap the top of the paddle.
HitLeft
        lda bally
        clc
        adc #1
        sec
        sbc p0y
        jmp CheckPaddle
HitRight
        lda bally
        clc
        adc #1
        sec
        sbc p1y
; Use an unsigned comparison to accept offsets 0 through 11.
; Negative offsets wrap to large bytes and fail. The two remaining
; thresholds divide valid contact heights into up, straight, or down.
CheckPaddle
        cmp #12
        bcs Miss
        cmp #4
        bcc AimUp
        cmp #8
        bcs AimDown
        lda #0
        beq SetAngle
AimUp
        lda #$FF
        bne SetAngle
AimDown
        lda #1
; A contains the selected vertical velocity. Save that, add one
; to the rally counter, then reverse dx. JMP Tone is a tail call:
; Tone's RTS returns to the caller of the current update.
SetAngle
        inc rallyHits
        sta dy
        lda dx
        eor #$FF
        clc
        adc #1
        sta dx
        lda #8
        jmp Tone
Miss
WaitForStep
        rts
; The ball passed the right edge, so the left player gets a point.
; Set winner only when the score reaches the match limit.
PointLeft
        inc score0
        lda score0
        cmp #11
        bne NextServe
        lda #1
        sta winner
        bne NextServe
; The opposite edge awards a point to player 1. Zero means no
; winner, so the winner values are 1 for left and 2 for right.
PointRight
        inc score1
        lda score1
        cmp #11
        bne NextServe
        lda #2
        sta winner
; Recenter the paddles and ball and play the point sound. If
; winner is already set, the next update will leave play frozen.
NextServe
        jsr Serve
        lda #19
        jmp Tone
; This is a small state reset for a new point. Ball coordinates,
; vertical velocity, the rally counter, and the pause all reset.
; The horizontal direction stays as it was when the point ended.
Serve
        lda #0
        sta rallyHits
        lda #38
        sta p0y
        sta p1y
        lda #74
        sta ballx
        lda #41
        sta bally
        lda #1
        sta dy
        lda #45
        sta delay
        rts

; Port 0 directions choose a mode and Fire confirms it.
; Directions and Fire are separate inputs. The direction masks test
; two active-low bits at once, allowing Left or Up for 1P and Right
; or Down for 2P. menuChoice is the highlight, while mode stays 0
; until the player confirms.
UpdateMenu
        lda SWCHA
        and #$50               ; Left or Up
        cmp #$50
        beq MenuCheckRight
        lda #1
        sta menuChoice
        bne MenuCheckFire
MenuCheckRight
        lda SWCHA
        and #$A0               ; Right or Down
        cmp #$A0
        beq MenuCheckFire
        lda #2
        sta menuChoice
; BIT copies input bit 7 to N without changing A. BMI means Fire
; is released. While the lock is set, a held Fire does nothing.
; Once unlocked, copy menuChoice into mode and begin the match.
MenuCheckFire
        bit INPT4
        bmi MenuReleased
        lda menuFireLock
        bne MenuInputDone
        lda menuChoice
        sta mode
        jmp StartMatch
; Reading a release unlocks confirmation. In particular, Reset
; with Fire held will keep the menu up until Fire is released.
MenuReleased
        lda #0
        sta menuFireLock
MenuInputDone
        rts

; Move at half speed, chasing incoming balls and returning to center
; when the ball is traveling away.
; The CPU paddle gets one move every other frame. AND #1 is
; clock % 2 in Python. If dx is negative, target the court's center;
; otherwise target the incoming ball's current Y coordinate.
MoveComputer
        lda clock
        and #1
        bne ComputerDone
        lda #42
        ldx dx
        bmi TrackTarget
        lda bally
; Compute paddleCenter minus target, then add 2. If negative,
; the paddle is above the target and should move down. If the
; adjusted difference is 0 through 4, it is close enough. Otherwise
; move up. Here the difference stays within signed byte range, so
; BMI on the adjusted result works as a signed comparison to zero.
TrackTarget
        sta cpuTarget
        lda p1y
        clc
        adc #5
        sec
        sbc cpuTarget
        clc
        adc #2
        bmi ComputerDown
        cmp #5
        bcc ComputerDone
        lda p1y
        cmp #4
        beq ComputerDone
        dec p1y
ComputerDone
        rts
; Increasing Y moves down. The same bottom limit as the human
; paddle prevents the CPU from moving outside the court.
ComputerDown
        lda p1y
        cmp #70
        beq ComputerDone
        inc p1y
        rts

        ORG $F600
; The menu and match each render exactly 192 visible lines.
; Keeping both kernels on the same frame budget prevents a timing
; change when the player switches from one to the other.
WaitMenuBlank
        lda INTIM
        bne WaitMenuBlank
        sta WSYNC
        sta VBLANK
        lda #2                 ; PF color follows the player on each half
        sta CTRLPF
        lda menuChoice
        cmp #1
        beq HighlightOne
        lda #4
        sta COLUP0
        bne MenuTop
HighlightOne
        lda #4
        sta COLUP1
; The selected option keeps its normal white player color.
; The other option is dimmed. The TIA's score-color mode applies
; the left and right player colors to the two halves of PF1.
MenuTop
        ldx #72
MenuTopLine
        sta WSYNC
        dex
        bne MenuTopLine
        ldx #27
; The two ROM tables hold pixel masks for 1P and 2P. Draw the
; left half first. NOPs delay the second PF1 write until the beam
; has passed it, so the same register can draw different letters
; on the two halves. NOP is useful here because timing is visible.
MenuLetterLine
        lda MenuLeft,x
        sta PF1
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        lda MenuRight,x
        sta PF1
        sta WSYNC
        dex
        bpl MenuLetterLine
        lda #0
        sta PF1
        ldx #92
; Count the remaining blank lines, then jump to the same
; overscan routine used by the match kernel.
MenuBottomLine
        sta WSYNC
        dex
        bne MenuBottomLine
        jmp EndPicture

; Each glyph row repeats across four scanlines. The tables are
; ordered bottom to top because X counts downward from 27.
MenuLeft
        .byte $e8,$e8,$e8,$e8
        .byte $48,$48,$48,$48
        .byte $48,$48,$48,$48
        .byte $4c,$4c,$4c,$4c
        .byte $4a,$4a,$4a,$4a
        .byte $ca,$ca,$ca,$ca
        .byte $4c,$4c,$4c,$4c
; The masks here form 2P. The right half uses unreflected PF1
; in this menu, so both tables use the same left-to-right bit order.
MenuRight
        .byte $e8,$e8,$e8,$e8
        .byte $88,$88,$88,$88
        .byte $88,$88,$88,$88
        .byte $ec,$ec,$ec,$ec
        .byte $2a,$2a,$2a,$2a
        .byte $2a,$2a,$2a,$2a
        .byte $ec,$ec,$ec,$ec

        ORG $F800
; The loop counts X from 20 down to 0, so store this mapping in
; reverse order. Repeating a row three times makes the digits taller.
ScoreLineRows
        .byte 6,6,6,5,5,5,4,4,4,3,3,3,2,2,2,1,1,1,0,0,0

; PF2 is shifted in opposite directions on the two halves of a
; reflected playfield. Keep two empty columns next to the center.
; One fixed-width array per side. Each score uses eight bytes.
; The first seven are row masks; the last is padding for easy indexing.
; Entries represent scores 0 through 11 and a blank glyph at 12.
LeftDigits
        .byte $38,$28,$28,$28,$28,$28,$38,$00
        .byte $10,$18,$10,$10,$10,$10,$38,$00
        .byte $38,$20,$20,$38,$08,$08,$38,$00
        .byte $38,$20,$20,$38,$20,$20,$38,$00
        .byte $28,$28,$28,$38,$20,$20,$20,$00
        .byte $38,$08,$08,$38,$20,$20,$38,$00
        .byte $38,$08,$08,$38,$28,$28,$38,$00
        .byte $38,$20,$20,$20,$20,$20,$20,$00
        .byte $38,$28,$28,$38,$28,$28,$38,$00
        .byte $38,$28,$28,$38,$20,$20,$38,$00
        .byte $38,$2A,$2A,$2A,$2A,$2A,$3A,$00
        .byte $10,$1A,$12,$12,$12,$12,$3A,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00
; Pack the same glyphs in the bit order used on the reflected
; right half of the screen. This prevents mirrored numerals.
RightDigits
        .byte $0E,$0A,$0A,$0A,$0A,$0A,$0E,$00
        .byte $04,$0C,$04,$04,$04,$04,$0E,$00
        .byte $0E,$02,$02,$0E,$08,$08,$0E,$00
        .byte $0E,$02,$02,$0E,$02,$02,$0E,$00
        .byte $0A,$0A,$0A,$0E,$02,$02,$02,$00
        .byte $0E,$08,$08,$0E,$02,$02,$0E,$00
        .byte $0E,$08,$08,$0E,$0A,$0A,$0E,$00
        .byte $0E,$02,$02,$02,$02,$02,$02,$00
        .byte $0E,$0A,$0A,$0E,$0A,$0A,$0E,$00
        .byte $0E,$0A,$0A,$0E,$02,$02,$0E,$00
        .byte $0E,$2A,$2A,$2A,$2A,$2A,$2E,$00
        .byte $04,$2C,$24,$24,$24,$24,$2E,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00

; Three 16-bit vector slots occupy the last six bytes of the ROM.
; The middle slot is the reset vector at $FFFC. .word writes the
; little-endian address of Start into each slot.
        ORG $FFFA
        .word Start
        .word Start
        .word Start
