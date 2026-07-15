# Caretaker

A Godot 4.7 3D game set in an underground research complex. The current playable scene combines first-person movement, facility interactions, environmental storytelling, lighting, ambience, and containment progression.

## Open the project

1. Install Godot 4.7 stable.
2. Import `project.godot` in the editor.
3. Run the project; the startup scene is `scenes/underground_research_complex.tscn`.

Controls: `WASD` to move, `Shift` to sprint, `Space` to jump, `E` to interact, and `Esc` to close facility messages.

## Validate from the command line

```sh
godot --headless --editor --path . --quit
godot --headless --path . --quit-after 5
```

Godot is not currently discoverable through `PATH` on every contributor machine. Use the full executable path when necessary.

## Team development

GitHub Issues are the single task backlog. Active work integrates into `team/integration`; `main` stays stable and only receives reviewed release PRs. Read [the team workflow](docs/TEAM_WORKFLOW.md) and [the agent guide](AGENTS.md) before making changes.

### Local AI-agent handoff workflow

When a GitHub Issue is labeled `agent:codex` or `agent:copilot`, the assigned agent works in an isolated task branch or worktree based on `team/integration`. The coordinating agent or human reviews the diff and verification results before delivery to `team/integration`. The GitHub Issue remains the source of requirements and coordination point for all work. See [AGENTS.md](AGENTS.md) and [the team workflow](docs/TEAM_WORKFLOW.md) for full implementation details, branch strategy, and verification procedures.
