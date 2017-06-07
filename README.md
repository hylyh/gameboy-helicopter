# gameboy-helicopter

Just having some fun with gameboy programming! This is a purely a personal project for learning purposes.

## Try it!
Check the [releases](https://github.com/jessicahayley/gameboy-helicopter/releases/) tab for prebuilt roms, I'll try to update that as I hit major milestones.

## Build it!

The preprocessor requires python2 (3 will work too I believe) and PIL. It also uses a virtualenv to run in. To set this up, install virtualenv (pip install virtualenv) then run `virtualenv venv` from the project root. To install PIL type `source venv/bin/activate` then `pip install Pillow`. Now you can run the preprocessor manually `python utils/preprocessor.py`, or through the makefile.

Requires [rgbds](https://github.com/rednex/rgbds) to build and I use [bgb](http://bgb.bircd.org/) to emulate. You will need to tweak the makefile to point to your bgb if you're using it.

To build and run in bgb: run `make`. To just build: `make build`. Outputs rom as `helicopter.gb`

## How do I learn?

Resources I used!

* the pan docs (literally the most invaluable tool for gb/gbc dev): http://bgb.bircd.org/pandocs.htm
* official gameboy manual (goes without saying): http://www.chrisantonellis.com/files/gameboy/gb-programming-manual.pdf
* opcodes: http://www.devrs.com/gb/files/GBCPU_Instr.html
* this gameboy course, has a lot of example code, not everything works as-is though: http://cratel.wichita.edu/cratel/ECE238Spr08
* honestly basically everything on this list: https://github.com/avivace/awesome-gbdev

Also for my editor I use spacemacs (nasm-mode)

### nyoooom
![Helicopter gif](http://i.imgur.com/XtclIkb.gif)
