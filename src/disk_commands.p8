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


;        if diskio.lf_start_list(main.command_arguments_ptr) {
;            main.txt_color(main.TXT_COLOR_HIGHLIGHT)
;            txt.print(" Blocks  Filename\r")
;            main.txt_color(main.TXT_COLOR_NORMAL)
;            while diskio.lf_next_entry_nocase() {
;                num_files++
;                txt.spc()
;                txt.spc()
;                if diskio.list_filetype == petscii:"dir"
;                    txt.print("[dir]")
;                else
;                    main.print_uw_right(diskio.list_blocks)
;                txt.spc()
;                txt.spc()
;                txt.print(diskio.list_filename)
;                txt.nl()
;                void cbm.STOP()
;                if_z {
;                    main.txt_color(main.TXT_COLOR_HIGHLIGHT)
;                    txt.print("Break\r")
;                    main.txt_color(main.TXT_COLOR_NORMAL)
;                    break
;                }
;            }
;            diskio.lf_end_list()
;            if num_files == 0 {
;                main.txt_color(main.TXT_COLOR_HIGHLIGHT)
;                txt.print("No files\r")
;                main.txt_color(main.TXT_COLOR_NORMAL)
;            }
;            return true
;        }

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

        ; special X16 dos command to only return the current path in the entry list
        ; pull request: https://github.com/commanderx16/x16-rom/pull/373
        ; note: I'm also using *=d filter to not get a screen full of nonsense when
        ; you run this code on a rom version that doesn't yet have the $=c command.
        cbm.SETNAM(7, petscii:"$=c:*=d")
        cbm.SETLFS(12, diskio.drivenumber, 0)
        ubyte status = 1
        void cbm.OPEN()          ; open 12,8,0,"$=c:*=d"
        if_cs
            goto io_error
        void cbm.CHKIN(12)        ; use #12 as input channel
        if_cs
            goto io_error

        while cbm.CHRIN()!='"' {
            ; skip up to entry name
        }

        bool first_line_diskname=true
        status = cbm.READST()
        while status==0 {
            cx16.r0 = &main.command_line
            repeat {
                @(cx16.r0) = cbm.CHRIN()
                if @(cx16.r0)==0
                    break
                cx16.r0++
            }
            process_line(main.command_line, first_line_diskname)
            first_line_diskname=false
            while cbm.CHRIN()!='"' and status==0 {
                status = cbm.READST()
                ; skipping up to next entry name
            }
        }
        status = cbm.READST()

io_error:
        cbm.CLRCHN()        ; restore default i/o devices
        cbm.CLOSE(12)

        if status!=0 and status & $40 == 0  {          ; bit 6=end of file
            err.set("IO error")
            return false
        }

        txt.nl()
        return true

        sub process_line(uword lineptr, bool diskname) {
            if diskname {
                main.txt_color(main.TXT_COLOR_HIGHLIGHT)
                txt.print("Disk name: ")
                main.txt_color(main.TXT_COLOR_NORMAL)
            }
            repeat {
                cx16.r0L=@(lineptr)
                if cx16.r0L=='"'
                    break
                txt.chrout(cx16.r0L)
                lineptr++
            }
            if diskname {
                main.txt_color(main.TXT_COLOR_HIGHLIGHT)
                txt.print("\rCurrent dir: ")
                main.txt_color(main.TXT_COLOR_NORMAL)
            } else if @(lineptr-1)!='/' {
                main.txt_color(main.TXT_COLOR_HIGHLIGHT)
                txt.print(" in ")
                main.txt_color(main.TXT_COLOR_NORMAL)
            }
        }
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
