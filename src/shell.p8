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
    const ubyte COLOR_ERROR = 10
    const ubyte COLOR_HIGHLIGHT = 13
    const ubyte COLOR_HIGHLIGHT2 = 14
    const ubyte COLOR_BACKGROUND = 11

    str command_line = "?" * 160
    str command_word = "?" * 32
    ubyte command_word_size
    uword command_arguments_ptr
    ubyte command_arguments_size

    sub start() {
        txt.iso()
        void cx16.screen_mode(1, false)
        cx16.rombank(0)     ; switch to kernal rom for faster operation
        print_intro()

        repeat {
            txt.color(COLOR_HIGHLIGHT)
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
        string.upper(command_word)      ; for ISO charset, this actually does a *lower*casing instead.

        return length>0
    }

    sub print_intro() {
        txt.color2(COLOR_NORMAL, COLOR_BACKGROUND)
        txt.clear_screen()
        txt.color(COLOR_HIGHLIGHT)
        txt.print(iso:"\r  Commander-X16 SHELL ")
        txt.color(COLOR_NORMAL)
        txt.print(iso:"- https://github.com/irmen/cx16shell\r")
    }
}
