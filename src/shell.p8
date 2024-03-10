%import textio
%import diskio
%import string
%import errors
%import disk_commands
%import misc_commands
%encoding iso
%zeropage basicsafe
%option no_sysinit

main {
    ubyte COLOR_NORMAL = 1
    ubyte COLOR_BACKGROUND = 6
    ubyte COLOR_HIGHLIGHT = 3
    ubyte COLOR_HIGHLIGHT_PROMPT = 13
    ubyte COLOR_ERROR = 10
    str command_line = "?" * 160
    str command_word = "?" * 64
    ubyte command_word_size
    uword command_arguments_ptr
    ubyte command_arguments_size


    sub start() {
        cx16.rombank(0)     ; switch to kernal rom bank for faster operation
        init_screen()
        load_config()

        repeat {
            txt.color(COLOR_HIGHLIGHT_PROMPT)
            txt.nl()
            txt.print("$ ")
            txt.color(COLOR_NORMAL)
            err.clear()

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
        txt.color2(COLOR_NORMAL, COLOR_BACKGROUND)
        cx16.VERA_DC_BORDER = COLOR_BACKGROUND
        txt.iso()
        txt.clear_screen()
    }

    sub load_config() {
        str configfile = petscii:"//shell-cmds/:config.sh"
        const uword script_buffer = $0400
        cx16.r0 = diskio.load_raw(configfile, script_buffer)            ; TODO be smarter to not overwrite basic memory if script > 1kb
        if cx16.r0!=0 {
            @(cx16.r0)=0
            @(cx16.r0+1)=0
            uword script_ptr = script_buffer
            do {
                ubyte eol_index = string.find(script_ptr, '\n')
                if_cc
                    eol_index = string.length(script_ptr)       ; last line without \n at the end
                script_ptr[eol_index] = 0
                command_line = script_ptr
                if not process_command(eol_index) {
                    err.set("error in config script")
                    break
                }
                script_ptr += eol_index + 1
            } until @(script_ptr)==0
        } else {
            diskio.send_command(petscii:"i")
        }
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
            command_word = aliased_cmd
        uword command_routine = commands.recognized(command_word)
        if command_routine!=0 {
            if lsb(call(command_routine))!=0   ; indirect JSR, only returning a byte in this case
                err.clear()
            else if not err.error_status
                err.set("Unspecified error")
        } else {
            ; see if there is an external shell command in the SHELL-CMDS subdirectory that matches
            diskio.list_filename = petscii:"//shell-cmds/:"
            void string.copy(command_word, &diskio.list_filename+14)
            if diskio.load(diskio.list_filename, 0)!=0
                void run_external_command()
            else {
                if command_line==".." {
                    txt.print("cd into directory. ")
                    command_arguments_ptr = ".."
                    command_arguments_size = string.length(command_arguments_ptr)
                    void disk_commands.cmd_cd()
                } else {
                    ; see if there is a program file that matches
                    uword real_filename_ptr = file_lookup_matching(command_line, true)
                    if real_filename_ptr!=0 {
                        command_word = real_filename_ptr
                        if is_directory(command_word) {
                            txt.print("cd into directory. ")
                            command_arguments_ptr = command_word
                            command_arguments_size = string.length(command_arguments_ptr)
                            void disk_commands.cmd_cd()
                        } else if not err.error_status {
                            run_file(command_word, false)
                        }
                    }
                    else
                        err.set("Invalid command")
                }
            }
        }
        return true
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
                    ubyte length = string.length(cmd)
                    uword filename = tabcomplete(cmd, length)
                    if filename!=0 {
                        txt.print(filename+length)
                    }
                }
            }
            sys.restore_prog8_internals()
            return 0    ; eat all other characters
        }

        sub tabcomplete(str prefix, ubyte prefixlen) -> uword {
            prefix[prefixlen] = '*'
            prefix[prefixlen+1] = 0
            if diskio.lf_start_list(prefix) {
                if diskio.lf_next_entry() {
                    diskio.lf_end_list()
                    void string.copy(diskio.list_filename, &tabcomplete_buffer)
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
            void string.copy(cmd_ptr, command_line)
            cmd_ptr = &command_line
        }

        ubyte space_idx = string.find(cmd_ptr, ' ')
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

    sub file_lookup_matching(uword filename_ptr, bool only_programs) -> uword {
        ; we re-use command_word variable as storage for processing the filenames read from disk.
        ; note that this also returns a success for directory names, not just file names.
        void iso_to_lowercase_petscii(filename_ptr)
        if diskio.lf_start_list(0) {
            while diskio.lf_next_entry() {
                command_word = diskio.list_filename
                ubyte disk_name_length = string.lower(command_word)
                bool has_prg_suffix = string.endswith(command_word, petscii:".prg")
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
                        command_word[disk_name_length-4] = '.'
                    }
                } else if only_programs and string.compare(command_word, filename_ptr)==0 {
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

    sub iso_to_lowercase_petscii(uword str_ptr) -> ubyte {
        ubyte length=0
        while @(str_ptr)!=0 {
            if @(str_ptr) >= 'a' and @(str_ptr) <= 'z'
                @(str_ptr) -= 32
            str_ptr++
            length++
        }
        return length
    }

    sub run_file(uword filename_ptr, bool via_basic_load) {
        if via_basic_load {
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
            txt.color(main.COLOR_HIGHLIGHT)
            txt.print("Running: ")
            txt.color(main.COLOR_NORMAL)
            txt.print(filename_ptr)
            txt.nl()
            ; TODO run command via a trampoline function that returns and reloads the shell afterwards
            ;      note: IONIT/RESTOR/CINT not needed before loading the shell as it does this by itself at startup. Only needed to set correct ram/rom banks.
            ;      q: how do we know the start address of the loaded program to JSR to ???  so that we return to the trampoline afterwards?
            run_file(filename_ptr, true);  for now just run it via basic
        }
    }

    sub run_external_command() -> bool {
        ; load the external command program that has already been loaded to $4000
        ; setup the 'shell bios' jump table

        const uword JUMPTABLE_TOP = $0800
        uword[] vectors = [
            ; NOTE:
            ;  - do NOT change the order of the vectors.
            ;  - only add new vectors AT THE START of the list (so existing ones stay on the same address)
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

        sys.push(diskio.drivenumber)     ; only variable in ZP that we need to save
        rsave()
        ; call the routine with the input registers
        romsub $4000 = external_command() -> ubyte @A
        cx16.set_program_args(command_arguments_ptr, command_arguments_size)
        cx16.r1 = call($4000)
        rrestore()
        diskio.drivenumber = sys.pop()
        return cx16.r1L != 0
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
            while diskio.lf_next_entry() {
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
        ubyte[5] colors
        colors[0] = main.COLOR_NORMAL
        colors[1] = main.COLOR_BACKGROUND
        colors[2] = main.COLOR_HIGHLIGHT
        colors[3] = main.COLOR_HIGHLIGHT_PROMPT
        colors[4] = main.COLOR_ERROR
        return &colors
    }

    sub extcommand_shell_version() -> str {
        str version_string="1.3"
        return version_string
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
        "nano", &misc_commands.cmd_edit,
        "mem", &misc_commands.cmd_mem,
        "cls", &misc_commands.cmd_cls,
        "echo", &misc_commands.cmd_echo,
        "mode", &misc_commands.cmd_mode,
        "color", &misc_commands.cmd_color,
        "hicolor", &misc_commands.cmd_highlight_color,
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
        "drive", &disk_commands.cmd_drive
    ]

    sub recognized(str cmdword) -> uword {
        ubyte idx
        for idx in 0 to len(commands_table)-1 step 2 {
            if string.compare(cmdword, commands_table[idx])==0
                return commands_table[idx+1]
        }
        return 0
    }
}