; EXAMPLE external command source code

%import diskio
%import strings
%import conv
%import shellroutines
%launcher none
%option no_sysinit
%zeropage basicsafe
%encoding iso
%address $4000


main {
    %option force_output

    sub printparts(ubyte numparts, ^^uword parts) {
        shell.print_ub(numparts)
        shell.print(" parts: ")
        if numparts > 0 {
            for cx16.r0L in 0 to numparts-1 {
                shell.print(parts[cx16.r0L])
                shell.chrout(',')
            }
        }
        shell.chrout('\n')
    }

    sub start()  {
        str args = "?" * 60
        cx16.get_program_args(args, len(args), false)

        uword[3] @nosplit parts
        ubyte num_args = strings.split(args, parts, len(parts))

        ^^ubyte filename
        uword num_bytes = 65535

        when num_args {
            1 -> {
                filename = parts[0]
            }
            3 -> {
                if "-n" != parts[0] {
                    shell.err_set("invalid arguments. Expected: [-n numbytes] filename")
                    sys.exit(1)
                }
                num_bytes = conv.str2uword(parts[1])
                filename = parts[2]
            }
            else -> {
                shell.err_set("invalid arguments. Expected: [-n numbytes] filename")
                sys.exit(1)
            }
        }

        str line = "?" * 16
        uword index = 0

        if diskio.f_open(filename) {
            while index < num_bytes {
                sys.memset(line, 16, 0)
                void diskio.f_read(line, 16)
                shell.chrout(' ')
                shell.txt_color(shell.TXT_COLOR_HIGHLIGHT)
                shell.print_uwhex(index, true)
                shell.txt_color(shell.TXT_COLOR_NORMAL)
                shell.chrout(' ')
                shell.chrout(' ')
                for cx16.r0L in 0 to 7 {
                    shell.print_ubhex(line[cx16.r0L], false)
                    shell.chrout(' ')
                }
                shell.chrout(' ')
                for cx16.r0L in 8 to 15 {
                    shell.print_ubhex(line[cx16.r0L], false)
                    shell.chrout(' ')
                }
                shell.chrout(' ')
                shell.chrout(' ')
                shell.txt_color(shell.TXT_COLOR_HIGHLIGHT_PROMPT)
                for cx16.r0L in 0 to 15 {
                    if line[cx16.r0L]==0 {
                        shell.chrout('.')
                    }
                    else {
                        shell.chrout(128)
                        shell.chrout(line[cx16.r0L])
                    }
                }
                shell.txt_color(shell.TXT_COLOR_NORMAL)
                shell.chrout('\n')
                index += 16

                if cbm.READST()!=0
                    break
                void cbm.STOP()
                if_z
                    break
            }

            diskio.f_close()
        } else {
            shell.err_set(diskio.status())
            sys.exit(1)
        }

        sys.exit(0)
    }
}
