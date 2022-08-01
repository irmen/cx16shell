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
| basic                  | return back to Basic prompt                                                                 |
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

### X16Edit text editor support (vi/ed command)

Either have X16Edit ROM edition present in ROM, or have the Hi-Ram version on disk as 'X16EDIT-6000' on the sdcard.
See [their github](https://github.com/stefan-b-jakobsson/x16-edit) for details on how to do this.


## Todo

- remember current working directory? (CbmDos doesn't do this for us...)

...
