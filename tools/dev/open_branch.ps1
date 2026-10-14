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

  Ссылка caretaker://inkscape/<путь к .svg от корня репозитория> открывает SVG из основного клона
  в Inkscape (issue #222). Принимаются только существующие файлы .svg внутри основного клона.

.EXAMPLE
  powershell -File tools\dev\open_branch.ps1 task/174-door-feedback
.EXAMPLE
  powershell -File tools\dev\open_branch.ps1          # список последних веток с origin
.EXAMPLE
  open_branch.ps1 -Uri caretaker://open/task/174-door-feedback   # так вызывает протокол
.EXAMPLE
  open_branch.ps1 -Uri caretaker://inkscape/docs/design/complex_v4/plans/generation/lower/l_old_core.svg
#>
[CmdletBinding()]
param(
    # Имя ветки на origin, например task/174-door-feedback.
    [Parameter(Position = 0)]
    [string]$Branch = "",
    # Ссылка caretaker://open/<ветка> или caretaker://inkscape/<путь .svg> (передаёт обработчик протокола).
    [string]$Uri = "",
    # Основной клон. По умолчанию — клон, в котором лежит скрипт.
    [string]$Repo = "",
    # Копия просмотра. По умолчанию «<основной клон>-review».
    [string]$ReviewPath = "",
    # Не запускать Godot и Inkscape (для проверок).
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
$InkscapeUriPrefix = "caretaker://inkscape/"
# Символы, недопустимые в пути к плану (кроме управляющих): двоеточие, обратный слэш, кавычки, маски.
$BadPathChars = [char[]]':\"<>|*?'
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

function Test-OnWindows {
    return ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)
}

## Godot, открытый на копии просмотра (только Windows: командная строка процессов через CIM).
function Get-GodotOnReview([string]$Review) {
    if (-not (Test-OnWindows)) { return @() }
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

## Путь к файлу из ссылки caretaker://inkscape/<путь от корня репозитория>. Ссылка может прийти
## откуда угодно, поэтому принимается только существующий .svg внутри основного клона: без «..»,
## абсолютных путей, двоеточий, обратных слэшей и символических ссылок по дороге.
function Resolve-InkscapeTarget([string]$Main, [string]$Value) {
    $raw = $Value.Trim()
    if (-not $raw.StartsWith($InkscapeUriPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Ожидалась ссылка вида ${InkscapeUriPrefix}<путь к .svg>, получено: $Value"
    }
    $relative = [Uri]::UnescapeDataString($raw.Substring($InkscapeUriPrefix.Length))
    if ($relative.Length -eq 0 -or $relative.IndexOfAny($BadPathChars) -ge 0 -or $relative -match '[\x00-\x1f\x7f]' `
            -or $relative.StartsWith('/') -or $relative.StartsWith('-')) {
        throw "Недопустимый путь к плану: '$relative'"
    }
    foreach ($segment in $relative.Split('/')) {
        if ($segment -eq '' -or $segment -eq '.' -or $segment -eq '..' -or $segment.EndsWith('.') -or $segment.EndsWith(' ')) {
            throw "Недопустимый путь к плану: '$relative'"
        }
    }
    if (-not $relative.EndsWith('.svg', [StringComparison]::OrdinalIgnoreCase)) {
        throw "В Inkscape открываются только файлы .svg: '$relative'"
    }
    $separator = [IO.Path]::DirectorySeparatorChar
    $root = [IO.Path]::GetFullPath($Main).TrimEnd('\', '/')
    $full = [IO.Path]::GetFullPath($root + $separator + ($relative -replace '/', $separator))
    if (-not $full.StartsWith($root + $separator, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Путь выходит за пределы клона: '$relative'"
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Файл не найден в клоне $root`: $relative"
    }
    $current = $full
    while ($current.Length -gt $root.Length) {
        if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Путь к плану проходит через символическую ссылку: '$relative'"
        }
        $current = Split-Path -Path $current -Parent
    }
    return $full
}

## Значение по умолчанию ключа реестра (пустая строка, если ключа нет).
function Get-RegistryDefault([string]$Key) {
    if (-not (Test-Path -LiteralPath $Key)) { return "" }
    $value = (Get-Item -LiteralPath $Key).GetValue('')
    if ($null -eq $value) { return "" }
    return ([string]$value).Trim().Trim('"')
}

## Inkscape: INKSCAPE_BIN -> реестр (App Paths, ключ установщика) -> Program Files -> PATH.
function Find-Inkscape {
    if ($env:INKSCAPE_BIN) {
        if (Test-Path -LiteralPath $env:INKSCAPE_BIN -PathType Leaf) { return $env:INKSCAPE_BIN }
        throw "INKSCAPE_BIN указывает на несуществующий файл: $env:INKSCAPE_BIN"
    }
    $candidates = New-Object System.Collections.Generic.List[string]
    if (Test-OnWindows) {
        foreach ($hive in @('HKCU:', 'HKLM:')) {
            $exe = Get-RegistryDefault "$hive\Software\Microsoft\Windows\CurrentVersion\App Paths\inkscape.exe"
            if ($exe) { $candidates.Add($exe) }
        }
        foreach ($key in @('HKCU:\Software\Inkscape\Inkscape', 'HKLM:\Software\Inkscape\Inkscape', 'HKLM:\Software\WOW6432Node\Inkscape\Inkscape')) {
            $dir = Get-RegistryDefault $key
            if ($dir) { $candidates.Add((Join-Path $dir 'bin\inkscape.exe')); $candidates.Add((Join-Path $dir 'inkscape.exe')) }
        }
        foreach ($base in @($env:ProgramFiles, $env:ProgramW6432, ${env:ProgramFiles(x86)}, (Join-Path ([string]$env:LOCALAPPDATA) 'Programs'))) {
            if ($base) { $candidates.Add((Join-Path $base 'Inkscape\bin\inkscape.exe')) }
        }
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    $command = Get-Command inkscape -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    throw "Inkscape не найден: установите его (inkscape.org) или задайте INKSCAPE_BIN с путём к inkscape.exe"
}

function Get-MainFromParameter {
    if ($Repo) { $start = $Repo } else { $start = $PSScriptRoot }
    return Get-MainClone (Resolve-Path -LiteralPath $start).Path
}

function Open-Inkscape {
    $main = Get-MainFromParameter
    $file = Resolve-InkscapeTarget $main $Uri
    Write-Host "План: $file" -ForegroundColor Green
    if ($NoGodot) { return }
    $inkscape = Find-Inkscape
    Write-Step "Открываю Inkscape"
    Start-Process -FilePath $inkscape -ArgumentList @("`"$file`"") | Out-Null
}

function Open-Branch {
    $main = Get-MainFromParameter
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
    if ($Uri -and $Uri.Trim().StartsWith($InkscapeUriPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        Open-Inkscape
    } else {
        Open-Branch
    }
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
