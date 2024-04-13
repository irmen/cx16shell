# Shell startup and configuration script.
# note: character encoding is ISO!
# note2: keep the size under 1 kilobyte otherwise it overwrites basic program memory!

# Screen mode and colors. Comment out to keep the defaults.
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

echo
shellver
echo

# Display the Message of the Day.
cat //shell-files/:motd.txt
