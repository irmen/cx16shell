
; definitions for the callback routines the Shell provides for external commands.

shell {
    romsub $07dc = version() -> uword @AY               ; returns pointer to string with shell's version
    romsub $07df = get_text_colors() -> uword @AY       ; returns address of array of 5 text color bytes (text, background, highlight, prompt, error)
    romsub $07e2 = chrout(ubyte character @A)
    romsub $07e5 = print(str string @AY) clobbers(A,Y)
    romsub $07e8 = print_ub(ubyte value @ A) clobbers(A,X,Y)
    romsub $07eb = print_ubhex(ubyte value @ A, bool prefix @ Pc) clobbers(A,X,Y)
    romsub $07ee = print_ubbin(ubyte value @ A, bool prefix @ Pc) clobbers(A,X,Y)
    romsub $07f1 = print_uw(uword value @AY) clobbers(A,Y)
    romsub $07f4 = print_uwhex(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    romsub $07f7 = print_uwbin(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    romsub $07fa = input_chars(uword buffer @ AY) clobbers(A) -> ubyte @Y
    romsub $07fd = err_set(str message @AY) clobbers(Y) -> bool @A

    ; input registers set by shell upon calling your command:
    ;    cx16.r0 = command address
    ;    cx16.r1 = length of command (byte)
    ;    cx16.r2 = arguments address
    ;    cx16.r3 = length of arguments (byte)

    ; command should return error status in A. You can use err_set() to set a specific error message for the shell.
    ; command CAN use the FREE zero page locations.
    ; command CANNOT use memory below $4000 (the shell sits there)
    ; command CAN use Ram $0400-up to the jump table start.
}