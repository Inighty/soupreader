#!/usr/bin/env bash
#
# codex_queue_runner.sh
# 基于任务清单顺序执行 Codex：
# - 每个任务完成后自动进入下一个任务
# - 支持会话续接（codex exec resume --last）
# - 支持 no-op 检测（exit 0 但工作区指纹不变 => 失败）
# - 支持每任务 verify_cmd 验证
#
# 任务文件（TSV）格式：
#   id<TAB>prompt<TAB>verify_cmd<TAB>required_paths_csv
# - 支持注释行（以 # 开头）和空行
# - verify_cmd / required_paths_csv 可留空
# - required_paths_csv 例：lib/features/settings,PLANS.md
#
# 可配置环境变量：
#   CODEX_QUEUE_TASK_FILE                默认 tasks.tsv
#   CODEX_QUEUE_STATE_DIR                默认 .codex-queue-state
#   CODEX_QUEUE_MAX_RETRIES              默认 2
#   CODEX_QUEUE_PAUSE_SECONDS            默认 2
#   CODEX_QUEUE_REQUIRE_CHANGE           默认 1（1=必须有工作区改动）
#   CODEX_QUEUE_USE_RESUME               默认 1（首个任务 fresh，后续 resume --last）
#   CODEX_QUEUE_RESUME_FROM_LAST_AT_START 默认 0（1=首个任务也走 resume --last）
#   CODEX_QUEUE_SKIP_VERIFY              默认 0（1=忽略 verify_cmd）
#   CODEX_QUEUE_STOP_ON_FAILURE          默认 1（失败后立即退出）
#   CODEX_QUEUE_OVERRIDE_CMD             测试用途；若设置则执行此命令替代 codex
#   CODEX_QUEUE_SANDBOX                  默认 danger-full-access
#   CODEX_QUEUE_BYPASS                   默认 1（1=带 --dangerously-bypass-approvals-and-sandbox）
#
# 退出码：
#   0   全部任务成功
#   125 任务 no-op（成功但无改动）
#   126 required_paths 无变化
#   127 verify_cmd 失败
#   其他：codex 命令自身退出码或调度失败码

set -euo pipefail

task_file="${CODEX_QUEUE_TASK_FILE:-tasks.tsv}"
state_dir="${CODEX_QUEUE_STATE_DIR:-.codex-queue-state}"
max_retries="${CODEX_QUEUE_MAX_RETRIES:-2}"
pause_seconds="${CODEX_QUEUE_PAUSE_SECONDS:-2}"
require_change="${CODEX_QUEUE_REQUIRE_CHANGE:-1}"
use_resume="${CODEX_QUEUE_USE_RESUME:-1}"
resume_from_last_at_start="${CODEX_QUEUE_RESUME_FROM_LAST_AT_START:-0}"
skip_verify="${CODEX_QUEUE_SKIP_VERIFY:-0}"
stop_on_failure="${CODEX_QUEUE_STOP_ON_FAILURE:-1}"
override_cmd="${CODEX_QUEUE_OVERRIDE_CMD:-}"
sandbox_mode="${CODEX_QUEUE_SANDBOX:-danger-full-access}"
bypass_approval="${CODEX_QUEUE_BYPASS:-1}"

done_file="$state_dir/done.tsv"
failed_file="$state_dir/failed.tsv"
logs_dir="$state_dir/logs"

mkdir -p "$state_dir" "$logs_dir"
touch "$done_file" "$failed_file"

if [[ ! -f "$task_file" ]]; then
  cat >&2 <<EOF
[codex-queue] 任务文件不存在: $task_file
[codex-queue] 请创建 TSV 文件，格式：
  id<TAB>prompt<TAB>verify_cmd<TAB>required_paths_csv
EOF
  exit 2
fi

if ! [[ "$max_retries" =~ ^[0-9]+$ ]] || (( max_retries < 1 )); then
  echo "[codex-queue] CODEX_QUEUE_MAX_RETRIES 必须是 >=1 的整数" >&2
  exit 2
fi

if ! [[ "$pause_seconds" =~ ^[0-9]+$ ]]; then
  echo "[codex-queue] CODEX_QUEUE_PAUSE_SECONDS 必须是 >=0 的整数" >&2
  exit 2
fi

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

hash_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return
  fi
  cksum | awk '{print $1}'
}

is_in_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

