%import textio
%import errors

misc_commands {

    uword[] commands_table = [
        iso:"basic", &cmd_basic,
        iso:"help", &cmd_help,
        iso:"num", &cmd_printnumber,
        iso:"run", &cmd_run
    ]

    sub recognized(str cmdword, ubyte length) -> uword {
        ubyte idx
        for idx in 0 to len(commands_table)-1 step 2 {
            if string.compare(cmdword, commands_table[idx])==0
                return commands_table[idx+1]
        }
        return 0
    }

    sub cmd_basic() -> bool {
        void cx16.screen_mode(0, false)
        txt.iso_off()
        sys.exit(0)
        return true  ; not reached
    }

    sub cmd_run() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing arg: filename")

        uword real_filename_ptr = main.file_lookup_matching(main.command_arguments_ptr, true)
        if real_filename_ptr {
            main.run_file(real_filename_ptr, true)
            return true
        }
        if not err.error_status
            return err.set(iso:"File not found")
        return false
    }

    sub cmd_printnumber() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing arg: number (any prefix)")

        if conv.any2uword(main.command_arguments_ptr) {
            txt.spc()
            txt.print_uw(cx16.r15)
            txt.nl()
            txt.print_uwhex(cx16.r15, true)
            txt.nl()
            txt.print_uwbin(cx16.r15, true)
            txt.nl()
            return true
        } else {
            return err.set(iso:"Invalid number")
        }
    }

    sub cmd_help() -> bool {
        txt.color(main.COLOR_HIGHLIGHT2)
        txt.print(iso:"Commands:\r")
        txt.color(main.COLOR_NORMAL)
        ubyte idx
        for idx in 0 to len(misc_commands.commands_table)-1 step 2 {
            txt.print(misc_commands.commands_table[idx])
            txt.spc()
            txt.spc()
        }
        for idx in 0 to len(disk_commands.commands_table)-1 step 2 {
            txt.print(disk_commands.commands_table[idx])
            txt.spc()
            txt.spc()
        }
        txt.print(iso:"\rOr simply type name of program to launch (case insensitive, no suffix req'd).\r")
        return true
    }
}
