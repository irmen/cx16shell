# Shell startup and configuration script.
# note: character encoding is ISO!
# note2: keep the size under 1 kilobyte otherwise it overwrites basic program memory!

# Screen mode and colors. Uncomment to keep the defaults.
mode 1
color 1,11,11
hicolor 14,13,10

# Aliases
alias dir=ls
alias type=cat
alias del=rm
alias ren=mv
alias copy=cp
alias vi=nano
alias pico=nano
alias edit=nano
alias date=time

# Display the Message of the Day.
# TODO uncomment this after the file load conflict is solved
# cat //shell-cmds/:motd.txt

echo
echo "  Commander-X16 Shell v1.3 - https://github.com/irmen/cx16shell"
echo
