sudo pacman -S --needed git base-devel \
  && git clone https://codeberg.org/harunashi/archnashi.git ~/archnashi \
  && cd ~/archnashi \
  && chmod +x ./archnashi.sh \
  && ./archnashi.sh
