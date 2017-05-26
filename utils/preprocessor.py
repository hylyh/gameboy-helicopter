import sys
import re

from PIL import Image

DEFAULTFILE = '../helicopter.asm'
MACROREGEX = r'([^ ]+) +{{ *(.+) *}}'

def sprites(*args):
    sprites = ''
    for arg in args:
        sprites += sprite(arg) + '\n'

    return sprites

def sprite(path):
    img = Image.open('sprites/' + path + '.png')

    bytes1, bytes2 = [], []

    col = 0
    for pixels in list(img.getdata()):
        if col == 0:
            bytes1.append([])
            bytes2.append([])

        r, g, b = pixels

        # Only check the red channel bc lazy
        if r == 255:
            # White
            bytes1[-1].append('0')
            bytes2[-1].append('0')
        elif r == 0:
            # Black
            bytes1[-1].append('1')
            bytes2[-1].append('1')
        elif r < 128:
            # Dark
            bytes1[-1].append('0')
            bytes2[-1].append('1')
        else:
            # Light
            bytes1[-1].append('1')
            bytes2[-1].append('0')

        col += 1
        if col > 7:
            col = 0

    output = ''
    for byte1, byte2 in zip(bytes1, bytes2):
        output += 'DB %' + ''.join(byte1) + ',%' + ''.join(byte2) + '\n'

    return output

# Just echos back what you put in, for testing
def echo(thing):
    return thing

def process(inname, outname=None):
    output_lines = []
    with open(inname, 'r') as f:
        for line in f.readlines():
            new_line = None
            match = re.match(MACROREGEX, line)
            if match:
                label = match.group(1)
                expression = match.group(2)

                # Eval whatever they put in the macro
                result = eval(expression)

                # Rebuild the line with the new result
                line = label + '\n' + result

            output_lines.extend(new_line or [line])

    with open(outname or inname + '.built', 'w') as f:
        f.write(''.join(output_lines))

def main():
    if len(sys.argv) != 2 and len(sys.argv) != 3:
        print('Please provide a single argument pointing to the .asm you want to process')
        print('Optionally you may provide a second argument specifiying the output file name')
        print('Assuming "' + DEFAULTFILE + '" for testing purposes')

    process(sys.argv[1] if len(sys.argv) > 1 else DEFAULTFILE, sys.argv[2] if len(sys.argv) > 2 else None)

if __name__ == '__main__':
    main()
