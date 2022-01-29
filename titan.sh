#!/bin/sh

[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/albertomosconi/titan/main/programs.csv"
[ -z "$aurhelper" ] && aurhelper="yay"

install_package() {
    pacman --noconfirm --needed -S "$1";
}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#TITAN/d" /etc/sudoers
	echo "$* #TITAN" >> /etc/sudoers ;
}

get_username_and_pass() {
    printf "username: " >&2
    read -r username
    while ! echo "$username" | grep -q "^[a-z_][a-z0-9_-]*$"; do
        printf "username invalid. must begin with letter, only lowercase, - or _.: " >&2
        read -r username
    done
    printf "enter password: "
    read -r pass1
    printf "confirm: "
    read -r pass2
    while ! [ "$pass1" = "$pass2" ]; do
        printf "passwords don't match!\n"
        unset pass2
        printf "enter password: "
        read -r pass1
        printf "confirm: "
        read -r pass2
    done
}

confirm() {
    printf "PROCEED? [Y/n] "
    read -r ok
    echo "$ok" | grep -q "^[nN]" && exit 1
}

setup() {
    # install necessary packages
    for x in curl ca-certificates base-devel git ntp zsh ; do
        install_package "$x"
    done

    useradd -m -g wheel -s /bin/zsh "$username"
    repodir="/home/$username/.local/src"
    mkdir -p "$repodir"
    chown -R $username:wheel "$(dirname "$repodir")"
    echo "$username:$pass1" | chpasswd
    unset pass1 pass2;

    [ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

    newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

    # Make pacman colorful, concurrent downloads and Pacman eye-candy.
    grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
    sed -i "s/^#ParallelDownloads = 8$/ParallelDownloads = 5/;s/^#Color$/Color/" /etc/pacman.conf

    # Make zsh the default shell for the user.
    chsh -s /bin/zsh "$username" >/dev/null 2>&1
    sudo -u "$username" mkdir -p "/home/$username/.cache/zsh/"
}

install_yay() {
    # Use all cores for compilation.
    sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
    
    sudo -u $username mkdir -p "$repodir/yay-bin"
    sudo -u $username git clone --depth 1 "https://aur.archlinux.org/yay-bin.git" "$repodir/yay-bin"
    cd "$repodir/yay-bin"
    sudo -u $username -D "$repodir/yay-bin" makepkg --noconfirm -si
}

install_pac() {
    printf "installing \`$1\`: $2"
    install_package "$1"
}

install_aur() {
    printf "installing \`$1\` from the AUR: $2"
    echo "$aurinstalled" | grep -q "^$1$" && return 1
    sudo -u "$username" yay -S --noconfirm "$1" >/dev/null 2>&1
}

install_loop() {
    # fetch the file with the list of programs
    ([ -f "$progsfile" ] && cp "$progsfile" /tmp/programs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/programs.csv
    aurinstalled=$(pacman -Qqm)
    while IFS=, read -r tag program desc; do
        case $tag in
            "A") install_aur "$program" ;;
            *) install_pac "$program" ;;
        esac
    done < /tmp/programs.csv
}


get_username_and_pass

confirm

setup

install_yay

install_loop

