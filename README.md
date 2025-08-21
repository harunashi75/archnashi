sudo pacman -S --needed git base-devel \
  && git clone https://github.com/harunashi75/archnashi.git ~/archnashi \
  && cd ~/archnashi \
  && chmod +x ./archnashi.sh \
  && ./archnashi.sh
