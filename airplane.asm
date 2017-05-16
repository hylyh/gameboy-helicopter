INCLUDE "includes/gbhw.inc"
INCLUDE "includes/ibmpc1.inc"

_DMACODE EQU $FF80
_OAMDATA EQU _RAM               ; Must be a multiple of $100
_OAMDATALENGTH EQU $A0
_INPUT EQU _OAMDATA+_OAMDATALENGTH ; Put input data at the end of the oam data

; Bullet data - 1 byte: 0 if not active, otherwise it is
_MAXBULLETS EQU 15
_BULLETDATA EQU _INPUT+1        ; Store the bullet data at once past input
_BULLETEDATALENGTH EQU _MAXBULLETS*1 ; Only one byte of data for now


                RSSET _RAM      ; Base location is _RAM
AirplaneYPos    RB 1            ; Set each to an incrementing location
AirplaneXPos    RB 1
AirplaneTileNum RB 1
AirplaneAttrs   RB 1
BulletSpriteStart RB 1          ; Should be the last one

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

  call initbullets

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

  call updatebullets

  jr loop

moveup:
  push af

  ld a, [AirplaneYPos]

  cp 16                         ; If the y position is 16 already, return
  jr z, .popret

  dec a                         ; Move up
  ld [AirplaneYPos], a
.popret:
  pop af
  ret

movedown:
  push af

  ld a, [AirplaneYPos]

  cp 152                        ; If the y position is 144, return
  jr z, .popret

  inc a                         ; Move down
  ld [AirplaneYPos], a
.popret:
  pop af
  ret

shoot:
  push af
  push bc
  push hl

  call getinactivebullet          ; Get an active bullet into h
  ld b, h                         ; Save this
  jr z, .skipshoot                ; Skip if there are no active bullets

  call getbulletsprite

  ld a, [AirplaneYPos]
  ld [hl], a                    ; Set to the airplane's y

  inc l
  ld a, [AirplaneXPos]
  ld [hl], a                    ; Set to the airplane's x

  ld h, b
  call getbulletdata
  ld [hl], 1                    ; Activate the bullet

.skipshoot:
  pop hl
  pop bc
  pop af
  ret

; Bullet stuff
initbullets:
  push af
  push bc
  push hl

  ld a, _MAXBULLETS
  ld b, a                       ; How many times to loop
.initloop:
  dec b                         ; Decrement bullet #

  ld h, b                       ; Put bullet # into b to get the sprite start
  call getbulletsprite          ; Sprite start location now in hl

  ld [hl], 32                    ; Y Pos
  inc l
  ld [hl], 13                    ; X pos
  inc l
  ld [hl], 4                     ; Tile num
  inc l
  ld [hl], %00000000             ; Sprite attrs

  ld h, b
  call getbulletdata             ; Get bullet data start in hl

  ld [hl], 0                     ; Bullet not active

  ld a, b
  cp 0
  jr nz, .initloop               ; If bullet # is not 0, loop again

  pop hl
  pop bc
  pop af
  ret

; Move all active bullets
updatebullets:
  push af
  push bc
  push hl

  ld a, _MAXBULLETS
  ld b, a                       ; How many times to loop

.updateloop:
  dec b

  ld h, b
  call getbulletdata

  ld a, [hl]
  cp 0
  jr z, .skipmove               ; If the bullet is not active, dont move it

  ld h, b
  call getbulletsprite
  inc l                         ; X pos

  ld a, [hl]
  inc a
  ld [hl], a                    ; Do move

  cp 168                        ; If deactivate if off screen to the right
  jr nz, .skipmove

  ld h, b
  call getbulletdata
  ld [hl], 0                    ; Deactivate

.skipmove:
  ld a, b
  cp 0
  jr nz, .updateloop            ; Loop if not the last bullet

  pop hl
  pop bc
  pop af
  ret

; Get the bullet sprite start location for the bullet # specified in register h, returns in register hl
getbulletsprite:
  push bc

  ld b, 0
  ld c, h

  ld hl, BulletSpriteStart
  add hl, bc
  add hl, bc
  add hl, bc
  add hl, bc                    ; SpriteStart + h * 4

  pop bc
  ret

; Get the bullet data start location for the bullet # specified in register h, returns in register hl
getbulletdata:
  push bc

  ld b, 0
  ld c, h

  ld hl, _BULLETDATA
  add hl, bc                    ; DataStart + h * 1

  pop bc
  ret

; Get the index of the first inactive bullet in h, if there isn't one, the z flag will be set
getinactivebullet:
  push af
  push bc

  ld a, _MAXBULLETS
  ld b, a                       ; How many times to loop
.getinactiveloop:
  dec b

  ld h, b
  call getbulletdata
  ld a, [hl]

  cp 1                          ; Is bullet active
  jr z, .continue               ; Skip if so

  ld h, b
  jr .popret                    ; Got what we needed, return

.continue:
  ld a, b
  cp 0
  jr nz, .getinactiveloop         ; Loop if not last bullet

.popret:
  pop bc
  pop af
  ret

; End bullet stuff

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
