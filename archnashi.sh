#!/bin/bash

# Fonction pour afficher les étapes et masquer le détail des commandes
exec_log() {
    echo -n "==> $1... "  # Affiche le message d'étape avec attente
    eval "$2" &> /dev/null   # Exécute la commande sans afficher les détails

    # Vérifie si la commande a réussi
    if [ $? -eq 0 ]; then
        echo -e "\e[32m[✓]\e[0m"  # Affiche une coche verte si réussi
    else
        echo -e "\e[31m[✗]\e[0m"  # Affiche une croix rouge si échec
        exit 1  # Arrête le script en cas d'erreur
    fi
}

# Pacman Setup & Update full system
exec_log "Enabling color in pacman" "sudo sed -i 's/^#Color$/Color/' '/etc/pacman.conf'"
exec_log "Enabling verbose package lists in pacman" "sudo sed -i 's/^#VerbosePkgLists$/VerbosePkgLists/' '/etc/pacman.conf'"
exec_log "Enabling parallel downloads in pacman" "sudo sed -i 's/^#\(ParallelDownloads.*\)/\1/' '/etc/pacman.conf'"
exec_log "Enabling multilib repository" "sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' '/etc/pacman.conf'"
exec_log "Enabling multithread compilation" "sudo sed -i 's/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j\$(nproc)\"/' /etc/makepkg.conf"
exec_log "Updating full system" "sudo pacman -Syyu --noconfirm"
exec_log "Installing pacman-contrib" "sudo pacman -S pacman-contrib --noconfirm"
exec_log "Enabling paccache timer" "sudo systemctl enable paccache.timer"

# Installing AUR helper
if ! pacman -Qm | grep -q yay-bin; then
    exec_log "Installing yay" "git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && cd /tmp/yay-bin && makepkg -si --noconfirm"
    rm -rf /tmp/yay-bin
    exec_log "yay -Y --gendb"
    exec_log "yay -Y --devel --save"
    exec_log "sed -i 's/\"sudoloop\": false,/\"sudoloop\": true,/' ~/.config/yay/config.json"
else
    echo -e "yay \e[32mis already installed.\e[0m"
fi

# Install Pipewire
packages=(
    pipewire
    wireplumber
    lib32-pipewire
    pipewire-alsa
    pipewire-jack
    pipewire-pulse
    alsa-utils
    alsa-plugins
    alsa-firmware
    alsa-ucm-conf
    sof-firmware
)

for package in "${packages[@]}"; do
    if ! pacman -Qq | grep -qw "$package"; then
        exec_log "Installing $package" "sudo pacman -S --noconfirm ${package}"
        exec_log "Enabling PipeWire services" "systemctl --user enable pipewire pipewire-pulse wireplumber"
    else
        echo -e "$package \e[32mis already installed.\e[0m"
    fi
done

# Install Essentials
packages=(
    gstreamer
    gst-plugins-bad
    gst-plugins-base
    gst-plugins-ugly
    gst-plugin-pipewire
    gstreamer-vaapi
    gst-plugins-good
    gst-libav
    fwupd
    xdg-utils
    rebuild-detector
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    fastfetch
    power-profiles-daemon
    hunspell
    hunspell-en_us
    duf
    p7zip
    unrar
    ttf-dejavu
    ttf-liberation
    ttf-meslo-nerd
    noto-fonts-emoji
    adobe-source-code-pro-fonts
    otf-font-awesome
    ntfs-3g
    fuse2
    fuse3
    exfatprogs
    bash-completion
    ffmpegthumbs
    man-db
    man-pages
)

for package in "${packages[@]}"; do
    if ! pacman -Qq | grep -qw "$package"; then
        exec_log "Installing $package" "sudo pacman -S --noconfirm ${package}"
    else
        echo -e "$package \e[32mis already installed.\e[0m"
    fi
done

