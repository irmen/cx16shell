%import textio
%import errors
%import conv
%encoding iso

misc_commands {

    uword[] commands_table = [
        "basic", &cmd_basic,
        "exit", &cmd_basic,
        "help", &cmd_help,
        "motd", &cmd_motd,
        "num", &cmd_printnumber,
        "run", &cmd_run,
        "vi", &cmd_edit,
        "pico", &cmd_edit,
        "nano", &cmd_edit,
        "mem", &cmd_mem,
        "cls", &cmd_cls
    ]

    str motd_file = petscii:"//shell-cmds/:motd.txt"

    sub recognized(str cmdword, ubyte length) -> uword {
        ubyte idx
        for idx in 0 to len(commands_table)-1 step 2 {
            if string.compare(cmdword, commands_table[idx])==0
                return commands_table[idx+1]
        }
        return 0
    }

    sub cmd_basic() -> bool {
        txt.color2(1, 6)
        txt.iso_off()
        void cx16.screen_mode(0, false)
        sys.exit(0)
        return true  ; not reached
    }

    sub cmd_run() -> bool {
        if main.command_arguments_size==0
            return err.set("Missing arg: filename")

        uword real_filename_ptr = main.file_lookup_matching(main.command_arguments_ptr, true)
        if real_filename_ptr {
            main.run_file(real_filename_ptr, true)
            return true
        }
        if not err.error_status
            return err.set("File not found")
        return false
    }

    sub cmd_cls() -> bool {
        txt.clear_screen()
        return true
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
        if main.command_arguments_size==0
            return err.set("Missing arg: number (any prefix)")

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
            return err.set("Invalid number")
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
        for idx in 0 to len(misc_commands.commands_table)-1 step 2 {
            txt.print(misc_commands.commands_table[idx])
            txt.spc()
            txt.spc()
        }
        txt.nl()
        for idx in 0 to len(disk_commands.commands_table)-1 step 2 {
            txt.print(disk_commands.commands_table[idx])
            txt.spc()
            txt.spc()
        }
        txt.color(main.COLOR_HIGHLIGHT)
        txt.print("\rCommands on disk:\r")
        txt.color(main.COLOR_NORMAL)
        txt.print("Type the name of an external command program located in 'SHELL-CMDS'\r  subdirectory (see documentation).\r")
        txt.print("Or simply type name of program to launch (no suffix req'd, case insens.).\r")
        txt.print("Typing the name of a directory, moves to there.\r")
        txt.print("Filename tab-completion is active (case sensitive).\r")
        return true
    }

    sub cmd_edit() -> bool {
        ; activate x16edit, see https://github.com/stefan-b-jakobsson/x16-edit/tree/master/docs
        ; try ROM search first, otherwise load the hi-ram version to $6000
        ubyte x16edit_bank
        for x16edit_bank in 31 downto 0  {
            cx16.rombank(x16edit_bank)
            if string.compare($fff0, petscii:"x16edit")==0
                break   ; found the x16edit rom tag
        }
        if not x16edit_bank {
            if diskio.load("x16edit-6000", 0) {
                x16edit_bank = 4
                launch_x16edit($6006)
                void cx16.screen_mode(1, false)     ; back to shell's screen mode
                return true
            } else {
                return err.set("no x16edit in rom and no x16edit-6000.prg on disk")
            }
        }

        ; launch the rom based editor
        launch_x16edit($c006)
        void cx16.screen_mode(1, false)     ; back to shell's screen mode
        return true

        sub launch_x16edit(uword entrypoint) {
            ; set screen resolution back to normal 80x60 for x16edit
            cx16.rombank(0)
            void cx16.screen_mode(0, false)
            cx16.rombank(x16edit_bank)
            cx16.r1H = %00000001        ; enable auto-indent
            cx16.r2L = 4
            cx16.r2H = 80
            cx16.r3L = diskio.drivenumber
            cx16.r3H = main.COLOR_BACKGROUND<<4 | main.COLOR_NORMAL
            cx16.r4 = 0                 ; choose default colors for status bar and headers
            if main.command_arguments_ptr {
                cx16.r0 = main.command_arguments_ptr
                cx16.r1L = main.command_arguments_size
                %asm {{
                    phx
                    ldx  #1
                    ldy  #255
                    lda  #>_return
                    pha
                    lda  #<_return
                    pha
                    jmp  (p8_entrypoint)
_return:            nop
                    plx
                }}
            } else {
                cx16.r1L = 0
                %asm {{
                    phx
                    ldx  #1
                    ldy  #255
                    lda  #>_return
                    pha
                    lda  #<_return
                    pha
                    jmp  (p8_entrypoint)
_return:            nop
                    plx
                }}
            }
            cx16.rombank(0)
        }
    }
}
