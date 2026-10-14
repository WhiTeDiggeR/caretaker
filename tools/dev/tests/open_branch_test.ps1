<#
  Проверка git-логики tools/dev/open_branch.ps1 на временном репозитории (issue #175).
  Запуск: pwsh -NoProfile -File tools/dev/tests/open_branch_test.ps1
  Godot не запускается (-NoGodot); проверяются копия просмотра, сохранение .godot/, защита ручных
  правок, валидация имени ветки и то, что основной клон не меняется. Сценарий идёт дважды: в обычной
  папке и в папке с кириллицей и пробелом, где скрипт запускается с консольной кодировкой cp866,
  как в Windows PowerShell на русской Windows (вывод git декодируется по [Console]::OutputEncoding).
  Ссылки caretaker://inkscape/<путь> (#222): разбор пути, отказ на путь вне клона и не-.svg, запуск
  подменённого Inkscape (INKSCAPE_BIN) с путём одним аргументом — запуск только вне Windows.
#>
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$script = Join-Path (Split-Path $PSScriptRoot -Parent) "open_branch.ps1"
$pwshBin = (Get-Process -Id $PID).Path
$root = Join-Path ([IO.Path]::GetTempPath()) ("open-branch-test-" + [Guid]::NewGuid().ToString("N"))
$env:GIT_AUTHOR_NAME = "test"; $env:GIT_AUTHOR_EMAIL = "test@example.com"
$env:GIT_COMMITTER_NAME = "test"; $env:GIT_COMMITTER_EMAIL = "test@example.com"
$script:checks = 0
$script:lastOutput = ""
$script:failures = 0
$script:prefix = ""
$script:cp866 = $false

function Check([bool]$Condition, [string]$Message) {
    $script:checks++
    if ($Condition) { Write-Host "PASS  $($script:prefix)$Message" } else {
        $script:failures++
        Write-Host "FAIL  $($script:prefix)$Message"
        if ($script:lastOutput) { Write-Host ($script:lastOutput.Trim() -replace '(?m)^', '      | ') }
    }
}

function G {
    $dir = $args[0]
    $rest = @($args | Select-Object -Skip 1)
    $out = & git -C $dir @rest
    if ($LASTEXITCODE -ne 0) { throw "git $($rest -join ' ') failed in $dir" }
    return $out
}

function Write-File([string]$Path, [string]$Text) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($Path, $Text)
}

## Запускает open_branch.ps1 отдельным процессом с перенаправленным stdin (неинтерактивно).
function Open-Branch([string[]]$Arguments, [string]$InputText = '') {
    $all = @('-NoProfile', '-File')
    if ($script:cp866) { $all += @($wrapper, $script) } else { $all += @($script) }
    $all += @('-Repo', $main, '-NoGodot') + $Arguments
    $output = $InputText | & $pwshBin @all 2>&1
    $script:lastOutput = ($output | Out-String)
    return $LASTEXITCODE
}

## Ссылка caretaker://inkscape/...; без -Launch Inkscape не запускается (-NoGodot).
function Open-Inkscape([string]$Link, [bool]$Launch = $false) {
    $extra = @('-Uri', $Link)
    if ($Launch) {
        $all = @('-NoProfile', '-File')
        if ($script:cp866) { $all += @($wrapper, $script) } else { $all += @($script) }
        $output = '' | & $pwshBin @($all + @('-Repo', $main) + $extra) 2>&1
        $script:lastOutput = ($output | Out-String)
        return $LASTEXITCODE
    }
    return (Open-Branch $extra)
}

function Get-MainState {
    return @{
        Head = (G $main rev-parse HEAD)
        Branch = (G $main symbolic-ref --short HEAD)
        Status = ((G $main status --porcelain=v1 --untracked-files=all) -join "`n")
        File = (Get-Content -Raw (Join-Path $main "notes.txt"))
    }
}

