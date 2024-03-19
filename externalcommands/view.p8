%import loader
%import shellroutines
%launcher none
%option no_sysinit
%zeropage basicsafe
%encoding iso
%address $4000

main $4000 {
    %option force_output

    sub start() {
        uword colors = shell.get_text_colors()
        txt.color(colors[2])
        shell.print("Image viewer for Commander X16.\rSupported formats: ")
        txt.color(colors[3])
        for cx16.r0 in loader.known_extensions {
            shell.print(cx16.r0)
            shell.chrout(' ')
        }
        shell.chrout('\r')
        txt.color(colors[0])

        str args = "?" * 40
        cx16.get_program_args(args, len(args), false)
        if args[0]==0 {
            txt.color(colors[4])
            shell.err_set("Missing arguments: filename")
            sys.exit(1)
        }

        uword extension = &args + rfind(args, '.')
        if not loader.is_known_extension(extension) {
            void iso_to_lowercase_petscii(args)
            if not loader.is_known_extension(extension) {
                shell.err_set("Invalid file extension")
                sys.exit(1)
            }
        }

        if loader.attempt_load(args, true) {
            txt.waitkey()
            loader.restore_screen_mode()
            sys.exit(0)
        }
        else
            sys.exit(1)
    }

    sub rfind(uword stringptr, ubyte char) -> ubyte {
        ubyte i
        for i in string.length(stringptr)-1 downto 0 {
            if @(stringptr+i)==char
                return i
        }
        return 0
    }

    sub iso_to_lowercase_petscii(uword str_ptr) -> ubyte {
        ubyte length=0
        while @(str_ptr)!=0 {
            if @(str_ptr) >= 'a' and @(str_ptr) <= 'z'
                @(str_ptr) -= 32
            str_ptr++
            length++
        }
        return length
    }

    sub load_error(uword what, uword filenameptr) {
        shell.print("load error: ")
        if what!=0
            shell.print(what)
        shell.print("\rfile: ")
        shell.print(filenameptr)
        shell.chrout('\r')
        sys.exit(0)
    }
}
