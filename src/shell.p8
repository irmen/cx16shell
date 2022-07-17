%import textio
%import diskio
%import string
%import errors
%import disk_commands
%import misc_commands
%zeropage basicsafe
%option no_sysinit

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
        txt.iso()
        void cx16.screen_mode(1, false)
        cx16.rombank(0)     ; switch to kernal rom for faster operation
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
                        ubyte success
                        callfar(0, command_routine, &success)
                        if success!=0
                            err.clear()
                        else if not err.error_status {
                            void err.set(iso:"Unspecified error")
                        }
                    } else {
                        ; see if there is a program file that matches
                        uword real_filename_ptr = file_lookup_matching(command_line, true)
                        if real_filename_ptr
                            run_file(real_filename_ptr, false)
                        else
                            void err.set(iso:"Invalid command")
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
        void iso_to_lowercase_petscii(filename_ptr)
        if diskio.lf_start_list(8, 0) {
            while diskio.lf_next_entry() {
                command_word = diskio.list_filename
                ubyte disk_name_length = string.lower(command_word)
                str name_suffix = "????"    ; TODO use string.endswith() once that is available in prog8
                void string.right(command_word, 4, name_suffix)
                bool has_prg_suffix = name_suffix==".prg"
                bool is_program = name_suffix[0]!='.' or has_prg_suffix
                if not only_programs or is_program {
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
            return err.set(diskio.status(disk_commands.drivenumber))
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
                c64.IOINIT()
                c64.RESTOR()
                c64.CINT()
                txt.print("\x93load \"")
                txt.print(filename_ptr)
                txt.print("\",")
                txt.print_ub(disk_commands.drivenumber)
                txt.print(":\n")
                cx16.kbdbuf_put(19)     ; home
                cx16.kbdbuf_put('\r')
                cx16.kbdbuf_put('r')
                cx16.kbdbuf_put('u')
                cx16.kbdbuf_put('n')
                cx16.kbdbuf_put(':')
                cx16.kbdbuf_put('\r')
                sys.exit(0)
            } else {
                ; TODO run command via a trampoline function that returns and reloads the shell afterwards
                run_file(filename_ptr, true);  for now just run it via basic
            }
        }
}
