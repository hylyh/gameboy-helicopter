INCLUDE "includes/gbhw.inc"

_DMACODE EQU $FF80
_OAMDATA EQU _RAM               ; Must be a multiple of $100
_OAMDATALENGTH EQU $A0

_BOOSTAMOUNT EQU $10            ; How much to go up
_MAXFLYSPEED EQU $45
_MAXFALLSPEED EQU $35
_CRASHSPEED EQU $19             ; If you hit a building faster than this you crash
_NUMBUILDINGS EQU 4
_BUILDINGSSIZE EQU _NUMBUILDINGS*2 ; 2 bytes per

            RSSET _OAMDATA      ; Base location is _OAMDATA
HeloYPos    RB 1                ; Set each to an incrementing location
HeloXPos    RB 1
HeloTileNum RB 1
HeloAttrs   RB 1

             RSSET _OAMDATA+_OAMDATALENGTH
_INPUT       RB 1               ; Put input data at the end of the oam data
_SEED        RB 1
_LASTINPUT   RB 1
_FALLSPEED   RB 1               ; Save this so we can make it accelerate
_FALLDIR     RB 1               ; 0 is down
_YPOSDECIMAL RB 1               ; Used for subpixel positioning on the y
_CRASHED     RB 1               ; Flag for if the player has crashed
_BUILDINGS   RB _BUILDINGSSIZE
_LASTSCROLL  RB 1               ; Last tile x scroll position

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
  ld bc, 16*(SpritesEnd-Sprites)
  call mem_Copy

  ld a, 0                       ; Clear sprite table
  ld hl, _OAMDATA
  ld bc, _OAMDATALENGTH
  call mem_Set

  call StartLCD                 ; Free to start the LCD again

  call initbuildings
  call drawbuildings

  ld a, 123                     ; blah blah ~random~
  ld [_SEED], a

  ld a, 255
  ld [_LASTSCROLL], a

initsprite:
  ld a, 64                      ; Initialize helo sprite
  ld [HeloYPos], a
  ld a, 16
  ld [HeloXPos], a
  ld a, 1
  ld [HeloTileNum], a
  ld a, %00000000
  ld [HeloAttrs], a
  ld a, 0
  ld [_FALLSPEED], a
  ld a, 0
  ld [_FALLDIR], a
  ld a, 0
  ld [_CRASHED], a

loop:
  halt
  nop                           ; Always need nop after halt

  ld a, [_CRASHED]
  and %00000001
  jr nz, initsprite             ; If you've crashed, start again

  call dofall

  call getinput

  ld a, [_INPUT]                ; Check keys

  push af                       ; Avoid clobbering a with the and

  and PADF_LEFT                 ; See if left is pressed
  call nz, moveleft

  pop af
  push af                       ; Don't clobber the a again

  and PADF_RIGHT                ; See if right is pressed
  call nz, moveright

  pop af
  push af

  and PADF_A
  call nz, moveup

  pop af

  ld b, a
  ld a, [_SEED]
  xor b
  ld [_SEED], a                 ; Put input into the seed? sure

  call updatebuildings

  jr loop

moveleft:
  push af

  ld a, [_FALLSPEED]
  cp 0
  jr z, .popret                 ; Don't move if fall speed is 0 (means we probably landed)

  ld a, [HeloXPos]

  cp 8                          ; If the x position is 8 already, return
  jr z, .popret

  dec a                         ; Move up
  ld [HeloXPos], a
.popret:
  pop af
  ret

moveright:
  push af

  ld a, [_FALLSPEED]
  cp 0
  jr z, .popret                 ; Don't move if fall speed is 0 (means we probably landed)

  ld a, [HeloXPos]

  cp 160                        ; If the y position is 160, return
  jr z, .popret

  inc a                         ; Move down
  ld [HeloXPos], a
.popret:
  pop af
  ret

moveup:
  push af

  ld a, [_LASTINPUT]
  and PADF_A
  jr nz, .popret                ; If up was held on the last frame, don't do this again

  ld a, [_FALLDIR]
  cp 0
  jr z, .slowdown               ; Helo is going down
  jr .goup                      ; Helo is going up

