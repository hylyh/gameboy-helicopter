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

  ld hl, Sprite                 ; Load the tile data into Vram
  ld de, _VRAM
  ld bc, 8*2
  call mem_CopyMono

  ld a, 0                       ; Clear sprite table
  ld hl, _OAMDATA
  ld bc, _OAMDATALENGTH
  call mem_Set

  call StartLCD                 ; Free to start the LCD again

  ld a, 0                       ; Clear screen (ascii for blank space)
  ld hl, _SCRN0
  ld bc, SCRN_VX_B*SCRN_VY_B    ; width * height
  call mem_SetVRAM

initsprite:
  ld a, 64                      ; Initialize sprite values
  ld [AirplaneYPos], a
  ld a, 8
  ld [AirplaneXPos], a
  ld a, 1
  ld [AirplaneTileNum], a
  ld a, %00000000
  ld [AirplaneAttrs], a

loop:
  halt
  nop                           ; Always need nop after halt

  call getinput

  ld a, [AirplaneXPos]          ; Get current x pos
  inc a
  ld [AirplaneXPos], a          ; Move right by one

  ld a, [_INPUT]                ; Check keys

  push af                       ; Avoid clobbering a with the and

  and PADF_UP                   ; See if up is pressed
  call nz, moveup

  pop af

  and PADF_DOWN                 ; See if down is pressed
  call nz, movedown

  jr loop

moveup:
  push af

  ld a, [AirplaneYPos]
  dec a
  ld [AirplaneYPos], a

  pop af
  ret

movedown:
  push af

  ld a, [AirplaneYPos]
  inc a
  ld [AirplaneYPos], a

  pop af
  ret

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

Sprite:
  DB %00000000                  ; Blank
  DB %00000000
  DB %00000000
  DB %00000000
  DB %00000000
  DB %00000000
  DB %00000000
  DB %00000000

  DB %00000000                  ; Airplane!
  DB %00010000
  DB %01010000
  DB %01111100
  DB %01111100
  DB %00010000
  DB %00010000
  DB %00000000
