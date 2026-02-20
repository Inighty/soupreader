# 阅读器颜色设置“辅助选择”对齐 legado ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心阅读设置语义对齐）`

## 背景与目标

### 背景

需求方反馈：当前颜色设置入口（阅读样式文字/背景、页眉页脚文字/分割线）均需手动输入 16 进制值，可用性较差。  
对照 legado 后确认：

- `../legado/app/src/main/java/io/legado/app/ui/book/read/config/BgTextConfigDialog.kt`
- `../legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `../legado/app/src/main/java/io/legado/app/help/config/ReadTipConfig.kt`

legado 在上述入口均通过 `ColorPickerDialog(TYPE_CUSTOM)` 进行辅助选色，而非仅手填 Hex。

本项目对应入口：

- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/settings/views/reading_tip_settings_view.dart`

### 目标（Success Criteria）

1. 颜色设置入口支持可视化辅助选择（与 legado 语义同向：先选色再写入配置）。
2. 保留 Hex 精确输入能力，但不再是唯一交互路径。
3. 选色确认后立即生效并保持现有状态流转（copyWith/save）不变。
4. 不引入与阅读主链路无关的扩展入口。

### 非目标（Non-goals）

1. 不改动书源五段链路（search/explore/bookInfo/toc/content）。
2. 不新增主题系统或动态颜色功能。
3. 不改动阅读配置存储结构（`ReadingSettings` 字段语义不变）。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| C1 | `simple_reader_view.dart:_showReadStyleColorInputDialog` | `BgTextConfigDialog.kt:tvTextColor/tvBgColor` | Flutter 侧仅弹窗输入 6 位 Hex；legado 使用可视化颜色选择器 | 颜色配置效率低，误输率高 |
| C2 | `simple_reader_view.dart:_showTipColorInputDialog` | `TipConfigDialog.kt:llTipColor/llTipDividerColor` | Flutter 侧“自定义”后仍需手填；legado 直接进取色器 | 页眉页脚颜色调整成本高 |
| C3 | `reading_tip_settings_view.dart:_showColorInputDialog` | `TipConfigDialog.kt + ReadBookActivity.kt:onColorSelected` | Flutter 页面级设置仍是文本输入语义，缺少可视化反馈 | 设置体验与 legado 不同义 |

## 逐项检查清单（强制）

- 入口：阅读样式“文字颜色/背景颜色”与“页眉页脚文字/分割线颜色”均可进入辅助选色。
- 状态：初始色、已自定义色、默认/同正文色三类状态展示与写入正确。
- 异常：Hex 输入非法时有可观测提示，不写入无效值。
- 文案：标题、提示、按钮语义明确（取消/确定/输入示例）。
- 排版：弹窗在移动端可滚动、无控件遮挡、明暗主题可读。
- 交互触发：预设色点击、滑杆调色、Hex 输入三条路径都能触发最终写入。

## 实施步骤

### Step 1（串行，前置）

- 目标：完成对照与计划落盘。
- 预期结果：差异点、检查清单、风险项明确。
- 验证方式：ExecPlan 文档创建并索引。
- 状态：`completed`

### Step 2（串行，依赖 Step 1）

- 目标：实现可复用颜色辅助选择弹窗（Cupertino 风格）。
- 涉及：
  - `lib/features/reader/widgets/reader_color_picker_dialog.dart`（新增）
- 预期结果：支持预览、预设色、HSV 滑杆、Hex 输入与校验。
- 验证方式：代码编译 + 弹窗交互手工验证。
- 状态：`completed`

### Step 3（并行，依赖 Step 2）

- 目标：替换阅读样式颜色入口。
- 涉及：
  - `lib/features/reader/views/simple_reader_view.dart`
- 预期结果：文字/背景颜色改为辅助选色；写回逻辑保持原语义。
- 验证方式：手工回归路径 A。
- 状态：`completed`

### Step 4（并行，依赖 Step 2）

- 目标：替换页眉页脚颜色入口（设置页 + 阅读器内设置页）。
- 涉及：
  - `lib/features/settings/views/reading_tip_settings_view.dart`
  - `lib/features/reader/views/simple_reader_view.dart`
- 预期结果：自定义颜色入口统一为辅助选色。
- 验证方式：手工回归路径 B/C。
- 状态：`completed`

### Step 5（串行，收尾）

