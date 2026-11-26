#!/usr/bin/env bash
# archnashi — post-install Arch Linux (KDE Plasma / Wayland)
# Usage: ./archnashi.sh [--yes] [--help]
#   --yes   répond "oui" aux questions optionnelles (installation non interactive)

set -Eeuo pipefail

LOG_FILE="${HOME}/archnashi.log"
ASSUME_YES=0

for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
        *) echo "Option inconnue : $arg" >&2; exit 2 ;;
    esac
done

# --- Affichage / exécution ---------------------------------------------------

GREEN=$'\e[32m'; RED=$'\e[31m'; RESET=$'\e[0m'

# run "Description" commande arg1 arg2 ...  (sans eval ; sortie complète dans le log)
run() {
    local desc="$1"; shift
    printf '==> %s... ' "$desc"
    {
        echo "### $desc"
        echo "\$ $*"
    } >>"$LOG_FILE"
    if "$@" >>"$LOG_FILE" 2>&1; then
        echo "${GREEN}[✓]${RESET}"
    else
        echo "${RED}[✗]${RESET}"
        echo "--- Dernières lignes du log ($LOG_FILE) ---" >&2
        tail -n 15 "$LOG_FILE" >&2
        exit 1
    fi
}

# ask "Question ?" [défaut o|n]  -> code 0 si oui
ask() {
    local prompt="$1" default="${2:-n}" reply
    if [[ $ASSUME_YES -eq 1 ]]; then return 0; fi
    local hint="[o/N]"; [[ $default == o ]] && hint="[O/n]"
    read -rp "$prompt $hint " reply || true
    reply="${reply:-$default}"
    [[ ${reply,,} == o || ${reply,,} == oui || ${reply,,} == y ]]
}

# install_pkgs "Description" paquet1 paquet2 ...  (un seul appel pacman, --needed)
install_pkgs() {
    local desc="$1"; shift
    run "$desc" sudo pacman -S --needed --noconfirm "$@"
}

# Ajoute une ligne à un fichier système seulement si elle est absente
append_once() {
    local line="$1" file="$2"
    grep -qxF "$line" "$file" 2>/dev/null || echo "$line" | sudo tee -a "$file" >/dev/null
}

# --- Vérifications préalables -----------------------------------------------

if [[ $EUID -eq 0 ]]; then
    echo "Ne lance pas ce script en root : il utilise sudo quand c'est nécessaire." >&2
    exit 1
fi
if ! command -v pacman >/dev/null; then
    echo "Ce script est prévu pour Arch Linux (pacman introuvable)." >&2
    exit 1
fi
: >"$LOG_FILE"
echo "Journal détaillé : $LOG_FILE"

# --- Détection du matériel ---------------------------------------------------

GPU_INFO="$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' || true)"
HAS_AMD_GPU=0; HAS_INTEL_GPU=0; HAS_NVIDIA_GPU=0
grep -qiE 'amd|ati|radeon'  <<<"$GPU_INFO" && HAS_AMD_GPU=1
grep -qi  'intel'           <<<"$GPU_INFO" && HAS_INTEL_GPU=1
grep -qi  'nvidia'          <<<"$GPU_INFO" && HAS_NVIDIA_GPU=1

CPU_VENDOR="$(awk -F': ' '/vendor_id/{print $2; exit}' /proc/cpuinfo)"

# --- Pacman ------------------------------------------------------------------

# Idempotent : ne fait rien si la ligne est déjà active
run "Activation de la couleur dans pacman"          sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf
run "Activation des listes de paquets détaillées"   sudo sed -i 's/^#VerbosePkgLists$/VerbosePkgLists/' /etc/pacman.conf
run "Activation des téléchargements parallèles"     sudo sed -i 's/^#\(ParallelDownloads.*\)/\1/' /etc/pacman.conf
run "Activation du dépôt multilib"                  sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf

# Drop-in makepkg (ne touche pas à /etc/makepkg.conf)
run "Compilation multithread (makepkg.conf.d)" \
    sudo bash -c 'mkdir -p /etc/makepkg.conf.d && printf "MAKEFLAGS=\"-j$(nproc)\"\n" > /etc/makepkg.conf.d/99-archnashi.conf'

run "Mise à jour complète du système" sudo pacman -Syu --noconfirm
install_pkgs "Installation de pacman-contrib et reflector" pacman-contrib reflector
run "Activation du timer paccache"   sudo systemctl enable paccache.timer
run "Activation du timer reflector"  sudo systemctl enable reflector.timer

# --- Microcode CPU -----------------------------------------------------------

case "$CPU_VENDOR" in
    AuthenticAMD) install_pkgs "Microcode AMD"   amd-ucode ;;
    GenuineIntel) install_pkgs "Microcode Intel" intel-ucode ;;
esac

# --- AUR helper : yay --------------------------------------------------------

