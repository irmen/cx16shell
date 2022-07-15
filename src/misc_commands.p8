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

        if not diskio.f_open(disk_commands.drivenumber, main.command_arguments_ptr)
            return err.set(diskio.status(disk_commands.drivenumber))

        ; make sure the screen and everything is set back to normal mode, and issue the load+run commands.
        c64.IOINIT()
        c64.RESTOR()
        c64.CINT()
        txt.print("\x93load \"")
        txt.print(main.command_arguments_ptr)
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
        return true  ; not reached
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
        txt.nl()
        return true
    }
}