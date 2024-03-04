%import textio

err {
    bool error_status

    sub clear() {
        error_status = false
    }

    sub set(str message) {
        error_status = true
        txt.color(main.COLOR_ERROR)
        txt.print(message)
        txt.nl()
        txt.color(main.COLOR_NORMAL)
    }
}
