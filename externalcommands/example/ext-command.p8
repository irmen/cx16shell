; EXAMPLE external command source code

%import shellroutines
%launcher none
%option no_sysinit
%zeropage basicsafe
%encoding iso
%address $4000


main $4000 {
    %option force_output

    sub start()  {
        shell.print("This is an external command program!\rinvoked command: ")
        shell.print(cx16.r0)        ; command
        shell.chrout(' ')
        shell.print_uw(cx16.r1)     ; length of command
        if cx16.r3 {
            shell.print("\rargs: ")
            shell.print(cx16.r2)        ; arguments
            shell.print("\rargs length=")
            shell.print_uw(cx16.r3)     ; length of arguments
        }
        shell.print("\renter name: ")
        str inputbuffer = "?"*20
        if shell.input_chars(inputbuffer) {
            shell.print("\rinput was: ")
            shell.print(inputbuffer)
            shell.chrout('\r')
        }
        shell.print_uwbin(12345, true)
        shell.chrout('\r')
        shell.print_ubhex(99, true)
        shell.chrout('\r')

        uword colors = shell.get_text_colors()
        shell.print_ub(colors[0])
        shell.chrout(' ')
        shell.print_ub(colors[1])
        shell.chrout(' ')
        shell.print_ub(colors[2])
        shell.chrout(' ')
        shell.print_ub(colors[3])
        shell.chrout(' ')
        shell.print_ub(colors[4])
        shell.chrout('\r')
        shell.print(shell.version())
        shell.chrout('\r')

        sys.exit(0)
        ; void shell.err_set("external command failed")
    }
}
