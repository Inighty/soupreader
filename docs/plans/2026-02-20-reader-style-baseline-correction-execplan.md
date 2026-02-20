# 2026-02-20 阅读器风格基准修正（按“之前界面风格”对齐 legado 入口语义）

状态：`done`

## 背景与目标
用户反馈“统一风格弄错了，应该按之前界面风格为准”。
上一轮改动将 `界面/设置/信息` 入口统一到了同一弹层壳子，虽然视觉一致，但与 legado 的入口语义不一致：
- `界面` 应对应样式弹层（ReadStyleDialog 语义）；
- `设置` 应对应行为设置弹层（MoreConfigDialog 语义）；
- `信息` 应对应页眉页脚信息弹层（TipConfigDialog 语义）。

本次目标：恢复“之前界面风格”基准，保持已完成的功能修复（自动阅读、正文高亮、字体切换、取色器增强）不回退。

## 范围
- `lib/features/reader/views/simple_reader_view.dart`
- `PLANS.md`
- 本 ExecPlan 文档

## 非目标
- 不修改阅读器五段链路（search/explore/bookInfo/toc/content）抓取与解析逻辑。
- 不回退此前已完成的功能修复（自动阅读/高亮/字体/取色器）。
- 不执行 `flutter analyze`。

## 成功标准
1. 底部工具栏 `界面` 入口回到旧风格样式弹层。
2. 底部工具栏 `设置` 入口回到旧风格行为设置弹层。
3. `信息` 入口回到旧风格信息弹层。
4. 已修复功能不受影响，定向测试通过。

## legado 对照文件（已读取）
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`（showReadStyle/showMoreSetting 入口链）

## 差异点清单（实现前）
| 编号 | soupreader 位置 | legado 对照 | 差异描述 | 影响 |
|---|---|---|---|---|
| SB-1 | `simple_reader_view.dart:_openInterfaceSettingsFromMenu` | `ReadMenu.llFont -> ReadBookActivity.showReadStyle -> ReadStyleDialog` | soupreader 直接进入统一页签壳子 | 与“之前界面风格”不一致 |
| SB-2 | `simple_reader_view.dart:_openBehaviorSettingsFromMenu` | `ReadMenu.llSetting -> ReadBookActivity.showMoreSetting -> MoreConfigDialog` | soupreader 直接进入统一页签壳子 | 设置页风格偏离基准 |
| SB-3 | `simple_reader_view.dart:_showLegacyTipConfigDialog` | `TipConfigDialog` 独立弹层 | soupreader 改为统一壳子子页 | 信息页视觉与交互层级变化 |

## 逐项检查清单（实现前）
- 入口：`界面/设置/信息` 三个入口路径。
- 状态：弹层打开、关闭、设置回写状态。
- 异常：弹层切换与快速关闭不崩溃。
- 文案：入口文案与标题语义一致。
- 排版：恢复旧风格容器高度、圆角、间距节奏。
- 交互触发：点击/长按/关闭动作保持可用。

## 实施步骤
1. 恢复入口路由
   - 预期：`界面`/`设置` 不再走统一页签壳子。
   - 验证：代码审查 + 运行时手工路径。
2. 恢复旧风格弹层壳子
   - 预期：`_showReadStyleDialog`、`_showLegacyMoreConfigDialog`、`_showLegacyTipConfigDialog` 回到旧实现。
   - 验证：代码审查 + 编译测试。
3. 回归验证与文档回填
   - 预期：相关测试通过，计划状态闭环。
   - 验证：定向 `flutter test` + 文档更新。

## 风险与回滚
- 风险 1：回退弹层壳子时误伤最近修复逻辑。
  - 缓解：仅改入口与弹层壳子函数，不改自动阅读/高亮/字体/取色器路径。
- 风险 2：老弹层与新设置组件并存，后续维护复杂。
  - 缓解：保留 `_showReadingSettingsSheet`，但不作为本轮主入口。

回滚策略：仅回滚 `simple_reader_view.dart` 本次提交。

## 验收与证据
- 命令验证：
  - `flutter test test/simple_reader_view_compile_test.dart test/reader_bottom_menu_new_test.dart`
  - `flutter test test/reading_font_family_test.dart`
- 手工回归路径：
  - 路径 A：阅读页 -> 底部 `界面` -> 样式弹层。
  - 路径 B：阅读页 -> 底部 `设置` -> 行为设置弹层。
  - 路径 C：阅读页 -> 界面弹层中的 `信息` -> 信息弹层。

## Progress
- [done] 完成 legado 入口链与弹层实现对照。
- [done] 完成入口路由恢复（界面/设置）。
- [done] 完成三个弹层壳子恢复（界面/设置/信息）。
- [done] 完成定向测试与文档回填。
- [done] 按用户最新口径“与 legado 一致（功能排版）”回补设置弹层高度与圆角语义。

## Surprises & Discoveries
- 统一外壳并不等于“同义迁移”；用户明确把“之前界面风格”作为验收基准。
- 现有代码同时保留了统一壳子与旧壳子能力；入口选择决定了最终体验。
- 当口径切换为“与 legado 一致”时，`设置` 弹层与 `界面` 弹层本身并非同壳风格，这是 legado 原始行为。

## Decision Log
- 决策 1：不回退此前功能修复，只回退风格壳子和入口路由。
- 决策 2：保留 `_showReadingSettingsSheet` 作为内部能力，避免大规模删改。
- 决策 3：以 legado 分离入口语义为准（界面/设置/信息分层）。
- 决策 4：按用户新增指令“与 legado 一致 功能排版”，将 `设置` 弹层还原为 legado 的固定高度（360 + bottomInset）与 14 圆角语义，而非跟随 `界面` 弹层壳子。

## Outcomes & Retrospective
### 做了什么
- `simple_reader_view.dart`
  - `_openInterfaceSettingsFromMenu` 改回 `_showReadStyleDialog()`。
  - `_openBehaviorSettingsFromMenu` 改回 `_showLegacyMoreConfigDialog()`。
  - `_showReadStyleDialog` 恢复为旧风格样式弹层实现。
  - `_showLegacyMoreConfigDialog` 恢复为旧风格 360dp 级别行为设置弹层。
  - `_showLegacyTipConfigDialog` 恢复为旧风格信息弹层实现。

### 后续回补（同日）
- `simple_reader_view.dart`
  - 在“以界面弹层为基准”的临时调整后，再按用户口径回补为 legado 同义：
  - `_showLegacyMoreConfigDialog` 使用 `height: 360 + bottomInset`。
  - `_showLegacyMoreConfigDialog` 圆角语义恢复 `Radius.circular(14)`。
- 结论：
  - 当前实现与 legado 在“界面/设置”弹层入口和布局语义保持同义，不再强行同壳。

### 为什么
- 用户明确要求以“之前界面风格”为基准；且 legado 对应能力本身是分离弹层语义。

### 如何验证
- `flutter test test/simple_reader_view_compile_test.dart test/reader_bottom_menu_new_test.dart` 通过。
- `flutter test test/reading_font_family_test.dart` 通过。

### 兼容影响
- 仅 UI 入口与弹层壳子调整，设置数据模型与存储字段未变化。
- 自动阅读、正文搜索高亮、字体 fallback、取色器增强逻辑保持不变。
