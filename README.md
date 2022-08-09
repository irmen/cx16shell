# Shell for Commander X16

Command Line Shell for Commander X16

Software License: MIT open source, see file LICENSE.

![Shell screenshot](./screenshot.png "Screenshot of the shel; running in X16 emulator")

## Compiling the shell

You'll need a very recent prog8 compiler to build this from source.
If the latest official release gives you problems compiling this program, you may have to use
the git master version that hasn't been officially released yet.

Just type ``make`` to compile the shell
Type ``make emu`` to compile and immediately start it in the Commander X16 emulator.

Save SHELL.PRG as AUTOBOOT.X16 to the sd-card to automatically load and run the shell at startup.


## Usage

Type "help" at the prompt to get a list of the built-in commands.

| command                | explanation                                                                                 |
|------------------------|---------------------------------------------------------------------------------------------|
| help                   | show short list of commands                                                                 |
| basic , exit           | return back to Basic prompt                                                                 |
| num                    | print number in various bases, accepts $hex, %binary and normal decimal                     |
| run  ,<br/> *filename* | loads and executes the given file. You can omit any .PRG suffix and is case insensitive.    |
| vi , ed                | uses X16Edit (in Rom or on disk) to edit the given text file  (see note below)              |       
| ls                     | shows files on disk. You can provide an optional pattern to match such as *.ASM or H???.TXT |
| cat                    | prints the contents of the given text file on the screen                                    |       
| rm , del               | remove given file from the disk                                                             |       
| mv , ren               | rename given file to given new filename                                                     |
| cp                     | copy given file to new file                                                                 |
| pwd                    | show current drive information                                                              |       
| cd                     | change current working directory                                                            |
| mkdir                  | create a new directory                                                                      |       
| rmdir                  | remove existing directory                                                                   |       
| relabel                | change disk name                                                                            |       
| drive                  | change current drive                                                                        |       
| mem                    | show some memory information                                                                |       

You can also type the name of an "external command" program, located in the SHELL-CMDS subdirectory.
Finally you can simply type the name of a program to launch (no file extension required, case-insensitive).


### X16Edit text editor support (vi/ed command)

Either have X16Edit ROM edition present in ROM, or have the Hi-Ram version on disk as 'X16EDIT-6000' on the sdcard.
See [their github](https://github.com/stefan-b-jakobsson/x16-edit) for details on how to do this.


## External commands

The shell can launch 'external commands' much like a Unix shell runs programs from disk.
You can write those commands yourself, they have to adhere to the following API.

Command should be assembled from address $4000 and up (to max $9f00).
They should be stored in the ``SHELL-CMDS`` subdirectory on your sdcard.

Utility routines you can call from your command program::

    $07e0 = shell_print(str string @AY) clobbers(A,Y)
    $07e3 = shell_print_uw(uword value @AY) clobbers(A,Y)
    $07e6 = shell_print_uwhex(uword value @ AY, ubyte prefix @ Pc) clobbers(A,Y)
    $07e9 = shell_print_uwbin(uword value @ AY, ubyte prefix @ Pc) clobbers(A,Y)
    $07ec = shell_input_chars(uword buffer @ AY) clobbers(A) -> ubyte @Y
    $07ef = shell_err_set(str message @AY) clobbers(Y) -> bool @A
    $07f2 = shell_reset_screen() clobbers(A,X,Y)

Input registers set by shell upon calling your command::

    cx16.r0 = command address
    cx16.r1 = length of command (byte)
    cx16.r2 = arguments address
    cx16.r3 = length of arguments (byte)

Command should return error status in A. You can use the ``err_set()`` routine to set a specific error message for the shell.
Command CAN use the FREE zero page locations.
Command CANNOT use memory below $4000 (the shell sits there).
Command CAN use Ram $0400-$07e0.

The "ext-command.p8" source file contains a piece of example Prog8 source code of an external command.


## Todo

- remember current working directory? (CbmDos doesn't do this for us...)

...
