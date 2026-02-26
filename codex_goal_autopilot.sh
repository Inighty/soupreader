#!/usr/bin/env bash
#
# codex_goal_autopilot.sh
# 给定一个大目标，自动循环：
#   1) 规划“下一批任务”（JSON schema 约束）
#   2) 转换为 tasks.tsv
#   3) 调用 codex_queue_runner.sh 顺序执行
#   4) 重复直到规划器判定 done=true 或达到最大轮次
#
# 依赖：codex, jq, bash
#
# 用法示例：
#   ./codex_goal_autopilot.sh --goal "迁移 legado 我的菜单（除 web 服务）"
#   ./codex_goal_autopilot.sh --goal-file /tmp/goal.txt --max-cycles 8
#
# 环境变量：
#   CODEX_GOAL_STATE_DIR                    默认 .codex-goal-state
#   CODEX_GOAL_TASKS_PER_CYCLE              默认 5
#   CODEX_GOAL_MAX_CYCLES                   默认 6
#   CODEX_GOAL_CONTINUE_ON_QUEUE_FAILURE    默认 1
#   CODEX_GOAL_SANDBOX                      默认 danger-full-access
#   CODEX_GOAL_BYPASS                       默认 1
#   CODEX_GOAL_MODEL                        默认空（使用 codex 默认模型）
#   CODEX_GOAL_PLAN_REASONING_EFFORT        默认 medium（仅规划阶段）
#   CODEX_GOAL_PLAN_TIMEOUT_SECONDS         默认 900（仅规划阶段）
#   CODEX_GOAL_OVERRIDE_PLAN_JSON           测试用途：直接使用该 JSON 文件作为规划结果
#   CODEX_GOAL_QUEUE_REQUIRE_CHANGE         默认 1
#   CODEX_GOAL_QUEUE_MAX_RETRIES            默认 2
#   CODEX_GOAL_QUEUE_STOP_ON_FAILURE        默认 1
#
# 退出码：
#   0   目标完成
#   1   队列执行失败且配置为失败即停 / 其它运行错误
#   2   参数错误
#   3   达到最大轮次仍未完成

set -euo pipefail

goal_text=""
goal_file=""
max_cycles="${CODEX_GOAL_MAX_CYCLES:-6}"
tasks_per_cycle="${CODEX_GOAL_TASKS_PER_CYCLE:-5}"
state_dir="${CODEX_GOAL_STATE_DIR:-.codex-goal-state}"
continue_on_queue_failure="${CODEX_GOAL_CONTINUE_ON_QUEUE_FAILURE:-1}"
sandbox_mode="${CODEX_GOAL_SANDBOX:-danger-full-access}"
bypass_approval="${CODEX_GOAL_BYPASS:-1}"
model_name="${CODEX_GOAL_MODEL:-}"
plan_reasoning_effort="${CODEX_GOAL_PLAN_REASONING_EFFORT:-medium}"
plan_timeout_seconds="${CODEX_GOAL_PLAN_TIMEOUT_SECONDS:-900}"
override_plan_json="${CODEX_GOAL_OVERRIDE_PLAN_JSON:-}"
queue_require_change="${CODEX_GOAL_QUEUE_REQUIRE_CHANGE:-1}"
queue_max_retries="${CODEX_GOAL_QUEUE_MAX_RETRIES:-2}"
queue_stop_on_failure="${CODEX_GOAL_QUEUE_STOP_ON_FAILURE:-1}"

usage() {
  cat <<'EOF'
用法：
  codex_goal_autopilot.sh --goal "你的大任务"
  codex_goal_autopilot.sh --goal-file /path/to/goal.txt

可选参数：
  --max-cycles N         最大循环轮次（默认来自 CODEX_GOAL_MAX_CYCLES，缺省 6）
  --tasks-per-cycle N    每轮最多规划任务数（默认来自 CODEX_GOAL_TASKS_PER_CYCLE，缺省 5）
  --state-dir DIR        状态目录（默认来自 CODEX_GOAL_STATE_DIR，缺省 .codex-goal-state）
  -h, --help             显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --goal)
      goal_text="${2:-}"
      shift 2
      ;;
    --goal-file)
      goal_file="${2:-}"
      shift 2
      ;;
    --max-cycles)
      max_cycles="${2:-}"
      shift 2
      ;;
    --tasks-per-cycle)
      tasks_per_cycle="${2:-}"
      shift 2
      ;;
    --state-dir)
      state_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[goal-autopilot] 未知参数: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "$goal_file" ]]; then
  if [[ ! -f "$goal_file" ]]; then
    echo "[goal-autopilot] goal 文件不存在: $goal_file" >&2
    exit 2
  fi
  goal_text="$(cat "$goal_file")"
fi

goal_text="$(printf '%s' "$goal_text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
if [[ -z "$goal_text" ]]; then
  echo "[goal-autopilot] 必须提供 --goal 或 --goal-file。" >&2
  exit 2
