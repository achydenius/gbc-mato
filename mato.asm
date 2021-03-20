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

    StoreWord $0, $1, Length        ; Set initial length to 1
    StoreWord $8, $9, Coords        ; Set initial coordinate to center of screen

    ld a, $0                        ; Zero ticks
    ld [Ticks], a

    ld a, $1
    ld [KeyState], a                ; Set direction to right

    call WaitVBlank                 ; Turn off LCD
    ld hl, rLCDC
    res LCDCF_ON_BIT, [hl]

    ld a, BCPSF_AUTOINC
    ldh [rBCPS], a                  ; Set first palette color to white,
    ld a, $FF
    ld [rBCPD], a
    ld a, $7F
    ld [rBCPD], a
    xor a, a                        ; second palette color to black
    ld [rBCPD], a
    ld [rBCPD], a
    ld a, $1F                       ; and third color to red
    ld [rBCPD], a
    ld a, $0
    ld [rBCPD], a

    ld b, $FF                       ; Set second tile's all pixels to second color
    ld c, $0
    ld d, $1
    call CreateSolidTile

    ld b, $0                        ; and third tile's to third color
    ld c, $FF
    ld d, $2
    call CreateSolidTile

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

    ; Main loop
Loop:
    call UpdateKeyState
    call WaitVBlank

    ld hl, Ticks                    ; Increment tick counter
    inc [hl]
    ld a, TICK_DIVIDER              ; Process every nth frame
    and a, [hl]
    jr nz, Loop

    call GetLastCoordAddress        ; Clear the last coordinate
    LoadWordHLI b, c
    call GetTileAddress
    ld a, BG_TILE_INDEX
    ld [hl], a

    LoadWord Coords, b, c           ; Get new head coordinate
    ld a, [KeyState]

    bit JOYPAD_UP_BIT, a
    jr z, .testRight
    dec b
    jr .endTest
.testRight:
    bit JOYPAD_RIGHT_BIT, a
    jr z, .testDown
    inc c
    jr .endTest
.testDown:
    bit JOYPAD_DOWN_BIT, a
    jr z, .testLeft
    inc b
    jr .endTest
.testLeft:
    bit JOYPAD_LEFT_BIT, a
    jr z, .endTest
    dec c
.endTest:
    call UpdateCoords

    LoadWord Coords, b, c           ; Draw updated first coordinate
    call GetTileAddress
    ld a, SNAKE_TILE_INDEX
    ld [hl], a

    jr Loop

; Update snake coordinates
; e.g. [(2, 2), (1, 2), (1, 1)]
; with new head coordinate (3, 2)
; -> [(3, 2), (2, 2), (1, 2)]
;
; b = New head y-coordinate
; c = New head x-coordinate
UpdateCoords:
    ; Update tail
    push bc                         ; Save head coordinates
    call GetLastCoordAddress        ; hl = Address to the second last x-coordinate
    dec hl
    LoadWord Length, b, c           ; bc = Loop counter (Length-1)
    dec bc
    ld a, b
    or c
    jr z, .head                     ; If length is one, update only head
.tail:
    ld d, h                         ; de = Address to next x-coordinate
    ld e, l
    inc de
    inc de

    ld a, [hl-]                     ; Replace next coordinate pair with current one
    ld [de], a
    dec de
    ld a, [hl-]
    ld [de], a

    dec bc                          ; Loop
    ld a, b
    or c
    jr nz, .tail
.head:
    ; Update head
    pop bc
    StoreWord b, c, Coords
    ret

; Get address to last coordinate pair
; Returns the address in hl
; Overwrites bc
GetLastCoordAddress:
    LoadWord Length, b, c
    dec bc
    ld hl, Coords
    add hl, bc
    add hl, bc
    ret

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

; Read and store arrow key state
; TODO: Store only one key press?
UpdateKeyState:
    ld a, ~P1F_4
    ldh [rP1], a
    ldh a, [rP1]
    cpl                             ; Complement bits so that set bit indicates a pressed key
    and $F
    jr z, .return                   ; Update direction only if a key is set
    ld [KeyState], a
.return:
    ret

; b = First bit plane value
; c = Second bit plane value
; d = Tile number
; Overwrites a, hl
CreateSolidTile:
    ld h, $0
    ld l, d
    REPT 4
    add hl, hl
    ENDR
    ld de, _VRAM
    add hl, de
    ld d, $8
.setPixelRow
    ld a, b
    ld [hl+], a
    ld a, c
    ld [hl+], a
    dec d
    jr nz, .setPixelRow
    ret

; Wait until start of next vblank
; Overwrites a
WaitVBlank:
    ld a, [rLY]
    cp a, $90
    jr nz, WaitVBlank
    ret

SECTION "Variables", WRAM0[$C000]
Variables:
Length:     DS 2
Coords:     DS 20 * 18 * 2
Ticks:      DS 1
KeyState:   DS 1
VariablesEnd:
