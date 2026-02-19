# ExecPlan 索引

本仓库迁移任务遵循 AGENTS 中 ExecPlan 机制。复杂功能与跨模块迁移必须先落盘计划再实现。

## 活跃计划

1. `docs/plans/2026-02-19-reader-core-config-parity-execplan.md`
   - 标题：Legado -> SoupReader 核心链路与阅读器配置迁移（排版/交互一致）
   - 状态：`active`
   - 口径：先完成核心链路与文本阅读配置迁移；排版一致性与交互一致性为阻塞验收门槛

## 阻塞计划

1. `docs/plans/2026-02-19-reader-extensions-blocked-execplan.md`
   - 标题：Legado -> SoupReader 扩展阅读能力冻结（漫画/TTS/朗读引擎）
   - 状态：`blocked`
   - 口径：未收到“开始做扩展功能”指令前保持冻结，不得并行启动

## 已完成计划

- 暂无

## 状态定义

- `draft`：草案，未进入实现
- `active`：实施中
- `blocked`：遇到阻塞或例外，待确认
- `done`：计划完成并具备验收证据
