INCLUDE "includes/gbhw.inc"
INCLUDE "includes/ibmpc1.inc"

_DMACODE EQU $FF80
_OAMDATA EQU _RAM               ; Must be a multiple of $100
_OAMDATALENGTH EQU $A0
_INPUT EQU _OAMDATA+_OAMDATALENGTH ; Put input data at the end of the oam data

                RSSET _RAM      ; Base location is _RAM
AirplaneYPos    RB 1            ; Set each to an incrementing location
AirplaneXPos    RB 1
AirplaneTileNum RB 1
AirplaneAttrs   RB 1
BulletYPos    RB 1
BulletXPos    RB 1
BulletTileNum RB 1
BulletAttrs   RB 1

SECTION "Vblank",ROM0[$0040]
  jp _DMACODE
SECTION "LCDC",ROM0[$0048]
  reti
SECTION "Time_Overflow",ROM0[$0050]
  reti
SECTION "Serial",ROM0[$0058]
  reti
SECTION "p1thru4",ROM0[$0060]
  reti

SECTION "start",ROM0[$0100]
  nop
  jp main

  ROM_HEADER ROM_NOMBC, ROM_SIZE_32KBYTE, RAM_SIZE_0KBYTE

INCLUDE "includes/memory.asm"

main:
  nop
  di                            ; disable interrupts
  ld sp, $ffff                  ; set the stack pointer to the highest memory location

  call initdma                  ; move dma code to hram

  ld a, IEF_VBLANK              ; enable the vblank interrupt
  ld [rIE], a

  ei                            ; re-enable interrupts

initscreen:
  ld a, %11100100               ; Palette colors, darkest to lightest

  ld [rBGP], a                  ; Set background palette
  ldh [rOBP0],a                 ; Set sprite palette 0
  ldh [rOBP1],a                 ; And palette 1

  ld a, 0                       ; Set background scroll position to upper left
  ld [rSCX], a
  ld [rSCY], a

  call StopLCD                  ; Need to stop LCD before loading vram

  ld hl, Sprites                ; Load the tile data into Vram
  ld de, _VRAM
  ld bc, 16*5
  call mem_Copy

  ld a, 0                       ; Clear sprite table
  ld hl, _OAMDATA
  ld bc, _OAMDATALENGTH
  call mem_Set

  call StartLCD                 ; Free to start the LCD again

  ld a, 2                       ; Clear screen with background tile
  ld hl, _SCRN0
  ld bc, SCRN_VX_B*SCRN_VY_B    ; width * height
  call mem_SetVRAM

initsprite:
  ld a, 64                      ; Initialize airplane sprite
  ld [AirplaneYPos], a
  ld a, 16
  ld [AirplaneXPos], a
  ld a, 1
  ld [AirplaneTileNum], a
  ld a, %00000000
  ld [AirplaneAttrs], a

  ld a, 64                      ; Initialize bullet
  ld [BulletYPos], a
  ld a, 16
  ld [BulletXPos], a
  ld a, 4
  ld [BulletTileNum], a
  ld a, %00000000
  ld [BulletAttrs], a

loop:
  halt
  nop                           ; Always need nop after halt

  call getinput

  ld a, [rSCX]                  ; Scroll background
  inc a
  ld [rSCX], a

  ld a, [_INPUT]                ; Check keys

  push af                       ; Avoid clobbering a with the and

  and PADF_UP                   ; See if up is pressed
  call nz, moveup

  pop af
  push af                       ; Don't clobber the a again

  and PADF_DOWN                 ; See if down is pressed
  call nz, movedown

  pop af

  and PADF_A
  call nz, shoot

  ld a, [BulletXPos]            ; Move bullet to the right
  inc a
  ld [BulletXPos], a

  jr loop

moveup:
  push af

  ld a, [AirplaneYPos]

  cp 16                         ; If the y position is 16 already, return
  jr z, .retpop

  dec a                         ; Move up
  ld [AirplaneYPos], a
.retpop:
  pop af
  ret

