#!/usr/bin/env bash
set -euo pipefail

readonly READY_LABEL="status:ready"
readonly IN_PROGRESS_LABEL="status:in-progress"
readonly BLOCKED_LABEL="status:blocked"
readonly VERIFICATION_LABEL="status:verification"
readonly COPILOT_LABEL="agent:copilot"

repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
base_branch="${BASE_BRANCH:-team/integration}"

issue_has_label() {
  local issue_number="$1"
  local expected_label="$2"

  gh issue view "$issue_number" --repo "$repo" --json labels \
    --jq ".labels | any(.name == \"${expected_label}\")"
}

select_task() {
  if [[ "${EVENT_NAME:-}" != "workflow_dispatch" && "${COPILOT_DISPATCH_ENABLED:-false}" != "true" ]]; then
    echo "Automatic dispatch is disabled. Set COPILOT_DISPATCH_ENABLED=true after the manual pilot."
    echo "issue_number=" >> "$GITHUB_OUTPUT"
    return 0
  fi

  local issue_number="${REQUESTED_ISSUE:-}"
  if [[ -n "$issue_number" ]]; then
    if [[ ! "$issue_number" =~ ^[0-9]+$ ]]; then
      echo "Requested issue number must be numeric." >&2
      return 1
    fi
    if [[ "$(gh issue view "$issue_number" --repo "$repo" --json state --jq .state)" != "OPEN" ]]; then
      echo "Requested issue #${issue_number} is not open." >&2
      return 1
    fi
    if [[ "$(issue_has_label "$issue_number" "$READY_LABEL")" != "true" || \
          "$(issue_has_label "$issue_number" "$COPILOT_LABEL")" != "true" ]]; then
      echo "Requested issue #${issue_number} is not ready for Copilot." >&2
      return 1
    fi
  else
    issue_number="$(
      gh issue list --repo "$repo" --state open \
        --label "$READY_LABEL" --label "$COPILOT_LABEL" \
        --limit 100 --json number,createdAt \
        --jq 'sort_by(.createdAt) | .[0].number // empty'
    )"
  fi

  if [[ -z "$issue_number" ]]; then
    echo "No ready Copilot tasks found. Copilot CLI will not be installed or invoked."
    echo "issue_number=" >> "$GITHUB_OUTPUT"
    return 0
  fi

  local existing_pr
  existing_pr="$(
    gh pr list --repo "$repo" --state open \
      --search "Refs #${issue_number} in:body" --json number \
      --jq '.[0].number // empty'
  )"
  if [[ -n "$existing_pr" ]]; then
    echo "Issue #${issue_number} already has open PR #${existing_pr}; skipping."
    echo "issue_number=" >> "$GITHUB_OUTPUT"
    return 0
  fi

  echo "Selected issue #${issue_number}."
  echo "issue_number=${issue_number}" >> "$GITHUB_OUTPUT"
}

claim_task() {
  local issue_number="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
  local branch="task/${issue_number}-copilot"

  # Re-check immediately before the mutation so concurrent or manual claims win safely.
  if [[ "$(issue_has_label "$issue_number" "$READY_LABEL")" != "true" || \
        "$(issue_has_label "$issue_number" "$COPILOT_LABEL")" != "true" ]]; then
    echo "Issue #${issue_number} changed state before claim; stopping." >&2
    return 1
  fi

  if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    echo "Remote branch ${branch} already exists." >&2
    return 1
  fi

  gh issue edit "$issue_number" --repo "$repo" \
    --remove-label "$READY_LABEL" --add-label "$IN_PROGRESS_LABEL"
  echo "claimed=true" >> "$GITHUB_OUTPUT"
  gh issue comment "$issue_number" --repo "$repo" --body \
    "Copilot CLI взял задачу в работу. Запуск: ${RUN_URL}"

  git switch -c "$branch" "origin/${base_branch}"
}

