# Caretaker repository instructions

- Read and follow the root `AGENTS.md` and `docs/TEAM_WORKFLOW.md` before planning or editing.
- This is a Godot 4.7 stable GDScript project; the main scene is `res://scenes/underground_research_complex.tscn`.
- Work only from a GitHub Issue with acceptance criteria and verification steps.
- Target delivery PRs to `team/integration`, never directly to `main`.
- Keep delivery PRs small and reference the issue with `Refs #<number>`; do not use `Fixes` until the change is merged into `main`.
- Do not edit a shared `.tscn`, `.tres`, `project.godot`, or binary asset unless the issue explicitly assigns that file or scene area to you.
- Preserve unrelated changes and Russian UTF-8 text.
- Report exact verification commands and results; if Godot cannot run, state that limitation.