movedown:
  push af

  ld a, [AirplaneYPos]

  cp 152                        ; If the y position is 144, return
  jr z, .retpop

  inc a                         ; Move down
  ld [AirplaneYPos], a
.retpop:
  pop af
  ret

shoot:
  push af

  ld a, [AirplaneYPos]
  ld [BulletYPos], a

  ld a, [AirplaneXPos]
  ld [BulletXPos], a

  pop af

getinput:
  push af
  push bc

  ld a, %00100000               ; select bit 5 for button keys
  ld [rP1], a


  ld a, [rP1]                   ; Read several times to let the values straighten out
  ld a, [rP1]
  ld a, [rP1]
  ld a, [rP1]

  and $0F                       ; take the bottom four bits
  swap a                        ; swap upper and lower
  ld b, a                       ; save button input in b

  ld a, %00010000               ; choose bit 4 for joystick
  ld [rP1], a

  ld a, [rP1]                   ; Read several times to let the values straighten out
  ld a, [rP1]
  ld a, [rP1]
  ld a, [rP1]

  and $0F                       ; take the bottom four bits
  or  b                         ; combine with the button input saved in b

  cpl                           ; inverse the bits so that 1 is pressed

  ld [_INPUT], a                ; save the result

  pop bc
  pop af
  ret

; DMA stuff
initdma:
  ld de, _DMACODE               ; Copy the dma code to hram
  ld hl, dmacode
  ld bc, dmaend-dmacode
  call mem_CopyVRAM
  ret

dmacode:                        ; Initiate a DMA transfer from _RAM
  push af
  ld a, _RAM/$100               ; First two bytes of transfer start location
  ldh [rDMA], a                 ; Start DMA transfer
  ld a, $28                     ; How many loops to wait

dma_wait:                       ; Wait for transfer to finish
  dec a
  jr nz, dma_wait
  pop af
  reti

dmaend:
; End DMA stuff

; If the lcd is on, wait for vblank then turn it off
StopLCD:
  ld a, [rLCDC]
  rlca                          ; Put the high bit of LCDC into the carry flag

  ret nc                        ; If screen is already off, exit

; Loop until vblank
stoplcd_wait:
  ld a, [rLY]                   ; Get LCDC y coord
  cp 145                        ; Is it on line 145?
  jr nz, stoplcd_wait           ; if not, keep waiting

  ld a, [rLCDC]                 ; Get the current LCDC val
  res 7, a                      ; reset bit 7
  ld [rLCDC], a                 ; and put it back

  ret

; Start up the LCD with required flags
StartLCD:
  ld a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ8|LCDCF_OBJON
  ld [rLCDC], a
  ret

Sprites:
  DB %00000000,%00000000        ; Blank
  DB %00000000,%00000000
  DB %00000000,%00000000
  DB %00000000,%00000000
  DB %00000000,%00000000
  DB %00000000,%00000000
  DB %00000000,%00000000
  DB %00000000,%00000000

  DB %00000000,%00000000        ; Airplane!
  DB %00001000,%00001000
  DB %01001000,%01001000
  DB %01111110,%01111110
  DB %01111110,%01111110
  DB %00001000,%00001000
  DB %00001000,%00001000
  DB %00000000,%00000000

  DB %01000000,%00000000        ; Background tile
  DB %00000100,%00000000
  DB %00010000,%00000000
  DB %00000010,%00000000
  DB %00000000,%00000000
  DB %01000000,%00000000
  DB %00000000,%00000000
  DB %00100000,%00000000

  DB %00000000,%00000000        ; Enemy
  DB %00000000,%00011000
  DB %00000000,%00100100
  DB %00000000,%01011010
  DB %00000000,%01011010
  DB %00000000,%00100100
  DB %00000000,%00011000
  DB %00000000,%00000000

  DB %00000000,%00000000        ; Bullet
  DB %00000000,%00000000
  DB %00000000,%00000000
  DB %00011000,%00011000
  DB %00011000,%00011000
  DB %00000000,%00000000
  DB %00000000,%00000000
  DB %00000000,%00000000
