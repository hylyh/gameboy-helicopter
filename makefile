PYTHON=python
VIRTUALENV=source venv/bin/activate

PREPROC=$(VIRTUALENV); $(PYTHON) utils/preprocessor.py
ASM=rgbasm -iincludes/
LINK=rgblink
FIX=rgbfix

EMU=wine /Users/jayhay/Documents/gbshit/bgb/bgb.exe

TARGET=helicopter

.PHONY: run clean

all: build run

build: preprocess asm link fix

preprocess: $(TARGET).asm
	$(PREPROC) $(TARGET).asm $(TARGET).asm.built

asm: $(TARGET).asm.built
	$(ASM) -o$(TARGET).obj $(TARGET).asm.built

link: $(TARGET).obj
	$(LINK) -o$(TARGET).gb $(TARGET).obj

fix: $(TARGET).gb
	$(FIX) -v -p0 $(TARGET).gb

run:
	$(EMU) $(TARGET).gb

clean:
	$(RM) $(TARGET).obj $(TARGET).gb $(TARGET).asm.built