fi

if ! [[ "$max_cycles" =~ ^[0-9]+$ ]] || (( max_cycles < 1 )); then
  echo "[goal-autopilot] --max-cycles 必须是 >=1 的整数" >&2
  exit 2
fi
if ! [[ "$tasks_per_cycle" =~ ^[0-9]+$ ]] || (( tasks_per_cycle < 1 )); then
  echo "[goal-autopilot] --tasks-per-cycle 必须是 >=1 的整数" >&2
  exit 2
fi
if ! [[ "$plan_timeout_seconds" =~ ^[0-9]+$ ]] || (( plan_timeout_seconds < 1 )); then
  echo "[goal-autopilot] CODEX_GOAL_PLAN_TIMEOUT_SECONDS 必须是 >=1 的整数" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[goal-autopilot] 需要 jq，请先安装。" >&2
  exit 1
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "[goal-autopilot] 需要 codex CLI，请先安装并登录。" >&2
  exit 1
fi
if [[ ! -x "./codex_queue_runner.sh" ]]; then
  echo "[goal-autopilot] 需要可执行脚本 ./codex_queue_runner.sh" >&2
  exit 1
fi

mkdir -p "$state_dir"
goal_txt_file="$state_dir/goal.txt"
schema_file="$state_dir/plan_schema.json"
run_log_file="$state_dir/run.log"
printf '%s\n' "$goal_text" > "$goal_txt_file"
touch "$run_log_file"

cat > "$schema_file" <<'EOF'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "done": { "type": "boolean" },
    "done_reason": { "type": "string" },
    "goal_summary": { "type": "string" },
    "tasks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "title": { "type": "string" },
          "priority": { "type": "integer" },
          "prompt": { "type": "string" },
          "verify_cmd": { "type": "string" },
          "required_paths": {
            "type": "array",
            "items": { "type": "string" }
          },
          "depends_on": {
            "type": "array",
            "items": { "type": "string" }
          }
        },
        "required": ["id", "title", "priority", "prompt", "verify_cmd", "required_paths", "depends_on"],
        "additionalProperties": false
      }
    },
    "notes": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "required": ["done", "done_reason", "goal_summary", "tasks", "notes"],
  "additionalProperties": false
}
EOF

build_codex_plan_cmd() {
  local prompt="$1"
  local output_json="$2"
  local -a cmd=(codex --sandbox "$sandbox_mode")
  if [[ "$bypass_approval" == "1" ]]; then
    cmd+=(--dangerously-bypass-approvals-and-sandbox)
  fi
  if [[ -n "$model_name" ]]; then
    cmd+=(--model "$model_name")
  fi
  if [[ -n "$plan_reasoning_effort" ]]; then
    cmd+=(-c "model_reasoning_effort=\"$plan_reasoning_effort\"")
  fi
  cmd+=(exec --skip-git-repo-check --output-schema "$schema_file" -o "$output_json" "$prompt")
  printf '%s\0' "${cmd[@]}"
}

plan_prompt_for_cycle() {
  local cycle="$1"
  local last_queue_result="$2"
  cat <<EOF
你是任务规划器。请基于当前仓库状态，把“大目标”拆成“下一批可执行任务”。

大目标：
$goal_text

当前轮次：$cycle / $max_cycles
每轮最多任务数：$tasks_per_cycle

上一轮队列结果（可为空）：
$last_queue_result

规划要求（必须遵守）：
1. 如果目标已经完成，输出 done=true 且 tasks=[]。
2. 如果未完成，输出 done=false，并给出最多 $tasks_per_cycle 条任务。
3. 每条任务必须是“可落地执行”的编码任务，prompt 要具体，避免泛化指令。
4. prompt 需包含：改动范围、预期行为、验证方式。
5. required_paths 必须是仓库内相对路径数组；不确定可留空数组。
6. verify_cmd 优先给定向验证命令；不要使用 flutter analyze（除非明确是提交前最终验收）。
7. 任务按 priority 从小到大表示先后顺序，输出时也尽量按该顺序。
8. 保持中文。

只输出满足 schema 的 JSON。
EOF
}

