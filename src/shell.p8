%import textio
%import diskio
%import strings
%import errors
%import disk_commands
%import misc_commands
%encoding iso
%zeropage basicsafe
%option no_sysinit

main {
    ubyte[5] text_colors = [1, 6, 3, 13, 10]
    const ubyte TXT_COLOR_NORMAL = 0
    const ubyte TXT_COLOR_BACKGROUND = 1
    const ubyte TXT_COLOR_HIGHLIGHT = 2
    const ubyte TXT_COLOR_HIGHLIGHT_PROMPT = 3
    const ubyte TXT_COLOR_ERROR = 4

    str command_line = "?" * 160
    str command_word = "?" * 64
    ubyte command_word_size
    uword command_arguments_ptr
    ubyte command_arguments_size
    uword @nozp old_NMI             ; not in zeropage, it must be retained through external commands


    sub start() {
        cx16.rombank(0)     ; switch to kernal rom bank for faster operation
        void diskio.fastmode(3)     ; fast reads and writes
        init_screen()
        load_config()
        old_NMI=cbm.NMINV

        the_loop:
        repeat {
            txt_color(TXT_COLOR_HIGHLIGHT_PROMPT)
            txt.nl()
            txt.print("$ ")
            txt_color(TXT_COLOR_NORMAL)
            err.clear()
            
            cbm.NMINV=&main.nmi_handler

            ; Used only in the `nmi_handler()`. 816 stack stuff don't need to be handled, because 65c816 in "native" mode uses a different NMI vector and we don't touch that.
            ubyte stackptr = sysext.getstackptr()

            cx16.set_chrin_keyhandler(0, &keystroke_handler)
            ubyte input_size = txt.input_chars(command_line)

            if input_size!=0 and command_line[0]!=159 {
                txt.nl()
                if not process_command(input_size)
                    err.set("Invalid input")
            }
        }
    }

    sub init_screen() {
        txt.color2(text_colors[TXT_COLOR_NORMAL], text_colors[TXT_COLOR_BACKGROUND])
        cx16.VERA_DC_BORDER = text_colors[TXT_COLOR_BACKGROUND]
        txt.iso()
        txt.clear_screen()
    }

    sub load_config() {
        str configfile = petscii:"//shell-files/:config.sh"
        if not execute_script(configfile)
            diskio.send_command(petscii:"i")
    }

    sub process_command(ubyte input_size) -> bool {
        if input_size==0
            return true
        if not parse_input(input_size)
            return false
        if command_word[0]=='#'
            return true     ; whole line is a comment
        uword aliased_cmd = aliases.lookup(command_word)
        if aliased_cmd!=0
            void strings.copy(aliased_cmd, command_word)
        uword command_routine = commands.recognized(command_word)
        if command_routine!=0 {
            if lsb(call(command_routine))!=0   ; indirect JSR, only returning a byte in this case
                err.clear()
            else if not err.error_status
                err.set("Unspecified error")
        } else {
            ; see if there is an external shell command in the SHELL-FILES/commands subdirectory that matches
            void strings.copy(petscii:"//shell-files/commands/:", diskio.list_filename)
            void strings.copy(command_word, &diskio.list_filename+24)        ; NOTE 24 is the length of "//shell-files/commands/:" !!
            if file_exists(diskio.list_filename) {
                if strings.endswith(diskio.list_filename, ".sh") or strings.endswith(diskio.list_filename, petscii:".sh")
                    run_file(diskio.list_filename, false)
                else
                    run_external_shell_command(diskio.list_filename)
                return true
            }

            if command_line==".." {
                txt.print("cd into directory. ")
                command_arguments_ptr = ".."
                command_arguments_size = strings.length(command_arguments_ptr)
                void disk_commands.cmd_cd()
            } else {
                ; see if there is a program file that matches
                uword real_filename_ptr = file_lookup_matching(command_line, true)
                if real_filename_ptr!=0 {
                    void strings.copy(real_filename_ptr, command_word)
                    if is_directory(command_word) {
                        txt.print("cd into directory. ")
                        command_arguments_ptr = command_word
                        command_arguments_size = strings.length(command_arguments_ptr)
                        void disk_commands.cmd_cd()
                    } else if not err.error_status {
                        run_file(command_word, false)
                    }
                }
                else
                    err.set("Invalid command")
            }
        }
        return true
    }

    sub is_program_file(str name) -> bool {
        if strings.endswith(name, ".prg")
            return true
        return not strings.contains(name, '.')
    }

    sub file_exists(str name) -> bool {
        if diskio.f_open(name) {
            diskio.f_close()
            return true
        }
        return false
    }

    sub keystroke_handler() -> ubyte {
        %asm {{
            sta  cx16.r0L
        }}
        if_cs {
            ; first entry, decide if we want to override
            if cx16.r0L==9 {
                ; intercept TAB
                sys.clear_carry()
                return 0
            }
            sys.set_carry()
            return 0
        } else {
            ; second entry, handle override
            sys.save_prog8_internals()          ; because this routine is kinda called as an interrupt
            if cx16.r0L==9 {
                ; process TAB
                uword cmd = grab_cmdline()
                if cmd!=0 and cmd[0]!=0 {
                    ubyte length = strings.length(cmd)
                    uword filename = tabcomplete(cmd, length)
                    if filename!=0 {
                        repeat length txt.chrout(157)     ; cursor left
                        txt.print(filename)
                    }
                }
            }
            sys.restore_prog8_internals()
            return 0    ; eat all other characters
        }

        sub tabcomplete(str prefix, ubyte prefixlen) -> uword {
            ; use CMD DOS prefix matching
            ; this has 2 benefits: it's super fast, and is already case-insensitive
            if diskio.lf_start_list_having_prefix(prefix) {
                if diskio.lf_next_entry() {
                    diskio.lf_end_list()
                    void strings.copy(diskio.list_filename, &tabcomplete_buffer)
                    return &tabcomplete_buffer
                }
                diskio.lf_end_list()
            }
            return 0
        }

        ubyte[80] tabcomplete_buffer

        sub grab_cmdline() -> uword {
            ; TODO is there a kernal buffer for the current editor line that we can read instead?
            ubyte @shared cursor_x, cursor_y
            %asm {{
                sec
                jsr  cbm.PLOT
                stx  p8v_cursor_y
                sty  p8v_cursor_x
            }}
            uword wordptr = &tabcomplete_buffer + cursor_x-1
            tabcomplete_buffer[cursor_x] = 0
            while cursor_x!=0 {
                cursor_x--
                tabcomplete_buffer[cursor_x] = txt.getchr(cursor_x, cursor_y)
            }
            while @(wordptr)!=' ' and wordptr!=&tabcomplete_buffer
                wordptr--
            return wordptr+1
        }
    }

    sub parse_input(ubyte length) -> bool {
        uword cmd_ptr = &command_line

        ; When the cursor was moved around on the screen (up/down) the '$' prompt prefix
        ; gets copied into the input buffer too (which is how CHRIN works...)
        ; So, simply replace all initial '$' characters by a space.
        while @(cmd_ptr)=='$' {
            @(cmd_ptr)=' '
            cmd_ptr++
        }

        ; replace Shift-SPACE by just normal SPACE
        cmd_ptr = &command_line
        while @(cmd_ptr)!=0 {
            if @(cmd_ptr)==$a0
                @(cmd_ptr)=' '
            cmd_ptr++
        }
        ; skip leading spaces
        cmd_ptr = &command_line
        while @(cmd_ptr)==' ' {
            cmd_ptr++
            length--
        }
        if cmd_ptr!=command_line {
            void strings.copy(cmd_ptr, command_line)
            cmd_ptr = &command_line
        }

        ubyte space_idx
        space_idx,void = strings.find(cmd_ptr, ' ')
        if_cs {
            cmd_ptr[space_idx] = 0
            command_arguments_ptr = cmd_ptr + space_idx + 1
            command_arguments_size = length - space_idx - 1
        } else {
            command_arguments_ptr = 0
            command_arguments_size = 0
        }
        command_word_size = strings.copy(cmd_ptr, command_word)
        void strings.upper(command_word)      ; for ISO charset, this actually does a *lower*casing instead.

        return length>0
    }

    sub file_lookup_matching(uword filename_ptr, bool only_programs) -> uword {
        ; we re-use command_word variable as storage for processing the filenames read from disk.
        ; note that this also returns a success for directory names, not just file names.
        ; The match is done case-insensitively, in ISO charset.
        strings.lower_iso(filename_ptr)
        if diskio.lf_start_list(0) {
            while diskio.lf_next_entry_nocase() {
                void strings.copy(diskio.list_filename, command_word)
                ubyte disk_name_length = strings.lower_iso(command_word)
                bool has_prg_suffix = strings.endswith(command_word, ".prg") or strings.endswith(command_word, ".sh")
                bool has_no_suffix = false
                void strings.find(command_word, '.')
                if_cc
                    has_no_suffix = true
                if not only_programs or has_no_suffix or has_prg_suffix {
                    if strings.compare(command_word, filename_ptr)==0 {
                        diskio.lf_end_list()
                        return diskio.list_filename
                    }
                    if has_prg_suffix {
                        command_word[disk_name_length-4] = 0
                        if strings.compare(command_word, filename_ptr)==0 {
                            diskio.lf_end_list()
                            return diskio.list_filename
                        }
                        command_word[disk_name_length-4] = '.'
                    }
                } else if only_programs and strings.compare(command_word, filename_ptr)==0 {
                    diskio.lf_end_list()
                    err.set("Not a program")
                    return 0
                }
            }
            diskio.lf_end_list()
            return 0
        } else {
            err.set(diskio.status())
            return 0
        }
    }

    sub run_file(uword filename_ptr, bool via_basic_load) {
        if strings.endswith(filename_ptr, ".sh") or strings.endswith(filename_ptr, petscii:".sh") {       ; improve this check...?
            void execute_script(filename_ptr)
            return
        }

        if via_basic_load {
            cbm.NMINV=main.old_NMI
            ; to avoid character translation issues, we remain in ISO charset mode to perform the actual LOAD.
            ; only right before issuing the RUN command we switch back to petscii mode.
            txt.color2(1,6)     ; default white on blue
            ;; void cx16.screen_mode(0, false)
            txt.print("\x13LOAD\"")         ; home, load
            txt.print(filename_ptr)         ; is in ISO charset! Hence not yet iso_off!
            txt.print("\",")
            txt.chrout('0' + diskio.drivenumber)
            txt.chrout(':')
            for cx16.r0L in petscii:"\x13\r\x8frun:\r"     ; home, enter, iso_off, 'run', enter
                cx16.kbdbuf_put(cx16.r0L)
            sys.exit(0)
        } else {
            txt_color(TXT_COLOR_HIGHLIGHT)
            txt.print("Running: ")
            txt_color(TXT_COLOR_NORMAL)
            txt.print(filename_ptr)
            txt.nl()
            ; TODO run command via a trampoline function that returns and reloads the shell afterwards
            ;      note: IONIT/RESTOR/CINT not needed before loading the shell as it does this by itself at startup. Only needed to set correct ram/rom banks.
            ;      q: how do we know the start address of the loaded program to JSR to ???  so that we return to the trampoline afterwards?
            run_file(filename_ptr, true);  for now just run it via basic
        }
    }

    sub run_external_shell_command(str filename) {

        if not is_program_file(filename) {
            err.set("Not a program")
            return
        }

        if diskio.load(filename, 0)==0 {
            err.set(diskio.status())
            return
        }

        ; load the external command program that has already been loaded to $4000
        ; setup the 'shell bios' jump table
        const uword JUMPTABLE_TOP = $0800
        uword[] vectors = [
            ; NOTE:
            ;  - do NOT change the order of the vectors.
            ;  - only add new vectors AT THE START of the list (so existing ones stay on the same address)
            &main.extcommand_print_l,
            &main.extcommand_print_ulhex,
            &main.extcommand_drive_number,
            &main.txt_color,
            &main.extcommand_shell_version,
            &main.extcommand_get_colors,
            &cbm.CHROUT,
            &txt.print,
            &txt.print_ub,
            &txt.print_ubhex,
            &txt.print_ubbin,
            &txt.print_uw,
            &txt.print_uwhex,
            &txt.print_uwbin,
            &txt.input_chars,
            &err.set
        ]

        uword jumptable = JUMPTABLE_TOP - 3*len(vectors)
        for cx16.r0 in vectors {
            poke(jumptable, $4c)        ; JMP
            pokew(jumptable+1, cx16.r0)
            jumptable += 3
        }

        ; --- save shell variables that we don't want to have destroyed ----
        sys.push(diskio.drivenumber)

        ; call the routine with the input registers
        extsub $4000 = external_command() -> ubyte @A
        cx16.set_program_args(command_arguments_ptr, command_arguments_size)
        cx16.r1 = call($4000)

        ; --- restore shell variables ---
        diskio.drivenumber = sys.pop()
    }

    sub execute_script(str scriptname) -> bool {
        const uword script_buffer = $0400
        cx16.r0 = diskio.load_raw(scriptname, script_buffer)            ; TODO be smarter to not overwrite basic memory if script > 1kb
        if cx16.r0!=0 {
            @(cx16.r0)=0
            @(cx16.r0+1)=0
            uword script_ptr = script_buffer
            do {
                ubyte eol_index
                eol_index,void = strings.find_eol(script_ptr)
                if_cc
                    eol_index = strings.length(script_ptr)       ; last line without \n at the end
                script_ptr[eol_index] = 0
                void strings.copy(script_ptr, command_line)
                if not process_command(eol_index) {
                    err.set("error in config script")
                    return false
                }
                script_ptr += eol_index + 1
            } until @(script_ptr)==0
            return true
        }
        return false
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

    sub is_directory(str filename) -> bool {
        if diskio.lf_start_list(filename) {
            while diskio.lf_next_entry_nocase() {
                if diskio.list_filename==filename {
                    bool is_dir = diskio.list_filetype==petscii:"dir"
                    diskio.lf_end_list()
                    return is_dir
                }
            }
        }
        err.set("File not found")
        return false
    }

    sub extcommand_get_colors() -> uword {
        return &text_colors
    }

    sub extcommand_shell_version() -> str {
        return "1.8-dev"
    }

    sub extcommand_drive_number() -> ubyte {
        return diskio.drivenumber
    }

    asmsub extcommand_print_l(long value @R0R1) clobbers(A,X,Y) {
        %asm {{
            lda  cx16.r0
            sta  txt.print_l.value
            lda  cx16.r0+1
            sta  txt.print_l.value+1
            lda  cx16.r0+2
            sta  txt.print_l.value+2
            lda  cx16.r0+3
            sta  txt.print_l.value+3
            jmp  txt.print_l
        }}
    }

    asmsub extcommand_print_ulhex(long value @R0R1, bool prefix @A) clobbers(A,X,Y) {
        %asm {{
            sta  txt.print_ulhex.prefix
            lda  cx16.r0
            sta  txt.print_ulhex.value
            lda  cx16.r0+1
            sta  txt.print_ulhex.value+1
            lda  cx16.r0+2
            sta  txt.print_ulhex.value+2
            lda  cx16.r0+3
            sta  txt.print_ulhex.value+3
            jmp  txt.print_ulhex
        }}
    }

    sub txt_color(ubyte @nozp colortype) {
        ; can't use txt.color because it may clobber a zeropage variable
        cbm.CHROUT(txt.color_to_charcode[text_colors[colortype]])
    }

    sub nmi_handler() {;forcefully kills the running process and returns to the shell prompt. 
        cbm.CLRCHN()
        cbm.CLALL()
        main.txt_color(main.TXT_COLOR_ERROR)
        txt.print("Received a Kill process signal...")
        sysext.setstackptr(main.start.stackptr)
        goto main.start.the_loop
    }
}

commands {
    uword[] commands_table = [
        "help", &misc_commands.cmd_help,
        "alias", &misc_commands.cmd_alias,
        "unalias", &misc_commands.cmd_unalias,
        "exit", &misc_commands.cmd_exit,
        "mon", &misc_commands.cmd_mon,
        "num", &misc_commands.cmd_printnumber,
        "run", &misc_commands.cmd_run,
        "nano", &misc_commands.cmd_nano,
        "mem", &misc_commands.cmd_mem,
        "cls", &misc_commands.cmd_cls,
        "echo", &misc_commands.cmd_echo,
        "mode", &misc_commands.cmd_mode,
        "color", &misc_commands.cmd_color,
        "hicolor", &misc_commands.cmd_highlight_color,
        "shellver", &misc_commands.cmd_shellver,
        "ls", &disk_commands.cmd_ls,
        "cat", &disk_commands.cmd_cat,
        "rm", &disk_commands.cmd_rm,
        "mv", &disk_commands.cmd_rename,
        "cp", &disk_commands.cmd_copy,
        "cd", &disk_commands.cmd_cd,
        "pwd", &disk_commands.cmd_pwd,
        "mkdir", &disk_commands.cmd_mkdir,
        "rmdir", &disk_commands.cmd_rmdir,
        "relabel", &disk_commands.cmd_relabel,
        "drive", &disk_commands.cmd_drive,
        "dos", &disk_commands.cmd_dos
    ]

    sub recognized(str cmdword) -> uword {
        ubyte idx
        for idx in 0 to len(commands_table)-1 step 2 {
            if strings.compare(cmdword, commands_table[idx])==0
                return commands_table[idx+1]
        }
        return 0
    }
}

sysext {
    inline asmsub getstackptr()->ubyte @X{
        %asm{{
            tsx
        }}
    }
    inline asmsub setstackptr(ubyte stackptr @X){
        %asm{{
            txs
        }}
    }
}
