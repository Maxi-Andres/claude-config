$ErrorActionPreference = 'SilentlyContinue'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$inputJson = [Console]::In.ReadToEnd()
try {
    $data = $inputJson | ConvertFrom-Json -ErrorAction Stop
} catch {
    return
}

# Carpeta actual
$cwd = ''
if ($data.workspace -and $data.workspace.current_dir) {
    $cwd = [string]$data.workspace.current_dir
} elseif ($data.cwd) {
    $cwd = [string]$data.cwd
}
$folder = if ($cwd) { Split-Path -Path $cwd -Leaf } else { '' }

# Rama de git
$branch = ''
if ($cwd -and (Test-Path -LiteralPath $cwd)) {
    Push-Location -LiteralPath $cwd
    try {
        $b = & git symbolic-ref --short HEAD 2>$null
        if (-not $b) { $b = & git rev-parse --short HEAD 2>$null }
        if ($b) { $branch = "$b".Trim() }
    } catch {}
    Pop-Location
}

# Modelo
$modelName = 'unknown'
if ($data.model -and $data.model.display_name) {
    $modelName = [string]$data.model.display_name
} elseif ($data.model -and $data.model.id) {
    $modelName = [string]$data.model.id
}

# Effort (nivel de razonamiento)
$effort = ''
if ($data.effort -and $data.effort.level) {
    $effort = [string]$data.effort.level
}

# Contexto
$ctxTotal = $null
$ctxUsed  = $null
$usedPct  = $null

if ($data.context_window) {
    if ($data.context_window.context_window_size) {
        $ctxTotal = [long]$data.context_window.context_window_size
    }
    if ($data.context_window.total_input_tokens) {
        $ctxUsed = [long]$data.context_window.total_input_tokens
    }
    if ($null -ne $data.context_window.used_percentage) {
        $usedPct = [double]$data.context_window.used_percentage
    }
}

# Texto del modelo con contexto total
# (solo lo agrega si el display_name no lo trae ya, para no repetir "(1M context)")
$modelText = $modelName
if ($ctxTotal -and $modelName -notmatch '(?i)context|ctx') {
    if ($ctxTotal -ge 1000000) {
        $modelText = "$modelName ($([Math]::Round($ctxTotal / 1000000))M ctx)"
    } elseif ($ctxTotal -ge 1000) {
        $modelText = "$modelName ($([Math]::Round($ctxTotal / 1000))K ctx)"
    }
}

# Tokens restantes
$tokensLeft = ''
if ($ctxTotal -and $ctxUsed) {
    $remaining = $ctxTotal - $ctxUsed
    if ($remaining -ge 1000) {
        $tokensLeft = "$([Math]::Round($remaining / 1000))K libres"
    } else {
        $tokensLeft = "$remaining libres"
    }
}

# Glyphs
# $IC_FOLDER = [char]0x2302  # ⌂  (house)
$IC_FOLDER = [char]0x25E7  # ◧  (Square with left side black)
$IC_BRANCH = [char]0x2387  # ⎇  (alternative key / branch)
$IC_MODEL  = [char]0x0BF9  # ௹  (Tamil rupee mark)
$IC_CTX    = [char]0x2230  # ∰  (volume integral)
$IC_TOKENS = [char]0x25A1  # □  (white square)
$IC_EFFORT = [char]0x29D6  # ⧖  (hourglass / effort)
$BAR_FULL  = [char]0x2588  # █
$BAR_EMPTY = [char]0x2591  # ░

function Build-Bar {
    param([double]$Pct, [int]$Width = 14)
    $filled = [int][Math]::Round($Pct * $Width / 100)
    if ($filled -gt $Width) { $filled = $Width }
    if ($filled -lt 0)      { $filled = 0 }
    return ([string]$BAR_FULL * $filled) + ([string]$BAR_EMPTY * ($Width - $filled))
}

