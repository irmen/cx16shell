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
        repeat num_aliases {
            txt.print(cx16.r0)
            txt.spc()
            txt.spc()
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

    sub add(str alias, str def) -> bool {
        if num_aliases==MAX_ALIASES {
            err.set("no more slots")
            return false
        }
        if string.length(alias)>7 or string.length(def)>7 {
            err.set("alias or def too long (max 7)")
            return false
        }

        ubyte existing_index = find_alias(alias)        ; returns 255 if not found
        if existing_index==255 {
            cx16.r4 = num_aliases*8
            cx16.r5 = &alias_defs + cx16.r4
            cx16.r4 += &alias_names
            num_aliases++
        } else {
            cx16.r4 = &alias_names + existing_index
            cx16.r5 = &alias_defs + existing_index
        }
        void string.copy(alias, cx16.r4)
        void string.copy(def, cx16.r5)
        return true
    }

    sub remove(str alias) {
        ubyte existing_index = find_alias(alias)
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

    sub find_alias(str alias) -> ubyte {
        cx16.r4 = &alias_names
        cx16.r5L = 0
        while(@(cx16.r4)!=0) {
            if string.compare(cx16.r4, alias)==0
                return cx16.r5L
            cx16.r4 += 8
            cx16.r5L += 8
        }
        return 255  ; not found
    }
}