.goup:                          ; If the helo is going up, go up more
  ld a, [_FALLSPEED]
  add a, _BOOSTAMOUNT
  ld [_FALLSPEED], a

  sub a, _MAXFLYSPEED
  jr c, .popret                ; If speed isn't over max speed, no prob

  ld a, _MAXFLYSPEED
  ld [_FALLSPEED], a            ; Cap the speed
  jr .popret

.slowdown:                      ; If the helo is going down, slow it down
  ld a, [_FALLSPEED]
  sub a, _BOOSTAMOUNT             ; Slow down
  ld [_FALLSPEED], a
  jr nc, .popret                ; If didnt go below 0, return

  call changefalldir            ; Start flying

  ld b, a
  ld a, 255
  sub a, b                      ; Get the amount we overflowed by

  ld [_FALLSPEED], a            ; And set that as the fallspeed

.popret:
  pop af
  ret

dofall:
  push af
  push bc

  ld a, [_FALLDIR]
  cp 0
  call z, fall                  ; Down if dir is 0
  call nz, fly                  ; Go up if it's not 0

.popret:
  pop bc
  pop af
  ret

fall:
  push af
  push bc
  push de

  call getbuildingbelowhelo     ; Puts distance in d

  ld a, d
  cp 0
  jr z, .onbuilding             ; If distance is 0, we landed!

  ld a, [_FALLSPEED]
  sra a
  sra a
  sra a
  sra a
  and %00001111                 ; Right four bits of fallspeed
  sub a, d
  jr c, .skipbuilding           ; Fallspeed wont take us into the building, no prob

.onbuilding:

  ld d, a                       ; Save a in d

  ld a, [_FALLSPEED]
  ld b, _CRASHSPEED
  sub a, b
  jr nc, .crashed               ; Fall speed is more than crash speed

  ld a, d

  ld b, a                       ; Save the difference
  ld a, [HeloYPos]
  add a, b                      ; Add the difference to the y pos
  ld [HeloYPos], a

  ld a, 0
  ld [_FALLSPEED], a            ; Set fallspeed to 0
  ld [_YPOSDECIMAL], a          ; As well as the position decimal

  ld a, [HeloXPos]
  dec a
  ld [HeloXPos], a

  jr .popret                    ; Nothin else

.crashed:
  ld a, 1
  ld [_CRASHED], a              ; We crashed

  jr .popret

.skipbuilding:

  call applyfallspeed

  ld a, [HeloYPos]
  ld b, a
  ld a, 151
  sub a, b
  jr c, .stopatbot              ; If the new position is higher than 151, stop

  ld a, [_FALLSPEED]
  add a, 1
  ld [_FALLSPEED], a            ; Increase the fall speed (fall faster)

  sub a, _MAXFALLSPEED
  jr c, .popret                 ; If the speed is below the max, no prob

  ld a, _MAXFALLSPEED
  ld [_FALLSPEED], a            ; Cap fallspeed

  jr .popret

.stopatbot:
  ld a, 152
  ld [HeloYPos], a

  ld a, [_FALLSPEED]
  ld b, _CRASHSPEED
  sub a, b
  jr nc, .crashed               ; Fall speed is more than crash speed

  ld a, 0
  ld [_FALLSPEED], a

  jr .popret

.popret:
  pop de
  pop bc
  pop af
  ret

fly:
  push af
  push bc

  ld a, [HeloYPos]              ; Save pos before
  ld b, a

  call applyfallspeed

  ld a, [HeloYPos]
  ld c, a
  ld a, b
  sub a, c
  call c, .stopattop            ; If the new position is higher than the old one it wrapped around

  ld a, [_FALLSPEED]
  sub a, 1
  ld [_FALLSPEED], a            ; Decrease the fall speed (fly up slower)

  jr nc, .popret                ; Didn't go below 0, no problem

  call changefalldir
  jr .popret

.stopattop:
  ld a, 8
  ld [HeloYPos], a

  ld a, 0
  ld [_FALLSPEED], a

  ret

.popret:
  pop bc
  pop af
  ret

getinput:
  push af
  push bc

  ld a, [_INPUT]
  ld [_LASTINPUT], a            ; Save the previous frame's input

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

