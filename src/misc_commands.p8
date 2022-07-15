%import textio
%import errors

misc_commands {

    uword[] commands_table = [
        iso:"basic", &cmd_basic,
        iso:"help", &cmd_help,
        iso:"?", &cmd_help
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
        return true     ; not reached
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