# Colores ANSI
$ESC     = [char]27
$CYAN    = "$ESC[36m"
$GREEN   = "$ESC[32m"
$YELLOW  = "$ESC[33m"
$MAGENTA = "$ESC[35m"
$RED     = "$ESC[31m"
$VIOLET  = "$ESC[38;5;141m"  # violeta (256-color)
$RESET   = "$ESC[0m"

# Armar la barra
$parts = @()
if ($folder)    { $parts += "$CYAN$IC_FOLDER $folder$RESET" }
if ($branch)    { $parts += "$GREEN$IC_BRANCH $branch$RESET" }
if ($modelText) { $parts += "$VIOLET$IC_MODEL $modelText$RESET" }

if ($effort) {
    $eColor = switch ($effort) {
        'low'    { $GREEN }
        'medium' { $CYAN }
        'high'   { $YELLOW }
        'xhigh'  { $MAGENTA }
        'max'    { $RED }
        default  { $CYAN }
    }
    $parts += "$eColor$IC_EFFORT $effort$RESET"
}

if ($null -ne $usedPct) {
    $pctInt = [int][Math]::Round($usedPct)
    $bar    = Build-Bar -Pct $usedPct
    $color  = if ($pctInt -ge 80) { $RED } else { $MAGENTA }
    $parts += "$color$IC_CTX $bar $pctInt%$RESET"
}

if ($tokensLeft) {
    $color = if ($usedPct -ge 80) { $RED } else { $CYAN }
    $parts += "$color$IC_TOKENS $tokensLeft$RESET"
}

# Uso de la suscripcion (ventana de 5 h y semanal)
$IC_5H   = [char]0x25F7  # ◷  (reloj)
$IC_WEEK = [char]0x25A6  # ▦  (calendario)
$IC_RST  = [char]0x21BB  # ↻  (reset)
$GRAY    = "$ESC[90m"

function Format-Reset {
    param([long]$Epoch)
    $when = [DateTimeOffset]::FromUnixTimeSeconds($Epoch).ToLocalTime()
    $left = $when - [DateTimeOffset]::Now
    if ($left.TotalSeconds -lt 0) { $left = [TimeSpan]::Zero }
    $in = if ($left.TotalDays -ge 1) { "{0}d {1}h" -f [int][Math]::Floor($left.TotalDays), $left.Hours }
          elseif ($left.TotalHours -ge 1) { "{0}h {1:D2}m" -f [int][Math]::Floor($left.TotalHours), $left.Minutes }
          else { "{0}m" -f [int][Math]::Ceiling($left.TotalMinutes) }
    $es  = [Globalization.CultureInfo]::GetCultureInfo('es-AR')
    $fmt = if ($left.TotalHours -lt 24) { 'HH:mm' } else { 'ddd HH:mm' }
    return "$($when.ToString($fmt, $es)) (en $in)"
}

function Build-Limit {
    param($Limit, [string]$Icon, [string]$Label)
    if (-not $Limit -or $null -eq $Limit.used_percentage) { return $null }
    $pct   = [double]$Limit.used_percentage
    $color = if ($pct -ge 90) { $RED } elseif ($pct -ge 70) { $YELLOW } else { $GREEN }
    $txt   = "$color$Icon $Label $(Build-Bar -Pct $pct -Width 10) $([int][Math]::Round($pct))%$RESET"
    if ($Limit.resets_at) { $txt += " $GRAY$IC_RST $(Format-Reset -Epoch ([long]$Limit.resets_at))$RESET" }
    return $txt
}

$usage = @()
if ($data.rate_limits) {
    $u = Build-Limit -Limit $data.rate_limits.five_hour -Icon $IC_5H   -Label '5h';  if ($u) { $usage += $u }
    $u = Build-Limit -Limit $data.rate_limits.seven_day -Icon $IC_WEEK -Label 'sem'; if ($u) { $usage += $u }
}

$out = ($parts -join '  ')
if ($usage.Count) { $out += "`n" + ($usage -join '   ') }
[Console]::Out.Write($out)