- 目标：执行定向测试并回填对照、进度与结果。
- 验证方式：`flutter test` 定向命令。
- 状态：`completed`

## 逐项对照清单（实现后）

| 编号 | 对照结果 | 说明 |
|---|---|---|
| C1 | 已同义 | `simple_reader_view.dart` 的阅读样式“文字颜色/背景颜色”已从纯 Hex 输入改为可视化辅助选色（预设 + HSV + Hex）。 |
| C2 | 已同义 | `simple_reader_view.dart` 的页眉页脚“文字颜色/分割线颜色”自定义入口已改为辅助选色。 |
| C3 | 已同义 | `reading_tip_settings_view.dart` 的设置页颜色自定义入口已改为辅助选色，保留确定后写回与持久化语义。 |

## 风险与回滚

### 失败模式

1. 弹窗状态管理异常导致选色值未正确回写。
2. 高度受限场景下弹窗内容溢出，操作不可达。
3. Hex 与滑杆状态不同步导致显示错乱。

### 阻塞条件（触发即 `blocked`）

1. 若 Flutter 侧无法稳定实现“可视化选色 + Hex 精确输入”并保持现有语义一致，需要暂停并与需求方确认。

### 回滚策略

1. 文件级回滚：`reader_color_picker_dialog.dart`、`simple_reader_view.dart`、`reading_tip_settings_view.dart`。
2. 保留本 ExecPlan 的差异记录与失败现象，避免重复试错。

## 验收与证据

### 手工回归路径

1. 路径 A：阅读器 -> 样式设置 -> 文字颜色/背景颜色 -> 选择预设色/拖动滑杆/输入 Hex -> 确认后正文颜色立即变化。
2. 路径 B：阅读器 -> 页眉页脚设置 -> 文字颜色/分割线颜色 -> 自定义 -> 选色确认 -> 页眉页脚即时生效。
3. 路径 C：设置页 -> 阅读相关 -> 页眉页脚与标题 -> 文字颜色/分割线颜色 -> 自定义 -> 生效并持久化。

### 命令验证

- 开发阶段不执行 `flutter analyze`。
- 本轮执行定向验证：
  - `flutter test test/reading_tip_settings_view_test.dart`
  - `flutter test test/simple_reader_view_compile_test.dart`

## Progress

- `2026-02-20`：
  - 已完成 Step 1：完成 legado 对照、差异清单、检查清单与计划落盘。
  - 已完成 Step 2：新增 `lib/features/reader/widgets/reader_color_picker_dialog.dart`，提供预览、预设色、HSV 滑杆与 Hex 输入校验。
  - 已完成 Step 3：`simple_reader_view.dart` 的阅读样式颜色入口改用 `showReaderColorPickerDialog`。
  - 已完成 Step 4：`simple_reader_view.dart` 与 `reading_tip_settings_view.dart` 的页眉页脚颜色自定义入口改用 `showReaderColorPickerDialog`。
  - 已完成 Step 5：执行定向验证
    - `flutter test test/reading_tip_settings_view_test.dart`
    - `flutter test test/simple_reader_view_compile_test.dart`
  - 兼容影响：仅调整颜色设置交互，不修改 `ReadingSettings` 字段结构与旧值兼容逻辑。

## Surprises & Discoveries

1. 当前项目存在两处独立“自定义颜色”实现（设置页与阅读器页），均为纯文本输入，存在重复逻辑。
2. 现有颜色字段均为 `int ARGB`，与 legado 取色回写语义天然兼容，可无迁移成本复用。

## Decision Log

1. 先抽取通用选色弹窗，再替换两个入口，避免同类逻辑继续分叉。
2. 保留 Hex 输入作为精确控制通道，但默认交互迁移到可视化选色。
3. 不新增第三方依赖，优先使用现有 Flutter/Cupertino 能力实现，降低集成风险。
4. 对“默认/同正文”这类非自定义状态，进入自定义选色时使用 `0xFFADADAD` 作为初始展示色，仅影响弹窗初值，不改业务语义。

## Outcomes & Retrospective

- 本轮完成了颜色设置交互从“纯手输”到“可视化辅助选择”的迁移，保持了 legado 的核心交互语义方向（自定义时进入取色器）。
- 现有两处重复实现已收敛为一个通用弹窗，后续新增颜色设置入口可直接复用。
- 后续可选优化：若需求方要求更高拟真，可继续补充色盘拖拽区域（当前为预设色 + HSV 滑杆）。
