        processor 6502
; Pong 1972 | NTSC, 4 KiB cartridge

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

        SEG.U RAM
        ORG $80
score0 ds 1
score1 ds 1
winner ds 1
sound ds 1
row ds 1
gfx0 ds 1
gfx1 ds 1
enable0 ds 1
enable1 ds 1
netEnable ds 1
leftDigitBase ds 1
rightDigitBase ds 1
clock ds 1
rallyHits ds 1
p0y ds 1
p1y ds 1
ballx ds 1
bally ds 1
dx ds 1
dy ds 1
delay ds 1
mode ds 1                ; 0 = menu, 1 = computer, 2 = two players
menuChoice ds 1
menuFireLock ds 1
cpuTarget ds 1

        SEG CODE
        ORG $F000
Start
        sei
        cld
        ldx #$FF
        txs
        lda #0
        ldx #127
ClearRAM
        sta $80,x
        dex
        bpl ClearRAM
        ldx #$2C
ClearTIA
        sta $00,x
        dex
        bpl ClearTIA
        lda #2
        sta VBLANK
        jsr ResetGame
        sta WSYNC
Frame
        lda #2
        sta VSYNC
        sta WSYNC
        sta WSYNC
        sta WSYNC
        lda #0
        sta VSYNC
        lda #43
        sta TIM64T
        inc clock
        jsr Update
        lda #$0E
        sta COLUP0
        sta COLUP1
        sta COLUPF
        lda #0
        sta COLUBK
        lda #1
        sta CTRLPF
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
BlinkLeft
        lda #12
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
BlinkRight
        lda #12
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
        sta WSYNC
        sta HMOVE
        sta CXCLR
        lda mode
        bne WaitBlank
        jmp WaitMenuBlank
WaitBlank
        lda INTIM
        bne WaitBlank
        sta WSYNC
        sta VBLANK

; Each of the seven numeral rows is three scanlines high. PF1 switches
; from left to right data after the beam has passed the first copy.
        ldx #20
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
Court
        lda gfx0
        sta GRP0
        lda gfx1
        sta GRP1
        lda enable0
        sta ENABL
        lda netEnable
        sta ENAM0
        inc row
        lda row
        sec
        sbc p0y
        cmp #11
        lda #0
        bcs LeftGraphic
        lda #$C0
LeftGraphic
        sta gfx0
        lda row
        sec
        sbc p1y
        cmp #11
        lda #0
        bcs RightGraphic
        lda #$C0
RightGraphic
        sta gfx1
        sta WSYNC
        lda row
        sec
        sbc bally
        cmp #2
        lda #0
        bcs BallGraphic
        lda #2
BallGraphic
        sta enable0
        ; Missile 0 is one color clock wide. Two logical rows per dash.
        lda row
        and #3
        cmp #2
        lda #0
        bcs NetGraphic
        lda #2
NetGraphic
        sta netEnable
        lda row
        cmp #85
        sta WSYNC
        bcc Court
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
Overscan
        sta WSYNC
        dex
        bne Overscan
        jmp Frame

; A = x coordinate, X = TIA object index (players, missiles, then ball).
; Coarse steps are five CPU cycles, or fifteen color clocks.
PositionX
        sec
        sta WSYNC
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

ResetGame
        lda #0
        sta mode
        lda #1
        sta menuChoice
        sta menuFireLock
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
CheckWinner
        lda winner
        beq Play
        rts

; A gives the pitch. Start a short cue.
Tone
        sta AUDF0
        lda #4
        sta AUDC0
        lda #7
        sta AUDV0
        sta sound
        rts

Play
        lda SWCHA
        and #$10
        bne P0Down
        lda p0y
        cmp #4
        beq P0Down
        dec p0y
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
P1Down
        lda SWCHA
        and #$02
        bne BallUpdate
        lda p1y
        cmp #70
        beq BallUpdate
        inc p1y
BallUpdate

        lda delay
        beq RallyPace
        dec delay
        rts
RallyPace
        lda rallyHits
        cmp #3
        bcs MoveBall
        lda clock
        and #3
        beq WaitForStep
MoveBall
        lda bally
        clc
        adc dy
        sta bally
        cmp #1
        beq FlipY
        cmp #82
        bne MoveX
FlipY
        lda dy
        eor #$FF
        clc
        adc #1
        sta dy
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
GoingLeft
        cmp #21
        beq HitLeft
        cmp #2
        bcc PointRight
        rts
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
PointLeft
        inc score0
        lda score0
        cmp #11
        bne NextServe
        lda #1
        sta winner
        bne NextServe
PointRight
        inc score1
        lda score1
        cmp #11
        bne NextServe
        lda #2
        sta winner
NextServe
        jsr Serve
        lda #19
        jmp Tone
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
MenuCheckFire
        bit INPT4
        bmi MenuReleased
        lda menuFireLock
        bne MenuInputDone
        lda menuChoice
        sta mode
        jmp StartMatch
MenuReleased
        lda #0
        sta menuFireLock
MenuInputDone
        rts

; Move at half speed, chasing incoming balls and returning to center
; when the ball is traveling away.
MoveComputer
        lda clock
        and #1
        bne ComputerDone
        lda #42
        ldx dx
        bmi TrackTarget
        lda bally
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
ComputerDown
        lda p1y
        cmp #70
        beq ComputerDone
        inc p1y
        rts

        ORG $F600
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
MenuTop
        ldx #72
MenuTopLine
        sta WSYNC
        dex
        bne MenuTopLine
        ldx #27
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
MenuBottomLine
        sta WSYNC
        dex
        bne MenuBottomLine
        jmp EndPicture

MenuLeft
        .byte $e8,$e8,$e8,$e8
        .byte $48,$48,$48,$48
        .byte $48,$48,$48,$48
        .byte $4c,$4c,$4c,$4c
        .byte $4a,$4a,$4a,$4a
        .byte $ca,$ca,$ca,$ca
        .byte $4c,$4c,$4c,$4c
MenuRight
        .byte $e8,$e8,$e8,$e8
        .byte $88,$88,$88,$88
        .byte $88,$88,$88,$88
        .byte $ec,$ec,$ec,$ec
        .byte $2a,$2a,$2a,$2a
        .byte $2a,$2a,$2a,$2a
        .byte $ec,$ec,$ec,$ec

        ORG $F800
ScoreLineRows
        .byte 6,6,6,5,5,5,4,4,4,3,3,3,2,2,2,1,1,1,0,0,0

; PF2 is shifted in opposite directions on the two halves of a
; reflected playfield. Keep two empty columns next to the center.
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

        ORG $FFFA
        .word Start
        .word Start
        .word Start






