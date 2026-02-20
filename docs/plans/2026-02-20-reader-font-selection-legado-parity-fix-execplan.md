# 阅读器字体选择失效修复（对照 legado）ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心设置链路修复）`

## 背景与目标

### 背景

需求方反馈：阅读器“选择字体”操作无效，要求先对照 legado 实现后修复。

本轮已完整复核 legado 相关实现：

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/font/FontSelectDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/font/FontAdapter.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/provider/ChapterProvider.kt`
- `/home/server/legado/app/src/main/res/layout/dialog_read_book_style.xml`
- `/home/server/legado/app/src/main/res/layout/item_font.xml`

本项目对应实现：

- `pubspec.yaml`
- `lib/app/theme/typography.dart`
- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/reader/models/reading_settings.dart`
- `lib/features/reader/widgets/page_factory.dart`
- `lib/features/reader/widgets/reader_page_agent.dart`

### 目标（Success Criteria）

1. 字体选择后正文排版可见变化，滚动/分页两种模式都生效。
2. 字体选项语义对齐 legado（系统字体主语义：默认/衬线/等宽）。
3. 设置持久化不变更协议，仅修复“选择后无效”问题。
4. 输出逐项对照与可复现验证步骤。

### 非目标（Non-goals）

1. 不在本轮引入 legado 的“外部字体文件目录选择”扩展能力。
2. 不改动阅读链路无关逻辑（search/explore/bookInfo/toc/content）。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| F1 | `pubspec.yaml` + `typography.dart` | `ChapterProvider.getTypeface` | soupreader 使用未注册字体名（`NotoSerifTC/NotoSansTC/SourceHanMono`），运行时回退默认字体 | 用户感知为“切换无效” |
| F2 | `typography.dart:ReadingFontFamily` | `FontSelectDialog + system_typefaces` | soupreader 字体选项命名与 legado 系统字体语义不对齐 | 设置含义不清晰 |
| F3 | `simple_reader_view.dart` 字体显示行 | `ReadStyleDialog` 文案 | 当前展示原始 fontFamily 字符串，不利于判断是否切换成功 | 可观测性较差 |

## 逐项检查清单（强制）

- 入口：阅读器“界面 -> 字体”可正常打开并切换。
- 状态：切换字体后分页/滚动模式均重排生效。
- 异常：非法索引与旧配置读取时有兜底。
- 文案：字体名称保持业务可理解语义。
- 排版：字体行与选择列表样式不跑版。
- 交互触发：点击选项后立即生效并持久化。

## 实施步骤

### Step 1（串行，前置）

- 目标：确认 legado 字体链路语义和本项目根因。
- 预期结果：明确修复点是“字体族映射与可用性”而非状态持久化。
- 验证方式：代码对照复核（上述 legado/soupreader 文件）。
- 状态：`completed`

### Step 2（串行，依赖 Step 1）

- 目标：修复 `ReadingFontFamily` 的字体映射，确保运行时可用且语义对齐 legacy 系统字体。
- 涉及：
  - `lib/app/theme/typography.dart`
  - `lib/features/reader/views/simple_reader_view.dart`
- 预期结果：字体切换后正文有可见差异，且界面显示用户可理解名称。
- 验证方式：定向测试 + 手工回归路径 A/B。
- 状态：`completed`

### Step 3（串行，收尾）

- 目标：补充测试与计划回填，输出逐项对照清单。
- 预期结果：ExecPlan 状态闭环为 `done`。
- 验证方式：定向测试记录 + 文档更新。
- 状态：`completed`

## 风险与回滚

### 失败模式

1. 不同平台对泛型字体族支持差异导致个别平台效果不明显。
2. 字体名称改动影响已有设置文案显示。

### 阻塞条件（触发即 `blocked`）

1. 若需引入外部字体文件目录选择能力才可达成同义，则本轮暂停并走例外流程。

### 回滚策略

1. 文件级回滚：`typography.dart`、`simple_reader_view.dart`。
2. 保留本 ExecPlan 记录与对照结论，避免重复排查。

## 验收与证据

### 手工回归路径

1. 路径 A：阅读页 -> 界面 -> 字体，依次选择“系统默认/衬线字体/无衬线字体/等宽字体”。
2. 路径 B：在分页模式与滚动模式分别观察正文字形变化并重进页面验证持久化。

### 命令验证

- 开发阶段仅执行定向测试，不执行 `flutter analyze`。
- 提交前才执行一次 `flutter analyze`（本轮尚未到提交阶段）。
- 已执行：
  - `flutter test test/reading_font_family_test.dart test/reading_settings_test.dart`

## 逐项对照清单（实现后）

| 项目 | legado 基准 | 当前实现 | 结论 |
|---|---|---|---|
| 字体主语义 | `system_typefaces`: 默认/衬线/等宽 | `ReadingFontFamily` 改为系统默认/衬线/无衬线/等宽（保留兼容项） | 已同义（含兼容扩展） |
| 字体可用性 | `ChapterProvider.getTypeface` 使用系统字体或文件字体 | Flutter 侧不再引用未注册字体名，改用系统泛型字体族 `serif/sans-serif/monospace` | 已同义 |
| 设置触发链路 | `ReadStyleDialog -> FontSelectDialog` 选择后即时生效 | `界面 -> 字体` 点击后触发 `_updateSettings(fontFamilyIndex)`，分页/滚动均重排 | 已同义 |
| 用户可观测性 | 字体项名称可理解 | 字体行显示名称，不再显示底层 family 字符串；列表项提供字体预览 | 已同义 |
| 持久化协议 | 存储字体配置并重进可恢复 | 继续使用既有 `fontFamilyIndex`，未改协议 | 已同义 |

## Progress

- `2026-02-20`：
  - 完成 Step 1：完成 legado 字体链路复核与根因确认。
  - 完成 Step 2：
    - `lib/app/theme/typography.dart`：将字体映射改为系统泛型字体族（`serif/sans-serif/monospace`），并按 legado 语义更新字体项名称；
    - `lib/features/reader/views/simple_reader_view.dart`：字体行显示改为字体名称；字体选择弹层列表项增加对应字体预览。
  - 完成 Step 3：
    - 新增 `test/reading_font_family_test.dart`，覆盖字体语义映射与索引兜底；
    - 执行 `flutter test test/reading_font_family_test.dart test/reading_settings_test.dart` 通过；
    - 回填 ExecPlan 与 `PLANS.md` 索引状态。
  - 兼容影响：
    - 仅改变字体族映射和显示文案，不改 `fontFamilyIndex` 持久化结构；
    - 历史配置可直接复用，非法索引继续回退“系统默认”。

## Surprises & Discoveries

1. 根因并非设置未保存，而是字体名在当前 Flutter 工程中不可用，导致回退默认字体。
2. legado 的系统字体主语义是“默认/衬线/等宽”，当前 soupreader 字体命名与此不一致。

## Decision Log

1. 本轮优先修复核心字体可用性，不提前实现“外部字体目录导入”扩展能力。
2. 保持 `fontFamilyIndex` 持久化协议不变，避免旧数据迁移风险。

## Outcomes & Retrospective

1. 已修复“选择字体无效”的核心问题：不再引用工程内不存在的字体名。
2. 字体设置可观测性提升：用户能直接看到当前字体名称及选项预览。
3. 未引入扩展字体导入流程，保持核心链路收敛，后续若需复刻 legado 外部字体目录能力可单开任务推进。
