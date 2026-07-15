[CmdletBinding()]
param(
    [string]$Repository = "",
    [switch]$PushIntegrationBranch
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is required. Install it and run 'gh auth login'."
}

gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run 'gh auth login'."
}

$repoArgs = @()
if ($Repository) {
    $repoArgs = @("--repo", $Repository)
}

$labels = @(
    @{ Name = "status:triage"; Color = "d4c5f9"; Description = "Needs clarification or decomposition" },
    @{ Name = "status:ready"; Color = "0e8a16"; Description = "Ready for an executor" },
    @{ Name = "status:in-progress"; Color = "fbca04"; Description = "Work is actively owned" },
    @{ Name = "status:blocked"; Color = "b60205"; Description = "Progress requires an external decision or dependency" },
    @{ Name = "status:verification"; Color = "1d76db"; Description = "Implementation complete; checks are running" },
    @{ Name = "status:done"; Color = "006b75"; Description = "Integrated and verified" },
    @{ Name = "agent:codex"; Color = "5319e7"; Description = "Preferred executor is Codex" },
    @{ Name = "agent:copilot"; Color = "0969da"; Description = "Preferred executor is GitHub Copilot" },
    @{ Name = "agent:human"; Color = "c2e0c6"; Description = "Requires a human executor" },
    @{ Name = "agent:any"; Color = "ededed"; Description = "Dispatcher may select any executor" },
    @{ Name = "area:gameplay"; Color = "f9d0c4"; Description = "Gameplay code or interaction" },
    @{ Name = "area:scene"; Color = "fef2c0"; Description = "Scene composition or node hierarchy" },
    @{ Name = "area:art"; Color = "c5def5"; Description = "Models, textures, materials, or visual direction" },
    @{ Name = "area:audio"; Color = "bfdadc"; Description = "Music, ambience, or sound effects" },
    @{ Name = "area:tooling"; Color = "d4c5f9"; Description = "CI, import, repository, or developer tooling" }
)

foreach ($label in $labels) {
    $arguments = @(
        "label", "create", $label.Name,
        "--color", $label.Color,
        "--description", $label.Description,
        "--force"
    ) + $repoArgs
    & gh @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create or update label '$($label.Name)'."
    }
}

if ($PushIntegrationBranch) {
    git show-ref --verify --quiet refs/heads/team/integration
    if ($LASTEXITCODE -ne 0) {
        git branch team/integration
    }
    git push --set-upstream origin team/integration
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to push team/integration."
    }
}

Write-Host "AI team labels are configured."
Write-Host "Next: protect main, require 'Godot validation', require a CODEOWNER review, and enable Copilot coding agent."
