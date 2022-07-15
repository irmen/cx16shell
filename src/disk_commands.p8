%import textio
%import string
%import diskio
%import conv
%import errors

disk_commands {

    ubyte drivenumber = 8

    uword[] commands_table = [
        iso:"ls", &cmd_ls,
        iso:"cat", &cmd_cat,
        iso:"vi", &cmd_edit,
        iso:"ed", &cmd_edit,
        iso:"pwd", &cmd_pwd,
        iso:"drive", &cmd_drive
    ]

    sub recognized(str cmdword, ubyte length) -> uword {
        ubyte idx
        for idx in 0 to len(commands_table)-1 step 2 {
            if string.compare(cmdword, commands_table[idx])==0
                return commands_table[idx+1]
        }
        return 0
    }

    sub cmd_ls() -> bool {
        if main.command_arguments_size
            return err.set(iso:"Has no args")
        return diskio.directory(drivenumber)
    }


    sub cmd_cat() -> bool {
        cx16.rombank(0)     ; switch to kernal rom for faster file i/o
        if diskio.f_open(drivenumber, main.command_arguments_ptr) {
            uword line = 0
            repeat {
                void diskio.f_readline(main.command_line)
                line++
                txt.color(main.COLOR_HIGHLIGHT2)
                txt.print_uw(line)
                txt.column(5)
                txt.print(": ")
                txt.color(main.COLOR_NORMAL)
                txt.print(main.command_line)
                txt.nl()
                if c64.READST() & 64 {
                    break
                }
                if c64.STOP2() {
                    err.set("break")
                    break
                }
            }
            diskio.f_close()
        } else {
            txt.print(iso:"cannot open\r")
            err.set(diskio.status(drivenumber))
        }
        cx16.rombank(4)     ; switch back to basic rom
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
            if diskio.load(drivenumber, "x16edit-6000", 0) {
                x16edit_bank = 4
                launch_x16edit($6006)
                void cx16.screen_mode(1, false)     ; back to shell's screen mode
                return true
            } else {
                return err.set(iso:"no x16edit in rom and no x16edit-6000.prg on disk")
            }
        }

        ; launch the rom based editor
        launch_x16edit($c006)
        void cx16.screen_mode(1, false)     ; back to shell's screen mode
        return true

        sub launch_x16edit(uword entrypoint) {
            ; set screen resolution back to normal 80x60 for x16edit
            cx16.rombank(4)
            void cx16.screen_mode(0, false)
            cx16.rombank(x16edit_bank)
            cx16.r1H = %00000001        ; enable auto-indent
            cx16.r2L = 4
            cx16.r2H = 80
            cx16.r3L = drivenumber
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
                    jmp  (entrypoint)
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
                    jmp  (entrypoint)
_return:            nop
                    plx
                }}
            }
            cx16.rombank(4)
        }
    }

    sub cmd_pwd() -> bool {
        if main.command_arguments_size
            return err.set(iso:"Has no args")
        txt.print(iso:"Drive number: ")
        txt.print_ub(drivenumber)
        txt.nl()
        return true
    }

    sub cmd_drive() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing arg: drive number")

        ubyte nr = conv.str2ubyte(main.command_arguments_ptr)

        when nr {
            8, 9, 10, 11 -> {
                drivenumber = nr
                return true
            }
            else -> {
                return err.set(iso:"Invalid drive number")
            }
        }
    }

}