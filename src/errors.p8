%import textio
%encoding iso

err {
    bool error_status

    sub clear() {
        error_status = false
    }

    sub no_args(str message) {
        error_status = true
        main.txt_color(main.TXT_COLOR_ERROR)
        txt.print("Missing arguments: ")
        set(message)
    }

    sub set(str message) {
        error_status = true
        main.txt_color(main.TXT_COLOR_ERROR)
        txt.print(message)
        txt.nl()
        main.txt_color(main.TXT_COLOR_NORMAL)
    }
}