function Invoke-Scenario([string]$Label, [string]$Parent, [string]$CloneName, [bool]$Cp866) {
    $script:prefix = $Label
    $script:cp866 = $Cp866
    $base = Join-Path $root $Parent
    New-Item -ItemType Directory -Path $base -Force | Out-Null
    $origin = Join-Path $base "origin.git"
    $seed = Join-Path $base "seed"
    $script:main = Join-Path $base $CloneName
    $main = $script:main
    $review = "$main-review"

    & git init --quiet --bare $origin
    & git init --quiet $seed
    G $seed checkout --quiet -b team/integration | Out-Null
    Write-File (Join-Path $seed ".gitignore") "/build/`n.godot/`n"
    Write-File (Join-Path $seed "project.godot") "config_version=5`n"
    Write-File (Join-Path $seed "notes.txt") "integration`n"
    Write-File (Join-Path $seed "scenes/room.tscn") "[gd_scene load_steps=2 format=3 uid=`"uid://aaa`"]`n`n[node name=`"Room`" type=`"Node3D`" unique_id=1]`ntext = `"Комната смотрителя`"`n"
    Write-File (Join-Path $seed "docs/заметки.txt") "кириллица в имени файла`n"
    Write-File (Join-Path $seed "plans/lower/l_core.svg") "<svg xmlns=`"http://www.w3.org/2000/svg`"/>`n"
    Write-File (Join-Path $seed "plans/мой план.svg") "<svg xmlns=`"http://www.w3.org/2000/svg`"/>`n"
    G $seed add -A | Out-Null
    G $seed commit --quiet -m "integration" | Out-Null
    G $seed checkout --quiet -b task/1-feature | Out-Null
    Write-File (Join-Path $seed "notes.txt") "feature`n"
    G $seed commit --quiet -am "feature" | Out-Null
    G $seed remote add origin $origin | Out-Null
    G $seed push --quiet origin team/integration task/1-feature | Out-Null

    & git clone --quiet --branch team/integration $origin $main
    # Незакоммиченная работа автора в основном клоне.
    Write-File (Join-Path $main "notes.txt") "my uncommitted work`n"
    Write-File (Join-Path $main "draft.txt") "untracked draft`n"
    $before = Get-MainState

    # Ветка, которой нет локально (появилась на origin после клонирования).
    G $seed checkout --quiet -b task/2-late team/integration | Out-Null
    Write-File (Join-Path $seed "notes.txt") "late`n"
    G $seed commit --quiet -am "late" | Out-Null
    G $seed push --quiet origin task/2-late | Out-Null

    # 1. Первый запуск создаёт копию просмотра.
    $code = Open-Branch @('task/1-feature')
    Check ($code -eq 0) "first run exits 0"
    Check (Test-Path (Join-Path $review ".git")) "review worktree is created next to the clone"
    Check ((Get-Content -Raw (Join-Path $review "notes.txt")) -eq "feature`n") "review shows origin/task/1-feature"
    Check ((G $review rev-parse HEAD) -eq (G $origin rev-parse task/1-feature)) "review HEAD is the origin commit"

    # 2. Файлы Godot не мешают переключению; .godot/ остаётся, остальное неотслеживаемое удаляется.
    Write-File (Join-Path $review ".godot/imported/cache.bin") "cache"
    Write-File (Join-Path $review "scenes/room.tscn.import") "generated"
    Write-File (Join-Path $review "scenes/room.gd.uid") "uid://bbb"
    Write-File (Join-Path $review "build/game.exe") "binary"
    Write-File (Join-Path $review "scenes/room.tscn") "[gd_scene load_steps=3 format=3 uid=`"uid://ccc`"]`n[node name=`"Room`" type=`"Node3D`" unique_id=77]`ntext = `"Комната смотрителя`"`n"
    $code = Open-Branch @('team/integration')
    Check ($code -eq 0) "Godot-generated changes do not block the switch"
    Check (Test-Path (Join-Path $review ".godot/imported/cache.bin")) ".godot/ cache is kept"
    Check (-not (Test-Path (Join-Path $review "scenes/room.tscn.import"))) "untracked .import is removed"
    Check (-not (Test-Path (Join-Path $review "scenes/room.gd.uid"))) "untracked .uid is removed"
    Check (-not (Test-Path (Join-Path $review "build"))) "ignored build/ is removed"
    Check ((Get-Content -Raw (Join-Path $review "scenes/room.tscn")).Contains('uid://aaa')) "resaved scene is reset"
    Check ((Get-Content -Raw (Join-Path $review "notes.txt")) -eq "integration`n") "review shows origin/team/integration"

    # 3. Ручная правка: без -Force переключение отменяется и правка цела; с -Force — сбрасывается.
    Write-File (Join-Path $review "notes.txt") "manual edit`n"
    Write-File (Join-Path $review "scenes/new_room.tscn") "[gd_scene format=3]`n"
    $code = Open-Branch @('task/1-feature')
    Check ($code -ne 0) "manual changes stop the switch without -Force"
    Check ($script:lastOutput.Contains('notes.txt') -and $script:lastOutput.Contains('new_room.tscn')) "manual changes are listed"
    Check ((Get-Content -Raw (Join-Path $review "notes.txt")) -eq "manual edit`n") "manual edit survives the refused switch"
    $code = Open-Branch @('task/1-feature', '-Force')
    Check ($code -eq 0) "-Force switches anyway"
    Check ((Get-Content -Raw (Join-Path $review "notes.txt")) -eq "feature`n") "-Force resets the manual edit"

    # 4. Ветка, которой нет локально, по ссылке caretaker:// с закодированным слэшем.
    $code = Open-Branch @('-Uri', 'caretaker://open/task%2F2-late')
    Check ($code -eq 0) "caretaker:// link opens a branch that is not local"
    Check ((Get-Content -Raw (Join-Path $review "notes.txt")) -eq "late`n") "review shows origin/task/2-late"

    # 4b. Без аргументов — список веток origin по дате; выбор номером или именем.
    $code = Open-Branch @() 'task/1-feature'
    Check ($code -eq 0) "no argument: branch is picked from the list"
    Check ($script:lastOutput.Contains('task/2-late') -and $script:lastOutput.Contains('task/1-feature')) "the list shows origin branches"
    Check ((Get-Content -Raw (Join-Path $review "notes.txt")) -eq "feature`n") "the branch typed at the list prompt is opened"

    # 5. Ссылка не может передать ничего, кроме имени ветки.
    $headBefore = G $review rev-parse HEAD
    foreach ($bad in @('caretaker://open/x;calc', 'caretaker://open/x%26calc', 'caretaker://open/x%22%20-Force',
            'caretaker://open/--upload-pack=touch', 'caretaker://open/a/../b', 'caretaker://open/$(calc)',
            'file:///etc/passwd', 'caretaker://open/', 'caretaker://open/x%0Acalc')) {
        $code = Open-Branch @('-Uri', $bad)
        Check ($code -ne 0) "rejects $bad"
    }
    Check ((G $review rev-parse HEAD) -eq $headBefore) "rejected links do not touch the review copy"

    # 6. Основной клон не изменился.
    $after = Get-MainState
    Check ($after.Head -eq $before.Head) "main clone HEAD is unchanged"
    Check ($after.Branch -eq $before.Branch) "main clone branch is unchanged"
    Check ($after.Status -eq $before.Status) "main clone status (uncommitted work) is unchanged"
    Check ($after.File -eq $before.File) "main clone uncommitted file content is unchanged"
    Check (@(Get-ChildItem -LiteralPath $base -Force | Where-Object { $_.Name -ne 'origin.git' -and $_.Name -ne 'seed' }).Count -eq 2) "nothing is created next to the clone except the review copy"

    # 7. caretaker://inkscape/<путь>: только существующий .svg внутри основного клона (#222).
    $plan = Join-Path $main "plans/lower/l_core.svg"
    $code = Open-Inkscape 'caretaker://inkscape/plans/lower/l_core.svg'
    Check ($code -eq 0 -and $script:lastOutput.Contains($plan)) "inkscape link resolves a plan inside the main clone"
    $code = Open-Inkscape 'caretaker://inkscape/plans/%D0%BC%D0%BE%D0%B9%20%D0%BF%D0%BB%D0%B0%D0%BD.svg'
    Check ($code -eq 0 -and $script:lastOutput.Contains((Join-Path $main "plans/мой план.svg"))) "inkscape link with percent-encoded Cyrillic and a space"
    $code = Open-Inkscape 'CARETAKER://inkscape/plans%2Flower%2Fl_core.svg'
    Check ($code -eq 0 -and $script:lastOutput.Contains($plan)) "inkscape link: scheme case and encoded slashes"
    Write-File (Join-Path $base "outside.svg") "<svg/>"
    Write-File (Join-Path $main "notes.svg.txt") "not svg"
    $linked = $false
    try { New-Item -ItemType SymbolicLink -Path (Join-Path $main "link") -Target $base -ErrorAction Stop | Out-Null; $linked = $true } catch { $linked = $false }
    $bad = @('caretaker://inkscape/notes.txt', 'caretaker://inkscape/notes.svg.txt', 'caretaker://inkscape/../outside.svg',
        'caretaker://inkscape/plans/%2E%2E/%2E%2E/outside.svg', 'caretaker://inkscape//etc/outside.svg',
        'caretaker://inkscape/C:%5Coutside.svg', 'caretaker://inkscape/plans%5C..%5C..%5Coutside.svg',
        'caretaker://inkscape/plans/missing.svg', 'caretaker://inkscape/', 'caretaker://inkscape/plans/l_core.svg%00.txt',
        'caretaker://inkscape/-x.svg', 'caretaker://inkscape/plans/lower/l_core.svg%22%20-Force', 'caretaker://inkscape/.git/x.svg/..')
    if ($linked) { $bad += 'caretaker://inkscape/link/outside.svg' }
    foreach ($uri in $bad) {
        $code = Open-Inkscape $uri
        Check ($code -ne 0) "inkscape rejects $uri"
    }
    if ($linked) { Remove-Item -LiteralPath (Join-Path $main "link") -Force }
    Remove-Item -LiteralPath (Join-Path $main "notes.svg.txt") -Force

    # 8. Запуск Inkscape: путь доходит до программы одним аргументом (апостроф, кириллица, пробел).
    if (-not $onWindows) {
        $argsFile = Join-Path $root "inkscape-args.txt"
        if (Test-Path $argsFile) { Remove-Item -LiteralPath $argsFile -Force }
        $env:INKSCAPE_BIN = $fakeInkscape
        $env:INKSCAPE_TEST_OUT = $argsFile
        try {
            $code = Open-Inkscape 'caretaker://inkscape/plans/%D0%BC%D0%BE%D0%B9%20%D0%BF%D0%BB%D0%B0%D0%BD.svg' -Launch $true
        } finally {
            Remove-Item Env:INKSCAPE_BIN, Env:INKSCAPE_TEST_OUT -ErrorAction SilentlyContinue
        }
        for ($i = 0; $i -lt 50 -and -not (Test-Path $argsFile); $i++) { Start-Sleep -Milliseconds 100 }
        $received = @()
        if (Test-Path $argsFile) { $received = @([IO.File]::ReadAllLines($argsFile)) }
        Check ($code -eq 0 -and $received.Count -eq 1 -and $received[0] -eq (Join-Path $main "plans/мой план.svg")) "Inkscape gets the plan path as one argument"
        $env:INKSCAPE_BIN = Join-Path $root "missing-inkscape"
        try { $code = Open-Inkscape 'caretaker://inkscape/plans/lower/l_core.svg' -Launch $true } finally { Remove-Item Env:INKSCAPE_BIN }
        Check ($code -ne 0 -and $script:lastOutput.Contains('INKSCAPE_BIN')) "missing INKSCAPE_BIN is reported"
    }
    Check ((Get-MainState).Status -eq $before.Status) "inkscape links do not change the main clone"
}

