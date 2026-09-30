#!/usr/bin/env bash
# Instala la config de Claude Code en Linux (o macOS).
# Copia el statusline a ~/.claude y mezcla settings.base.json con el settings.json existente.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dest="$HOME/.claude"
settings="$dest/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "Falta jq (lo usan el statusline y este instalador). Instalalo con uno de estos:"
  echo "  sudo apt install jq      # Debian / Ubuntu"
  echo "  sudo dnf install jq      # Fedora"
  echo "  sudo pacman -S jq        # Arch"
  echo "  brew install jq          # macOS"
  exit 1
fi

mkdir -p "$dest"
install -m 755 "$repo/linux/statusline-command.sh" "$dest/statusline-command.sh"
echo "✓ statusline -> $dest/statusline-command.sh"

current='{}'
if [[ -f $settings ]]; then
  cp "$settings" "$settings.bak.$(date +%Y%m%d-%H%M%S)"
  current=$(cat "$settings")
fi

# Lo existente se conserva; lo del repo pisa las mismas claves
jq -n --argjson cur "$current" --slurpfile base "$repo/settings.base.json" \
      --arg cmd "bash $dest/statusline-command.sh" \
  '$cur * $base[0] * {statusLine: {type: "command", command: $cmd}}' > "$settings.tmp"
mv "$settings.tmp" "$settings"
echo "✓ settings -> $settings"
echo "Listo. Reiniciá Claude Code para ver los cambios."
