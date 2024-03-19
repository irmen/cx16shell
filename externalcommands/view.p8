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

        if loader.attempt_load(args, true) {
            txt.waitkey()
            loader.restore_screen_mode()
            sys.exit(0)
        }
        else
            sys.exit(1)
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