compute_git_fingerprint() {
  local -a specs=("$@")
  if (( ${#specs[@]} == 0 )); then
    specs=(.)
  fi

  local tracked_hash
  local staged_hash
  local untracked_hash

  tracked_hash=$(
    git -c core.quotepath=false diff --no-ext-diff --binary -- "${specs[@]}" \
      | hash_stream
  )
  staged_hash=$(
    git -c core.quotepath=false diff --no-ext-diff --cached --binary -- "${specs[@]}" \
      | hash_stream
  )
  untracked_hash=$(
    git -c core.quotepath=false ls-files --others --exclude-standard -z -- "${specs[@]}" \
      | xargs -0 -r sha256sum \
      | sort \
      | hash_stream
  )

  printf '%s|%s|%s\n' "$tracked_hash" "$staged_hash" "$untracked_hash"
}

csv_to_array() {
  local csv="$1"
  local -n out_ref=$2
  out_ref=()
  if [[ -z "$csv" ]]; then
    return
  fi
  local raw
  IFS=',' read -r -a raw <<< "$csv"
  local item
  for item in "${raw[@]}"; do
    item="$(trim "$item")"
    if [[ -n "$item" ]]; then
      out_ref+=("$item")
    fi
  done
}

print_cmd() {
  local -a arr=("$@")
  local q=()
  local p
  for p in "${arr[@]}"; do
    q+=("$(printf '%q' "$p")")
  done
  printf '%s\n' "${q[*]}"
}

run_cmd_with_log() {
  local log_file="$1"
  shift
  local -a cmd_arr=("$@")

  echo "[codex-queue] command: $(print_cmd "${cmd_arr[@]}")"
  set +e
  "${cmd_arr[@]}" 2>&1 | tee "$log_file"
  local rc=${PIPESTATUS[0]}
  set -e
  return "$rc"
}

build_codex_exec_cmd() {
  local prompt="$1"
  local -a cmd=(codex --sandbox "$sandbox_mode")
  if [[ "$bypass_approval" == "1" ]]; then
    cmd+=(--dangerously-bypass-approvals-and-sandbox)
  fi
  cmd+=(exec --skip-git-repo-check "$prompt")
  printf '%s\0' "${cmd[@]}"
}

build_codex_resume_cmd() {
  local prompt="$1"
  local -a cmd=(codex --sandbox "$sandbox_mode")
  if [[ "$bypass_approval" == "1" ]]; then
    cmd+=(--dangerously-bypass-approvals-and-sandbox)
  fi
  cmd+=(exec resume --last --skip-git-repo-check "$prompt")
  printf '%s\0' "${cmd[@]}"
}

declare -A completed=()
while IFS=$'\t' read -r done_id _rest; do
  done_id="$(trim "${done_id:-}")"
  if [[ -n "$done_id" ]]; then
    completed["$done_id"]=1
  fi
done < "$done_file"

session_started=0
if [[ "$resume_from_last_at_start" == "1" ]]; then
  session_started=1
fi

total_tasks=0
skipped_done=0
success_count=0
failed_count=0

while IFS=$'\t' read -r task_id task_prompt verify_cmd required_paths extra; do
  task_id="$(trim "${task_id:-}")"
  task_prompt="${task_prompt:-}"
  verify_cmd="${verify_cmd:-}"
  required_paths="${required_paths:-}"

  if [[ -z "$task_id" ]]; then
    continue
  fi
  if [[ "$task_id" == \#* ]]; then
    continue
  fi
  if [[ "$task_id" == "id" && "$(trim "$task_prompt")" == "prompt" ]]; then
    continue
  fi

  total_tasks=$((total_tasks + 1))

  if [[ -n "${completed[$task_id]:-}" ]]; then
    skipped_done=$((skipped_done + 1))
    echo "[codex-queue] skip completed task: $task_id"
    continue
  fi

  if [[ -z "$task_prompt" ]]; then
    echo "[codex-queue] task $task_id 的 prompt 为空，跳过并记失败。" >&2
    printf '%s\t%s\t%s\t%s\n' \
      "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      "$task_id" \
      "2" \
      "empty prompt" >> "$failed_file"
    failed_count=$((failed_count + 1))
    if [[ "$stop_on_failure" == "1" ]]; then
      exit 2
    fi
    continue
  fi

  echo "[codex-queue] ===== task $task_id ====="
  echo "[codex-queue] prompt: $task_prompt"
  if [[ -n "$verify_cmd" && "$skip_verify" != "1" ]]; then
    echo "[codex-queue] verify_cmd: $verify_cmd"
  fi
  if [[ -n "$required_paths" ]]; then
    echo "[codex-queue] required_paths: $required_paths"
  fi

  attempt=1
  task_done=0
  last_rc=1

  while (( attempt <= max_retries )); do
    log_file="$logs_dir/${task_id}.attempt${attempt}.log"
    echo "[codex-queue] task=$task_id attempt=$attempt/$max_retries"

    local_repo_check=0
    before_fp=""
    after_fp=""
    before_req_fp=""
    after_req_fp=""
    declare -a req_specs=()

    if is_in_git_repo; then
      local_repo_check=1
      if [[ "$require_change" == "1" ]]; then
        before_fp="$(compute_git_fingerprint .)"
      fi
      if [[ -n "$required_paths" ]]; then
        csv_to_array "$required_paths" req_specs
        if (( ${#req_specs[@]} > 0 )); then
          before_req_fp="$(compute_git_fingerprint "${req_specs[@]}")"
        fi
      fi
    fi

    rc=0
    if [[ -n "$override_cmd" ]]; then
      set +e
      TASK_ID="$task_id" TASK_PROMPT="$task_prompt" TASK_ATTEMPT="$attempt" \
        bash -lc "$override_cmd" 2>&1 | tee "$log_file"
      rc=${PIPESTATUS[0]}
      set -e
    else
      if [[ "$use_resume" == "1" && "$session_started" == "1" ]]; then
        mapfile -d '' cmd_arr < <(build_codex_resume_cmd "$task_prompt")
      else
        mapfile -d '' cmd_arr < <(build_codex_exec_cmd "$task_prompt")
      fi
      run_cmd_with_log "$log_file" "${cmd_arr[@]}" || rc=$?
      session_started=1
    fi

    if [[ "$rc" -ne 0 ]]; then
      echo "[codex-queue] task=$task_id attempt=$attempt failed: rc=$rc"
      last_rc="$rc"
      attempt=$((attempt + 1))
      if (( pause_seconds > 0 )); then
        sleep "$pause_seconds"
      fi
      continue
    fi

    if (( local_repo_check )) && [[ "$require_change" == "1" ]]; then
      after_fp="$(compute_git_fingerprint .)"
      if [[ "$after_fp" == "$before_fp" ]]; then
        echo "[codex-queue] task=$task_id no-op: exit 0 but repo fingerprint unchanged." >&2
        last_rc=125
        attempt=$((attempt + 1))
        if (( pause_seconds > 0 )); then
          sleep "$pause_seconds"
        fi
        continue
      fi
    fi

    if (( local_repo_check )) && [[ -n "$required_paths" ]] && (( ${#req_specs[@]} > 0 )); then
      after_req_fp="$(compute_git_fingerprint "${req_specs[@]}")"
      if [[ "$after_req_fp" == "$before_req_fp" ]]; then
        echo "[codex-queue] task=$task_id required_paths unchanged: $required_paths" >&2
        last_rc=126
        attempt=$((attempt + 1))
        if (( pause_seconds > 0 )); then
          sleep "$pause_seconds"
        fi
        continue
      fi
    fi

    if [[ -n "$verify_cmd" && "$skip_verify" != "1" ]]; then
      echo "[codex-queue] running verify_cmd for task=$task_id ..."
      set +e
      bash -lc "$verify_cmd"
      verify_rc=$?
      set -e
      if [[ "$verify_rc" -ne 0 ]]; then
        echo "[codex-queue] task=$task_id verify failed: rc=$verify_rc" >&2
        last_rc=127
        attempt=$((attempt + 1))
        if (( pause_seconds > 0 )); then
          sleep "$pause_seconds"
        fi
        continue
      fi
    fi

    task_done=1
    printf '%s\t%s\tattempt=%s\n' \
      "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      "$task_id" \
      "$attempt" >> "$done_file"
    completed["$task_id"]=1
    success_count=$((success_count + 1))
    echo "[codex-queue] task=$task_id done."
    break
  done

  if [[ "$task_done" -ne 1 ]]; then
    failed_count=$((failed_count + 1))
    printf '%s\t%s\t%s\t%s\n' \
      "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      "$task_id" \
      "$last_rc" \
      "exhausted retries" >> "$failed_file"
    echo "[codex-queue] task=$task_id failed after retries, rc=$last_rc" >&2
    if [[ "$stop_on_failure" == "1" ]]; then
      exit "$last_rc"
    fi
  fi
done < "$task_file"

echo "[codex-queue] ===== summary ====="
echo "[codex-queue] total_tasks:   $total_tasks"
echo "[codex-queue] skipped_done:  $skipped_done"
echo "[codex-queue] success_count: $success_count"
echo "[codex-queue] failed_count:  $failed_count"
echo "[codex-queue] done_file:     $done_file"
echo "[codex-queue] failed_file:   $failed_file"
echo "[codex-queue] logs_dir:      $logs_dir"

if (( failed_count > 0 )); then
  exit 1
fi

exit 0
