#!/usr/bin/env bash
#
# 极简入口：只关心“大任务自动完成”
# 用法：
#   ./codex_goal_simple.sh "你的大任务描述"
#   ./codex_goal_simple.sh --goal-file /path/to/goal.txt
#
# 说明：
# - 内部调用 codex_goal_autopilot.sh
# - 不要求你手动传 max-cycles/tasks-per-cycle
# - 仍保留默认安全护栏，避免无限空转/无限消耗

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
用法：
  ./codex_goal_simple.sh "你的大任务描述"
  ./codex_goal_simple.sh --goal-file /path/to/goal.txt
  ./codex_goal_simple.sh --goal "你的大任务描述"
EOF
}

if [[ ! -x "./codex_goal_autopilot.sh" ]]; then
  echo "[codex-goal-simple] 缺少可执行脚本 ./codex_goal_autopilot.sh" >&2
  exit 1
fi

# 你无需关心这些参数；这里给出稳定默认值。
export CODEX_GOAL_MAX_CYCLES="${CODEX_GOAL_MAX_CYCLES:-120}"
export CODEX_GOAL_TASKS_PER_CYCLE="${CODEX_GOAL_TASKS_PER_CYCLE:-6}"
export CODEX_GOAL_CONTINUE_ON_QUEUE_FAILURE="${CODEX_GOAL_CONTINUE_ON_QUEUE_FAILURE:-1}"
export CODEX_GOAL_STATE_DIR="${CODEX_GOAL_STATE_DIR:-.codex-goal-state}"

# 队列侧默认：防“只说不做”，并允许有限重试。
export CODEX_QUEUE_REQUIRE_CHANGE="${CODEX_QUEUE_REQUIRE_CHANGE:-1}"
export CODEX_QUEUE_MAX_RETRIES="${CODEX_QUEUE_MAX_RETRIES:-3}"
export CODEX_QUEUE_STOP_ON_FAILURE="${CODEX_QUEUE_STOP_ON_FAILURE:-1}"

if [[ $# -eq 0 ]]; then
  printf '请输入大任务描述: '
  read -r goal_input || true
  goal_input="${goal_input#"${goal_input%%[![:space:]]*}"}"
  goal_input="${goal_input%"${goal_input##*[![:space:]]}"}"
  if [[ -z "$goal_input" ]]; then
    usage
    exit 2
  fi
  exec ./codex_goal_autopilot.sh --goal "$goal_input"
fi

case "$1" in
  -h|--help|--goal|--goal-file)
    exec ./codex_goal_autopilot.sh "$@"
    ;;
  *)
    if [[ "$1" == -* ]]; then
      # 允许高级用户直接透传 autopilot 参数
      exec ./codex_goal_autopilot.sh "$@"
    fi
    # 默认把整串参数当作目标文本
    exec ./codex_goal_autopilot.sh --goal "$*"
    ;;
esac
