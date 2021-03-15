INCLUDE "hardware.inc"

LCDCF_ON_BIT        EQU 7
JOYPAD_RIGHT_BIT    EQU 0
JOYPAD_LEFT_BIT     EQU 1
JOYPAD_UP_BIT       EQU 2
JOYPAD_DOWN_BIT     EQU 3

SECTION "Header", ROM0[$100]
    jp Start

SECTION "Code", ROM0[$150]
Start:
    di                              ; Disable interrupts

    ld hl, Variables                ; Set all variables to zero
    ld bc, VariablesEnd-Variables
.clearByte:
    xor a, a
    ld [hl+], a
    dec bc
    ld a, c
    or b
    jr nz, .clearByte

    ld a, $0                        ; Set up test data for snake
    ld [Length], a
    ld a, $3
    ld [Length+1], a
    ld hl, TmpData
    ld bc, Coords
    ld d, $6
.copyCoord:
    ld a, [hl+]
    ld [bc], a
    inc bc
    dec d
    jr nz, .copyCoord

    call WaitVBlank                 ; Turn off LCD
    ld hl, rLCDC
    res LCDCF_ON_BIT, [hl]

    ld a, BCPSF_AUTOINC
    ldh [rBCPS], a                  ; Set first palette color to white
    ld a, $FF
    ld [rBCPD], a
    ld a, $7F
    ld [rBCPD], a
    xor a, a                        ; and second palette color to black
    ld [rBCPD], a
    ld [rBCPD], a

    ld b, $8                        ; Set second tile's all pixels to second color
    ld hl, _VRAM+$10
.setPixelRow
    ld a, $FF
    ld [hl+], a
    ld a, $0
    ld [hl+], a
    dec b
    jr nz, .setPixelRow

    ld hl, rLCDC                    ; Turn on LCD
    set LCDCF_ON_BIT, [hl]

Loop:
    call WaitVBlank

    call ReadArrowKeys              ; Read arrow keys to a
    bit JOYPAD_RIGHT_BIT, a
    jr z, .testDown
.testDown:
    bit JOYPAD_DOWN_BIT, a
    jr z, .testLeft
.testLeft:
    bit JOYPAD_LEFT_BIT, a
    jr z, .endTest

.endTest:
    ld a, [Length]
    ld d, a
    ld a, [Length+1]
    ld e, a

    ld hl, Coords
.drawCoord:
    ld a, [hl+]
    ld b, a
    ld a, [hl+]
    ld c, $1

    call SetTile

    dec de
    ld a, e
    or d
    jr nz, .drawCoord

    jr Loop

; Set tile in tilemap
; a = x-coordinate
; b = y-coordinate
; c = Tile number
; Overwrites a
SetTile:
    push hl
    push de

    ld h, $0
    ld l, b
    REPT 5                          ; Multiply y coordinate by 32 since each row consists of 32 tiles
    add hl, hl
    ENDR

    ld d, $0                        ; Add x coordinate
    ld e, a
    add hl, de

    ld de, _SCRN0                   ; Add tilemap base address
    add hl, de
    ld a, c                         ; Set the tile
    ld [hl], a

    pop de
    pop hl

; Return arrow keys state in register a
ReadArrowKeys:
    ld a, ~P1F_4
    ldh [rP1], a
    ldh a, [rP1]
    cpl                             ; Complement bits so that set bit indicates a pressed key
    ret

; Wait until start of next vblank
; Overwrites a
WaitVBlank:
    ld a, [rLY]
    cp a, $90
    jr nz, WaitVBlank
    ret

SECTION "Data", ROM0, ALIGN[4]
BGColor:    DW ($1F << 10) | ($1F << 5) | $1F
WormColor:  DW 0
TmpData:    DB 1, 1, 1, 2, 1, 3

SECTION "Variables", WRAM0[$C000]
Variables:
Length: DS 2
Coords: DS 20 * 18 * 2
VariablesEnd:
