#!/bin/sh


[ -z "$progsfile"] && progsfile="https://raw.githubusercontent.com/LukeSmithxyz/LARBS/master/progs.csv"
[ -z "$aurhelper" ] && aurhelper="yay"

install_package() {
    pacman --noconfirm --needed -S "$1";
}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#TITAN/d" /etc/sudoers
	echo "$* #TITAN" >> /etc/sudoers ;
}

install_loop() {
    # fetch the file with the list of programs
    ([ -f "$progsfile" ] && cp "$progsfile" progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > progs.csv
}


for x in curl ca-certificates base-devel git ntp zsh ; do
    install_package "$x"
done

useradd -m -g wheel -s /bin/zsh "alberto"
repodir="/home/alberto/.local/src"
mkdir -p "$repodir"
chown -R alberto:wheel "$(dirname "$repodir")"
echo "alberto:arch" | chpasswd

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Make pacman colorful, concurrent downloads and Pacman eye-candy.
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 8$/ParallelDownloads = 5/;s/^#Color$/Color/" /etc/pacman.conf

sudo -u alberto mkdir -p "$repodir/yay-bin"
sudo -u alberto git clone --depth 1 "https://aur.archlinux.org/yay-bin.git" "$repodir/yay-bin"
cd "$repodir/yay-bin"
sudo -u alberto -D "$repodir/yay-bin" makepkg --noconfirm -si

install_loop