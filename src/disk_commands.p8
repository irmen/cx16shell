%import textio
%import strings
%import diskio
%import conv
%import errors
%encoding iso

disk_commands {

    sub cmd_ls() -> bool {
        if main.command_arguments_ptr!=0
            void strings.lower_iso(main.command_arguments_ptr)

        ; see if the argument is a directory, if so, change into it to list its contents
        if main.command_arguments_ptr!=0  {
            if not strings.contains(main.command_arguments_ptr,'*') and not strings.contains(main.command_arguments_ptr,'?') {
                void strings.copy(diskio.curdir(), main.command_word)
                diskio.chdir(main.command_arguments_ptr)
                if diskio.status_code()==0 {
                    defer diskio.chdir(main.command_word)
                    main.command_arguments_ptr = 0
                }
            }
        }

        cbm.SETNAM(3, petscii:"$=l")
        cbm.SETLFS(12, diskio.drivenumber, 0)
        void cbm.OPEN()          ; open 12,8,0,"$=l"
        if_cs
            goto io_error
        void cbm.CHKIN(12)        ; use #12 as input channel
        if_cs
            goto io_error

        repeat 7   void cbm.CHRIN()     ; skip the 4 prologue bytes and 2 size bytes of the header line and the first quote

        while cbm.CHRIN()!=0 {
            ; skip until the next 0-byte
        }

        repeat {
            void cbm.STOP()
            if_z {
                main.txt_color(main.TXT_COLOR_HIGHLIGHT)
                txt.print("Break\r")
                main.txt_color(main.TXT_COLOR_NORMAL)
                break
            }

            ; skip 2 bytes + 2 bytes (size in Kb)
            repeat 4  void cbm.CHRIN()
            while cbm.CHRIN()!='"' {
                if cbm.READST()!=0
                    goto end
                ; read until the first quote
            }

            ; store filename
            cx16.r1 = &diskio.list_filename
            repeat {
                cx16.r0L = cbm.CHRIN()
                if cx16.r0L=='"' {
                    @(cx16.r1) = 0
                    break
                }
                @(cx16.r1) = cx16.r0L
                cx16.r1++
            }

            if main.command_arguments_ptr==0 or strings.pattern_match_nocase(diskio.list_filename, main.command_arguments_ptr, true) {
                do {
                    cx16.r15L = cbm.CHRIN()
                } until cx16.r15L!=' '      ; skip blanks up to 3 chars entry type
                diskio.list_filetype[0] = cx16.r15L
                diskio.list_filetype[1] = cbm.CHRIN()
                diskio.list_filetype[2] = cbm.CHRIN()

                if diskio.list_filetype[0]!=petscii:'d' {
                    ; normal file, read the rest of the line
                    repeat 25  void cbm.CHRIN()
                    str hexsize = "????????"
                    for cx16.r0L in 0 to 7 {
                        hexsize[cx16.r0L] = cbm.CHRIN()
                    }
                    cx16.r0 = conv.str_l(conv.hex2long(hexsize))
                    repeat 10-strings.length(cx16.r0) txt.spc()
                    txt.print(cx16.r0)
                    txt.spc()
                    txt.spc()
                } else {
                    txt.print("     (dir)  ")
                }
                txt.print(diskio.list_filename)
                txt.nl()
            }

            while cbm.CHRIN()!=0 {
                ; skip everything up to the next 0 byte
            }
        }

end:
        cbm.CLRCHN()
        cbm.CLOSE(12)
        return true

io_error:
        cbm.CLRCHN()
        cbm.CLOSE(12)
        err.set("IO error")
        return false
    }

    sub cmd_rm() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("filename")
            return false
        }
        void strings.find(main.command_arguments_ptr, '*')
        if_cs {
            ;main.txt_color(main.TXT_COLOR_HIGHLIGHT)
            ;txt.print("Has * wildcard. Sure y/n? ")
            ;main.txt_color(main.TXT_COLOR_NORMAL)
            ;ubyte answer = c64.CHRIN()
            ;txt.nl()
            ;if answer == 'y' {
            ;    err.set("TODO custom pattern matching with * wildcard") ; TODO
            ;    return false
            ;}
            err.set("Refused to act on * wildcard")
            return false
        }
        diskio.delete(main.command_arguments_ptr)
        print_disk_status()
        return true
    }

    sub cmd_rename() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("oldfilename newfilename")
            return false
        }

        uword newfilename
        ubyte space_idx
        space_idx,void = strings.find(main.command_arguments_ptr, ' ')
        if_cs {
            newfilename = main.command_arguments_ptr + space_idx + 1
            main.command_arguments_ptr[space_idx] = 0
            diskio.rename(main.command_arguments_ptr, newfilename)
            print_disk_status()
            return true
        } else {
            err.no_args("oldfilename newfilename")
            return false
        }
    }

    sub print_disk_status() {
        main.txt_color(main.TXT_COLOR_HIGHLIGHT)
        txt.print(diskio.status())
        main.txt_color(main.TXT_COLOR_NORMAL)
        txt.nl()
    }

    sub cmd_cat() -> bool {
        uword[3] @nosplit parts
        ubyte num_parts = strings.split(main.command_arguments_ptr, parts, len(parts))
        if num_parts==0 or num_parts==2 {
            err.no_args("[-n count] filename")
            return false
        }

        uword filename_ptr = parts[0]
        uword max_lines = 65535
        if num_parts==3 {
            max_lines = conv.str2uword(parts[1])
            filename_ptr = parts[2]
        }

        if diskio.f_open(filename_ptr) {
            uword line = 0
            while line<max_lines {
                void diskio.f_readline(main.command_line)
                line++
                main.txt_color(main.TXT_COLOR_HIGHLIGHT)
                txt.print_uw(line)
                txt.column(5)
                txt.print(": ")
                main.txt_color(main.TXT_COLOR_NORMAL)
                txt.print(main.command_line)
                txt.nl()
                if cbm.READST() & 64 !=0 {
                    break
                }
                void cbm.STOP()
                if_z {
                    err.set("break")
                    break
                }
            }
            diskio.f_close()
        } else {
            err.set(diskio.status())
        }
        return true
    }

    sub cmd_pwd() -> bool {
        if main.command_arguments_size!=0 {
            err.set("Has no args")
            return false
        }
        main.txt_color(main.TXT_COLOR_HIGHLIGHT)
        txt.print("Drive number: ")
        main.txt_color(main.TXT_COLOR_NORMAL)
        txt.print_ub(diskio.drivenumber)
        txt.nl()
        main.txt_color(main.TXT_COLOR_HIGHLIGHT)
        txt.print("Current dir: ")
        txt.print(diskio.curdir())
        main.txt_color(main.TXT_COLOR_NORMAL)
        txt.nl()
        return true
    }

    sub cmd_mkdir() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("dirname")
            return false
        }
        diskio.mkdir(main.command_arguments_ptr)
        print_disk_status()
        return true
    }

    sub cmd_cd() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("dirname")
            return false
        }
        diskio.chdir(main.command_arguments_ptr)
        print_disk_status()
        return true
    }

    sub cmd_rmdir() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("dirname")
            return false
        }

        void strings.find(main.command_arguments_ptr, '*')
        if_cs {
            err.set("Refused to act on * wildcard")
            return false
        }

        diskio.rmdir(main.command_arguments_ptr)
        print_disk_status()
        return true
    }

    sub cmd_relabel() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("diskname")
            return false
        }
        diskio.relabel(main.command_arguments_ptr)
        print_disk_status()
        return true
    }

    sub cmd_copy() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("oldfilename newfilename")
            return false
        }

        uword newfilename
        ubyte space_idx
        space_idx,void = strings.find(main.command_arguments_ptr, ' ')
        if_cs {
            newfilename = main.command_arguments_ptr + space_idx + 1
            main.command_arguments_ptr[space_idx] = 0
            diskio.list_filename[0] = petscii:'c'
            diskio.list_filename[1] = petscii:':'
            ubyte length = strings.copy(newfilename, &diskio.list_filename+2)
            diskio.list_filename[length+2] = petscii:'='
            void strings.copy(main.command_arguments_ptr, &diskio.list_filename+length+3)
            diskio.send_command(diskio.list_filename)
            print_disk_status()
            return true
        } else {
            err.no_args("oldfilename newfilename")
            return false
        }
    }

    sub cmd_drive() -> bool {
        if main.command_arguments_size==0 {
            err.no_args("drive number")
            return false
        }

        ubyte nr = conv.str2ubyte(main.command_arguments_ptr)

        when nr {
            8, 9 -> {
                txt.print("Switching drive.\r")
                diskio.drivenumber = nr
                void diskio.fastmode(3)     ; switch this drive to fast reads and writes as well
                main.command_arguments_size = 0
                return cmd_pwd()
            }
            else -> {
                err.set("Invalid drive number")
                return false
            }
        }
    }

    sub cmd_dos() -> bool {
        if main.command_arguments_size!=0 {
            if @(main.command_arguments_ptr)=='"'
                main.command_arguments_ptr++
            diskio.send_command(main.command_arguments_ptr)
        }
        txt.print(diskio.status())
        txt.nl()
        return true
    }
}