install_yay() {
    local tmp
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

if ! command -v yay >/dev/null; then
    run "Installation de yay" install_yay
    run "Configuration de yay" yay --save --sudoloop --devel
else
    echo "yay ${GREEN}est déjà installé.${RESET}"
fi

# --- Audio (PipeWire) --------------------------------------------------------
# Les services PipeWire sont activés par socket via les paquets : rien à enable.

install_pkgs "Installation de PipeWire" \
    pipewire wireplumber lib32-pipewire pipewire-alsa pipewire-jack pipewire-pulse \
    alsa-utils alsa-plugins alsa-ucm-conf sof-firmware

# --- Essentiels --------------------------------------------------------------

install_pkgs "Installation des paquets essentiels" \
    gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugin-pipewire \
    gst-plugin-va gst-libav \
    fwupd xdg-utils xdg-desktop-portal xdg-desktop-portal-gtk fastfetch power-profiles-daemon \
    hunspell hunspell-en_us hunspell-fr-comprehensive duf 7zip unrar \
    ttf-dejavu ttf-liberation ttf-meslo-nerd noto-fonts-emoji adobe-source-code-pro-fonts otf-font-awesome \
    ntfs-3g fuse3 exfatprogs bash-completion ffmpegthumbs man-db man-pages \
    networkmanager

run "Activation de NetworkManager" sudo systemctl enable NetworkManager

# --- Pilotes graphiques ------------------------------------------------------
# libva-mesa-driver est fusionné dans mesa ; vulkan-mesa-layers reste séparé.

if [[ $HAS_AMD_GPU -eq 1 ]]; then
    install_pkgs "Pilotes AMD" \
        mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon \
        vulkan-icd-loader lib32-vulkan-icd-loader vulkan-mesa-layers
elif [[ $HAS_INTEL_GPU -eq 1 ]]; then
    install_pkgs "Pilotes Intel" \
        mesa lib32-mesa vulkan-intel lib32-vulkan-intel \
        vulkan-icd-loader lib32-vulkan-icd-loader vulkan-mesa-layers
elif [[ $HAS_NVIDIA_GPU -eq 1 ]]; then
    echo "GPU NVIDIA détecté : installe le pilote à la main (nvidia-open / nvidia-utils), non géré ici."
else
    echo "Aucun GPU reconnu : pilotes graphiques ignorés."
fi

# --- Bluetooth ---------------------------------------------------------------
# bluez-plugins n'existe plus : intégré à bluez.

install_pkgs "Installation du Bluetooth" bluez bluez-utils
run "Activation du service Bluetooth" sudo systemctl enable bluetooth

# --- KDE Plasma --------------------------------------------------------------

install_pkgs "Installation des applications KDE" \
    konsole kate dolphin ark okular gwenview spectacle partitionmanager \
    print-manager kdeplasma-addons kcalc plasma-systemmonitor kwalletmanager \
    plasma-nm xdg-desktop-portal-kde \
    qt6-multimedia qt6-multimedia-gstreamer qt6-multimedia-ffmpeg qt6-wayland

# Plasma 6.8 fournit son propre gestionnaire de connexion (remplace SDDM)
if ask "Installer et activer plasma-login-manager (écran de connexion) ?" o; then
    install_pkgs "Installation de plasma-login-manager" plasma-login-manager
    if systemctl list-unit-files display-manager.service &>/dev/null \
       && [[ -e /etc/systemd/system/display-manager.service ]]; then
        echo "Un gestionnaire de connexion est déjà activé : on ne le remplace pas."
    else
        run "Activation de plasma-login-manager" sudo systemctl enable plasmalogin.service
    fi
fi

# --- Applications optionnelles ----------------------------------------------

if ask "Installer les applications courantes (LibreOffice, qBittorrent, Discord, Kdenlive, KPat, VLC) ?" o; then
    install_pkgs "Installation des applications" libreoffice-fresh qbittorrent discord kdenlive kpat vlc vlc-plugins-all
fi

if ask "Installer les outils de jeu (Steam, Lutris, Wine, Godot, GameMode, Gamescope, umu-launcher) ?" o; then
    # Les dépendances de Wine/Steam sont tirées automatiquement par les paquets.
    install_pkgs "Installation des outils de jeu" \
        steam lutris wine-staging godot \
        gamemode lib32-gamemode gamescope umu-launcher
fi

if ask "Installer les outils de développement (VS Code, Node.js, Python, Electron) ?" o; then
    # nodejs ne contient pas npm sur Arch : paquet séparé
    install_pkgs "Installation des outils de développement" code nodejs npm python electron
fi

# --- Sécurité / robustesse (optionnel) --------------------------------------

if ask "Installer un pare-feu (ufw) et earlyoom ?" o; then
    install_pkgs "Installation d'ufw et earlyoom" ufw earlyoom
    run "Politique ufw par défaut (entrant refusé)" sudo ufw default deny incoming
    run "Activation d'ufw"      sudo ufw --force enable
    run "Activation du service ufw" sudo systemctl enable ufw
    run "Activation d'earlyoom" sudo systemctl enable earlyoom
fi

if ask "Installer snapper (snapshots, utile surtout avec Btrfs) ?" n; then
    install_pkgs "Installation de snapper" snapper
fi

# --- Réglages système --------------------------------------------------------

run "GTK_USE_PORTAL=1 (sans doublon)" append_once 'GTK_USE_PORTAL=1' /etc/environment
run "Swappiness à 10" \
    sudo bash -c "echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf"

# --- Fin ---------------------------------------------------------------------

echo -e "\nInstallation terminée. Journal : $LOG_FILE"
if ask "Redémarrer maintenant ?" n; then
    sudo reboot
else
    echo "Pense à redémarrer pour appliquer tous les changements."
fi
