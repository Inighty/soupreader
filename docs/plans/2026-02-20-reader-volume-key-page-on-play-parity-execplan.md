# 阅读器 `volumeKeyPageOnPlay` 运行态联动回补（对照 legado）ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心交互回补）`

## 背景与目标

### 背景

在既有计划 `reader-ui-settings-continued` 中，`volumeKeyPageOnPlay` 被标记为 `blocked`，原因是依赖 TTS 运行态信号。当前 TTS 主链路已完成，本项需按 legacy 语义补齐“朗读播放中音量键翻页拦截”。

已完整读取 legado 对照文件：

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt`
- `/home/server/legado/app/src/main/res/xml/pref_config_read.xml`

legacy 基准语义：

1. `AppConfig.volumeKeyPage` 为总开关，默认 `true`。
2. `AppConfig.volumeKeyPageOnPlay` 控制“朗读播放中是否仍允许音量键翻页”。
3. 当 `volumeKeyPageOnPlay=false` 且 `BaseReadAloudService.isPlay()==true` 时，音量键不触发翻页。

### 目标（Success Criteria）

1. 音量键翻页决策统一到可复用 helper，避免页面层散落判定。
2. 朗读播放中且 `volumeKeyPageOnPlay=false` 时，音量键翻页被阻断。
3. 非音量键（方向键/翻页键/空格）不受该开关影响。
4. 补齐自动化测试，覆盖上述行为。

### 非目标（Non-goals）

1. 不实现 `customPageKey` 自定义按键映射。
2. 不改动 `设置编码` 链路。
3. 不扩展朗读设置弹窗（本轮仍按既有 Non-goals 保持）。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| VK1 | `simple_reader_view.dart:_handleKeyEvent` | `ReadBookActivity.volumeKeyPage` | 运行态条件判断存在，但未沉淀为统一 helper | 后续回归风险高 |
| VK2 | `reader_key_paging_helper_test.dart` | `ReadBookActivity.onKeyDown + volumeKeyPage` | 缺少 `volumeKeyPageOnPlay` 专项测试 | 容易回归且不易发现 |

## 逐项检查清单（强制）

- 入口：阅读页键盘事件入口是否统一走 helper 判定。
- 状态：朗读播放中开关开/关两种状态是否符合 legacy 语义。
- 异常：非音量键是否被误拦截。
- 文案：本项不新增用户可见文案，确保原文案不变。
- 排版：本项不涉及 UI 布局改动。
- 交互触发：音量键翻页在不同状态下触发/阻断是否可复现。

## 实施步骤

### Step 1（串行，前置）

- 目标：复核 legacy 音量键与朗读联动语义，并落盘差异点。
- 状态：`completed`
- 验证：上述 3 个 legacy 文件完成整文件读取。

### Step 2（串行，依赖 Step 1）

- 目标：抽离 `volumeKeyPageOnPlay` 联动判定到 helper，并在阅读页调用。
- 涉及：
  - `lib/features/reader/services/reader_key_paging_helper.dart`
  - `lib/features/reader/views/simple_reader_view.dart`
- 状态：`completed`
- 验证：代码评审确认调用链统一。

### Step 3（串行，依赖 Step 2）

- 目标：补齐定向测试并执行回归。
- 涉及：
  - `test/reader_key_paging_helper_test.dart`
  - `test/simple_reader_view_compile_test.dart`（回归执行）
- 状态：`completed`
- 验证：
  - `flutter test test/reader_key_paging_helper_test.dart`
  - `flutter test test/simple_reader_view_compile_test.dart test/reader_key_paging_helper_test.dart`

## 逐项对照清单（实现后）

| 编号 | 差异项 | 对照结果 | 说明 |
|---|---|---|---|
| VK1 | 运行态判定散落页面层 | 已同义 | 新增 `shouldBlockVolumePagingDuringReadAloud`，页面层改为统一调用。 |
| VK2 | 缺少 `volumeKeyPageOnPlay` 专项测试 | 已同义 | 增加播放中开关开/关、非音量键不受影响三类断言。 |

## 风险与回滚

### 失败模式

1. helper 判定条件写错导致音量键被全局误拦截。
2. 朗读状态读取错误（将 paused 当作 playing）导致行为偏差。

### 阻塞条件（触发即标记 `blocked`）

1. 若平台无法稳定上报按键事件，导致无法验证音量键分支，则需转为 `blocked` 并走例外流程。

### 回滚策略

1. 文件级回滚：
   - `lib/features/reader/services/reader_key_paging_helper.dart`
   - `lib/features/reader/views/simple_reader_view.dart`
   - `test/reader_key_paging_helper_test.dart`
2. 不影响其它朗读功能改动，可独立回退。

## 验收与证据

### 手工回归路径

1. 开启朗读并保持播放中，关闭“朗读时音量键翻页”，按音量键应不触发翻页。
2. 开启朗读并保持播放中，开启“朗读时音量键翻页”，按音量键应触发翻页。
3. 使用方向键/翻页键/空格，行为不受 `volumeKeyPageOnPlay` 开关影响。

### 命令验证

- `flutter test test/reader_key_paging_helper_test.dart`
- `flutter test test/simple_reader_view_compile_test.dart test/reader_key_paging_helper_test.dart`
- 未执行 `flutter analyze`（符合仓库规则：仅提交前执行一次）。

## Progress

- `2026-02-20`：
  - 完成 Step 1：对 legacy 音量键联动语义做整文件核对。
  - 完成 Step 2：新增 helper 判定函数并替换页面层直接判断。
  - 完成 Step 3：补充单测并通过定向回归。
  - 兼容影响：仅重构决策入口与补测，不改变现有设置存储协议。

## Surprises & Discoveries

1. 现有实现已具备运行态判定主逻辑，核心缺口在“可复用封装 + 自动化验证”。
2. legacy 默认值在 XML 与运行态 getter 存在历史差异，实际运行以 `AppConfig` getter（`true`）为准。

## Decision Log

1. 本轮不扩大到 `customPageKey`，聚焦 `volumeKeyPageOnPlay` 单点闭环。
2. 采用“helper 抽离 + 页面调用 + 单测覆盖”策略，优先控制回归风险。
3. 旧计划中的 `blocked` 记录保留历史信息，同时在对照表中回填“已回补”。

## Outcomes & Retrospective

1. `volumeKeyPageOnPlay` 已完成从“依赖已解除但缺少独立闭环”到“可复用 + 可测试”的迁移收口。
2. 本项完成后，`reader-ui-settings-continued` 中该条目不再属于未回补差异。
