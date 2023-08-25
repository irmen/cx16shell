%import textio
%import diskio
%import string
%import errors
%import disk_commands
%import misc_commands
%zeropage basicsafe

main {
    const ubyte COLOR_NORMAL = 1
    const ubyte COLOR_HIGHLIGHT = 14
    const ubyte COLOR_HIGHLIGHT_PROMPT = 13
    const ubyte COLOR_ERROR = 10
    const ubyte COLOR_BACKGROUND = 11

    str command_line = "?" * 160
    str command_word = "?" * 64
    ubyte command_word_size
    uword command_arguments_ptr
    ubyte command_arguments_size

    sub start() {
        cx16.rombank(0)     ; switch to kernal rom for faster operation
        txt.iso()
        txt.color2(COLOR_NORMAL, COLOR_BACKGROUND)
        void cx16.screen_mode(1, false)
        txt.clear_screen()
        print_intro()

        repeat {
            txt.color(COLOR_HIGHLIGHT_PROMPT)
            txt.nl()
            txt.print(iso:"$ ")
            txt.color(COLOR_NORMAL)
            err.clear()
            ubyte input_size = txt.input_chars(command_line)
            if input_size and command_line[0]!=159 {
                txt.nl()
                if parse_input(input_size) {
                    uword command_routine = disk_commands.recognized(command_line, command_word_size)
                    if command_routine==0
                        command_routine = misc_commands.recognized(command_line, command_word_size)
                    if command_routine {
                        cx16.r0 = callfar(cx16.getrambank(), command_routine, 0)       ; indirect JSR
                        if cx16.r0L!=0
                            err.clear()
                        else if not err.error_status {
                            void err.set(iso:"Unspecified error")
                        }
                    } else {
                        ; see if there is an external shell command in the SHELL-CMDS subdirectory that matches
                        diskio.list_filename = "//shell-cmds/:"
                        void string.copy(command_word, &diskio.list_filename+14)
                        if diskio.load(diskio.list_filename, 0)
                            void run_external_command()
                        else {
                            ; see if there is a program file that matches
                            uword real_filename_ptr = file_lookup_matching(command_line, true)
                            if real_filename_ptr
                                run_file(real_filename_ptr, false)
                            else
                                void err.set(iso:"Invalid command")
                        }
                    }
                } else {
                    void err.set(iso:"Invalid input")
                }
            }
        }
    }

    sub parse_input(ubyte length) -> bool {
        uword cmd_ptr = &command_line
        ; replace Shift-SPACE by just normal SPACE
        while @(cmd_ptr) {
            if @(cmd_ptr)==$a0
                @(cmd_ptr)=iso:' '
            cmd_ptr++
        }
        ; skip leading spaces
        cmd_ptr = &command_line
        while @(cmd_ptr)==iso:' ' {
            cmd_ptr++
            length--
        }

        ubyte space_idx = string.find(cmd_ptr, iso:' ')
        if_cs {
            cmd_ptr[space_idx] = 0
            command_arguments_ptr = cmd_ptr + space_idx + 1
            command_arguments_size = length - space_idx - 1
        } else {
            command_arguments_ptr = 0
            command_arguments_size = 0
        }
        command_word_size = string.copy(cmd_ptr, command_word)
        void string.upper(command_word)      ; for ISO charset, this actually does a *lower*casing instead.

        return length>0
    }

    sub print_intro() {
        txt.color2(COLOR_NORMAL, COLOR_BACKGROUND)
        txt.clear_screen()
        txt.color(COLOR_HIGHLIGHT_PROMPT)
        txt.print(iso:"\r  Commander-X16 SHELL ")
        txt.color(COLOR_NORMAL)
        txt.print(iso:"- https://github.com/irmen/cx16shell\r")
		
		txt.color(4)
		txt.print(iso:"\r  o                   o  ")
		
		txt.color(COLOR_HIGHLIGHT)
		txt.print(iso:"OS")
		txt.color(COLOR_NORMAL)
		txt.print(iso:": Commander X16 BASIC v2 Rom ")
		byte ver = @($ff80) as byte
		if ver == -1
			txt.print(iso:"unstable") 
		else{
			txt.print(iso:"R")
			if ver < 0 ver *= -1
			txt.print_b(ver)
		}
		
		txt.color(4)
		txt.print(iso:"\r  M@\\               /@M  ")
		
		txt.color(COLOR_HIGHLIGHT)
		txt.print(iso:"Host")
		txt.color(COLOR_NORMAL)
		txt.print(iso:": Commander X16 ")
		if (@($9FBE)==$31) and (@($9FBF) == $36) 
			txt.print(iso:"Official Emulator") 
		else txt.print(iso:" gen1 board")
		; TODO add functionality to distinguish gen2 and gen3 if it's going to be possible. 
		; Additionally add support for distinguishing Box16
		
		txt.color(14)
		txt.print(iso:"\r  M@@@\\           /@@@M  ")
		
		txt.color(COLOR_HIGHLIGHT)
		txt.print(iso:"Shell")
		txt.color(COLOR_NORMAL)
		txt.print(iso:": SHELL.PRG") ;are version numbers even a thing here?
		
		txt.color(14)
		txt.print(iso:"\r  :@@@@@\\       /@@@@@:  ")
		
		txt.color(COLOR_HIGHLIGHT)
		txt.print(iso:"Resolution")
		txt.color(COLOR_NORMAL)
		txt.print(iso:": 640x240") ; default resolution when using SHELL.PRG
		
		txt.color(3)
		txt.print(iso:"\r   \\@@@@@@\\   /@@@@@@/   ")
		
		txt.color(COLOR_HIGHLIGHT)
		txt.print(iso:"CPU")
		txt.color(COLOR_NORMAL)
		txt.print(iso:": WDC 65c02 (1) @ 8MHz")
		
		txt.color(5)
		txt.print(iso:"\r     \'\'\"\"**N N**\"\"\'\'     ")
		
		txt.color(COLOR_HIGHLIGHT)
		txt.print(iso:"GPU")
		txt.color(COLOR_NORMAL)
		txt.print(iso:": VERA module") ;should we even bother detecting vera version, FX support etc?
		
		txt.color(7)
		txt.print(iso:"\r           N N           ")
		
		txt.color(COLOR_HIGHLIGHT)
		txt.print(iso:"Memory")
		txt.color(COLOR_NORMAL)
		txt.print(iso:": ")
		txt.print_uw((sys.progend()-737) / 1024)
		txt.print(iso:"KiB / ")
		txt.print_uw((cbm.MEMTOP(0, true)-2) / 1024)
		txt.print(iso:"KiB")
		
		txt.color(7)
		txt.print(iso:"\r       ..-*N N*-..       ")
		
		txt.color(COLOR_HIGHLIGHT)
		txt.print(iso:"Hi-Memory")
		txt.color(COLOR_NORMAL)
		txt.print(iso:": ")
		txt.print_uw(cx16.numbanks() * $0008)
		txt.print(iso:"KiB (")
		txt.print_uw(cx16.numbanks())
		txt.print(iso:" banks)")
		
		txt.color(8)
		txt.print(iso:"\r    :@@@@@/   \\@@@@@:    ")
		txt.color(2)
		txt.print(iso:"\r    M@@@/       \\@@@M    ")
		
		ubyte j
		for j in 0 to 15{
			txt.color(j)
			txt.print(iso:"\xad#")
		}
		
		txt.color(2)
		txt.print(iso:"\r    M@/           \\@M    ")
		
		ubyte i
		for i in 0 to 15{
			txt.color(i)
			;txt.print(iso:"\xad#")
		}
		
		txt.print(iso:"\r")
    }

    sub file_lookup_matching(uword filename_ptr, bool only_programs) -> uword {
        ; we re-use command_word variable as storage for processing the filenames read from disk.
        void iso_to_lowercase_petscii(filename_ptr)
        if diskio.lf_start_list(0) {
            while diskio.lf_next_entry() {
                command_word = diskio.list_filename
                ubyte disk_name_length = string.lower(command_word)
                bool has_prg_suffix = string.endswith(command_word, ".prg")
                bool has_no_suffix = false
                void string.find(command_word, '.')
                if_cc
                    has_no_suffix = true
                if not only_programs or has_no_suffix or has_prg_suffix {
                    if string.compare(command_word, filename_ptr)==0 {
                        diskio.lf_end_list()
                        return diskio.list_filename
                    }
                    if has_prg_suffix {
                        command_word[disk_name_length-4] = 0
                        if string.compare(command_word, filename_ptr)==0 {
                            diskio.lf_end_list()
                            return diskio.list_filename
                        }
                        command_word[disk_name_length-4] = iso:'.'
                    }
                } else if only_programs and string.compare(command_word, filename_ptr)==0 {
                    diskio.lf_end_list()
                    return err.set(iso:"Not a program")
                }
            }
            diskio.lf_end_list()
            return 0
        } else {
            return err.set(diskio.status())
        }
    }

    sub iso_to_lowercase_petscii(uword str_ptr) -> ubyte {
        ubyte length=0
        while @(str_ptr)!=0 {
            if @(str_ptr) >= iso:'a' and @(str_ptr) <= iso:'z'
                @(str_ptr) -= 32
            str_ptr++
            length++
        }
        return length
    }

    sub run_file(uword filename_ptr, bool via_basic_load) {
        txt.color(main.COLOR_HIGHLIGHT)
        txt.print(iso:"Running: ")
        txt.color(main.COLOR_NORMAL)
        txt.print(filename_ptr)
        txt.nl()

        if via_basic_load {
            ; make sure the screen and everything is set back to normal mode, and issue the load+run commands.
            txt.iso_off()
            txt.color2(1,6)     ; default white on blue
            void cx16.screen_mode(0, false)
            txt.print("\x13lO\"")       ; home, load
            txt.print(filename_ptr)
            txt.print("\",")
            txt.chrout('0' + diskio.drivenumber)
            txt.nl()
            cx16.kbdbuf_put($13)        ; home, enter, run, enter
            cx16.kbdbuf_put('\r')
            cx16.kbdbuf_put('r')
            cx16.kbdbuf_put('U')
            cx16.kbdbuf_put('\r')
            sys.exit(0)
        } else {
            ; TODO run command via a trampoline function that returns and reloads the shell afterwards
            ;      note: IONIT/RESTOR/CINT not needed before loading the shell as it does this by itself at startup. Only needed to set correct ram/rom banks.
            ;      q: how do we know the start address of the loaded program to JSR to ???  so that we return to the trampoline afterwards?
            run_file(filename_ptr, true);  for now just run it via basic
        }
    }

    sub run_external_command() -> bool {
        ; load the external command program that has already been loaded to $4000
        ; setup the 'shell bios' jump table
        poke($06e0, $4c)    ; JMP
        pokew($06e1, &txt.print)
        poke($06e3, $4c)    ; JMP
        pokew($06e4, &txt.print_uw)
        poke($06e6, $4c)    ; JMP
        pokew($06e7, &txt.print_uwhex)
        poke($06e9, $4c)    ; JMP
        pokew($06ea, &txt.print_uwbin)
        poke($06ec, $4c)    ; JMP
        pokew($06ed, &txt.input_chars)
        poke($06ef, $4c)    ; JMP
        pokew($06f0, &err.set)
        push(diskio.drivenumber)     ; only variable in ZP that we need to save
        rsave()
        ; call the routine with the input registers
        romsub $4000 = external_command(uword command @R0, ubyte command_size @R1, uword arguments @R2, ubyte args_size @R3) -> ubyte @A
        cx16.r0L = external_command(&command_word, command_word_size, command_arguments_ptr, command_arguments_size)
        rrestore()
        pop(diskio.drivenumber)
        return cx16.r0L
    }

    sub print_uw_right(uword value) {
        if value < 10
            txt.spc()
        if value < 100
            txt.spc()
        if value < 1000
            txt.spc()
        if value < 10000
            txt.spc()
        txt.print_uw(value)
    }
}