run_copilot() {
  local issue_number="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
  local issue_title issue_body prompt_file
  issue_title="$(gh issue view "$issue_number" --repo "$repo" --json title --jq .title)"
  issue_body="$(gh issue view "$issue_number" --repo "$repo" --json body --jq .body)"
  prompt_file="${RUNNER_TEMP:?RUNNER_TEMP is required}/copilot-task.md"

  cat > "$prompt_file" <<EOF
Implement GitHub Issue #${issue_number}: ${issue_title}

Read and follow AGENTS.md, docs/TEAM_WORKFLOW.md, .github/copilot-instructions.md,
and any applicable .github/instructions files before editing.

You are already on a dedicated task branch based on ${base_branch}.
Make only the smallest complete code change required by the issue.
Do not commit, push, create or edit GitHub issues or pull requests, merge branches,
or modify main. The surrounding workflow owns all GitHub mutations.
Do not modify files under .github/workflows. GitHub blocks the workflow token from
publishing workflow-file changes; those tasks require a human or Codex executor.
Do not edit files or scene areas that the issue does not assign.
Preserve Russian UTF-8 text and unrelated content.
Run useful local checks, but the workflow will repeat the required verification.

Issue body:
${issue_body}
EOF

  copilot -p "$(cat "$prompt_file")" \
    --no-ask-user \
    --disable-builtin-mcps \
    --max-ai-credits "${COPILOT_MAX_AI_CREDITS:-50}" \
    --available-tools='bash,edit,create,apply_patch,view,grep,glob' \
    --allow-tool=read \
    --allow-tool=write \
    --allow-tool='shell(git status),shell(git status:*),shell(git diff:*),shell(git log:*)' \
    --allow-tool='shell(rg:*),shell(find:*),shell(ls:*)' \
    --allow-tool="shell(${GODOT_BINARY}:*)" \
    --deny-tool='shell(git commit),shell(git push),shell(git reset:*),shell(git checkout:*),shell(git switch:*)' \
    --deny-tool='shell(gh:*),shell(rm:*)'
}

deliver_task() {
  local issue_number="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
  local branch="task/${issue_number}-copilot"
  local issue_title pr_url
  issue_title="$(gh issue view "$issue_number" --repo "$repo" --json title --jq .title)"

  if [[ -z "$(git status --porcelain)" ]]; then
    echo "Copilot completed without producing changes." >&2
    return 1
  fi

  local workflow_changes
  workflow_changes="$(git status --porcelain -- .github/workflows)"
  if [[ -n "$workflow_changes" ]]; then
    echo "Copilot tasks cannot modify protected workflow files:" >&2
    echo "$workflow_changes" >&2
    gh issue comment "$issue_number" --repo "$repo" --body \
      "Copilot CLI изменил защищённые файлы в .github/workflows. Изменения не опубликованы; такую задачу должен выполнить Codex или человек."
    return 1
  fi

  git diff --check
  "${GODOT_BINARY}" --headless --editor --path . --quit
  "${GODOT_BINARY}" --headless --path . --quit-after 5

  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git add --all
  git commit -m "#${issue_number} Implement Copilot task"
  git push origin "HEAD:${branch}"

  pr_url="$(
    gh pr create --repo "$repo" --draft \
      --base "$base_branch" --head "$branch" \
      --title "${issue_title}" \
      --body "Refs #${issue_number}

Automated Copilot CLI delivery.

Verification completed before push:
- ${GODOT_BINARY} --headless --editor --path . --quit
- ${GODOT_BINARY} --headless --path . --quit-after 5
- git diff --check"
  )"

  gh issue edit "$issue_number" --repo "$repo" \
    --remove-label "$IN_PROGRESS_LABEL" --add-label "$VERIFICATION_LABEL"
  gh issue comment "$issue_number" --repo "$repo" --body \
    "Copilot CLI подготовил draft PR: ${pr_url}"
}

fail_task() {
  local issue_number="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"

  gh issue edit "$issue_number" --repo "$repo" \
    --remove-label "$IN_PROGRESS_LABEL" --add-label "$BLOCKED_LABEL" || true
  gh issue comment "$issue_number" --repo "$repo" --body \
    "Автоматический запуск завершился ошибкой и остановлен без слияния. Логи: ${RUN_URL}" || true
}

case "${1:-}" in
  select) select_task ;;
  claim) claim_task ;;
  run) run_copilot ;;
  deliver) deliver_task ;;
  fail) fail_task ;;
  *)
    echo "Usage: $0 {select|claim|run|deliver|fail}" >&2
    exit 2
    ;;
esac
