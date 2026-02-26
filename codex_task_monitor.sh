#!/usr/bin/env bash
#
# codex_task_monitor.sh — minimal scheduler that runs
# `codex --dangerously-bypass-approvals-and-sandbox exec
# "continue to next task"` on a loop, restarting immediately if the codex
# process stays silent for longer than the configured inactivity timeout.
# It can also detect "no-op runs" (command succeeds but repository content
# fingerprint does not change) and stop after repeated no-op streaks.

set -euo pipefail

cmd=(
  codex
  --sandbox danger-full-access
  --dangerously-bypass-approvals-and-sandbox
  exec
  --skip-git-repo-check
  "continue to next task"
)

if [[ -n "${CODEX_MONITOR_CMD:-}" ]]; then
  cmd=(bash -lc "${CODEX_MONITOR_CMD}")
fi

print_current_command() {
  local part
  local quoted=()
  for part in "${cmd[@]}"; do
    quoted+=("$(printf '%q' "$part")")
  done
  echo "[codex-monitor] command: ${quoted[*]}"
}

is_in_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

compute_worktree_fingerprint() {
  local tracked_hash
  local staged_hash
  local untracked_hash

  tracked_hash=$(
    git -c core.quotepath=false diff --no-ext-diff --binary -- . \
      | sha256sum \
      | awk '{print $1}'
  )
  staged_hash=$(
    git -c core.quotepath=false diff --no-ext-diff --cached --binary -- . \
      | sha256sum \
      | awk '{print $1}'
  )
  untracked_hash=$(
    git -c core.quotepath=false ls-files --others --exclude-standard -z \
      | xargs -0 -r sha256sum \
      | sha256sum \
      | awk '{print $1}'
  )

  printf '%s|%s|%s\n' "$tracked_hash" "$staged_hash" "$untracked_hash"
}

terminate_codex_process() {
  local pid=$1
  local grace_seconds=${2:-5}

  if ! kill -TERM "$pid" 2>/dev/null; then
    return 0
  fi

  for (( i = 0; i < grace_seconds; i++ )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done

  kill -KILL "$pid" 2>/dev/null || true
}

# Allow overrides via env vars: CODEX_MONITOR_INACTIVITY_TIMEOUT (seconds)
# CODEX_MONITOR_INTERVAL_SECONDS (pause between completed runs),
# CODEX_MONITOR_REQUIRE_WORKTREE_CHANGE (1/0),
# CODEX_MONITOR_MAX_NO_CHANGE_RUNS (integer >= 1).
inactivity_timeout=${CODEX_MONITOR_INACTIVITY_TIMEOUT:-60}
pause_seconds=${CODEX_MONITOR_INTERVAL_SECONDS:-60}
require_worktree_change=${CODEX_MONITOR_REQUIRE_WORKTREE_CHANGE:-1}
max_no_change_runs=${CODEX_MONITOR_MAX_NO_CHANGE_RUNS:-3}

run_codex_with_watchdog() {
  local inactivity_limit=$1
  local last_output
  last_output=$(date +%s)
  local exit_code=0
  local inactivity_triggered=0
  local line
  local output_dir
  local worktree_check_enabled=0
  local start_fingerprint=""
  local end_fingerprint=""
  output_dir=$(mktemp -d -t codex-monitor-XXXXXX)
  local output_fifo="$output_dir/codex-output"

  if [[ "$require_worktree_change" != "0" ]] && is_in_git_repo; then
    worktree_check_enabled=1
    start_fingerprint=$(compute_worktree_fingerprint)
  fi

  mkfifo "$output_fifo"
  TERM=xterm "${cmd[@]}" >"$output_fifo" 2>&1 &
  local codex_pid=$!

  exec 3<"$output_fifo"
  rm -f "$output_fifo"

  while true; do
    local read_something=0
    if IFS= read -r -t 1 -u 3 line; then
      read_something=1
      last_output=$(date +%s)
      printf '%s\n' "$line"
    fi

    if (( read_something )); then
      continue
    fi

    if ! kill -0 "$codex_pid" 2>/dev/null; then
      # Flush any remaining output before capturing the exit code.
      while IFS= read -r -u 3 line; do
        printf '%s\n' "$line"
      done

      if wait "$codex_pid"; then
        exit_code=0
      else
        exit_code=$?
      fi
      break
    fi

    local now
    now=$(date +%s)
    if (( now - last_output >= inactivity_limit )); then
      echo "[codex-monitor] no output from codex for ${inactivity_limit}s; terminating run..." >&2
      terminate_codex_process "$codex_pid"
      if wait "$codex_pid"; then
        exit_code=0
      else
        exit_code=$?
      fi
      inactivity_triggered=1
      break
    fi
  done

  exec 3<&-
  rm -rf "$output_dir"

  if (( inactivity_triggered )); then
    return 124
  fi

  if [[ $exit_code -ne 0 ]]; then
    return "$exit_code"
  fi

  if (( worktree_check_enabled )); then
    end_fingerprint=$(compute_worktree_fingerprint)
    if [[ "$end_fingerprint" == "$start_fingerprint" ]]; then
      echo "[codex-monitor] command exited 0 but worktree fingerprint is unchanged." >&2
      return 125
    fi
  fi

  return 0
}

no_change_streak=0

while true; do
  echo "[codex-monitor] starting run at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  print_current_command

  if run_codex_with_watchdog "$inactivity_timeout"; then
    no_change_streak=0
    echo "[codex-monitor] codex exec completed successfully (exit 0)."
    echo "[codex-monitor] waiting ${pause_seconds}s before the next run..."
    sleep "$pause_seconds"
    continue
  else
    exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
      echo "[codex-monitor] codex exec produced no output for ${inactivity_timeout}s. Restarting immediately."
      continue
    fi

    if [[ $exit_code -eq 125 ]]; then
      no_change_streak=$((no_change_streak + 1))
      echo "[codex-monitor] no-op run detected (no worktree change)."
      echo "[codex-monitor] no-op streak: ${no_change_streak}/${max_no_change_runs}."
      if (( no_change_streak >= max_no_change_runs )); then
        echo "[codex-monitor] reached max no-op streak; exiting with code 125."
        exit 125
      fi
      continue
    fi

    no_change_streak=0
    echo "[codex-monitor] codex exec exited with errors (exit $exit_code)."
    echo "[codex-monitor] waiting ${pause_seconds}s before the next run..."
    sleep "$pause_seconds"
  fi
done
