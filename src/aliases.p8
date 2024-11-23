%import strings
%import textio
%encoding iso

aliases {
    ; every alias and command is of length 1 to 7 (with a trailing 0 byte) but takes up 8 bytes in total
    ; so there are 16 possible aliases available.
    ubyte[128] alias_names
    ubyte[128] alias_defs
    ubyte num_aliases
    const ubyte MAX_ALIASES = len(alias_names)/8

    sub lookup(str name) -> str {
        cx16.r0L = find_alias(name)
        if cx16.r0L==255
            return $0000

        return &alias_defs + cx16.r0L
    }

    sub print_list() {
        cx16.r0 = &alias_names
        cx16.r1 = &alias_defs
        ubyte column = 0
        repeat num_aliases {
            txt.column(2+column)
            txt.print(cx16.r0)
            column+=10
            if column>50 {
                txt.nl()
                column=0
            }
            cx16.r0+=8
            cx16.r1+=8
        }
        txt.nl()
    }

    sub print_table() {
        main.txt_color(main.TXT_COLOR_HIGHLIGHT)
        txt.print("Alias")
        txt.column(10)
        txt.print("Command\r")
        main.txt_color(main.TXT_COLOR_NORMAL)
        cx16.r0 = &alias_names
        cx16.r1 = &alias_defs
        repeat num_aliases {
            txt.print(cx16.r0)
            txt.column(10)
            txt.print(cx16.r1)
            txt.nl()
            cx16.r0+=8
            cx16.r1+=8
        }
    }

    sub add(str aliasname, str def) -> bool {
        if num_aliases==MAX_ALIASES {
            err.set("no more slots")
            return false
        }
        if strings.length(aliasname)>7 or strings.length(def)>7 {
            err.set("alias or def too long (max 7)")
            return false
        }

        ubyte existing_index = find_alias(aliasname)        ; returns 255 if not found
        if existing_index==255 {
            cx16.r4 = num_aliases*8
            cx16.r5 = &alias_defs + cx16.r4
            cx16.r4 += &alias_names
            num_aliases++
        } else {
            cx16.r4 = &alias_names + existing_index
            cx16.r5 = &alias_defs + existing_index
        }
        void strings.copy(aliasname, cx16.r4)
        void strings.copy(def, cx16.r5)
        return true
    }

    sub remove(str aliasname) {
        ubyte existing_index = find_alias(aliasname)
        if existing_index==255
            return  ; not found
        ; move all aliases 1 up in the table
        for cx16.r0L in existing_index to len(alias_names) - existing_index - 8 {
            alias_names[cx16.r0L] = alias_names[cx16.r0L+8]
            alias_defs[cx16.r0L] = alias_defs[cx16.r0L+8]
        }
        num_aliases--
        alias_names[num_aliases*8]=0
        alias_defs[num_aliases*8]=0
    }

    sub find_alias(str aliasname) -> ubyte {
        cx16.r4 = &alias_names
        cx16.r5L = 0
        while(@(cx16.r4)!=0) {
            if strings.compare(cx16.r4, aliasname)==0
                return cx16.r5L
            cx16.r4 += 8
            cx16.r5L += 8
        }
        return 255  ; not found
    }
}
