%import loader
%import shellroutines
%launcher none
%option no_sysinit
%zeropage basicsafe
%encoding iso
%address $4000

main $4000 {
    %option force_output
    uword colors

    sub start() {
        colors = shell.get_text_colors()
        shell.txt_color(shell.TXT_COLOR_HIGHLIGHT)
        shell.print("Image viewer for Commander X16.\rSupported formats: ")
        shell.txt_color(shell.TXT_COLOR_HIGHLIGHT_PROMPT)
        for cx16.r0 in loader.known_extensions {
            shell.print(cx16.r0)
            shell.chrout(' ')
        }
        shell.chrout('\r')
        shell.txt_color(shell.TXT_COLOR_NORMAL)

        str args = "?" * 40
        cx16.get_program_args(args, len(args), false)
        if args[0]==0 {
            shell.txt_color(shell.TXT_COLOR_ERROR)
            shell.err_set("Missing arguments: filename")
            sys.exit(1)
        }

        uword extension = &args + rfind(args, '.')

        if ".txt"==extension or ".bas"==extension {
            shell.err_set("Can't view text files, use 'nano' to view those")
            sys.exit(1)
        }

        if not loader.is_known_extension(extension) {
            shell.err_set("Invalid file extension")
            sys.exit(1)
        }

        if loader.attempt_load(args, true) {
            void txt.waitkey()
            loader.restore_screen_mode()
            ; colors and text mode are wrong, fix this back up
            init_screen()
            sys.exit(0)
        }
        else
            sys.exit(1)
    }

    sub init_screen() {
        txt.color2(colors[0], colors[1])
        cx16.VERA_DC_BORDER = colors[1]
        txt.iso()
        txt.clear_screen()
    }

    sub rfind(uword stringptr, ubyte char) -> ubyte {
        ubyte i
        for i in string.length(stringptr)-1 downto 0 {
            if @(stringptr+i)==char
                return i
        }
        return 0
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
