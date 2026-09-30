# Instala la config de Claude Code en Windows.
# Copia el statusline a ~/.claude y mezcla settings.base.json con el settings.json existente.
# Uso: powershell -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = 'Stop'

$repo     = $PSScriptRoot
$dest     = Join-Path $HOME '.claude'
$settings = Join-Path $dest 'settings.json'

New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item (Join-Path $repo 'windows\statusline-command.ps1') $dest -Force
Write-Host "OK statusline -> $dest\statusline-command.ps1"

# Mezcla recursiva: lo existente se conserva; lo del repo pisa las mismas claves
function Merge-Json($Target, $Source) {
    foreach ($p in $Source.PSObject.Properties) {
        $t = $Target.PSObject.Properties[$p.Name]
        if ($t -and $t.Value -is [PSCustomObject] -and $p.Value -is [PSCustomObject]) {
            Merge-Json $t.Value $p.Value
        } else {
            $Target | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
        }
    }
}

$current = [PSCustomObject]@{}
if (Test-Path $settings) {
    Copy-Item $settings "$settings.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $current = Get-Content $settings -Raw | ConvertFrom-Json
}
$base = Get-Content (Join-Path $repo 'settings.base.json') -Raw | ConvertFrom-Json
Merge-Json $current $base

$script = (Join-Path $dest 'statusline-command.ps1') -replace '\\', '/'
Merge-Json $current ([PSCustomObject]@{
    statusLine = [PSCustomObject]@{
        type    = 'command'
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File $script"
    }
})

# UTF-8 sin BOM
$json = $current | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText($settings, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Host "OK settings -> $settings"
Write-Host 'Listo. Reinicia Claude Code para ver los cambios.'
