# 阅读器自动阅读失效修复（对照 legado）ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心交互链路修复）`

## 背景与目标

### 背景

需求方反馈：阅读器“自动阅读/自动翻页”无效。

本轮已完成 legado 对照文件全量复核：

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/AutoPager.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ReadView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/ContentTextView.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/delegate/PageDelegate.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/AutoReadDialog.kt`

本项目对应实现：

- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/reader/widgets/auto_pager.dart`
- `lib/features/reader/widgets/page_factory.dart`

### 目标（Success Criteria）

1. 自动阅读在翻页模式下按“逐页推进”生效，不再直接跳到下一章。
2. 到达末页/末章时自动阅读可自动停止，避免无效空转。
3. 自动阅读运行时的菜单入口可达（符合 legado 运行态优先弹自动阅读设置语义）。
4. 不破坏既有 `autoReadSpeed` 持久化字段与阅读主链路。

### 非目标（Non-goals）

1. 不在本轮实现 legado 非核心扩展项（如 eInk 专属绘制进度条）。
2. 不改动搜索/发现/详情/目录/正文抓取链路。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| AR-1 | `simple_reader_view.dart` 中 `AutoPager.onNextPage` | `ReadView.fillPage + AutoPager` | 翻页模式回调当前直接加载下一章，而非翻下一页 | 单章场景“自动阅读无效” |
| AR-2 | `simple_reader_view.dart` 菜单入口 | `ReadBookActivity.showActionMenu` | 运行中点菜单未优先进入自动阅读面板 | 运行态不可观测、调速入口弱 |
| AR-3 | `auto_pager.dart` 与调用方停止策略 | `PageDelegate.hasNext -> autoPageStop` | 末页/末章边界未统一停止 | 计时器空转、用户感知异常 |

## 逐项检查清单（强制）

- 入口：自动阅读启动/停止与运行态面板入口可达。
- 状态：滚动/翻页模式均可持续推进并在边界正确停机。
- 异常：单章节、末章末页、无下一页时不崩溃且有可观测反馈。
- 文案：自动阅读相关文案语义保持一致。
- 排版：自动阅读面板打开/关闭不遮挡关键阅读交互。
- 交互触发：快捷按钮、菜单入口与自动停机行为一致。

## 实施步骤

### Step 1（串行，前置）

- 目标：落地差异清单并建立修复计划。
- 验证方式：ExecPlan 落盘 + `PLANS.md` 索引登记。
- 状态：`completed`

### Step 2（串行，依赖 Step 1）

- 目标：修复翻页模式自动阅读主链路（逐页推进、末页停机）。
- 涉及：
  - `lib/features/reader/views/simple_reader_view.dart`
- 验证方式：定向测试 + 手工回归路径 A/B。
- 状态：`completed`

### Step 3（串行，依赖 Step 2）

- 目标：对齐运行态入口语义（自动阅读运行时，菜单优先进入自动阅读面板）。
- 涉及：
  - `lib/features/reader/views/simple_reader_view.dart`
- 验证方式：手工回归路径 C。
- 状态：`completed`

### Step 4（并行，依赖 Step 2/3）

- 目标：补充定向测试覆盖自动阅读核心行为。
- 涉及：
  - `test/` 相关测试文件
- 验证方式：`flutter test` 定向用例。
- 状态：`completed`

### Step 5（串行，收尾）

- 目标：回填 ExecPlan 动态章节、逐项对照清单与兼容影响。
- 状态：`completed`

## 风险与回滚

### 失败模式

1. 翻页模式链路修改后影响手动翻页状态更新。
2. 菜单入口优先级调整造成已有弹层冲突。

### 阻塞条件（触发即 `blocked`）

1. 若 legado 同义链路在 Flutter 端存在不可规避平台限制，需先记录例外并暂停实现。

### 回滚策略

1. 文件级回滚：`simple_reader_view.dart`、对应测试文件。
2. 保留本 ExecPlan 作为问题复盘证据。

## 验收与证据

### 手工回归路径

1. 路径 A：翻页模式开启自动阅读，观察按页自动前进。
2. 路径 B：跳到末章末页后开启自动阅读，确认会自动停止。
3. 路径 C：自动阅读运行中点击菜单入口，确认优先打开自动阅读面板。

### 命令验证

- 开发阶段仅执行定向测试，不执行 `flutter analyze`。
- 提交前才执行一次 `flutter analyze`（本轮尚未到提交阶段）。
- 已执行：
  - `flutter test test/auto_pager_test.dart test/simple_reader_view_compile_test.dart test/reading_settings_test.dart`

## 逐项对照清单（实现后）

| 项目 | legado 基准 | 当前实现 | 结论 |
|---|---|---|---|
| 翻页模式自动阅读推进粒度 | `ReadView.fillPage(PageDirection.NEXT)` | `AutoPager` 回调改为 `_pageFactory.moveToNext()` 逐页推进 | 已同义 |
| 末页自动停机 | `PageDelegate.hasNext -> autoPageStop()` | 无下一页时执行 `_stopAutoPagerAtBoundary()` 停止并提示 | 已同义 |
| 运行态菜单入口 | `showActionMenu()` 运行中优先 `AutoReadDialog` | `ClickAction.showMenu` 在自动阅读运行时优先 `_openAutoReadPanel()` | 已同义 |
| 与朗读互斥语义 | `autoPage()` 启动前 `ReadAloud.stop()` | 启动自动阅读前，若朗读中先执行 `_readAloudService.stop()` | 已同义 |
| 自动阅读面板可达性 | `AutoReadDialog` 可达 | `_showAutoReadPanel` 补齐开启路径，运行中可进入面板 | 已同义 |

## Progress

- `2026-02-20`：
  - 完成 Step 1：完成 legado 全链路复核与差异清单落盘。
  - 完成 Step 2：
    - `simple_reader_view.dart` 自动阅读回调改为 `_handleAutoPagerNextTick()`；
    - 翻页模式改为 `PageFactory.moveToNext()` 逐页推进，不再直接 `_loadChapter(next)`。
  - 完成 Step 3：
    - 新增 `_openAutoReadPanel()`；
    - `ClickAction.showMenu` 在自动阅读运行中优先打开自动阅读面板；
    - `_showAutoReadPanel` 与菜单/搜索弹层互斥。
  - 完成 Step 4：
    - 新增 `test/auto_pager_test.dart`，覆盖自动阅读定时触发与 toggle 暂停/恢复。
  - 完成 Step 5：
    - 回填逐项对照清单与命令验证证据。
  - 兼容影响：
    - `autoReadSpeed` 持久化字段与取值范围保持不变；
    - 自动阅读在翻页模式下行为由“跳章”修正为“翻页”，更贴近 legado 语义。

## Surprises & Discoveries

1. 当前 `_showAutoReadPanel` 仅有关闭路径，没有开启路径，导致面板入口不可达。
2. 自动阅读在翻页模式下目前触发“下一章加载”，与 legado 的“下一页推进”语义偏差明显。

## Decision Log

1. 先修复核心可用性（逐页推进 + 边界停机），再补入口语义，不扩大到扩展能力。
2. 保持 `autoReadSpeed` 数据结构不变，避免历史设置迁移风险。

## Outcomes & Retrospective

1. 自动阅读核心功能恢复可用：翻页模式下可按页持续推进。
2. 末页停机与运行态入口语义补齐后，用户可感知自动阅读状态并进行调速/停止操作。
3. 本轮未扩大到 eInk 专属策略，保持核心链路收敛。
