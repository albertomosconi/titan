#!/bin/sh

[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/albertomosconi/titan/main/programs.csv"
[ -z "$aurhelper" ] && aurhelper="yay"

install_package() {
    pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 ;
}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#TITAN/d" /etc/sudoers.d/$username
	sudo echo "$* #TITAN" >> /etc/sudoers.d/$username ;
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
    printf "installing base packages\n"
    for x in curl ca-certificates base-devel git ntp zsh reflector ; do
        install_package "$x"
    done

    printf "creating user\n"
    useradd -m -g wheel -s /bin/zsh "$username"
    repodir="/home/$username/.local/src"
    mkdir -p "$repodir"
    chown -R $username:wheel "$(dirname "$repodir")"
    echo "$username:$pass1" | chpasswd
    unset pass1 pass2;

    # Make zsh the default shell for the user.
    chsh -s /bin/zsh "$username" >/dev/null 2>&1
    sudo -u "$username" mkdir -p "/home/$username/.cache/zsh/"

    [ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case
    newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

    # Make pacman colorful, concurrent downloads and Pacman eye-candy.
    grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
    sed -i "s/^#ParallelDownloads = 8$/ParallelDownloads = 5/;s/^#Color$/Color/" /etc/pacman.conf

    # configure and enable reflector
    sudo systemctl enable reflector.timer
    sudo echo "--save /etc/pacman.d/mirrolist
--protocol https
--country Italy
--age 6
--sort rate" > /etc/xdg/reflector/reflector.conf
    sudo systemctl start reflector.timer
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
    printf "installing \`$1\`: $2\n";
    install_package "$1"
}

install_aur() {
    printf "installing \`$1\` from the AUR: $2\n";
    echo "$aurinstalled" | grep -q "^$1$" && return 1
    sudo -u "$username" yay -S --noconfirm "$1" >/dev/null 2>&1
}

install_loop() {
    # fetch the file with the list of programs
    ([ -f "$progsfile" ] && cp "$progsfile" /tmp/programs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/programs.csv
    aurinstalled=$(pacman -Qqm)
    while IFS=, read -r tag program desc; do
        case $tag in
            "A") install_aur "$program" "$desc" ;;
            *) install_pac "$program" "$desc" ;;
        esac
    done < /tmp/programs.csv;
}

post_install() {
    # This line, overwriting the `newperms` command above will allow the user to run
    # serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
    newperms "%wheel ALL=(ALL) ALL #TITAN
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm"
}


get_username_and_pass

confirm

setup

install_yay

install_loop

post_install

clear