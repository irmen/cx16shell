; EXAMPLE external command source code

%launcher none
%option no_sysinit
%zeropage basicsafe
%address $4000

shell {
    romsub $06e0 = shell_print(str string @AY) clobbers(A,Y)
    romsub $06e3 = shell_print_uw(uword value @AY) clobbers(A,Y)
    romsub $06e6 = shell_print_uwhex(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    romsub $06e9 = shell_print_uwbin(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    romsub $06ec = shell_input_chars(uword buffer @ AY) clobbers(A) -> ubyte @Y
    romsub $06ef = shell_err_set(str message @AY) clobbers(Y) -> bool @A

    ; input registers set by shell upon calling your command:
    ;    cx16.r0 = command address
    ;    cx16.r1 = length of command (byte)
    ;    cx16.r2 = arguments address
    ;    cx16.r3 = length of arguments (byte)

    ; command should return error status in A. You can use err_set() to set a specific error message for the shell.
    ; command CAN use the FREE zero page locations.
    ; command CANNOT use memory below $4000 (the shell sits there)
    ; command CAN use Ram $0400-$06df.
}

main $4000 {
    %option force_output

    sub start()  {
        shell.shell_print(iso:"This is an external command program!\rinvoked command: ")
        shell.shell_print(cx16.r0)        ; command
        cbm.CHROUT(iso:' ')
        shell.shell_print_uw(cx16.r1)     ; length of command
        if cx16.r3 {
            shell.shell_print(iso:"\rargs: ")
            shell.shell_print(cx16.r2)        ; arguments
            shell.shell_print(iso:"\rargs length=")
            shell.shell_print_uw(cx16.r3)     ; length of arguments
        }
        shell.shell_print(iso:"\renter name: ")
        str inputbuffer = "?"*20
        if shell.shell_input_chars(inputbuffer) {
            shell.shell_print(iso:"\rinput was: ")
            shell.shell_print(inputbuffer)
            cbm.CHROUT(iso:'\r')
        }
        shell.shell_print_uwbin(12345, true)
        cbm.CHROUT(iso:'\r')
        sys.exit(0)
        ; void shell.shell_err_set(iso:"external command failed")
    }
}