# Обёртка: запускает open_branch.ps1 с консольной кодировкой cp866 (OEM русской Windows).
$wrapper = Join-Path $root "cp866_wrapper.ps1"
# Подмена Inkscape: записывает полученные аргументы построчно в $INKSCAPE_TEST_OUT.
$fakeInkscape = Join-Path $root "fake-inkscape.sh"
$onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Test-Path variable:IsWindows) -and $IsWindows)

try {
    New-Item -ItemType Directory -Path $root | Out-Null
    [IO.File]::WriteAllText($wrapper, @'
[Text.Encoding]::RegisterProvider([Text.CodePagesEncodingProvider]::Instance)
[Console]::OutputEncoding = [Text.Encoding]::GetEncoding(866)
$target = $args[0]
$rest = @($args | Select-Object -Skip 1)
& $target @rest
exit $LASTEXITCODE
'@)
    if (-not $onWindows) {
        [IO.File]::WriteAllText($fakeInkscape, "#!/bin/sh`nprintf '%s\n' `"`$@`" > `"`$INKSCAPE_TEST_OUT`"`n")
        & chmod +x $fakeInkscape
    }
    Invoke-Scenario "" "ascii" "caretaker" $false
    Invoke-Scenario "[кириллица и апостроф cp866] " "Документы/Godot" "dima's-first-game" $true
    Invoke-Scenario "[кириллица и пробел cp866] " "Проверка кириллицы/Мои проекты" "клон игры" $true
} catch {
    $script:failures++
    Write-Host "FAIL  exception: $($_.Exception.Message)"
    Write-Host $script:lastOutput
} finally {
    if (Test-Path $root) { Remove-Item -Recurse -Force $root }
}

Write-Host "OPEN_BRANCH_TEST checks=$($script:checks) failures=$($script:failures)"
if ($script:failures -gt 0) { exit 1 }
