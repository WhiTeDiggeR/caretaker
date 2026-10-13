<#
  Проверка git-логики tools/dev/open_branch.ps1 на временном репозитории (issue #175).
  Запуск: pwsh -NoProfile -File tools/dev/tests/open_branch_test.ps1
  Godot не запускается (-NoGodot); проверяются копия просмотра, сохранение .godot/, защита ручных
  правок, валидация имени ветки и то, что основной клон не меняется.
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

function Check([bool]$Condition, [string]$Message) {
    $script:checks++
    if ($Condition) { Write-Host "PASS  $Message" } else {
        $script:failures++
        Write-Host "FAIL  $Message"
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
    $all = @('-NoProfile', '-File', $script, '-Repo', $main, '-NoGodot') + $Arguments
    $output = $InputText | & $pwshBin @all 2>&1
    $script:lastOutput = ($output | Out-String)
    return $LASTEXITCODE
}

function Get-MainState {
    return @{
        Head = (G $main rev-parse HEAD)
        Branch = (G $main symbolic-ref --short HEAD)
        Status = ((G $main status --porcelain=v1 --untracked-files=all) -join "`n")
        File = (Get-Content -Raw (Join-Path $main "notes.txt"))
    }
}

try {
    New-Item -ItemType Directory -Path $root | Out-Null
    $origin = Join-Path $root "origin.git"
    $seed = Join-Path $root "seed"
    $main = Join-Path $root "caretaker"
    $review = "$main-review"

    & git init --quiet --bare $origin
    & git init --quiet $seed
    G $seed checkout --quiet -b team/integration | Out-Null
    Write-File (Join-Path $seed ".gitignore") "/build/`n.godot/`n"
    Write-File (Join-Path $seed "project.godot") "config_version=5`n"
    Write-File (Join-Path $seed "notes.txt") "integration`n"
    Write-File (Join-Path $seed "scenes/room.tscn") "[gd_scene load_steps=2 format=3 uid=`"uid://aaa`"]`n`n[node name=`"Room`" type=`"Node3D`" unique_id=1]`n"
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
    Write-File (Join-Path $review "scenes/room.tscn") "[gd_scene load_steps=3 format=3 uid=`"uid://ccc`"]`n[node name=`"Room`" type=`"Node3D`" unique_id=77]`n"
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
} catch {
    $script:failures++
    Write-Host "FAIL  exception: $($_.Exception.Message)"
    Write-Host $script:lastOutput
} finally {
    if (Test-Path $root) { Remove-Item -Recurse -Force $root }
}

Write-Host "OPEN_BRANCH_TEST checks=$($script:checks) failures=$($script:failures)"
if ($script:failures -gt 0) { exit 1 }
