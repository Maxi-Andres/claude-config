# claude-config

Mi configuración de Claude Code, para tenerla igual en cualquier compu (Windows o Linux).

## Qué incluye

| Archivo | Qué es |
|---|---|
| `settings.base.json` | Settings compartidos: modelo, effort, tema, modo de permisos, etc. |
| `windows/statusline-command.ps1` | Statusline para Windows (PowerShell) |
| `linux/statusline-command.sh` | El mismo statusline para Linux/macOS (bash + `jq`) |
| `install.ps1` / `install.sh` | Instaladores |

El statusline muestra dos líneas:

```
◧ carpeta  ⎇ rama  ௹ Modelo (1M context)  ⧖ high  ∰ █░░░░░░░░░░░░░ 5%  □ 946K libres
◷ 5h ██░░░░░░░░ 22% ↻ 01:20 (en 3h 17m)   ▦ sem ░░░░░░░░░░ 5% ↻ lun 21:00 (en 5d 22h)
```

La segunda línea es el uso de la suscripción: la ventana de 5 horas y la semanal, cada una con su hora de reset.
Sale del campo `rate_limits` que Claude Code le pasa al statusline, sin llamadas extra. Si no llega ese campo (por ejemplo, con una API key), la línea no aparece.

## Instalar

**Windows**
```powershell
git clone <url> claude-config
cd claude-config
powershell -ExecutionPolicy Bypass -File install.ps1
```

**Linux / macOS** (necesita `jq`: `sudo apt install jq`, `sudo dnf install jq`, `sudo pacman -S jq` o `brew install jq`)
```bash
git clone <url> claude-config
cd claude-config
bash install.sh
```

El instalador:
1. Copia el statusline a `~/.claude/`.
2. Hace un backup de `~/.claude/settings.json` (`settings.json.bak.<fecha>`).
3. **Mezcla** `settings.base.json` con lo que ya tenías: conserva tus otras claves (permisos, plugins, etc.) y pisa sólo las que están en el repo.
4. Configura `statusLine` con la ruta correcta de esa máquina.

Reiniciá Claude Code después de instalar.

## Cambiar algo

El repo manda. Editá acá, commiteá, y en cada compu hacé `git pull` y volvé a correr el instalador.

## Qué NO está (a propósito)

- `.credentials.json`, `history.jsonl`, `projects/`, `sessions/`: son secretos o datos de cada máquina.
- `skills/synced` y `plugins/synced`: se sincronizan solos desde tu cuenta de claude.ai.
# claude-config
