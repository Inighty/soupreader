# 阅读器“启用替换规则”开关（菜单/点击动作/目录展示）对齐 legado ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心阅读链路）`

## 背景与目标

### 背景

阅读器当前仍存在与 legado 不同义的替换规则开关行为：

- “阅读操作 -> 启用替换规则”仍为占位提示；
- 点击区域动作“替换开关”仍为占位提示；
- 正文/标题替换目前默认始终生效，缺少开关状态流转；
- 目录“使用替换规则”切换后不会即时刷新标题展示。

本任务已完整复核 legacy 参考实现：

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/data/entities/Book.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/res/layout/view_read_menu.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/toc/TocActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/toc/ChapterListAdapter.kt`

### 目标（Success Criteria）

1. 阅读操作菜单 `启用替换规则` 支持可切换，并显示勾选状态。
2. 点击区域动作 `替换开关` 支持直接切换替换规则状态。
3. 正文与标题替换链路按开关生效，切换后即时刷新当前阅读结果。
4. 目录 `使用替换规则` 切换后，标题展示可即时刷新，不残留旧缓存结果。
5. 开关状态具备持久化，重进阅读页后行为稳定可复现。

### 非目标（Non-goals）

1. 不在本任务实现云端进度同步、TTS、正文编辑等其他占位项。
2. 不扩展替换规则编辑器能力（仅对接现有入口与状态开关）。
3. 不改造与替换规则无关的阅读排版和书源抓取流程。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| R1 | `lib/features/reader/views/simple_reader_view.dart:3595` | `ReadBookActivity.kt:526,1557` | 阅读操作菜单 `启用替换规则` 为占位提示，未切换状态 | 菜单语义缺失 |
| R2 | `lib/features/reader/views/simple_reader_view.dart:1919` | `ReadBookActivity.kt:526` | 点击动作 `toggleReplaceRule` 为占位提示 | 点击动作链路缺失 |
| R3 | `lib/features/reader/views/simple_reader_view.dart:2170` | `ReadBookViewModel.kt:540` + `Book.kt:200` | 正文/标题替换始终执行，缺少开关控制与默认值回退语义 | 与 legacy 状态流转不一致 |
| R4 | `lib/features/reader/views/simple_reader_view.dart:2154` + `reader_catalog_sheet.dart:703` | `TocActivity.kt:149` + `ChapterListAdapter.kt:78` | 目录“使用替换规则”切换后未重算展示标题，且未与正文替换开关联动 | 目录展示不一致 |
| R5 | `lib/core/services/settings_service.dart` | `Book.kt.ReadConfig.useReplaceRule` | 缺少书籍级替换开关持久化 | 重进页面后状态不可复现 |

## 逐项检查清单（强制）

- 入口：阅读操作菜单、点击区域动作是否均可切换替换开关。
- 状态：开关切换后正文/标题是否即时更新；重进阅读页是否保持状态。
- 异常：章节为空、无缓存正文、书籍信息缺失时切换是否稳定。
- 文案：开关提示语与菜单文案是否保持业务语义一致。
- 排版：菜单列表仅追加勾选态，不改变既有结构与热区。
- 交互触发：目录“使用替换规则”切换后是否即时刷新标题。

## 实施步骤（依赖与并行）

### Step 1（串行，前置）

- 目标：落盘 ExecPlan、差异清单、检查清单。
- 状态：`completed`
- 验证：`PLANS.md` 可索引本任务。

### Step 2（串行，依赖 Step 1）

- 目标：实现书籍级替换开关持久化与默认值回退。
- 涉及：
  - `lib/core/services/settings_service.dart`
  - `test/app_settings_test.dart`
- 状态：`completed`

### Step 3（串行，依赖 Step 2）

- 目标：接入阅读链路（正文/标题替换）与菜单/点击动作开关。
- 涉及：
  - `lib/features/reader/views/simple_reader_view.dart`
  - `lib/features/reader/services/chapter_title_display_helper.dart`
  - `test/chapter_title_display_helper_test.dart`
- 状态：`completed`

### Step 4（可并行，依赖 Step 3 基础状态）

- 目标：目录“使用替换规则”切换后即时刷新展示标题。
- 涉及：
  - `lib/features/reader/widgets/reader_catalog_sheet.dart`
  - `lib/features/reader/views/simple_reader_view.dart`
- 状态：`completed`

### Step 5（串行，收尾）

- 目标：补齐验证证据与逐项对照清单回填。
- 状态：`completed`

## 风险与回滚

### 失败模式

1. 开关切换后未清理缓存，导致正文或目录标题展示滞后。
2. 持久化维度错误（全局/书籍混用）导致跨书籍状态串扰。
3. 切换时触发重载引起阅读进度跳动。

### 阻塞条件（触发即标记 `blocked`）

1. 现有存储层无法提供稳定书籍维度持久化键。
2. 切换后无法在不破坏阅读状态的前提下刷新正文。

### 回滚策略

1. 按文件粒度回滚：`simple_reader_view.dart`、`settings_service.dart`、`reader_catalog_sheet.dart`。
2. 保留测试变更，作为回归基线复用。

## 验收与证据

### 手工回归路径

1. 阅读页 -> 阅读操作 -> `启用替换规则`，重复切换两次观察正文变化。
2. 配置点击区域动作为 `替换开关`，点击触发切换并观察正文变化。
3. 打开目录 -> 菜单 -> `使用替换规则`，验证标题即时刷新。
4. 退出阅读页再进入，验证当前书籍替换开关状态保持。

### 命令验证

- 开发过程：仅执行定向测试，不执行 `flutter analyze`。
- 提交推送前：执行且仅执行一次 `flutter analyze`（本轮未到提交阶段）。

## Progress

- `2026-02-20`：
  - 已完成：Step 1（ExecPlan 与差异清单落盘）。
  - 已完成：Step 2（书籍级开关持久化）
    - `SettingsService` 新增 `book_use_replace_rule_map` 持久化键；
    - 新增 `getBookUseReplaceRule/saveBookUseReplaceRule`；
    - 增补 `app_settings_test.dart` 覆盖持久化与旧格式兼容。
  - 已完成：Step 3（阅读链路接入）
    - 阅读页新增 `_useReplaceRule` 状态，启动时按书籍维度读取；
    - 点击动作 `替换开关` 与阅读操作菜单 `启用替换规则` 均接入真实切换；
    - 正文替换计算 `_computeReplaceStage` 按开关执行；
    - 目录标题构建按 `目录开关 && 正文开关` 执行替换。
  - 已完成：Step 4（目录切换刷新）
    - `reader_catalog_sheet.dart` 新增切换后标题缓存失效与重算流程；
    - `simple_reader_view.dart` 在目录切换回调中清理目录标题缓存。
  - 已完成：Step 5（验证与回填）
    - 命令验证：
      - `flutter test test/app_settings_test.dart test/chapter_title_display_helper_test.dart test/simple_reader_view_compile_test.dart --reporter expanded`（通过）
    - 兼容影响：
      - 新增 `book_use_replace_rule_map` 偏好键，旧版本无该键时按回退值处理；
      - 当前回退值对齐 legacy 主路径：`epub` 默认关闭，其余默认开启。

## 逐项对照清单（本轮回填）

| 检查项 | 结果 | 证据/说明 |
|---|---|---|
| 入口 | 通过 | 阅读操作菜单 `启用替换规则` 已从占位改为可切换；点击区域动作 `替换开关` 已接入实际切换 |
| 状态 | 通过 | 切换后清理替换缓存并重载当前章节，正文与标题即时刷新 |
| 异常 | 通过 | 无章节时仅更新开关与持久化，不触发章节重载导致崩溃 |
| 文案 | 通过 | 保持 `启用替换规则/已开启替换规则/已关闭替换规则` 语义 |
| 排版 | 通过 | 仅在阅读操作菜单文案前增加勾选标记，不改变菜单结构 |
| 交互触发 | 通过 | 目录 `使用替换规则` 切换后会清空标题缓存并重新解析，避免旧数据残留 |

## Surprises & Discoveries

1. 当前目录面板虽有 `使用替换规则` 开关 UI，但未真正驱动标题重算链路。
2. 现有正文替换缓存 `_replaceStageCache` 需要在开关切换时显式失效。

## Decision Log

1. 持久化采用“书籍维度”而非全局维度，以贴近 legado `Book.ReadConfig.useReplaceRule` 语义。
2. 目录标题替换生效条件对齐 legacy：`目录开关 && 正文替换开关`。

## Outcomes & Retrospective

- 本轮结果：
  - legacy `changeReplaceRuleState -> replaceRuleChanged -> loadContent(false)` 对应链路已在 Flutter 侧闭环；
  - 菜单与点击动作两条入口均可驱动同一替换开关状态；
  - 目录标题替换切换具备即时刷新能力，且与正文开关联动。
- 保留差异：
  - legacy 的图片类书籍默认关闭替换规则；当前项目暂无图片阅读模式，仅对齐了 `epub` 分支默认关闭语义。
