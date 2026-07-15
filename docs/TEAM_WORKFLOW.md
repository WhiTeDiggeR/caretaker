# AI and human team workflow

## Repository-specific decisions

The repository already uses `main`, so it remains the stable branch. Renaming it to `master` would add migration work without improving the workflow. The existing `codex/underground-complex` work is the starting point for `team/integration`.

This Godot project has large text scenes and binary art assets. Parallel work is therefore organized around file ownership, not only around feature ownership. The startup scene `scenes/underground_research_complex.tscn` is a coordination hotspot: only one task may edit it at a time.

## Task intake

Describe the desired result to the Codex dispatcher. Codex turns it into one or more GitHub Issues using the task or bug form. An issue is ready only when it contains:

- outcome and user-visible behavior;
- acceptance criteria;
- verification steps;
- dependencies;
- likely files or scene areas;
- preferred executor or `Dispatcher decides`.

The issue, not a private chat, is the durable source of truth. Decisions made in chat must be copied to the issue.

## States and labels

- `status:triage` — incomplete or awaiting decomposition.
- `status:ready` — actionable with acceptance criteria.
- `status:in-progress` — owned and being implemented.
- `status:blocked` — cannot progress; the latest comment names the blocker.
- `status:verification` — implementation is complete and checks are running.
- `status:done` — delivered to `team/integration` and verified.
- `agent:codex`, `agent:copilot`, `agent:human`, `agent:any` — preferred executor.
- `area:gameplay`, `area:scene`, `area:art`, `area:audio`, `area:tooling` — coordination area.

## Implementation loop

1. Start from the latest `team/integration` in an isolated worktree or task branch.
2. Claim the task and any shared scene in the issue.
3. Make the smallest complete change and commit with the issue number.
4. Sync with `team/integration`, resolve conflicts while context is fresh, and run verification.
5. Deliver to `team/integration` and post the commit plus verification evidence to the issue.
6. Another agent may immediately build on that integrated commit.

Codex and local human contributors may push verified commits directly to `team/integration`. Copilot cloud agent cannot deliver without a PR; its narrowly scoped PR targets `team/integration` and is merged after CI/conflict checks without a separate release-review ceremony.

## Release

When an increment is playable and CI is green, open one PR from `team/integration` to `main`. A human reviews gameplay impact, scene churn, asset provenance, and test evidence. Agents may review and suggest changes, but cannot approve the final release or merge it to `main`.

## Moving to another repository

Copy the reusable files (`AGENTS.md`, `.github/`, `.ai-team/project.yml`, and `tools/bootstrap_ai_team.ps1`), then edit only `.ai-team/project.yml` and the project-specific sections of `AGENTS.md`. Run the bootstrap script after installing and authenticating GitHub CLI.
