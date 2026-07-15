## Purpose

Refs #

Describe the player-visible or team-visible result.

## Target

- [ ] Delivery PR to `team/integration` (Copilot cloud transport or conflict-isolated contribution)
- [ ] Release PR from `team/integration` to `main`

## Verification

- [ ] `godot --headless --editor --path . --quit`
- [ ] `godot --headless --path . --quit-after 5`
- [ ] Affected scene tested manually when applicable
- [ ] `git diff --check`

Commands, results, and manual scenario:

## Coordination and risk

- [ ] Shared scene/file ownership was recorded in the issue
- [ ] No unrelated scene/resource churn
- [ ] No unapproved binary assets or unknown licenses

Known limitations or follow-up work:
