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
                            if command_line==".." {
                                txt.print(iso:"cd into directory. ")
                                command_arguments_ptr = ".."
                                command_arguments_size = string.length(command_arguments_ptr)
                                disk_commands.cmd_cd()
                            } else {
                                ; see if there is a program file that matches
                                uword real_filename_ptr = file_lookup_matching(command_line, true)
                                if real_filename_ptr {
                                    command_word = real_filename_ptr
                                    if is_directory(command_word) {
                                        txt.print(iso:"cd into directory. ")
                                        command_arguments_ptr = command_word
                                        command_arguments_size = string.length(command_arguments_ptr)
                                        disk_commands.cmd_cd()
                                    } else if not err.error_status {
                                        run_file(command_word, false)
                                    }
                                }
                                else
                                    void err.set(iso:"Invalid command")
                            }
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
    }

    sub file_lookup_matching(uword filename_ptr, bool only_programs) -> uword {
        ; we re-use command_word variable as storage for processing the filenames read from disk.
        ; note that this also returns a success for directory names, not just file names.
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
        if via_basic_load {
            ; to avoid character translation issues, we remain in ISO charset mode to perform the actual LOAD.
            ; only right before issuing the RUN command we switch back to petscii mode.
            txt.color2(1,6)     ; default white on blue
            void cx16.screen_mode(0, false)
            txt.print(iso:"\x13LOAD\"")         ; home, load
            txt.print(filename_ptr)             ; is in ISO charset
            txt.print(iso:"\",")
            txt.chrout(iso:'0' + diskio.drivenumber)
            txt.chrout(iso:':')
            for cx16.r0L in "\x13\r\x8frun:\r"     ; home, enter, iso_off, 'run', enter
                cx16.kbdbuf_put(cx16.r0L)
            sys.exit(0)
        } else {
            txt.color(main.COLOR_HIGHLIGHT)
            txt.print(iso:"Running: ")
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

    sub is_directory(str filename) -> bool {
        if diskio.lf_start_list(filename) {
            while diskio.lf_next_entry() {
                if diskio.list_filename==filename {
                    bool is_dir = diskio.list_filetype=="dir"
                    diskio.lf_end_list()
                    return is_dir
                }
            }
        }
        return err.set(iso:"File not found")
    }
}
