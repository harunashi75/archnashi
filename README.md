# archnashi

Script de post-installation pour **Arch Linux** : KDE Plasma (Wayland), PipeWire, Bluetooth, pilotes AMD/Intel détectés automatiquement, `yay`, et réglages pacman/système.

## Installation

```bash
sudo pacman -S --needed git base-devel \
  && git clone https://github.com/harunashi75/archnashi.git ~/archnashi \
  && cd ~/archnashi \
  && chmod +x ./archnashi.sh \
  && ./archnashi.sh
```

Lis le script avant de le lancer : il modifie `/etc/pacman.conf`, `/etc/environment` et ajoute des fichiers dans `/etc/sysctl.d/` et `/etc/makepkg.conf.d/`.

## Ce que fait le script

- Configure pacman (couleur, téléchargements parallèles, multilib) et met le système à jour
- Installe le microcode CPU, `yay`, PipeWire, les codecs, les polices, NetworkManager, le Bluetooth
- Détecte ton GPU (AMD ou Intel) et installe les pilotes Mesa/Vulkan correspondants (NVIDIA : manuel)
- Installe KDE et propose `plasma-login-manager`
- Propose en option : applications courantes, jeux (Steam, Lutris, Wine, Godot), pare-feu `ufw` + `earlyoom`, `snapper`

## Options

- `--yes` : répond « oui » à toutes les questions optionnelles (non interactif)
- Le script est relançable : rien n'est installé ni écrit en double
- Journal complet dans `~/archnashi.log` (affiché en cas d'erreur)

Le script **ne redémarre pas** sans te le demander.
