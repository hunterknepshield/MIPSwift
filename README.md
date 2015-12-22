# MIPSwift
A MIPS interpreter written in Swift by Hunter Knepshield.

## What it can do
- Execute most MIPS assembly instructions.
- Expand several pseudo instructions into one or more real instructions, just like assemblers do.
- Perform a variety of syscall operations, including reading input and printing output.
- Execute assembler directives, such as .data, .word, .ascii, etc.
- Execute a number of MIPSwift-specific commands for viewing contents of memory and registers, locations of labels, etc.
- Dynamically pause and resume execution at will between input of instructions.
- Set a variety of options for verbose parsing and dumping of various information.
- Read a local file's contents, parse and execute instructions within.
- Execute safely - if something would cause an error if it went through to execution, you'll be warned and nothing bad will happen (in most cases; this is not guaranteed).

## What it can't do (yet...?), a.k.a. issues
- Unable to handle creation of instructions from their raw numeric encoding, e.g. `0000 00ss ssst tttt dddd d000 0010 0000` being translated to `add $d, $s, $t`.

## License
Modification and redistribution of this software is permitted under the MIT License. See LICENSE.txt for more information.
