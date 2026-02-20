# 阅读器顶部栏排版对齐 legado ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心阅读交互排版修正）`

## 背景与目标

### 背景

需求方反馈：阅读器顶部栏“只能看到一点小说名和一点网址”，信息可读性明显不足。  
对照 legado 已完整阅读：

- `../legado/app/src/main/res/layout/view_read_menu.xml`（467 行，完整）
- `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`（590 行，完整）

本项目对应实现：

- `lib/features/reader/widgets/reader_menus.dart`
- `lib/features/reader/views/simple_reader_view.dart`

### 目标（Success Criteria）

1. 顶部栏排版语义与 legado 同向：信息区优先，操作区不挤占章节文本可读宽度。
2. 书名、章节名、章节链接在常见设备宽度下可稳定显示有效文本（而非仅 1~2 个字符）。
3. 不丢失既有操作入口（书源操作、目录、更多、搜索等通过现有菜单/快捷区保留）。
4. 保持 `Shadcn + Cupertino` 组件栈，不引入其它 UI 体系。

### 非目标（Non-goals）

1. 不改动阅读正文渲染与翻页逻辑。
2. 不改动右侧快捷栏功能定义（仅必要联动）。
3. 不改动阅读设置数据模型。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| T1 | `reader_menus.dart:ReaderTopMenu` | `view_read_menu.xml:title_bar_addition` | 当前顶栏同一行放置多枚操作按钮，章节信息被压缩；legado 为“章节信息区 + 书源按钮”优先布局 | 书名/链接可读性差 |
| T2 | `reader_menus.dart:_buildActionChip` | `view_read_menu.xml:tv_source_action` | 当前书源 chip 在小屏 maxWidth 仅 56/74；legado 为 maxWidth 120dp 且不与大量按钮同排竞争 | 书源名截断严重 |
| T3 | `simple_reader_view.dart:ReaderTopMenu 调用` | `ReadMenu.kt:upBookView + bindEvent` | 顶栏承载过多重复动作（刷新/搜索/目录/更多/净化），与 legado 职责拆分不同 | 顶栏信息主次颠倒 |

## 逐项检查清单（强制）

- 入口：显示菜单后，顶部栏可见且书名/章节/链接文本区优先展示。
- 状态：`showReadTitleAddition` 开/关两种状态下排版都不走样。
- 异常：本地书籍（无在线链接）时链接与书源动作的展示逻辑正确。
- 文案：标题与按钮文案保持既有业务语义。
- 排版：信息层级（书名 > 章节名 > 链接）清晰，右侧操作不挤压信息区。
- 交互触发：书名点击、章节链接点击/长按、书源动作点击保持可用。

## 实施步骤

### Step 1（串行，前置）

- 目标：完成对照与 ExecPlan 落盘。
- 验证方式：计划文档创建 + `PLANS.md` 索引登记。
- 状态：`completed`

### Step 2（串行，依赖 Step 1）

- 目标：重构 `ReaderTopMenu` 顶栏信息布局（两层文本 + 右侧书源动作）。
- 涉及：
  - `lib/features/reader/widgets/reader_menus.dart`
- 验证方式：编译通过 + 手工检查布局。
- 状态：`completed`

### Step 3（并行，依赖 Step 2）

- 目标：同步 `simple_reader_view.dart` 顶栏调用参数，移除顶部重复动作占位。
- 涉及：
  - `lib/features/reader/views/simple_reader_view.dart`
- 验证方式：编译通过 + 行为回归。
- 状态：`completed`

### Step 4（串行，收尾）

- 目标：定向测试并回填逐项对照与证据。
- 验证方式：
  - `flutter test test/simple_reader_view_compile_test.dart`
  - `flutter test test/reader_bottom_menu_new_test.dart`
- 状态：`completed`

## 逐项对照清单（实现后）

| 编号 | 对照结果 | 说明 |
|---|---|---|
| T1 | 已同义 | `ReaderTopMenu` 改为“书名主行 + 章节附加行”信息优先结构，不再同排堆叠多枚操作按钮。 |
| T2 | 已同义 | 书源动作改为独立右侧 chip，最大宽度调整为 `120`，与 legado 语义一致。 |
| T3 | 已同义 | `simple_reader_view.dart` 顶栏调用移除重复动作参数，顶部不再承载搜索/目录/刷新/净化占位。 |

## 风险与回滚

### 失败模式

1. 顶部动作简化后，用户感知入口位置变化。
2. 顶栏高度变化与右侧快捷栏位置出现轻微重叠。

### 阻塞条件（触发即 `blocked`）

1. 若在 `Shadcn + Cupertino` 下无法保证信息区可读且交互不回退，需要暂停并与需求方确认。

### 回滚策略

1. 文件级回滚：
   - `lib/features/reader/widgets/reader_menus.dart`
   - `lib/features/reader/views/simple_reader_view.dart`
2. 保留本计划中的差异与决策记录，便于回退后再次推进。

## 验收与证据

### 手工回归路径

1. 打开任意在线书籍 -> 呼出阅读菜单 -> 检查顶栏书名/章节名/链接展示宽度。
2. 点击章节名/链接，验证打开逻辑；长按验证“浏览器/应用内打开”切换。
3. 切换“显示标题附加信息”开关后重复 1/2，确认排版稳定。

### 命令验证

- 开发阶段不执行 `flutter analyze`。
- 本轮执行定向测试：
  - `flutter test test/simple_reader_view_compile_test.dart`
  - `flutter test test/reader_bottom_menu_new_test.dart`

## Progress

- `2026-02-20`：
  - 已完成 Step 1：对照 legado 顶部栏实现并完成 ExecPlan 落盘。
  - 已完成 Step 2：`reader_menus.dart` 顶栏布局重构为两层信息区 + 右侧书源动作区。
  - 已完成 Step 3：`simple_reader_view.dart` 顶栏调用参数同步，移除顶部重复动作占位。
  - 已完成 Step 4：执行定向验证：
    - `flutter test test/simple_reader_view_compile_test.dart`
    - `flutter test test/reader_bottom_menu_new_test.dart`
  - 兼容影响：仅影响阅读菜单顶部栏排版与入口分布，不改动阅读数据与书源逻辑。

## Surprises & Discoveries

1. 当前顶部栏与右侧快捷栏存在功能重复，导致顶部区域信息可读性下降。
2. `ReaderTopMenu` 小屏 source chip 限宽策略偏保守，放大了文本拥挤问题。

## Decision Log

1. 先修正“信息区宽度被挤压”主问题，再考虑细节视觉微调。
2. 顶栏遵循 legado 的信息优先策略：减少同排操作按钮数量。
3. 保留现有功能入口，但优先复用底部菜单/快捷栏，避免顶栏再堆叠按钮。

## Outcomes & Retrospective

- 当前问题“书名与网址仅显示少量字符”已从布局层面修复：文本区得到稳定可用宽度。
- 顶部栏职责回归信息展示，功能入口由底部菜单与快捷栏承接，整体与 legado 的信息优先策略更一致。
