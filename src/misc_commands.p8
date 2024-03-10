%import textio
%import errors
%import conv
%import aliases
%encoding iso

misc_commands {

    str motd_file = petscii:"//shell-cmds/:motd.txt"

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
            txt.print(main.command_arguments_ptr)
        }
        return true
    }

    sub cmd_color() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("textcolor,bgcolor,bordercolor")
            return false
        }

        ubyte txtcol = conv.str2ubyte(main.command_arguments_ptr) & 15
        main.command_arguments_ptr += cx16.r15 + 1
        ubyte bgcol = conv.str2ubyte(main.command_arguments_ptr) & 15
        main.command_arguments_ptr += cx16.r15 + 1

        if txtcol==bgcol {
            err.set("Text and bg color are the same")
            return false
        }

        main.COLOR_NORMAL = txtcol
        main.COLOR_BACKGROUND = bgcol
        cx16.VERA_DC_BORDER = conv.str2ubyte(main.command_arguments_ptr)
        txt.color2(main.COLOR_NORMAL, main.COLOR_BACKGROUND)
        txt.clear_screen()
        return true
    }

    sub cmd_highlight_color() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("strongcolor,promptcolor,errcolor")
            return false
        }

        ubyte strcol = conv.str2ubyte(main.command_arguments_ptr) & 15
        main.command_arguments_ptr += cx16.r15 + 1
        
        if strcol==main.COLOR_BACKGROUND {
            err.set("Highlight and bg color are the same")
            return false
        }

        ubyte prptcol = conv.str2ubyte(main.command_arguments_ptr) & 15
        main.command_arguments_ptr += cx16.r15 + 1

        ubyte errcol = conv.str2ubyte(main.command_arguments_ptr)

        if errcol==main.COLOR_BACKGROUND {
            err.set("Error and bg color are the same")
            return false
        }

        if errcol==main.COLOR_NORMAL {
            err.set("Error and text color are the same")
            return false
        }

        txt.print("H: ")
        txt.color(main.COLOR_HIGHLIGHT)
        txt.print_ub(main.COLOR_HIGHLIGHT)
        txt.color(main.COLOR_NORMAL)
        txt.print("->")
        txt.color(strcol)
        txt.print_ub(strcol)
        txt.color(main.COLOR_NORMAL)

        txt.print("\rP: ")
        txt.color(main.COLOR_HIGHLIGHT_PROMPT)
        txt.print_ub(main.COLOR_HIGHLIGHT_PROMPT)
        txt.color(main.COLOR_NORMAL)
        txt.print("->")
        txt.color(prptcol)
        txt.print_ub(prptcol)
        txt.color(main.COLOR_NORMAL)

        txt.print("\rE: ")
        txt.color(main.COLOR_ERROR)
        txt.print_ub(main.COLOR_ERROR)
        txt.color(main.COLOR_NORMAL)
        txt.print("->")
        txt.color(errcol)
        txt.print_ub(errcol)
        txt.color(main.COLOR_NORMAL)


        main.COLOR_HIGHLIGHT = strcol
        main.COLOR_HIGHLIGHT_PROMPT = prptcol
        main.COLOR_ERROR = errcol
        return true
    }


    sub cmd_mode() -> bool {
        if main.command_arguments_size==0 {
            void cx16.get_screen_mode()
            %asm {{
                sta  cx16.r2L
                stx  cx16.r3L
                sty  cx16.r4L
            }}
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
            void cx16.screen_mode(cx16.r15L, false)
            main.init_screen()
            return true
        } else {
            err.set("Invalid mode (0-11)")
            return false
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

    sub cmd_motd() -> bool {
        txt.color(main.COLOR_HIGHLIGHT)
        txt.print("Message Of The Day (motd.txt):\r")
        txt.color(main.COLOR_NORMAL)
        main.command_arguments_ptr = &motd_file
        main.command_arguments_size = string.length(motd_file)
        return disk_commands.cmd_cat()
    }

    sub cmd_help() -> bool {
        txt.color(main.COLOR_HIGHLIGHT)
        txt.print("Builtin Commands:\r")
        txt.color(main.COLOR_NORMAL)
        ubyte idx
        for idx in 0 to len(commands.commands_table)-1 step 2 {
            txt.print(commands.commands_table[idx])
            txt.spc()
            txt.spc()
        }
        if aliases.num_aliases!=0 {
            txt.color(main.COLOR_HIGHLIGHT)
            txt.print("\rAliases:\r")
            txt.color(main.COLOR_NORMAL)
            aliases.print_list()
        }
        txt.color(main.COLOR_HIGHLIGHT)
        txt.print("\rCommands on disk:\r")
        txt.color(main.COLOR_NORMAL)
        txt.print("Type the name of an external command program located in 'SHELL-CMDS'\r  subdirectory (see documentation).\r")
        txt.print("Or just type name of program to launch (no suffix req'd, case insensitive).\r")
        txt.print("Typing the name of a directory moves into it.\r")
        txt.print("Filename tab-completion is active (case sensitive).\r")
        return true
    }

    sub cmd_edit() -> bool {
        ; activate rom based x16edit, see https://github.com/stefan-b-jakobsson/x16-edit/tree/master/docs
        ubyte x16edit_bank = cx16.search_x16edit()
        if x16edit_bank<255 {
            sys.enable_caseswitch()     ; workaround for character set issue in X16Edit 0.7.1
            ;; void cx16.screen_mode(0, false)   ; back to 80x60 mode?
            txt.iso_off()
            ubyte filename_length = 0
            if main.command_arguments_ptr!=0
                filename_length = main.command_arguments_size
            ubyte old_bank = cx16.getrombank()
            cx16.rombank(x16edit_bank)
            cx16.x16edit_loadfile_options(1, 255, main.command_arguments_ptr,
                mkword(%00000011, filename_length),         ; auto-indent and word-wrap enable
                mkword(80, 4),          ; wrap and tabstop
                mkword(main.COLOR_BACKGROUND<<4 | main.COLOR_NORMAL, diskio.drivenumber),
                mkword(0,0))
            cx16.rombank(0)
            main.init_screen()
            sys.disable_caseswitch()
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
