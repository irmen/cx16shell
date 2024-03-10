# Shell for Commander X16

Command Line Shell for Commander X16

Software License: MIT open source, see file LICENSE.

![Shell screenshot](./screenshot.png "Screenshot of the shell; running in X16 emulator")

## Compiling the shell

You'll need a Prog8 compiler v9.8 or later, to build this from source.
If the latest official release gives you problems compiling this program, you may have to use
the git master version that hasn't been officially released yet.

First type ``git submodule update --init`` to fetch the external modules. 
Then just type ``make`` to compile the shell.
Type ``make emu`` to compile, copy everything to the correct folders on the sdcard,
and immediately start it in the Commander X16 emulator.

Save SHELL.PRG as AUTOBOOT.X16 to the sd-card to automatically load and run the shell at startup.


## Usage

Type "help" at the prompt to get a list of the built-in commands.

| command                | explanation                                                                                 |
|------------------------|---------------------------------------------------------------------------------------------|
| help                   | show short list of commands                                                                 |
| alias                  | create a new command alias                                                                  | 
| unalias                | remove an existing command alias                                                            | 
| exit                   | return back to Basic prompt                                                                 |
| mon                    | enter the machine code monitor program                                                      |
| num                    | print number in various bases, accepts $hex, %binary and normal decimal                     |
| run  ,<br/> *filename* | loads and executes the given file. You can omit any .PRG suffix and is case insensitive.    |
| nano                   | uses X16Edit (in Rom or on disk) to edit the given text file  (see note below)              |       
| mem                    | show some memory information                                                                |       
| cls                    | clear the screen                                                                            |       
| echo                   | print something to the screen. Accepts some escaped characters and \xAB to print char $AB   |       
| mode                   | change screen mode                                                                          |
| color                  | change main screen colors                                                                   |
| hicolor                | change highlight screen colors                                                              |
| ls                     | shows files on disk. You can provide an optional pattern to match such as *.ASM or H???.TXT |
| cat                    | prints the contents of the given text file on the screen                                    |       
| rm                     | remove given file from the disk                                                             |       
| mv                     | rename given file to given new filename                                                     |
| cp                     | copy given file to new file                                                                 |
| cd                     | change current working directory                                                            |
| pwd                    | show current drive information                                                              |       
| mkdir                  | create a new directory                                                                      |       
| rmdir                  | remove existing directory                                                                   |       
| relabel                | change disk name                                                                            |       
| drive                  | change current drive                                                                        |       

You can also type the name of an "external command" program, located in the SHELL-CMDS subdirectory.
Finally you can simply type the name of a program to launch (no file extension required, case-insensitive).

"time" (and "date") and "neofetch" are available as some potentially useful external commands.

You can use tab for filename completion (case-sensitive).

## Startup config script

If a "config.sh" script file exists in the SHELL-CMDS subdirectory, this will be loaded and executed
at startup. Every line will be executed as a shell command. Empty lines or lines starting with a '#' will be skipped.

The default config.sh file contains a bunch of command aliases, sets the screen mode and changes the color scheme,
and prints a welcome message. You can change the script however you like, just remember that it is saved in ISO character encoding.

## External commands

The shell can launch 'external commands' much like a Unix shell runs programs from disk.
You can write those commands yourself, they have to adhere to the following API.

Command should be assembled from address $4000 and up (to max $9f00).
They should be stored in the ``SHELL-CMDS`` subdirectory on your sdcard.

Utility routines you can call from your command program::

    romsub $07dc = version() -> uword @AY               ; returns pointer to string with shell's version
    romsub $07df = get_text_colors() -> uword @AY       ; returns address of array of 5 text color bytes (text, background, highlight, prompt, error)
    romsub $07e2 = chrout(ubyte character @A)
    romsub $07e5 = print(str string @AY) clobbers(A,Y)
    romsub $07e8 = print_ub(ubyte value @ A) clobbers(A,X,Y)
    romsub $07eb = print_ubhex(ubyte value @ A, bool prefix @ Pc) clobbers(A,X,Y)
    romsub $07ee = print_ubbin(ubyte value @ A, bool prefix @ Pc) clobbers(A,X,Y)
    romsub $07f1 = print_uw(uword value @AY) clobbers(A,Y)
    romsub $07f4 = print_uwhex(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    romsub $07f7 = print_uwbin(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    romsub $07fa = input_chars(uword buffer @ AY) clobbers(A) -> ubyte @Y
    romsub $07fd = err_set(str message @AY) clobbers(Y) -> bool @A

Command receives arguments at $0:BF00 (zero terminated, see  https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2007%20-%20Memory%20Map.md#bank-0)
(you can use the cx16.get_program_args routine to retrieve them)
Command should return error status in A. You can use the ``err_set()`` routine to set a specific error message for the shell.
Command CAN use the *free* zero page locations.
Command CANNOT use memory below $4000 (the shell program itself sits there).
Command CAN use Golden Ram $0400-up to where the jump table starts (see above). 

The "ext-command.p8" source file contains a piece of example Prog8 source code of an external command.


## Todo

- add a (external) 'view' command to view images (make it part of the imageviewer project)
- typing a filename with a known image suffix should launch the 'view' program automatically
- do the same for sound files including zsm / zcm
- new memory layout? Shell program at the top of memory (say $6000-$9f00) so that you can load regular programs at $0801? What about the external commands? No longer forced to start at $4000 but just regular programs?

...
