<#
.SYNOPSIS
  Регистрирует ссылки caretaker://open/<ветка> (issue #175) и caretaker://inkscape/<путь к .svg>
  (issue #222) для текущего пользователя Windows.

.DESCRIPTION
  Без прав администратора: ключ HKCU\Software\Classes\caretaker. Скрипт open_branch.ps1 копируется
  в %LOCALAPPDATA%\Caretaker\, а путь к основному клону запоминается в команде протокола, поэтому
  ссылка работает, даже если основной клон переключён на ветку, где скрипта нет.
  После обновления open_branch.ps1 запустите установку ещё раз.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\dev\install_branch_protocol.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\dev\install_branch_protocol.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    # Удалить протокол и установленную копию скрипта.
    [switch]$Uninstall,
    # Основной клон. По умолчанию — клон, в котором лежит этот скрипт.
    [string]$Repo = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$Scheme = "caretaker"
$ClassKey = "HKCU:\Software\Classes\$Scheme"
$InstallDir = Join-Path $env:LOCALAPPDATA "Caretaker"
$InstalledScript = Join-Path $InstallDir "open_branch.ps1"
# Вывод git (путь к клону) — UTF-8; без этого Windows PowerShell читает его как OEM cp866 и портит кириллицу.
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

if ($Uninstall) {
    if (Test-Path $ClassKey) { Remove-Item -Path $ClassKey -Recurse -Force }
    if (Test-Path $InstallDir) { Remove-Item -Path $InstallDir -Recurse -Force }
    Write-Host "Протокол ${Scheme}:// удалён. Копия просмотра (<клон>-review) не тронута: удалите её командой из docs/branch-preview.md."
    return
}

if ($Repo) { $start = $Repo } else { $start = $PSScriptRoot }
$main = $null
$savedConsoleEncoding = $null
try { $savedConsoleEncoding = [Console]::OutputEncoding; [Console]::OutputEncoding = $Utf8NoBom } catch { $savedConsoleEncoding = $null }
try {
    $worktrees = @(& git -c core.quotepath=false -C $start worktree list --porcelain)
    $gitCode = $LASTEXITCODE
} finally {
    if ($null -ne $savedConsoleEncoding) { [Console]::OutputEncoding = $savedConsoleEncoding }
}
foreach ($line in $worktrees) {
    if ($line.StartsWith('worktree ')) { $main = $line.Substring('worktree '.Length); break }
}
if ($gitCode -ne 0 -or -not $main) { throw "Не удалось найти основной клон для $start" }
# Без обратного слэша в конце: «\"» в команде протокола экранировал бы закрывающую кавычку.
$main = [IO.Path]::GetFullPath($main).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath (Join-Path $main '.git'))) { throw "Путь к клону прочитан неверно: $main" }

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "open_branch.ps1") -Destination $InstalledScript -Force

$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
# %1 — вся ссылка; open_branch.ps1 сам проверяет её: имя ветки только из [A-Za-z0-9._/-],
# путь для Inkscape — только существующий .svg внутри основного клона.
$command = "`"$powershell`" -NoProfile -ExecutionPolicy Bypass -File `"$InstalledScript`" -Repo `"$main`" -PauseAtEnd -Uri `"%1`""

New-Item -Path $ClassKey -Force | Out-Null
Set-ItemProperty -Path $ClassKey -Name "(default)" -Value "URL:Caretaker branch preview and plans"
Set-ItemProperty -Path $ClassKey -Name "URL Protocol" -Value ""
New-Item -Path "$ClassKey\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "$ClassKey\shell\open\command" -Name "(default)" -Value $command

Write-Host "Готово: ссылки ${Scheme}://open/<ветка> открывают ветку из клона $main"
Write-Host "        ссылки ${Scheme}://inkscape/<путь к .svg> открывают план из этого клона в Inkscape"
Write-Host "Скрипт: $InstalledScript"
Write-Host "Проверка: Win+R -> ${Scheme}://open/team/integration"