applyfallspeed:
  push af
  push bc
  push de
  push hl

  ld a, [_FALLSPEED]
  sra a
  sra a
  sra a
  sra a
  and %00001111                 ; Shift two to the right, set leftmost to 0

  ld d, a                       ; put high four bits of fallspeed into high bits of de

  ld a, [_FALLSPEED]
  sla a
  sla a
  sla a
  sla a
  and %11110000

  ld e, a                       ; Put low four bits of fallspeed in low bits of de

  ld a, [HeloYPos]
  ld h, a                       ; Load y position into high of hl

  ld a, [_YPOSDECIMAL]
  ld l, a                       ; Load decimal into low of hl

  ld a, [_FALLDIR]
  cp 0                          ; Are we going down?

  jr z, .doadd                  ; Going down
  jr .dosub                     ; Going up

.doadd:
  add hl, de

  ld a, h
  ld [HeloYPos], a

  ld a, l
  ld [_YPOSDECIMAL], a

  jr .popret

.dosub:
  ld a, h
  sub a, d                      ; THERE'S NO 16 BIT SUB

  ld [HeloYPos], a

  ld a, l
  sbc a, e

  ld [_YPOSDECIMAL], a

  jr .popret

.popret:
  pop hl
  pop de
  pop bc
  pop af
  ret

changefalldir:
  push af

  ld a, 0
  ld [_FALLSPEED], a            ; Set fallspeed to 0

  ld a, [_FALLDIR]
  cpl
  and %00000001                 ; Only flip the last bit

  ld [_FALLDIR], a              ; Switch the fall direction

  pop af
  ret

initbuildings:                  ; Move the default building data into ram
  push af
  push bc
  push de
  push hl

  ld a, _BUILDINGSSIZE
  ld b, a

  ld hl, Buildings
  ld d, h
  ld e, l

  ld hl, _BUILDINGS

.loop:
  dec b

  ld a, [de]
  ld [hl], a
  inc hl
  inc de

  ld a, b
  cp 0
  jr nz, .loop                  ; Keep looping if there's more data

  pop hl
  pop de
  pop bc
  pop af
  ret

drawbuildings:
  push af
  push bc
  push de
  push hl

  ld a, 0
  ld hl, _SCRN0
  ld bc, SCRN_VX_B*SCRN_VY_B    ; width * height
  call mem_SetVRAM              ; Clear background

  ld hl, _BUILDINGS             ; Buildings addr in hl

  ld a, _BUILDINGSSIZE
  ld b, a                       ; How many bytes left

.loop:
  ld a, [hl]
  ld d, a                       ; Building column

  inc hl

  ld a, [hl]
  ld e, a                       ; Building height

  call drawbuilding

  inc hl                        ; Next building

  dec b
  dec b                         ; Two bytes down

  ld a, b
  cp 0

  jr nz, .loop                  ; Loop if not

  pop hl
  pop de
  pop bc
  pop af
  ret

; d - building column
; e - building height
drawbuilding:
  push af
  push bc
  push de
  push hl

  ld a, SCRN_Y_B                ; How many rows on screen
  ld b, e
  sub a, b                      ; Get top row of building

  ld b, a                       ; Counter in b

  ld hl, _SCRN0

.findstartloop:

  ld a, l
  add a, 32
  ld l, a

  ld a, h
  adc a, 0
  ld h, a                       ; Add the carry (if any) into h

  dec b
  ld a, b
  cp 0
  jr nz, .findstartloop         ; Loop if not at the end

  ld a, l
  add a, d
  ld l, a                       ; Now we add the column pos

  ld a, h
  adc a, 0
  ld h, a                       ; Add the carry (if any) into h

  ld a, 3
  ld bc, 1
  call mem_SetVRAM              ; Draw top of building first

.drawloop:                      ; We have hl at the start position
  ld a, l
  add a, 31
  ld l, a                       ; Move down to the next row

  ld a, h
  adc a, 0
  ld h, a                       ; Add the carry (if any) into h

  ld a, 2
  ld bc, 1
  call mem_SetVRAM              ; Draw building tile

  dec e
  ld a, e
  cp 0
  jr nz, .drawloop              ; Keep looping if not at bottom of building

  pop hl
  pop de
  pop bc
  pop af
  ret

