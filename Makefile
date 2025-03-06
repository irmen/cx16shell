.PHONY:  all clean run

PROG8C ?= prog8c       # if that fails, try this alternative (point to the correct jar file location): java -jar $(PROG8C).jar
ZIP ?= zip


all:  shell.prg ext-command.prg neofetch.prg time.prg view.prg man.prg

clean:
	rm -f *.prg *.asm *.vice-*

run:  all
	mcopy -D o shell.prg x:SHELL
	mmd -D s x:SHELL-FILES || true
	mmd -D s x:SHELL-FILES/commands || true
	mcopy -D o ext-command.prg x:SHELL-FILES/commands/EXT-COMMAND
	mcopy -D o neofetch.prg x:SHELL-FILES/commands/NEOFETCH
	mcopy -D o time.prg x:SHELL-FILES/commands/TIME
	mcopy -D o view.prg x:SHELL-FILES/commands/VIEW
	mcopy -D o man.prg x:SHELL-FILES/commands/MAN
	mcopy -s -D o externalcommands/manpages x:SHELL-FILES/
	mcopy -s -D o externalcommands/neofetch/manpage.txt x:SHELL-FILES/manpages/neofetch
	mcopy -D o config.sh motd.txt x:SHELL-FILES/
	PULSE_LATENCY_MSEC=20 x16emu -sdcard ~/cx16sdcard.img -scale 2 -quality best -run -prg shell.prg -rtc -debug

shell.prg: src/shell.p8 src/aliases.p8 src/errors.p8 src/disk_commands.p8 src/misc_commands.p8
	$(PROG8C) $< -target cx16

ext-command.prg: externalcommands/example/ext-command.p8 externalcommands/shellroutines.p8
	$(PROG8C) $< -target cx16 -srcdirs externalcommands

neofetch.prg: externalcommands/neofetch/neofetch.p8 externalcommands/shellroutines.p8
	$(PROG8C) $< -target cx16 -srcdirs externalcommands

time.prg: externalcommands/time.p8 externalcommands/shellroutines.p8
	$(PROG8C) $< -target cx16

view.prg: externalcommands/view.p8 externalcommands/shellroutines.p8
	$(PROG8C) $< -target cx16 -srcdirs externalcommands/imageviewer/src

man.prg: externalcommands/man.p8 externalcommands/shellroutines.p8
	$(PROG8C) $< -target cx16

zip: all
	rm -f shell.zip
	rm -rf SHELL-FILES
	cp shell.prg SHELL.PRG
	mkdir -p SHELL-FILES/commands
	cp ext-command.prg SHELL-FILES/commands/EXT-COMMAND
	cp neofetch.prg SHELL-FILES/commands/NEOFETCH
	cp time.prg SHELL-FILES/commands/TIME
	cp view.prg SHELL-FILES/commands/VIEW
	cp man.prg SHELL-FILES/commands/MAN
	cp -r externalcommands/manpages SHELL-FILES/
	cp externalcommands/neofetch/manpage.txt SHELL-FILES/manpages/neofetch
	cp config.sh motd.txt SHELL-FILES/
	$(ZIP) -r shell.zip SHELL.PRG SHELL-FILES
