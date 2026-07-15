# Repository agent guide

## Project

- This is a Godot 4.7 stable 3D game written in GDScript.
- The renderer is Forward Plus and 3D physics uses Jolt Physics.
- The startup scene is `res://scenes/underground_research_complex.tscn`.
- Gameplay scripts and composed scenes live in `scenes/`.
- Reusable props and interactions live in `objects/`.
- Materials and shaders live in `materials/`; imported source assets live in `loads/`.
- Player-facing text is Russian. Preserve UTF-8 and do not replace Russian text with transliteration.

## Source of truth

- GitHub Issues are the task source of truth. Do not begin untracked feature work.
- Every task must state the outcome, acceptance criteria, verification, and files or scene areas likely to change.
- Use the labels and states described in `docs/TEAM_WORKFLOW.md`.
- If requirements are ambiguous, comment on the issue and stop before making a broad product or art-direction decision.

## Branches and delivery

- `main` is the stable branch in this repository. Do not push directly to it.
- `team/integration` is the shared integration branch and the base for all active work.
- Work in an isolated worktree or `task/<issue-number>-<slug>` branch based on the latest `team/integration`.
- Sync from `team/integration` before editing a shared scene and again before delivery.
- Deliver small, coherent commits to `team/integration`; include the issue number in commit messages.
- A release PR from `team/integration` to `main` is the only PR that requires full human review.
- GitHub Copilot cloud agent delivers through a PR by design. Its PR must target `team/integration`, remain narrowly scoped, and is treated as a delivery transport rather than a release PR. Merge it promptly after CI and conflict checks.
- Agents must never merge to `main`, deploy a build, rewrite history, force-push, or discard another contributor's changes.

## Coordination rules

- One agent owns a file or scene area at a time. Record the ownership in the issue before editing `.tscn`, `.tres`, `project.godot`, or a shared script.
- Avoid parallel edits to `scenes/underground_research_complex.tscn`; it is the current integration hotspot.
- Read the latest issue comments and `git status` before changing files.
- Preserve unrelated dirty-worktree changes. Never reset, restore, or reformat files outside the task.
- Prefer reusable sub-scenes and scripts over adding more inline resources to the large startup scene.
- Do not hand-edit `.uid` or `.import` files. Let Godot generate metadata when source assets change.
- Do not add or replace large binary assets unless the issue explicitly authorizes it and records licensing/provenance.

## GDScript and scene conventions

- Use typed parameters, return types, node references, and state where practical.
- Prefix private helpers and state with `_`.
- Keep node paths stable. When renaming or moving a node, update every scene/script reference in the same task.
- Prefer signals and explicit methods over per-frame tree searches. Cache stable node/group lookups in `_ready()`.
- Prefix intentionally unused parameters with `_`.
- Keep gameplay constants named and centralized near the top of a script.
- Do not mix broad scene beautification with gameplay logic in one task.

## Verification

Run the strongest available checks before delivery:

1. `godot --headless --editor --path . --quit`
2. `godot --headless --path . --quit-after 5`
3. Open and exercise the affected scene in Godot 4.7 when the change is visual, interactive, physics-related, or audio-related.
4. Run `git diff --check` and inspect the final diff for accidental scene churn.

If Godot is unavailable, say so explicitly in the issue or delivery summary; do not claim runtime verification.

## Definition of done

- Acceptance criteria are met.
- No unrelated files changed.
- The project imports without script or resource errors.
- The affected scene was smoke-tested when applicable.
- Verification commands and results are recorded.
- Known limitations and follow-up work are added to the issue.
