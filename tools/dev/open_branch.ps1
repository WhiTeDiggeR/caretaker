<#
.SYNOPSIS
  Открывает свежую версию ветки в отдельной рабочей копии для просмотра и запускает Godot (issue #175).

.DESCRIPTION
  1. git fetch origin <ветка> (ветка может отсутствовать локально);
  2. копия просмотра (git worktree, по умолчанию «<клон>-review» рядом с основным клоном)
     создаётся при первом запуске, затем переключается: checkout --detach origin/<ветка>,
     сброс отслеживаемых изменений и удаление неотслеживаемых файлов, кроме .godot/;
  3. git lfs pull;
  4. godot --editor --path <копия просмотра>.

  Основной клон (его ветка, индекс и файлы) не меняется: обновляются только ссылки origin/*.
  Копия просмотра одноразовая — из неё не коммитят. Скрипт ничего не коммитит и не пушит.

.EXAMPLE
  powershell -File tools\dev\open_branch.ps1 task/174-door-feedback
.EXAMPLE
  powershell -File tools\dev\open_branch.ps1          # список последних веток с origin
.EXAMPLE
  open_branch.ps1 -Uri caretaker://open/task/174-door-feedback   # так вызывает протокол
#>
[CmdletBinding()]
param(
    # Имя ветки на origin, например task/174-door-feedback.
    [Parameter(Position = 0)]
    [string]$Branch = "",
    # Ссылка caretaker://open/<ветка> (передаёт обработчик протокола).
    [string]$Uri = "",
    # Основной клон. По умолчанию — клон, в котором лежит скрипт.
    [string]$Repo = "",
    # Копия просмотра. По умолчанию «<основной клон>-review».
    [string]$ReviewPath = "",
    # Не запускать Godot (для проверок).
    [switch]$NoGodot,
    # Сбросить копию просмотра без вопроса, даже если в ней есть ручные правки.
    [switch]$Force,
    # Ждать Enter перед закрытием окна (ставит обработчик протокола).
    [switch]$PauseAtEnd
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$BranchPattern = '^[A-Za-z0-9._/-]+$'
$UriPrefix = "caretaker://open/"
$RecentBranchCount = 20
# Файлы, которые Godot создаёт или переписывает сам при открытии проекта.
$GeneratedPatterns = @('*.import', '*.uid')
$GeneratedDirectory = '.godot/'
$ResavedPatterns = @('*.tscn', '*.tres')
# Git пишет пути и тексты в UTF-8, а PowerShell декодирует вывод нативных команд по
# [Console]::OutputEncoding — на русской Windows это OEM cp866, и пути с кириллицей портятся.
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Step([string]$Text) {
    Write-Host "==> $Text" -ForegroundColor Cyan
}

## Invoke-Git <папка> <аргументы git...>; простая функция, чтобы -x/--prune ушли в git как есть.
function Invoke-Git {
    $Directory = $args[0]
    $GitArgs = @($args | Select-Object -Skip 1)
    $output = & git -c core.quotepath=false -C $Directory @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgs -join ' ') завершился с кодом $LASTEXITCODE"
    }
    return $output
}

## Имя ветки из ссылки caretaker://open/<ветка> или из аргумента; строгая проверка, чтобы
## ссылка не могла передать в git или в командную строку ничего, кроме имени ветки.
function Resolve-BranchName([string]$Value) {
    $name = $Value.Trim()
    if ($name.StartsWith($UriPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $name = [Uri]::UnescapeDataString($name.Substring($UriPrefix.Length))
    } elseif ($name -match '^[A-Za-z][A-Za-z0-9+.-]*:') {
        throw "Ожидалась ссылка вида ${UriPrefix}<ветка>, получено: $Value"
    }
    $name = $name.TrimEnd('/')
    if ($name.StartsWith('origin/')) {
        $name = $name.Substring('origin/'.Length)
    }
    if ($name -notmatch $BranchPattern -or $name.StartsWith('-') -or $name.StartsWith('/') `
            -or $name.Contains('..') -or $name.Contains('//') -or $name.EndsWith('.lock') -or $name.EndsWith('.')) {
        throw "Недопустимое имя ветки: '$name'. Разрешены только A-Z a-z 0-9 . _ / -"
    }
    return $name
}

function Test-Generated([string]$Path) {
    if ($Path.StartsWith($GeneratedDirectory)) { return $true }
    foreach ($pattern in $GeneratedPatterns) {
        if ($Path -like $pattern) { return $true }
    }
    return $false
}

## Эвристика «изменён только пересохранением в Godot»: после удаления атрибутов, которые
## Godot пересчитывает сам (uid, unique_id, load_steps, format), и пустых строк текст совпадает
## с версией в HEAD.
function Get-NormalizedScene([string[]]$Lines) {
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($line in $Lines) {
        $clean = $line -replace ' uid="uid://[^"]*"', '' -replace ' unique_id=\d+', '' `
            -replace ' load_steps=\d+', '' -replace ' format=\d+', ''
        $clean = $clean.TrimEnd()
        if ($clean.Length -gt 0) { $result.Add($clean) }
    }
    return , $result.ToArray()
}

function Test-ResavedOnly([string]$Review, [string]$Path) {
    $matchesScene = $false
    foreach ($pattern in $ResavedPatterns) {
        if ($Path -like $pattern) { $matchesScene = $true }
    }
    if (-not $matchesScene) { return $false }
    $headLines = & git -c core.quotepath=false -C $Review show "HEAD:$Path" 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    $file = Join-Path $Review $Path
    if (-not (Test-Path -LiteralPath $file)) { return $false }
    $before = Get-NormalizedScene @($headLines)
    $after = Get-NormalizedScene @(Get-Content -LiteralPath $file -Encoding UTF8)
    return (Compare-Object -ReferenceObject $before -DifferenceObject $after -SyncWindow 0 | Measure-Object).Count -eq 0
}

## Изменения в копии просмотра, которые не создал Godot: их сброс может стоить чьей-то работы.
function Get-ManualChange([string]$Review) {
    $manual = New-Object System.Collections.Generic.List[string]
    $status = Invoke-Git $Review status --porcelain=v1 --untracked-files=all
    foreach ($line in @($status)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $code = $line.Substring(0, 2)
        $path = $line.Substring(3).Trim('"')
        if ($path.Contains(' -> ')) { $path = $path.Split(@(' -> '), [StringSplitOptions]::None)[1] }
        if (Test-Generated $path) { continue }
        if ($code -ne '??' -and (Test-ResavedOnly $Review $path)) { continue }
        $manual.Add("$code $path")
    }
    return $manual.ToArray()
}

## Godot, открытый на копии просмотра (только Windows: командная строка процессов через CIM).
function Get-GodotOnReview([string]$Review) {
    $onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)
    if (-not $onWindows) { return @() }
    $full = [IO.Path]::GetFullPath($Review).TrimEnd('\')
    $found = Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($full, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
    return @($found)
}

function Get-MainClone([string]$Start) {
    $lines = Invoke-Git $Start worktree list --porcelain
    foreach ($line in @($lines)) {
        if ($line.StartsWith('worktree ')) { return $line.Substring('worktree '.Length) }
    }
    throw "Не удалось найти основной клон для $Start"
}

function Select-RecentBranch([string]$Main) {
    Write-Step "Обновляю список веток с origin"
    Invoke-Git $Main fetch --prune origin | Out-Null
    $refs = @(Invoke-Git $Main for-each-ref --sort=-committerdate "--count=$RecentBranchCount" `
        '--format=%(refname:lstrip=3)|%(committerdate:relative)|%(subject)' refs/remotes/origin |
        Where-Object { $_ -and -not $_.StartsWith('HEAD|') })
    if ($refs.Count -eq 0) { throw "На origin нет веток" }
    for ($i = 0; $i -lt $refs.Count; $i++) {
        $parts = $refs[$i].Split('|')
        Write-Host ("{0,3}. {1}  ({2})  {3}" -f ($i + 1), $parts[0], $parts[1], $parts[2])
    }
    $answer = Read-Host "Номер или имя ветки"
    $number = 0
    if ([int]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $refs.Count) {
        return $refs[$number - 1].Split('|')[0]
    }
    return $answer
}

function Find-Godot {
    if ($env:GODOT_BIN) {
        if (Test-Path -LiteralPath $env:GODOT_BIN) { return $env:GODOT_BIN }
        throw "GODOT_BIN указывает на несуществующий файл: $env:GODOT_BIN"
    }
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw "Godot не найден: задайте GODOT_BIN (консольная обёртка Godot_v4.7-stable_win64_console.exe) или добавьте godot в PATH"
}

function Open-Branch {
    if ($Repo) { $start = $Repo } else { $start = $PSScriptRoot }
    $main = Get-MainClone (Resolve-Path -LiteralPath $start).Path
    if ($ReviewPath) { $review = $ReviewPath } else { $review = "$main-review" }
    $review = [IO.Path]::GetFullPath($review)
    if ([IO.Path]::GetFullPath($main).TrimEnd('\', '/') -eq $review.TrimEnd('\', '/')) {
        throw "Копия просмотра не может совпадать с основным клоном: $review"
    }

    if ($Uri) { $requested = $Uri } elseif ($Branch) { $requested = $Branch } else { $requested = Select-RecentBranch $main }
    $name = Resolve-BranchName $requested
    $remoteRef = "refs/remotes/origin/$name"

    Write-Step "Скачиваю origin/$name"
    Invoke-Git $main fetch origin "+refs/heads/${name}:$remoteRef" | Out-Null

    if (-not (Test-Path -LiteralPath (Join-Path $review '.git'))) {
        if ((Test-Path -LiteralPath $review) -and @(Get-ChildItem -LiteralPath $review -Force).Count -gt 0) {
            throw "Папка $review уже существует и не является копией просмотра. Укажите другую через -ReviewPath."
        }
        Write-Step "Создаю копию просмотра $review (один раз)"
        Invoke-Git $main worktree add --detach $review $remoteRef | Out-Null
    } else {
        $godot = @(Get-GodotOnReview $review)
        if ($godot.Count -gt 0) {
            Write-Warning "Godot открыт на копии просмотра (PID $(($godot | ForEach-Object { $_.ProcessId }) -join ', ')). Закройте его, чтобы он не пересохранил файлы старой ветки."
            if (-not $Force) {
                $answer = Read-Host "Закрыть Godot сейчас? [д/Н]"
                if ($answer -match '^(д|y)') {
                    $godot | ForEach-Object { Stop-Process -Id $_.ProcessId }
                    Start-Sleep -Seconds 1
                } else {
                    throw "Переключение отменено: Godot открыт на копии просмотра"
                }
            }
        }
        $manual = @(Get-ManualChange $review)
        if ($manual.Count -gt 0) {
            Write-Warning "В копии просмотра есть изменения, которые не похожи на файлы Godot:"
            $manual | ForEach-Object { Write-Host "    $_" }
            if (-not $Force) {
                $interactive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
                if (-not $interactive) { throw "Переключение отменено: есть ручные правки (запустите с -Force, чтобы сбросить)" }
                $answer = Read-Host "Сбросить их и переключиться? [д/Н]"
                if ($answer -notmatch '^(д|y)') { throw "Переключение отменено" }
            }
        }
        Write-Step "Переключаю копию просмотра на origin/$name"
        Invoke-Git $review checkout --force --detach $remoteRef | Out-Null
        Invoke-Git $review reset --hard --quiet $remoteRef | Out-Null
        # -x удаляет и игнорируемые файлы (build/, build_info.json), -e сохраняет кэш импорта.
        Invoke-Git $review clean -fdxq -e /.godot/ | Out-Null
    }

    $lfs = & git -c core.quotepath=false -C $review lfs version 2>$null
    if ($LASTEXITCODE -eq 0 -and $lfs) {
        Write-Step "git lfs pull"
        Invoke-Git $review lfs pull | Out-Null
    } else {
        Write-Warning "Git LFS не установлен: вместо ассетов будут указатели (см. docs/LFS.md)"
    }

    $commit = Invoke-Git $review log -1 '--format=%h %s'
    Write-Host "Копия просмотра: $review" -ForegroundColor Green
    Write-Host "Ветка: origin/$name @ $commit" -ForegroundColor Green
    if ($NoGodot) { return }
    $godotBin = Find-Godot
    Write-Step "Открываю Godot"
    Start-Process -FilePath $godotBin -ArgumentList @('--editor', '--path', "`"$review`"") | Out-Null
}

$savedOutputEncoding = $OutputEncoding
$savedConsoleEncoding = $null
try {
    $savedConsoleEncoding = [Console]::OutputEncoding
    [Console]::OutputEncoding = $Utf8NoBom
} catch {
    $savedConsoleEncoding = $null  # без консоли кодировку не поменять; тогда вывод git не декодируется консолью
}
$OutputEncoding = $Utf8NoBom
$exitCode = 0
try {
    Open-Branch
    if ($PauseAtEnd) { Start-Sleep -Seconds 3 }
} catch {
    Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red
    if ($PauseAtEnd) { Read-Host "Нажмите Enter, чтобы закрыть окно" | Out-Null }
    $exitCode = 1
} finally {
    $OutputEncoding = $savedOutputEncoding
    if ($null -ne $savedConsoleEncoding) {
        try { [Console]::OutputEncoding = $savedConsoleEncoding } catch { $savedConsoleEncoding = $null }
    }
}
exit $exitCode
