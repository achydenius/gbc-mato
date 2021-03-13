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

Loop:
    call WaitVBlank

    call ReadArrowKeys              ; Read arrow keys to a
    ld c, $0                        ; and set default color offset to c

    bit JOYPAD_RIGHT_BIT, a
    jr z, .testDown
    ld c, $2
.testDown:
    bit JOYPAD_DOWN_BIT, a
    jr z, .testLeft
    ld c, $4
.testLeft:
    bit JOYPAD_LEFT_BIT, a
    jr z, .setColor
    ld c, $6
.setColor:
    ld hl, Colors                   ; Calculate color address
    ld b, $0
    add hl, bc

    ld a, BCPSF_AUTOINC             ; Set background color
    ldh [rBCPS], a
    ld a, [hl+]
    ldh [rBCPD], a
    ld a, [hl]
    ldh [rBCPD], a

    jr Loop

; Return arrow keys state in register a
ReadArrowKeys:
    ld a, ~P1F_4
    ldh [rP1], a
    ldh a, [rP1]
    cpl                             ; Complement bits so that set bit indicates a pressed key
    ret

; Wait until start of next vblank
WaitVBlank:
    ld a, [rLY]
    cp a, $90
    jr nz, WaitVBlank
    ret

SECTION "Data", ROM0, ALIGN[4]
Colors:
    DW ($1F << 10) | ($1F << 5) | $1F
    DW $1F
    DW $1F << 5
    DW $1F << 10
