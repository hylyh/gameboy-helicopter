ASM=rgbasm -iincludes/
LINK=rgblink
FIX=rgbfix

EMU=wine /Users/jayhay/Documents/gbshit/bgb/bgb.exe

TARGET=helicopter

.PHONY: run clean

all: build run

build: asm link fix

asm: $(TARGET).asm
	$(ASM) -o$(TARGET).obj $(TARGET).asm

link: $(TARGET).obj
	$(LINK) -o$(TARGET).gb $(TARGET).obj

fix: $(TARGET).gb
	$(FIX) -v -p0 $(TARGET).gb

run:
	$(EMU) $(TARGET).gb

clean:
	$(RM) $(TARGET).obj $(TARGET).gb
