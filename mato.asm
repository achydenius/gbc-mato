INCLUDE "hardware.inc"

LCDCF_ON_BIT        EQU 7
JOYPAD_RIGHT_BIT    EQU 0
JOYPAD_LEFT_BIT     EQU 1
JOYPAD_UP_BIT       EQU 2
JOYPAD_DOWN_BIT     EQU 3

BG_TILE_INDEX       EQU 0
SNAKE_TILE_INDEX    EQU 1

TICK_DIVIDER        EQU $F

; Load a word from memory address
; \1 = Memory address to the first byte
; \2 = Register for storing the high byte
; \3 = Register for storing the low byte
LoadWord:\
    MACRO
    ld a, [\1]
    ld \2, a
    ld a, [\1+1]
    ld \3, a
    ENDM

; Load a word from hl register, also increment hl
; \1 = Register for storing the high byte
; \2 = Register for storing the low byte
LoadWordHLI:\
    MACRO
    ld a, [hl+]
    ld \1, a
    ld a, [hl+]
    ld \2, a
    ENDM

; Store a word to memory address
; \1 = High byte
; \2 = Low byte
; \3 = Memory address for storing the word
StoreWord:\
    MACRO
    ld a, \1
    ld [\3], a
    ld a, \2
    ld [\3+1], a
    ENDM

SECTION "Header", ROM0[$100]
    jp Start

SECTION "Code", ROM0[$150]
Start:
    di                              ; Disable interrupts

    StoreWord $0, $4, Length        ; Set length to 4
    StoreWord $2, $3, Coords        ; Set coordinates to [(3, 2), (3, 1), (2, 1), (1, 1)]
    StoreWord $1, $3, Coords+2
    StoreWord $1, $2, Coords+4
    StoreWord $1, $1, Coords+6

    ld a, $0                        ; Zero ticks
    ld [Ticks], a

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

    ; Draw initial state
    call WaitVBlank

    LoadWord Length, d, e           ; de = Loop counter
    ld hl, Coords
.drawCoord:
    LoadWordHLI b, c

    push hl
    call GetTileAddress
    ld a, SNAKE_TILE_INDEX
    ld [hl], a
    pop hl

    dec de                          ; Loop
    ld a, d
    or e
    jr nz, .drawCoord

    ; Main loop where snake is moving right
Loop:
    call WaitVBlank

    ld hl, Ticks
    inc [hl]

    ld a, [Ticks]                   ; Update snake every nth frame
    and a, TICK_DIVIDER
    jr nz, Loop

    ; Update coordinates
    LoadWord Length, d, e           ; de = Loop counter (Length-1)
    dec de
    ld hl, Coords                   ; Get address to the last coordinate pair
    add hl, de
    add hl, de

    ; Clear last coordinate
    push hl
    LoadWordHLI b, c
    call GetTileAddress
    ld a, BG_TILE_INDEX
    ld [hl], a
    pop hl

    dec hl                          ; hl = Address to second last x-coordinate
.update:
    ld b, h                         ; bc = Address to next x-coordinate
    ld c, l
    inc bc
    inc bc

    ld a, [hl-]                     ; Replace next coordinate pair with current one
    ld [bc], a
    dec bc
    ld a, [hl-]
    ld [bc], a

    dec de                          ; Loop
    ld a, d
    or e
    jr nz, .update

    ; Update head
    ; TODO: Replace with current direction
    inc hl
    inc hl
    inc [hl]

    ; Draw updated first coordinate
    LoadWord Coords, b, c
    call GetTileAddress
    ld a, SNAKE_TILE_INDEX
    ld [hl], a

    jr Loop

; Get address of a tile in tilemap
; b = y-coordinate
; c = x-coordinate
; Returns the address in hl
GetTileAddress:
    push bc

    ld h, $0
    ld l, b
    REPT 5                          ; Multiply y coordinate by 32 since each row consists of 32 tiles
    add hl, hl
    ENDR

    ld b, $0                        ; Add x coordinate
    add hl, bc

    ld bc, _SCRN0                   ; Add tilemap base address
    add hl, bc

    pop bc
    ret

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
Ticks:  DS 1
VariablesEnd:
