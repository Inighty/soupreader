# 阅读器侧边亮度栏优化（对照 legado）ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心阅读 UI 交互优化）`

## 背景与目标

### 背景

需求方反馈：阅读器界面侧边亮度栏需要进一步优化。  
本轮已完整对照 legado 相关实现：

- `../legado/app/src/main/res/layout/view_read_menu.xml`（`ll_brightness`）
- `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`（`upBrightnessState`、`upBrightnessVwPos`）

当前 soupreader 对应实现：

- `lib/features/reader/widgets/reader_bottom_menu.dart`（`ReaderBottomMenuNew._buildBrightnessPanel`）

### 目标（Success Criteria）

1. 保持 legado 同义能力：自动亮度切换、手动亮度滑杆、左右位置切换。
2. 优化侧栏体感：避免超长亮度条占据过大视觉面积，提升可读与可操作性。
3. 在不同设备高度下保持稳定布局，不出现压缩或溢出。
4. 不改动亮度持久化字段与读写语义。

### 非目标（Non-goals）

1. 不改动系统亮度服务层（`ScreenBrightnessService`）。
2. 不改动底部菜单其它功能入口语义。
3. 不引入新 UI 组件体系。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| B1 | `reader_bottom_menu.dart:_buildBrightnessPanel` | `view_read_menu.xml:ll_brightness` | Flutter 侧亮度栏高度随可用区无限放大，长屏下过长 | 视觉占位过重，拖动距离过长 |
| B2 | `reader_bottom_menu.dart:panelColor` | `ReadMenu.kt:llBrightness.background` | 当前浅色主题透明度较高，侧栏观感偏“整块发白” | 干扰正文阅读 |
| B3 | `reader_bottom_menu.dart` | `ReadMenu.kt:upBrightnessState`/`upBrightnessVwPos` | 功能语义已同义，但缺少“高度上限”约束 | 缺少稳定体验兜底 |

## 逐项检查清单（强制）

- 入口：阅读菜单展示时亮度栏可见（开关开启条件下）。
- 状态：自动亮度开关、手动滑杆、左右位置切换均可用。
- 异常：小高度与大高度设备均不出现溢出、抖动、不可拖动。
- 文案：无新增文案，保持现状。
- 排版：亮度栏高度有上限，视觉不压迫正文区域。
- 交互触发：滑杆拖动实时生效，自动亮度模式下滑杆不可交互。

## 实施步骤

### Step 1（串行，前置）

- 目标：对照 legado，落盘差异点与检查清单。
- 验证方式：ExecPlan 文档创建 + 索引登记。
- 状态：`completed`

### Step 2（串行，依赖 Step 1）

- 目标：优化亮度侧栏布局参数（高度限制、透明度、尺寸细节）。
- 涉及：
  - `lib/features/reader/widgets/reader_bottom_menu.dart`
- 验证方式：编译通过 + 手工视觉检查。
- 状态：`completed`

### Step 3（串行，依赖 Step 2）

- 目标：补充定向测试，防止亮度栏高度回归。
- 涉及：
  - `test/reader_bottom_menu_new_test.dart`
- 验证方式：`flutter test` 定向命令。
- 状态：`completed`

### Step 4（串行，收尾）

- 目标：回填逐项对照、Progress、结果总结并关闭计划。
- 状态：`completed`

## 风险与回滚

### 失败模式

1. 侧栏高度过短导致滑杆可用区不足。
2. 透明度调整后在深浅主题之一可读性下降。

### 阻塞条件（触发即 `blocked`）

1. 若在保持 legado 同义能力前提下无法同时满足“可读性 + 可操作性”，需暂停并与需求方确认。

### 回滚策略

1. 文件级回滚：
   - `lib/features/reader/widgets/reader_bottom_menu.dart`
   - `test/reader_bottom_menu_new_test.dart`

## 逐项对照清单（实现后）

| 编号 | 对照项 | 结果 | 说明 |
|---|---|---|---|
| B1 | 亮度栏高度策略 | 已同义（优化后） | 保持 legado 三段结构语义，新增高度上限（最大 400）避免长屏空白拉长 |
| B2 | 亮度栏背景观感 | 已同义（优化后） | 透明度由浅色偏高调整为更接近 legado 的半透明观感，降低正文干扰 |
| B3 | 自动亮度/滑杆/左右切换语义 | 已同义 | 保持开关、滑杆禁用逻辑与左右切换行为不变，`key` 不变 |

## 验收与证据

### 手工回归路径

1. 阅读页呼出菜单，确认亮度栏在左侧显示且高度不过长。
2. 切换“自动亮度”开关，验证图标状态与滑杆可用性。
3. 点击位置切换按钮，验证侧栏左右切换。

### 命令验证

- 开发过程不执行 `flutter analyze`。
- 本轮执行：
  - `flutter test test/reader_bottom_menu_new_test.dart`
  - `flutter test test/simple_reader_view_compile_test.dart`

### 逐项检查清单回填（结果）

- 入口：通过。阅读菜单展示时亮度栏正常出现，位置与显隐逻辑未变。
- 状态：通过。自动亮度切换、手动滑杆、左右位置切换均正常。
- 异常：通过。长屏下亮度栏不再无限拉长；小高度情况下面板按可用高度收缩，无溢出。
- 文案：通过。未新增或修改用户可见文案。
- 排版：通过。亮度栏最大高度固定，视觉占位明显收敛。
- 交互触发：通过。滑杆拖动实时更新，自动亮度开启时滑杆保持不可交互。

## Progress

- `2026-02-20`：
  - 已完成 Step 1：对照 legado 并形成差异清单。
  - 已完成 Step 2：实现亮度栏高度上限（最大 400）与透明度收敛，保留 legado 交互语义。
  - 已完成 Step 3：新增“长屏高度受限”回归测试并通过定向测试。
  - 已完成 Step 4：逐项对照与检查清单回填，计划关闭。
  - 兼容影响：仅影响阅读菜单亮度侧栏 UI，不改动设置结构、持久化字段与服务层行为。

## Surprises & Discoveries

1. 当前亮度栏通过 `Expanded` 吃满可用高度，长屏设备视觉负担明显。
2. 旧实现虽对滑杆长度做了 320 上限，但容器仍会拉满，导致“空白背景条”成为主要视觉问题。

## Decision Log

1. 保留 legado 的三项核心交互语义不变，仅优化容器高度策略与观感参数。
2. 采用“容器高度上限 + 滑杆区域自适应”的方式，而非改动顶部/底部定位规则，降低行为偏移风险。
3. 通过新增单测固定“长屏高度上限”行为，避免后续回归。

## Outcomes & Retrospective

- 结果：已完成侧边亮度栏优化，长屏下不再出现过长亮度白条，交互语义与 legado 保持同义。
- 质量：新增并通过定向测试，覆盖亮度栏高度上限场景。
- 后续：若需求方需要进一步贴近 legado 的“面板角半径/边框强度”细节，可在不改交互语义前提下继续微调视觉参数。
