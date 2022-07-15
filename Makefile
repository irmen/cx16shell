.PHONY:  all clean emu

all:  shell.prg

clean:
	rm -f shell.prg shell.asm *.vice-*

emu:  shell.prg
	mcopy -D o $< x:SHELL
	x16emu -sdcard ~/cx16sdcard.img -scale 2 -quality best -run -prg shell.prg

shell.prg: src/shell.p8 src/errors.p8
	p8compile $< -target cx16
