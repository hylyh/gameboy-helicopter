# gameboy-helicopter

Just having some fun with gameboy programming! This is a purely a personal project for learning purposes.

## How to

The preprocessor requires python2 (3 will work too I believe) and PIL. It also uses a virtualenv to run in. To set this up, install virtualenv (pip install virtualenv) then run `virtualenv venv` from the project root. To install PIL type `source venv/bin/activate` then `pip install Pillow`. Now you can run the preprocessor manually `python utils/preprocessor.py`, or through the makefile.

Requires [rgbds](https://github.com/rednex/rgbds) to build and I use [bgb](http://bgb.bircd.org/) to emulate. You will need to tweak the makefile to point to your bgb if you're using it.

To build and run in bgb: run `make`. To just build: `make build`. Outputs rom as `helicopter.gb`

### nyoooom
![Helicopter gif](http://i.imgur.com/1u0bOND.gif)
