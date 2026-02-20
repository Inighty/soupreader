# 阅读器底部四入口栏排版对齐 legado（目录/朗读/界面/设置）ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心阅读 UI 排版）`

## 背景与目标

### 背景

需求方明确本轮只关注底部四入口栏：`目录 / 朗读 / 界面 / 设置`。  
本轮 legacy 对照基准（已完整阅读）：

- `../legado/app/src/main/res/layout/view_read_menu.xml`（`ll_catalog`、`ll_read_aloud`、`ll_font`、`ll_setting`）
- `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`（四入口点击与长按触发）

当前 soupreader 对应实现：

- `lib/features/reader/widgets/reader_bottom_menu.dart`
- `lib/features/reader/views/simple_reader_view.dart`

### 目标（Success Criteria）

1. 四入口行在布局语义上对齐 legacy：顺序、热区宽度、图标与文案垂直排布节奏同义。
2. 四入口触发语义保持同义（目录点击、朗读点击/长按、界面点击、设置点击）。
3. 仅修改四入口栏排版，不扩展到搜索正文/快捷动作区迁移。

### 非目标（Non-goals）

1. 不改动右侧快捷动作区与搜索正文工具链。
2. 不改动亮度侧栏与章节进度逻辑。
3. 不改动设置模型与持久化字段。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| BT1 | `reader_bottom_menu.dart:_buildBottomTabs` | `view_read_menu.xml:四入口行` | 行外层额外 `top/bottom` 补白，四入口垂直重心偏离 legacy | 四入口观感位置偏低，节奏不一致 |
| BT2 | `reader_bottom_menu.dart:_buildTabItem` | `view_read_menu.xml:iv_*/tv_*` | 图标/文字参数与 legacy 存在轻微偏差（icon=19、font=11.5） | 信息层级与可读性略弱 |
| BT3 | `reader_bottom_menu.dart:_buildTabItem` | `ReadMenu.kt:llReadAloud` | 非激活态文案字重偏重 | 与 legacy 常态视觉不一致 |

## 逐项检查清单（强制）

- 入口：`目录/朗读/界面/设置` 四入口可见且顺序正确。
- 状态：`朗读` 在运行态与暂停态图标反馈正确，长按仍可触发。
- 异常：小屏/大屏下四入口无重叠、无截断。
- 文案：四入口文案保持 legacy 业务语义。
- 排版：热区、图标与标签间距、行内留白与 legacy 同义。
- 交互触发：点击/长按回调映射正确。

## 实施步骤

### Step 1（串行，前置）

- 目标：输出差异清单并落盘 ExecPlan。
- 验证方式：计划文档创建 + `PLANS.md` 索引登记。
- 状态：`completed`

### Step 2（串行，依赖 Step 1）

- 目标：仅调整 `ReaderBottomMenuNew` 四入口栏排版参数。
- 涉及：
  - `lib/features/reader/widgets/reader_bottom_menu.dart`
- 验证方式：编译通过 + 手工排版检查。
- 状态：`completed`

### Step 3（串行，依赖 Step 2）

- 目标：补充并执行定向测试，验证四入口行为未回归。
- 涉及：
  - `test/reader_bottom_menu_new_test.dart`
- 验证方式：`flutter test` 定向命令。
- 状态：`completed`

### Step 4（串行，收尾）

- 目标：回填逐项对照清单、检查结果与结论。
- 状态：`completed`

## 风险与回滚

### 失败模式

1. 排版参数收敛后，某些窄屏机型出现文案拥挤。

### 阻塞条件（触发即 `blocked`）

1. 若无法在四入口热区不变前提下同时满足可读性与点击稳定性，需暂停并确认。

### 回滚策略

1. 文件级回滚：
   - `lib/features/reader/widgets/reader_bottom_menu.dart`
   - `test/reader_bottom_menu_new_test.dart`

## 验收与证据

## 逐项对照清单（实现后）

| 编号 | 对照项 | 结果 | 说明 |
|---|---|---|---|
| BT1 | 四入口行外层留白 | 已同义（优化后） | 四入口行外层 `top/bottom` 额外补白已收敛为 `0`，与 legacy 节奏一致 |
| BT2 | 图标与文字尺寸 | 已同义（优化后） | 图标尺寸调至 `20`，文案字号调至 `12`，对齐 legacy 的 `maxHeight=20dp` 与 `textSize=12sp` |
| BT3 | 非激活态字重 | 已同义（优化后） | 非激活态字重从偏重收敛为常规字重，降低视觉噪音 |

### 手工回归路径

1. 阅读页呼出菜单，检查四入口顺序与排版。
2. 点击 `目录/朗读/界面/设置`，核对触发行为。
3. 长按 `朗读`，核对长按回调。

### 命令验证

- 开发过程不执行 `flutter analyze`。
- 本轮执行：
  - `flutter test test/reader_bottom_menu_new_test.dart`
  - `flutter test test/simple_reader_view_compile_test.dart`

### 逐项检查清单回填（结果）

- 入口：通过。`目录/朗读/界面/设置` 顺序未变，入口可见性正常。
- 状态：通过。`朗读` 运行/暂停图标反馈与长按回调保持可用。
- 异常：通过。四入口在当前测试屏幕下无重叠与截断。
- 文案：通过。四入口文案保持 legacy 业务语义。
- 排版：通过。图标/字号/行留白参数已收敛，视觉节奏更贴近 legacy。
- 交互触发：通过。四入口点击与长按映射测试全部通过。

## Progress

- `2026-02-20`：
  - 已完成 Step 1：需求澄清并重置差异清单（仅四入口栏）。
  - 已完成 Step 2：四入口行排版参数对齐（图标尺寸、字号、行留白、字重）。
  - 已完成 Step 3：新增并通过四入口图标/字号回归测试。
  - 已完成 Step 4：逐项对照与检查清单回填，计划关闭。
  - 兼容影响：仅影响底部四入口栏视觉排版，不改动业务状态流转与持久化。

## Surprises & Discoveries

1. 本轮需求范围已明确收敛为“四入口栏”，不包含快捷动作区迁移。
2. 四入口行外层少量补白与字重偏重，是“看起来不像 legacy”的主要视觉来源。

## Decision Log

1. 保留现有入口语义，仅做四入口排版参数收敛，避免超范围改动。
2. 不改动快捷动作区承载位置，避免再次偏离需求边界。

## Outcomes & Retrospective

- 结果：底部四入口栏已完成参数对齐，视觉节奏与 legacy 更接近。
- 质量：定向测试通过，覆盖入口顺序、热区、图标字号与朗读长按状态。
- 后续：若你需要，我可以继续按截图把四入口图标本体风格（glyph 形状）再对齐 legacy 资源语义。