# Install AMD Drivers
packages=(
    mesa
    lib32-mesa
    vulkan-radeon
    lib32-vulkan-radeon
    vulkan-icd-loader
    lib32-vulkan-icd-loader
    libva-mesa-driver
    lib32-libva-mesa-driver
    vulkan-mesa-layers
    mesa-vdpau
    lib32-mesa-vdpau
)

for package in "${packages[@]}"; do
    if ! pacman -Qq | grep -qw "$package"; then
        exec_log "Installing $package" "sudo pacman -S --noconfirm ${package}"
    else
        echo -e "$package \e[32mis already installed.\e[0m"
    fi
done

# Install Bluetooth
packages=(
    bluez
    bluez-plugins
    bluez-utils
)

for package in "${packages[@]}"; do
    if ! pacman -Qq | grep -qw "$package"; then
        exec_log "Installing $package" "sudo pacman -S --noconfirm ${package}"
        exec_log "enabling bluetooth service" "sudo systemctl enable bluetooth"
    else
        echo -e "$package \e[32mis already installed.\e[0m"
    fi
done

# Install Useful Packages for KDE
packages=(
    konsole
    kwrite
    dolphin
    ark
    xdg-desktop-portal-kde
    okular
    print-manager
    gwenview
    spectacle
    partitionmanager
    qt6-multimedia
    qt6-multimedia-gstreamer
    qt6-multimedia-ffmpeg
    qt6-wayland
    kdeplasma-addons
    kcalc
    plasma-systemmonitor
    kwalletmanager
    kpat
    kdenlive
    qbittorrent
)

for package in "${packages[@]}"; do
    if ! pacman -Qq | grep -qw "$package"; then
        exec_log "Installing $package" "sudo pacman -S --noconfirm ${package}"
    else
        echo -e "$package \e[32mis already installed.\e[0m"
    fi
done

# Install Softwares
packages=(
    discord
    libreoffice-fresh
    steam
    lutris
    wine-staging
    godot
)

for package in "${packages[@]}"; do
    if ! pacman -Qq | grep -qw "$package"; then
        exec_log "Installing $package" "sudo pacman -S --noconfirm ${package}"
    else
        echo -e "$package \e[32mis already installed.\e[0m"
    fi
done

# Install WineDependencies
packages=(
    gnutls
    lib32-gnutls
    libpulse
    lib32-libpulse
    lib32-alsa-plugins
    alsa-lib
    lib32-alsa-lib
    sqlite
    libxcomposite
    lib32-libxcomposite
    libva
    lib32-libva
    gtk3
    lib32-gtk3
    gst-plugins-base-libs
    lib32-gst-plugins-base-libs
)

for package in "${packages[@]}"; do
    if ! pacman -Qq | grep -qw "$package"; then
        exec_log "Installing $package" "sudo pacman -S --needed --asdeps --noconfirm ${package}"
    else
        echo -e "$package \e[32mis already installed.\e[0m"
    fi
done

if [ ! -f /etc/sddm.conf ]; then
        exec_log "Creating /etc/sddm.conf" "sudo touch /etc/sddm.conf"
    fi
    exec_log "Setting Breeze theme for SDDM" "echo -e '[Theme]\nCurrent=breeze' | sudo tee -a /etc/sddm.conf"
    exec_log "Setting Numlock=on for SDDM" "echo -e '[General]\nNumlock=on' | sudo tee -a /etc/sddm.conf"
    exec_log "Setting GTK_USE_PORTAL=1" "echo 'GTK_USE_PORTAL=1' | sudo tee -a /etc/environment"

# exec_log "Disable Intel split-lock" "echo 'kernel.split_lock_mitigate=0' | sudo tee /etc/sysctl.d/99-split-lock.conf"
    exec_log "Setting swappiness to 10" "echo -e 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf"

echo -e "\nInstallation complete! Press [Enter] to reboot."

# Waits for user to press "Enter" to reboot
read -r -p "Restarting..." && sudo reboot
