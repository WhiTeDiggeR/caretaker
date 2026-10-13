# Caretaker

A Godot 4.7 3D game set in an underground research complex. The current playable scene combines first-person movement, facility interactions, environmental storytelling, lighting, ambience, and containment progression.

## Open the project

1. Install Godot 4.7 stable.
2. Import `project.godot` in the editor.
3. Run the project: it opens the main menu (`scenes/shell/main_menu.tscn`); «Новая игра» loads the complex `scenes/underground_research_complex.tscn`. To open the complex directly, run that scene (F6) in the editor.

Controls: `WASD` to move, `Shift` to sprint, `Space` to jump, `E` to interact, and `Esc` to close facility messages.

## Validate from the command line

```sh
godot --headless --editor --path . --quit
godot --headless --path . --quit-after 5                                                  # main menu
godot --headless --path . res://scenes/underground_research_complex.tscn --quit-after 5  # complex
```

Godot is not currently discoverable through `PATH` on every contributor machine. Use the full executable path when necessary.

## Build the game

Export presets live in `export_presets.cfg` (`Windows Desktop` x86_64 and `Linux`). With the Godot 4.7 stable export templates installed:

```sh
bash tools/build/export_windows.sh      # build/windows/caretaker.exe + caretaker.pck
bash tools/build/export.sh linux        # build/linux/caretaker.x86_64 + caretaker.pck
```

`build/` is ignored by git. Running the scripts on Windows, installing the templates and the smoke test are described in [tools/build/README.md](tools/build/README.md). The `Build` workflow (`.github/workflows/build.yml`) does the same on every push to `team/integration` or on a manual run and uploads the Windows build as a workflow artifact; there are no releases or deployments.

The game version is `application/config/version` in `project.godot`; exported builds add the short commit hash (for example `0.1.0 · 1a2b3c4`, `dev` when running from the editor). It is shown in the bottom-left corner of the main menu and written to the log at startup.

## Logs and saves

File logging is enabled in every build (`debug/file_logging` in `project.godot`). The engine output, errors and warnings go to `user://logs/godot.log`; the last 10 runs are kept as `godot<date>.log` next to it. Saves are in `user://saves`. `user://` resolves to:

- Windows: `%APPDATA%\Godot\app_userdata\Dima'sFirstGame\`
- Linux: `~/.local/share/godot/app_userdata/Dima'sFirstGame/`

Attach `logs/godot.log` to bug reports. The first log line written by the game names the build and the log folder.

## Preview a branch (Windows)

`caretaker://open/<branch>` links (or `powershell -ExecutionPolicy Bypass -File tools\dev\open_branch.ps1 <branch>`) open the latest version of a branch in a separate review worktree next to your clone and start Godot; your own clone is not touched. One-time setup and details: [docs/branch-preview.md](docs/branch-preview.md).

## Team development

GitHub Issues are the single task backlog. Active work integrates into `team/integration`; `main` stays stable and only receives reviewed release PRs. Read [the team workflow](docs/TEAM_WORKFLOW.md) and [the agent guide](AGENTS.md) before making changes.

### Local AI-agent handoff workflow

When a GitHub Issue is labeled `agent:codex` or `agent:copilot`, the assigned agent works in an isolated task branch or worktree based on `team/integration`. The coordinating agent or human reviews the diff and verification results before delivery to `team/integration`. The GitHub Issue remains the source of requirements and coordination point for all work. See [AGENTS.md](AGENTS.md) and [the team workflow](docs/TEAM_WORKFLOW.md) for full implementation details, branch strategy, and verification procedures.
