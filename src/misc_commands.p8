%import textio
%import errors
%import conv
%import aliases
%encoding iso

misc_commands {

    sub cmd_exit() -> bool {
        txt.color2(1, 6)
        txt.iso_off()
        sys.exit(0)
        return true  ; not reached
    }

    sub cmd_run() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("filename")
            return false
        }

        uword real_filename_ptr = main.file_lookup_matching(main.command_arguments_ptr, true)
        if real_filename_ptr!=0 {
            main.run_file(real_filename_ptr, true)
            return true
        }
        if not err.error_status
            err.set("File not found")
        return false
    }

    sub cmd_cls() -> bool {
        txt.clear_screen()
        return true
    }

    sub cmd_echo() -> bool {
        if main.command_arguments_size!=0 {
            while string.isspace(@(main.command_arguments_ptr))
                main.command_arguments_ptr++
            while @(main.command_arguments_ptr)!=0 {
                when @(main.command_arguments_ptr) {
                    '\\' -> {
                        main.command_arguments_ptr++
                        when @(main.command_arguments_ptr) {
                            '\\' -> txt.chrout('\\')
                            '"' -> txt.chrout('"')
                            's' -> txt.spc()
                            'n' -> txt.nl()
                            'b' -> txt.bell()
                            'c' -> {
                                main.command_arguments_ptr++
                                cx16.r0L = @(main.command_arguments_ptr)-'0'
                                if cx16.r0L >= 5 {
                                    err.set("invalid txt color number")
                                    return false
                                }
                                main.txt_color(cx16.r0L)
                            }
                            'x' -> {
                                str hex = "??"
                                main.command_arguments_ptr++
                                hex[0] = @(main.command_arguments_ptr)
                                main.command_arguments_ptr++
                                hex[1] = @(main.command_arguments_ptr)
                                txt.chrout(conv.hex2uword(hex) as ubyte)
                            }
                            0 -> return true
                            else -> txt.chrout(@(main.command_arguments_ptr))
                        }
                    }
                    0 -> break
                    '"' -> { /* quotes need to be escaped */ }
                    else -> txt.chrout(@(main.command_arguments_ptr))
                }
                main.command_arguments_ptr++
            }
        }
        txt.nl()
        return true
    }

    sub cmd_color() -> bool {
        if main.command_arguments_size==0 {
            txt.print("Current: text=")
            txt.print_ub(main.text_colors[main.TXT_COLOR_NORMAL])
            txt.print(" bg=")
            txt.print_ub(main.text_colors[main.TXT_COLOR_BACKGROUND])
            txt.print(" border=")
            txt.print_ub(cx16.VERA_DC_BORDER)
            txt.nl()
            return true
        }

        ubyte txtcol = conv.str2ubyte(main.command_arguments_ptr) & 15
        main.command_arguments_ptr += cx16.r15 + 1
        ubyte bgcol = conv.str2ubyte(main.command_arguments_ptr) & 15
        main.command_arguments_ptr += cx16.r15 + 1

        if txtcol==bgcol {
            err.set("Text and bg color are the same")
            return false
        }

        main.text_colors[main.TXT_COLOR_NORMAL] = txtcol
        main.text_colors[main.TXT_COLOR_BACKGROUND] = bgcol
        cx16.VERA_DC_BORDER = conv.str2ubyte(main.command_arguments_ptr)
        txt.color2(main.text_colors[main.TXT_COLOR_NORMAL], main.text_colors[main.TXT_COLOR_BACKGROUND])
        txt.clear_screen()
        return true
    }

    sub cmd_highlight_color() -> bool {
        if main.command_arguments_size==0 {
            txt.print("Current: highlight=")
            txt.print_ub(main.text_colors[main.TXT_COLOR_HIGHLIGHT])
            txt.print(" prompt=")
            txt.print_ub(main.text_colors[main.TXT_COLOR_HIGHLIGHT_PROMPT])
            txt.print(" error=")
            txt.print_ub(main.text_colors[main.TXT_COLOR_ERROR])
            txt.nl()
            return true
        }

        ubyte strcol = conv.str2ubyte(main.command_arguments_ptr) & 15
        main.command_arguments_ptr += cx16.r15 + 1
        
        if strcol==main.text_colors[main.TXT_COLOR_BACKGROUND] {
            err.set("Highlight and bg color are the same")
            return false
        }

        ubyte prptcol = conv.str2ubyte(main.command_arguments_ptr) & 15
        main.command_arguments_ptr += cx16.r15 + 1

        ubyte errcol = conv.str2ubyte(main.command_arguments_ptr)

        if errcol==main.text_colors[main.TXT_COLOR_BACKGROUND] {
            err.set("Error and bg color are the same")
            return false
        }

        if errcol==main.text_colors[main.TXT_COLOR_NORMAL] {
            err.set("Error and text color are the same")
            return false
        }

        main.text_colors[main.TXT_COLOR_HIGHLIGHT] = strcol
        main.text_colors[main.TXT_COLOR_HIGHLIGHT_PROMPT] = prptcol
        main.text_colors[main.TXT_COLOR_ERROR] = errcol
        return true
    }


    sub cmd_mode() -> bool {
        if main.command_arguments_size==0 {
            get_active_mode()
            txt.print("Active screen mode: ")
            txt.print_ub(cx16.r2L)
            txt.print(" (")
            txt.print_ub(cx16.r3L)
            txt.print(" by ")
            txt.print_ub(cx16.r4L)
            txt.print(")\rCall with mode number to switch modes.\r")
            return true
        }
        if conv.any2uword(main.command_arguments_ptr)!=0 {
            if cx16.r15L>11 {
                err.set("Invalid mode (0-11)")
                return false
            }
            get_active_mode()
            if cx16.r2L != cx16.r15L {
                void cx16.screen_mode(cx16.r15L, false)
                main.init_screen()
            }
            return true
        } else {
            err.set("Invalid mode (0-11)")
            return false
        }

        sub get_active_mode() {
            void cx16.get_screen_mode()
            %asm {{
                sta  cx16.r2L
                stx  cx16.r3L
                sty  cx16.r4L
            }}
        }
    }

    sub cmd_mem() -> bool {
        txt.print("Shell prg: ")
        txt.print_uwhex(cbm.MEMBOT(0, true), true)
        txt.chrout('-')
        txt.print_uwhex(sys.progend(), true)
        txt.print("\rRam banks: ")
        txt.print_uw(cx16.numbanks())
        txt.chrout('=')
        txt.print_uw(cx16.numbanks() * $0008)
        txt.print("KB\rMemTop: ")
        txt.print_uwhex(cbm.MEMTOP(0, true), true)
        txt.nl()
        return true
    }

    sub cmd_printnumber() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("number (can use % and $ prefixes too)")
            return false
        }

        if conv.any2uword(main.command_arguments_ptr)!=0 {
            txt.spc()
            txt.print_uw(cx16.r15)
            txt.nl()
            txt.print_uwhex(cx16.r15, true)
            txt.nl()
            txt.print_uwbin(cx16.r15, true)
            txt.nl()
            return true
        } else {
            err.set("Invalid number")
            return false
        }
    }

    sub cmd_help() -> bool {
        main.txt_color(main.TXT_COLOR_HIGHLIGHT)
        txt.print("Builtin Commands:\r")
        main.txt_color(main.TXT_COLOR_NORMAL)
        ubyte idx
        for idx in 0 to len(commands.commands_table)-1 step 2 {
            txt.print(commands.commands_table[idx])
            txt.spc()
            txt.spc()
        }
        if aliases.num_aliases!=0 {
            main.txt_color(main.TXT_COLOR_HIGHLIGHT)
            txt.print("\rAliases:\r")
            main.txt_color(main.TXT_COLOR_NORMAL)
            aliases.print_list()
        }
        main.txt_color(main.TXT_COLOR_HIGHLIGHT)
        txt.print("\rCommands on disk:\r")
        main.txt_color(main.TXT_COLOR_NORMAL)
        txt.print("Type the name of an external command program located in 'SHELL-FILES'\r  subdirectory (see documentation).\r")
        txt.print("Or just type name of program to launch (no suffix req'd, case insensitive).\r")
        txt.print("Typing the name of a directory moves into it.\r")
        txt.print("Filename tab-completion is active (case sensitive).\r")
        return true
    }

    sub cmd_edit() -> bool {
        ; activate rom based x16edit, see https://github.com/stefan-b-jakobsson/x16-edit/tree/master/docs
        ubyte x16edit_bank = cx16.search_x16edit()
        if x16edit_bank<255 {
            ;; void cx16.screen_mode(0, false)   ; back to 80x60 mode?
            ubyte filename_length = 0
            if main.command_arguments_ptr!=0 {
                filename_length = main.command_arguments_size
                if not string.endswith(main.command_arguments_ptr, ".sh")
                    txt.iso_off()
            } else
                txt.iso_off()
            ubyte old_bank = cx16.getrombank()
            cx16.rombank(x16edit_bank)
            cx16.x16edit_loadfile_options(1, 255, main.command_arguments_ptr,
                mkword(%00000011, filename_length),         ; auto-indent and word-wrap enable
                mkword(80, 4),          ; wrap and tabstop
                mkword(main.text_colors[main.TXT_COLOR_BACKGROUND]<<4 | main.text_colors[main.TXT_COLOR_NORMAL], diskio.drivenumber),
                mkword(0,0))
            cx16.rombank(0)
            main.init_screen()
            return true
        } else {
            err.set("no x16edit found in rom")
            return false
        }
    }

    sub cmd_mon() -> bool {
        txt.print("Entering the machine language monitor.\r")
        txt.print("(use 'G' without args, to return directly back to the shell)\r")
        cx16.monitor()
        txt.nl()
        return true
    }

    sub cmd_alias() -> bool {
        if main.command_arguments_size==0 {
            aliases.print_table()
            return true
        }
        ubyte equals_idx = string.find(main.command_arguments_ptr, '=')
        if_cs {
            uword def_ptr = main.command_arguments_ptr + equals_idx + 1
            main.command_arguments_ptr[equals_idx] = 0
            return aliases.add(main.command_arguments_ptr, def_ptr)
        }
        err.no_args("alias=command")
        return false

    }

    sub cmd_unalias() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("alias")
            return false
        }
        aliases.remove(main.command_arguments_ptr)
        return true
    }
}
