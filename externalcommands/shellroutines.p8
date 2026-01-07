
; definitions for the callback routines the Shell provides for external commands.

shell {
    extsub $07d0 = print_l(long value @ R0R1) clobbers(A, X, Y)
    extsub $07d3 = print_ulhex(long value @ R0R1, bool prefix @A) clobbers(A, X, Y)
    extsub $07d6 = drive_number() -> ubyte @A
    extsub $07d9 = txt_color(ubyte colortype @A) clobbers(A)       ; activate one of the 5 color types (constants defined below)
    extsub $07dc = version() -> uword @AY               ; returns pointer to string with shell's version
    extsub $07df = get_text_colors() -> uword @AY       ; returns address of array of 5 text color bytes (text, background, highlight, prompt, error)
    extsub $07e2 = chrout(ubyte character @A)
    extsub $07e5 = print(str string @AY) clobbers(A,Y)
    extsub $07e8 = print_ub(ubyte value @ A) clobbers(A,X,Y)
    extsub $07eb = print_ubhex(ubyte value @ A, bool prefix @ Pc) clobbers(A,X,Y)
    extsub $07ee = print_ubbin(ubyte value @ A, bool prefix @ Pc) clobbers(A,X,Y)
    extsub $07f1 = print_uw(uword value @AY) clobbers(A,Y)
    extsub $07f4 = print_uwhex(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    extsub $07f7 = print_uwbin(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    extsub $07fa = input_chars(uword buffer @ AY) clobbers(A) -> ubyte @Y
    extsub $07fd = err_set(str message @AY) clobbers(A,Y)

    ; color types for txt_color() routine:
    const ubyte TXT_COLOR_NORMAL = 0
    const ubyte TXT_COLOR_BACKGROUND = 1
    const ubyte TXT_COLOR_HIGHLIGHT = 2
    const ubyte TXT_COLOR_HIGHLIGHT_PROMPT = 3
    const ubyte TXT_COLOR_ERROR = 4

    ; command receives arguments at $0:BF00 (zero terminated, see  https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2007%20-%20Memory%20Map.md#bank-0)
    ;         (you can use the cx16.get_program_args routine to retrieve them)
    ; command should return error status in A. You can use err_set() to set a specific error message for the shell.
    ; command CAN use the FREE zero page locations.
    ; command CANNOT use memory below $4000 (the shell program itself sits there!)
    ; command CAN use Ram $0400-up to the jump table start (see romsubs above)
}
