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
        iso:"rm", &cmd_rm,
        iso:"del", &cmd_rm,
        iso:"mv", &cmd_rename,
        iso:"ren", &cmd_rename,
        iso:"cp", &cmd_copy,
        iso:"cd", &cmd_cd,
        iso:"pwd", &cmd_pwd,
        iso:"mkdir", &cmd_mkdir,
        iso:"rmdir", &cmd_rmdir,
        iso:"relabel", &cmd_relabel,
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
        ubyte num_files = 0
        if diskio.lf_start_list(drivenumber, main.command_arguments_ptr) {
            txt.color(main.COLOR_HIGHLIGHT)
            txt.print(iso:" Blocks  Filename\r")
            txt.color(main.COLOR_NORMAL)
            while diskio.lf_next_entry() {
                num_files++
                txt.spc()
                txt.spc()
                if diskio.list_filetype == "dir"
                    txt.print(iso:"[dir]")
                else
                    main.print_uw_right(diskio.list_blocks)
                txt.spc()
                txt.spc()
                txt.print(diskio.list_filename)
                txt.nl()
                if c64.STOP2() {
                    txt.color(main.COLOR_HIGHLIGHT)
                    txt.print(iso:"Break\r")
                    txt.color(main.COLOR_NORMAL)
                    break
                }
            }
            diskio.lf_end_list()
            if num_files == 0 {
                txt.color(main.COLOR_HIGHLIGHT)
                txt.print(iso:"No files\r")
                txt.color(main.COLOR_NORMAL)
            }
            return true
        }
        return err.set(iso:"IO error")
    }

    sub cmd_rm() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing arg: filename")
        void string.find(main.command_arguments_ptr, '*')
        if_cs {
            ;txt.color(main.COLOR_HIGHLIGHT)
            ;txt.print(iso:"Has * wildcard. Sure y/n? ")
            ;txt.color(main.COLOR_NORMAL)
            ;ubyte answer = c64.CHRIN()
            ;txt.nl()
            ;if answer == iso:'y' {
            ;    return err.set(iso:"TODO custom pattern matching with * wildcard") ; TODO
            ;}
            return err.set(iso:"Refused to act on * wildcard")
        }
        diskio.delete(drivenumber, main.command_arguments_ptr)
        print_disk_status()
        return true
    }

    sub cmd_rename() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing args: oldfilename newfilename")

        uword newfilename
        ubyte space_idx = string.find(main.command_arguments_ptr, iso:' ')
        if_cs {
            newfilename = main.command_arguments_ptr + space_idx + 1
            main.command_arguments_ptr[space_idx] = 0
            diskio.rename(drivenumber, main.command_arguments_ptr, newfilename)
            print_disk_status()
            return true
        } else {
            return err.set(iso:"Missing args: oldfilename newfilename")
        }
    }

    sub print_disk_status() {
        txt.color(main.COLOR_HIGHLIGHT)
        txt.print(diskio.status(drivenumber))
        txt.color(main.COLOR_NORMAL)
        txt.nl()
    }

    sub cmd_cat() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing arg: filename")

        if diskio.f_open(drivenumber, main.command_arguments_ptr) {
            uword line = 0
            repeat {
                void diskio.f_readline(main.command_line)
                line++
                txt.color(main.COLOR_HIGHLIGHT)
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
                    void err.set("break")
                    break
                }
            }
            diskio.f_close()
        } else {
            void err.set(diskio.status(drivenumber))
        }
        return true
    }

    sub cmd_pwd() -> bool {
        if main.command_arguments_size
            return err.set(iso:"Has no args")
        txt.print(iso:"Drive number: ")
        txt.print_ub(drivenumber)
        txt.nl()
        txt.print(iso:"Disk name: ")
        uword name = diskio.diskname(drivenumber)
        if name==0
            return err.set(iso:"IO error")
        txt.print(name)
        txt.print(iso:"\r(sorry, no directory information yet)\r")
        return true
    }

    sub internal_send_command_print_status(ubyte nameoffset) {
        void string.copy(main.command_arguments_ptr, &diskio.list_filename+nameoffset)
        void diskio.send_command(drivenumber, diskio.list_filename)
        print_disk_status()
    }

    sub cmd_mkdir() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing arg: dirname")

        diskio.list_filename[0] = 'm'
        diskio.list_filename[1] = 'd'
        diskio.list_filename[2] = ':'
        internal_send_command_print_status(3)
        return true
    }

    sub cmd_cd() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing arg: dirname")

        diskio.list_filename[0] = 'c'
        diskio.list_filename[1] = 'd'
        diskio.list_filename[2] = ':'
        internal_send_command_print_status(3)
        return true
    }

    sub cmd_rmdir() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing arg: dirname")

        void string.find(main.command_arguments_ptr, '*')
        if_cs
            return err.set(iso:"Refused to act on * wildcard")

        diskio.list_filename[0] = 'r'
        diskio.list_filename[1] = 'd'
        diskio.list_filename[2] = ':'
        internal_send_command_print_status(3)
        return true
    }

    sub cmd_relabel() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing arg: diskname")

        diskio.list_filename[0] = 'r'
        diskio.list_filename[1] = '-'
        diskio.list_filename[2] = 'h'
        diskio.list_filename[3] = ':'
        internal_send_command_print_status(4)
        return true
    }

    sub cmd_copy() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing args: oldfilename newfilename")

        uword newfilename
        ubyte space_idx = string.find(main.command_arguments_ptr, iso:' ')
        if_cs {
            newfilename = main.command_arguments_ptr + space_idx + 1
            main.command_arguments_ptr[space_idx] = 0
            diskio.list_filename[0] = 'c'
            diskio.list_filename[1] = ':'
            ubyte length = string.copy(newfilename, &diskio.list_filename+2)
            diskio.list_filename[length+2] = '='
            void string.copy(main.command_arguments_ptr, &diskio.list_filename+length+3)
            void diskio.send_command(drivenumber, diskio.list_filename)
            print_disk_status()
            return true
        } else {
            return err.set(iso:"Missing args: oldfilename newfilename")
        }
    }

    sub cmd_drive() -> bool {
        if main.command_arguments_size==0
            return err.set(iso:"Missing arg: drive number")

        ubyte nr = conv.str2ubyte(main.command_arguments_ptr)

        when nr {
            8, 9 -> {
                txt.print(iso:"Switching drive.\r")
                drivenumber = nr
                main.command_arguments_size = 0
                return cmd_pwd()
            }
            else -> {
                return err.set(iso:"Invalid drive number")
            }
        }
    }

}