convert_plan_to_tsv() {
  local plan_json="$1"
  local tsv_file="$2"
  jq -r '
    ["id","prompt","verify_cmd","required_paths_csv"],
    (
      .tasks
      | sort_by(.priority, .id)
      | .[]
      | [
          (.id | tostring | gsub("[\t\r\n]+"; " ")),
          (.prompt | tostring | gsub("[\t\r\n]+"; " ")),
          (.verify_cmd | tostring | gsub("[\t\r\n]+"; " ")),
          (
            (.required_paths // [])
            | map(tostring | gsub("[,\t\r\n]+"; " "))
            | map(select(length > 0))
            | join(",")
          )
        ]
    )
    | @tsv
  ' "$plan_json" > "$tsv_file"
}

last_queue_result=""
completed=0

for (( cycle = 1; cycle <= max_cycles; cycle++ )); do
  cycle_dir="$state_dir/cycle-$cycle"
  mkdir -p "$cycle_dir"
  plan_json="$cycle_dir/plan.json"
  tasks_tsv="$cycle_dir/tasks.tsv"
  plan_prompt_file="$cycle_dir/plan_prompt.txt"
  queue_stdout_log="$cycle_dir/queue.log"

  echo "[goal-autopilot] ===== cycle $cycle/$max_cycles =====" | tee -a "$run_log_file"

  if [[ -n "$override_plan_json" ]]; then
    cp "$override_plan_json" "$plan_json"
    echo "[goal-autopilot] 使用 CODEX_GOAL_OVERRIDE_PLAN_JSON: $override_plan_json" | tee -a "$run_log_file"
  else
    plan_prompt_for_cycle "$cycle" "$last_queue_result" > "$plan_prompt_file"
    mapfile -d '' plan_cmd < <(build_codex_plan_cmd "$(cat "$plan_prompt_file")" "$plan_json")
    echo "[goal-autopilot] planning... (timeout=${plan_timeout_seconds}s, reasoning=${plan_reasoning_effort})" | tee -a "$run_log_file"
    set +e
    if command -v timeout >/dev/null 2>&1; then
      timeout --foreground "$plan_timeout_seconds" "${plan_cmd[@]}" 2>&1 | tee -a "$run_log_file"
      plan_rc=${PIPESTATUS[0]}
    else
      "${plan_cmd[@]}" 2>&1 | tee -a "$run_log_file"
      plan_rc=${PIPESTATUS[0]}
    fi
    set -e
    if [[ "$plan_rc" -eq 124 ]]; then
      echo "[goal-autopilot] 规划超时（>${plan_timeout_seconds}s）。可调整 CODEX_GOAL_PLAN_TIMEOUT_SECONDS。" | tee -a "$run_log_file"
      exit 124
    fi
    if [[ "$plan_rc" -ne 0 ]]; then
      echo "[goal-autopilot] 规划失败，rc=$plan_rc" | tee -a "$run_log_file"
      exit "$plan_rc"
    fi
  fi

  if ! jq -e . >/dev/null 2>&1 < "$plan_json"; then
    echo "[goal-autopilot] 规划结果不是合法 JSON: $plan_json" | tee -a "$run_log_file"
    exit 1
  fi

  done_flag="$(jq -r '.done' "$plan_json")"
  done_reason="$(jq -r '.done_reason' "$plan_json")"
  task_count="$(jq -r '.tasks | length' "$plan_json")"
  echo "[goal-autopilot] planner done=$done_flag tasks=$task_count reason=$done_reason" | tee -a "$run_log_file"

  if [[ "$done_flag" == "true" ]]; then
    if [[ "$task_count" -ne 0 ]]; then
      echo "[goal-autopilot] 警告：done=true 但 tasks 非空，忽略 tasks 并结束。" | tee -a "$run_log_file"
    fi
    completed=1
    break
  fi

  if [[ "$task_count" -eq 0 ]]; then
    echo "[goal-autopilot] 未完成但无任务可执行，停止。请人工检查规划质量。" | tee -a "$run_log_file"
    exit 1
  fi

  convert_plan_to_tsv "$plan_json" "$tasks_tsv"
  echo "[goal-autopilot] tasks written: $tasks_tsv" | tee -a "$run_log_file"

  set +e
  CODEX_QUEUE_TASK_FILE="$tasks_tsv" \
  CODEX_QUEUE_STATE_DIR="$cycle_dir/queue-state" \
  CODEX_QUEUE_REQUIRE_CHANGE="$queue_require_change" \
  CODEX_QUEUE_MAX_RETRIES="$queue_max_retries" \
  CODEX_QUEUE_STOP_ON_FAILURE="$queue_stop_on_failure" \
  CODEX_QUEUE_SANDBOX="$sandbox_mode" \
  CODEX_QUEUE_BYPASS="$bypass_approval" \
  ./codex_queue_runner.sh | tee "$queue_stdout_log"
  queue_rc=${PIPESTATUS[0]}
  set -e

  last_queue_result="rc=$queue_rc; done_file=$cycle_dir/queue-state/done.tsv; failed_file=$cycle_dir/queue-state/failed.tsv"
  echo "[goal-autopilot] queue finished: $last_queue_result" | tee -a "$run_log_file"

  if [[ "$queue_rc" -ne 0 && "$continue_on_queue_failure" != "1" ]]; then
    echo "[goal-autopilot] 队列失败且设置为失败即停。" | tee -a "$run_log_file"
    exit "$queue_rc"
  fi
done

if (( completed )); then
  echo "[goal-autopilot] 目标已完成。"
  exit 0
fi

echo "[goal-autopilot] 达到最大轮次 $max_cycles，目标仍未完成。" >&2
exit 3
