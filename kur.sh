#!/bin/bash
# Minimo OS's settings, put in place from this repository: each file under ev/
# is linked from its place in $HOME (a real file found there is kept as
# <name>.yedek), Minimo's own parts are linked from ~/Proyectos/minimo-os, and
# Minimo's services are enabled (in its session only: minimo-session.target).
# The two files outside $HOME (sistem/) need root: the commands are printed.
#   ~/Proyectos/minimo-ayarlar/kur.sh
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"
M="$HOME/Proyectos/minimo-os"
link() {   # link <target> <place>
    local t=$1 p=$2
    mkdir -p "$(dirname "$p")"
    if [ -L "$p" ]; then rm "$p"; elif [ -e "$p" ]; then mv "$p" "$p.yedek"; echo "yedeklendi: $p.yedek"; fi
    ln -s "$t" "$p"
}
cd "$R/ev"
find . -type f ! -name '*.bak*' | sed 's|^\./||' | while read -r f; do link "$R/ev/$f" "$HOME/$f"; done
# Minimo's own: its Hyprland parts and Ghostty's config, from its repository.
for f in apariencia atajos reglas; do link "$M/hypr/minimo/$f.lua" "$HOME/.config/hypr/minimo/$f.lua"; done
link "$M/hypr/minimo.lua" "$HOME/.config/hypr/minimo.lua"
link "$M/terminal/ghostty/config" "$HOME/.config/ghostty/config"
systemctl --user daemon-reload
systemctl --user enable minimo-shell.service minimo-clipboard.service minimo-polkit.service minimo-keys.service minimo-dock.service
echo
echo "Kök dosyaları (bir kez):"
echo "  sudo install -Dm755 $R/sistem/minimo-session /usr/local/bin/minimo-session"
echo "  sudo install -Dm644 $R/sistem/minimo.desktop /usr/share/wayland-sessions/minimo.desktop"
echo "Paketler: ghostty hyprpolkitagent kitty quickshell cliphist (depolardan), hyprland-plugin-hyprbars (AUR)"
