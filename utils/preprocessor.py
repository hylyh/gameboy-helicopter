import sys
import re

DEFAULTFILE = '../helicopter.asm'
MACROREGEX = r'([^ ]+) +{{ *(.+) *}}'

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
                result = eval(expression)

                # Rebuild the line with the new result
                line = label + '\n' + result

            output_lines.extend(new_line or [line])

    with open(outname, 'w') as f:
        f.write(''.join(output_lines))

def main():
    if len(sys.argv) != 2 or len(sys.argv != 3):
        print('Please provide a single argument pointing to the .asm you want to process')
        print('Optionally you may provide a second argument specifiying the output file name')
        print('Assuming "' +  '"for testing purposes')

    process(sys.argv[1] if len(sys.argv) > 1 else DEFAULTFILE, sys.argv[2] if len(sys.argv) > 2 else None)

if __name__ == '__main__':
    main()
