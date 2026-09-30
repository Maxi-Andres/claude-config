#!/usr/bin/env bash
# Statusline de Claude Code para Linux (equivalente a windows/statusline-command.ps1).
# Requiere: jq. Opcional: git.

input=$(cat)
command -v jq >/dev/null 2>&1 || { printf 'statusline: falta jq'; exit 0; }

# Un solo jq para todo; separador \x1f para que los campos vacíos no se colapsen
IFS=$'\x1f' read -r cwd model effort ctx_total ctx_used used_pct \
    h5_pct h5_reset wk_pct wk_reset < <(
  printf '%s' "$input" | jq -r '[
    (.workspace.current_dir // .cwd // ""),
    (.model.display_name // .model.id // "unknown"),
    (.effort.level // ""),
    (.context_window.context_window_size // ""),
    (.context_window.total_input_tokens // ""),
    (.context_window.used_percentage // "" | if . == "" then . else round end),
    (.rate_limits.five_hour.used_percentage // "" | if . == "" then . else round end),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // "" | if . == "" then . else round end),
    (.rate_limits.seven_day.resets_at // "")
  ] | map(tostring) | join("\u001f")' 2>/dev/null
) || exit 0

# Carpeta y rama
folder=${cwd##*/}
branch=''
if [[ -n $cwd && -d $cwd ]] && command -v git >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Modelo con contexto total (si el display_name no lo trae ya)
model_text=$model
if [[ -n $ctx_total ]] && ! grep -qiE 'context|ctx' <<<"$model"; then
  if (( ctx_total >= 1000000 )); then model_text="$model ($(( (ctx_total + 500000) / 1000000 ))M ctx)"
  elif (( ctx_total >= 1000 )); then model_text="$model ($(( (ctx_total + 500) / 1000 ))K ctx)"
  fi
fi

# Tokens restantes
tokens_left=''
if [[ -n $ctx_total && -n $ctx_used ]]; then
  remaining=$(( ctx_total - ctx_used ))
  if (( remaining >= 1000 )); then tokens_left="$(( (remaining + 500) / 1000 ))K libres"
  else tokens_left="$remaining libres"; fi
fi

# Glyphs
IC_FOLDER='◧'; IC_BRANCH='⎇'; IC_MODEL='௹'; IC_CTX='∰'; IC_TOKENS='□'; IC_EFFORT='⧖'
IC_5H='◷'; IC_WEEK='▦'; IC_RST='↻'

# Colores ANSI
CYAN=$'\e[36m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; MAGENTA=$'\e[35m'; RED=$'\e[31m'
VIOLET=$'\e[38;5;141m'; GRAY=$'\e[90m'; RESET=$'\e[0m'

build_bar() {  # build_bar <pct> [ancho]
  local pct=$1 width=${2:-14} filled i out=''
  filled=$(( (pct * width + 50) / 100 ))
  (( filled > width )) && filled=$width
  (( filled < 0 )) && filled=0
  for (( i = 0; i < width; i++ )); do
    if (( i < filled )); then out+='█'; else out+='░'; fi
  done
  printf '%s' "$out"
}

fmt_date() {  # fmt_date <epoch> <formato>  (GNU date, con fallback BSD/macOS)
  date -d "@$1" "+$2" 2>/dev/null || date -r "$1" "+$2"
}

format_reset() {  # format_reset <epoch>
  local epoch=$1 now left days hours mins in when
  local -a dias=(lun mar mié jue vie sáb dom)
  now=$(date +%s)
  left=$(( epoch - now )); (( left < 0 )) && left=0
  days=$(( left / 86400 )); hours=$(( left % 86400 / 3600 )); mins=$(( left % 3600 / 60 ))
  if (( days >= 1 )); then in="${days}d ${hours}h"
  elif (( hours >= 1 )); then in=$(printf '%dh %02dm' "$hours" "$mins")
  else in="$(( (left + 59) / 60 ))m"; fi
  when=$(fmt_date "$epoch" '%H:%M')
  (( left >= 86400 )) && when="${dias[$(( $(fmt_date "$epoch" '%u') - 1 ))]} $when"
  printf '%s (en %s)' "$when" "$in"
}

build_limit() {  # build_limit <pct> <reset> <icono> <etiqueta>
  local pct=$1 reset=$2 icon=$3 label=$4 color txt
  [[ -z $pct ]] && return
  if (( pct >= 90 )); then color=$RED; elif (( pct >= 70 )); then color=$YELLOW; else color=$GREEN; fi
  txt="$color$icon $label $(build_bar "$pct" 10) $pct%$RESET"
  [[ -n $reset ]] && txt+=" $GRAY$IC_RST $(format_reset "$reset")$RESET"
  printf '%s' "$txt"
}

# Línea 1
parts=()
[[ -n $folder ]]     && parts+=("$CYAN$IC_FOLDER $folder$RESET")
[[ -n $branch ]]     && parts+=("$GREEN$IC_BRANCH $branch$RESET")
[[ -n $model_text ]] && parts+=("$VIOLET$IC_MODEL $model_text$RESET")

if [[ -n $effort ]]; then
  case $effort in
    low) ec=$GREEN ;; medium) ec=$CYAN ;; high) ec=$YELLOW ;;
    xhigh) ec=$MAGENTA ;; max) ec=$RED ;; *) ec=$CYAN ;;
  esac
  parts+=("$ec$IC_EFFORT $effort$RESET")
fi

if [[ -n $used_pct ]]; then
  if (( used_pct >= 80 )); then c=$RED; else c=$MAGENTA; fi
  parts+=("$c$IC_CTX $(build_bar "$used_pct") $used_pct%$RESET")
fi

if [[ -n $tokens_left ]]; then
  if [[ -n $used_pct ]] && (( used_pct >= 80 )); then c=$RED; else c=$CYAN; fi
  parts+=("$c$IC_TOKENS $tokens_left$RESET")
fi

# Línea 2: uso de la suscripción (ventana de 5 h y semanal)
usage=()
u=$(build_limit "$h5_pct" "$h5_reset" "$IC_5H" '5h');   [[ -n $u ]] && usage+=("$u")
u=$(build_limit "$wk_pct" "$wk_reset" "$IC_WEEK" 'sem'); [[ -n $u ]] && usage+=("$u")

out=''
for p in "${parts[@]}"; do out+="${out:+  }$p"; done
if (( ${#usage[@]} )); then
  line2=''
  for p in "${usage[@]}"; do line2+="${line2:+   }$p"; done
  out+=$'\n'"$line2"
fi
printf '%s' "$out"
