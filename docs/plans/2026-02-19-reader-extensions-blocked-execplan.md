# Legado -> SoupReader 扩展阅读能力冻结（漫画/TTS/朗读引擎）

- 状态：`blocked`
- 负责人：`Core-Migration`
- 更新时间：`2026-02-19`
- 解锁条件：需求方明确下达“开始做扩展功能”

## 背景与目标

### 背景
- 本仓库执行“核心优先、扩展后置”策略。
- 当前需求仅覆盖核心链路与文本阅读器配置迁移。

### 目标
- 明确扩展功能冻结边界，避免提前实现扩展入口/流程/文案。

### 非目标
- 本计划不进行任何扩展功能开发，仅用于冻结与追踪。

## 差异点清单（冻结项）

| ID | 能力 | legado 参考位置 | 冻结原因 | 影响 |
| --- | --- | --- | --- | --- |
| E-01 | 漫画阅读配置迁移 | `/home/server/legado/app/src/main/java/io/legado/app/ui/book/manga` | 未收到扩展解锁指令 | 漫画配置与交互暂不迁移 |
| E-02 | 朗读引擎配置 | `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/SpeakEngineDialog.kt` | 未收到扩展解锁指令 | 引擎选择流程暂不迁移 |
| E-03 | HTTP TTS 配置 | `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/HttpTtsEditDialog.kt` | 未收到扩展解锁指令 | 在线朗读扩展暂不迁移 |

## 实施步骤

### Step 1：冻结声明落盘（已完成）
- 在计划中记录冻结范围、解锁条件和禁止事项。

### Step 2：等待解锁指令（进行中）
- 收到“开始做扩展功能”前，持续维持 `blocked`。

## 风险与回滚

- 风险：若误将扩展改动混入核心迁移，将破坏执行顺序与验收口径。
- 控制：
  - 扩展项不得并行启动；
  - 若发现误触发，立即停止并回到 `blocked` 追踪。

## 验收与证据

- 验收标准：
  - 扩展项未被提前实现；
  - 核心计划中扩展项明确标记为 `blocked` 并与本计划一致。

## Progress

- [x] Step 1：冻结声明落盘
- [ ] Step 2：等待解锁指令

## Surprises & Discoveries

- 暂无。

## Decision Log

- 决策：在未解锁前，不允许以“预埋接口”“顺手优化”等名义提前启动扩展开发。

## Outcomes & Retrospective

- 待解锁后回填。

