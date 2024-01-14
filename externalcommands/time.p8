; Show the current date and time

%import textio
%import syslib
%launcher none
%option no_sysinit
%zeropage basicsafe
%encoding iso
%address $4000

shell {
    romsub $06e0 = print(str string @AY) clobbers(A,Y)
    romsub $06e3 = print_uw(uword value @AY) clobbers(A,Y)
    romsub $06e6 = print_uwhex(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    romsub $06e9 = print_uwbin(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    romsub $06ec = input_chars(uword buffer @ AY) clobbers(A) -> ubyte @Y
    romsub $06ef = err_set(str message @AY) clobbers(Y) -> bool @A

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
        str[13] months = [0, "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        str[8] days = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        shell.print("Current date and time (from RTC clock):\r")
        ; romsub $ff50 = clock_get_date_time()  clobbers(A, X, Y)  -> uword @R0, uword @R1, uword @R2, uword @R3   ; result registers see clock_set_date_time()
        void cx16.clock_get_date_time()      ; uword yearmonth @R0, uword dayhours @R1, uword minsecs @R2, uword jiffiesweekday @R3
        uword year = 1900 + cx16.r0L
        ubyte month = cx16.r0H
        ubyte day = cx16.r1L
        ubyte hour = cx16.r1H
        ubyte minutes = cx16.r2L
        ubyte seconds = cx16.r2H
        ubyte weekday = cx16.r3H
        shell.print(days[weekday])
        shell.print(", ")
        shell.print(months[month])
        shell.print(" ")
        shell.print_uw(day)
        shell.print(", ")
        shell.print_uw(year)
        shell.print(".  ")
        if hour<10
            shell.print("0")
        shell.print_uw(hour)
        shell.print(":")
        if minutes<10
            shell.print("0")
        shell.print_uw(minutes)
        shell.print(":")
        if seconds<10
            shell.print("0")
        shell.print_uw(seconds)
        cbm.CHROUT('\r')

;        ubyte clock_lo
;        ubyte clock_mid
;        ubyte clock_hi
;        %asm {{
;            jsr  cbm.RDTIM
;            sta  p8v_clock_lo
;            stx  p8v_clock_mid
;            sty  p8v_clock_hi
;        }}
;        shell.print("\rJiffy clock: ")
;        shell.print_uwhex(clock_hi, true)
;        shell.print_uwhex(mkword(clock_mid, clock_lo), false)
;        cbm.CHROUT('\r')
        sys.exit(0)
    }
}
