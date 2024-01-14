.PHONY:  all clean emu

all:  shell.prg ext-command.prg neofetch.prg time.prg

clean:
	rm -f *.prg *.asm *.vice-*

emu:  all
	mmd -D s x:SHELL-CMDS || true
	mcopy -D o shell.prg x:SHELL
	mcopy -D o ext-command.prg x:SHELL-CMDS/EXT-COMMAND
	mcopy -D o neofetch.prg x:SHELL-CMDS/NEOFETCH
	mcopy -D o time.prg x:SHELL-CMDS/TIME
	mcopy -D o time.prg x:SHELL-CMDS/DATE
	mcopy -D o motd.txt x:SHELL-CMDS/motd.txt
	PULSE_LATENCY_MSEC=20 x16emu -sdcard ~/cx16sdcard.img -scale 2 -quality best -run -prg shell.prg -rtc

shell.prg: src/shell.p8 src/errors.p8 src/disk_commands.p8 src/misc_commands.p8
	p8compile $< -target cx16 -sourcelines

ext-command.prg: externalcommands/example/ext-command.p8
	p8compile $< -target cx16 -srcdirs externalcommands

neofetch.prg: externalcommands/neofetch/neofetch.p8
	p8compile $< -target cx16 -srcdirs externalcommands

time.prg: externalcommands/time.p8
	p8compile $< -target cx16

zip: all
	rm -f shell.zip
	rm -rf SHELL-CMDS
	mkdir SHELL-CMDS
	cp shell.prg SHELL.PRG
	cp ext-command.prg SHELL-CMDS/EXT-COMMAND
	cp neofetch.prg SHELL-CMDS/NEOFETCH
	cp time.prg SHELL-CMDS/TIME
	cp time.prg SHELL-CMDS/DATE
	7z a shell.zip SHELL.PRG SHELL-CMDS