updatebuildings:
  push af
  push bc
  push hl

  ld a, [rSCX]
  inc a
  ld [rSCX], a                  ; Scroll buildings

  sub a, 8

  sra a
  sra a
  sra a                         ; Translate a to tile position
  and a, %00011111              ; Make sure nothing carried

  ld c, a                       ; c is the position we're looking for

  ld a, [_LASTSCROLL]
  cp c
  jr z, .popret                 ; If the last scroll position is the same as the current, don't check again

  ld a, c
  ld [_LASTSCROLL], a              ; Save the current scroll position

  ld a, _NUMBUILDINGS
  ld b, a                       ; b is our counter

  ld hl, _BUILDINGS             ; hl is the current memory location

.loop:
  dec b

  ld a, [hl]                    ; Get position
  cp c
  jr nz, .skip                  ; If not the same position, no big deal

  call resetbuilding

.skip:
  inc hl
  inc hl                        ; Next building

  ld a, b
  cp 0
  jr nz, .loop                  ; Loop through buildings

.popret:
  pop hl
  pop bc
  pop af
  ret

; hl - building memory location (column)
resetbuilding:
  push af
  push bc
  push hl

  inc hl                        ; Height

  call randomnum
  and a, %00001111
  add a, 2
  ld [hl], a

  call drawbuildings

  pop hl
  pop bc
  pop af
  ret

; Try to find a building below the helo, if there is one put the dist to it in d. else put 255
getbuildingbelowhelo:
  push af
  push bc
  push hl

  ld a, [rSCX]
  ld b, a

  ld a, [HeloXPos]
  add a, b                      ; Add the current screen offset
  sub a, 4
  sra a
  sra a
  sra a                         ; Divide x pos by 8 to get tile pos
  and a, %00011111              ; pls no carry flag
  ld b, a

  ld c, _NUMBUILDINGS
  ld hl, _BUILDINGS

.buildingloop:
  ld a, [hl]                    ; Get column
  cp b                          ; Is this the column we're looking for?
  jr z, .found                  ; If so, found!

  inc hl                        ; Next building
  inc hl

  dec c
  ld a, c
  cp 0
  jr nz, .buildingloop          ; Not at the end of the buildings, keep going

.nobuilding:
  ld d, 255                     ; Didn't find anything

  jr .popret

.found:
  inc hl                        ; Height

  ld a, [HeloYPos]
  sub a, 8
  ld b, a

  ld a, [hl]                    ; Get the building's height
  ld d, a
  ld a, SCRN_Y_B
  sub a, d                      ; Get y tile pos from top of screen

  sla a
  sla a
  sla a                         ; Multiply by 8 to get pixel pos

  sub a, b                      ; Subtract building top y pos by helo y pos
  jr c, .nobuilding             ; If that result was negative, we're below the building, so no building

  ld d, a                       ; Save the distance in the return register

  jr .popret

.popret:
  pop hl
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

.stoplcd_wait:                  ; Loop until vblank
  ld a, [rLY]                   ; Get LCDC y coord
  cp 145                        ; Is it on line 145?
  jr nz, .stoplcd_wait          ; if not, keep waiting

  ld a, [rLCDC]                 ; Get the current LCDC val
  res 7, a                      ; reset bit 7
  ld [rLCDC], a                 ; and put it back

  ret

; Start up the LCD with required flags
StartLCD:
  ld a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ8|LCDCF_OBJON
  ld [rLCDC], a
  ret

; returns a pseudorandom number in a
randomnum:
  push bc

  ld a, [_SEED]

  ld b, a
  rrca
  rrca
  rrca
  xor $1F
  add a, b
  sbc a, 255

  ld b, a

  ld a, [rDIV]
  xor b                         ; Some more randomness for good measure

  ld [_SEED], a

  pop bc
  ret

Sprites: {{ sprites("blank", "helo", "building", "building_top") }}
SpritesEnd:

Buildings:                      ; column, height
  DB 8, 8                       ; Initial building info
  DB 16, 5
  DB 24, 13
  DB 32, 7
