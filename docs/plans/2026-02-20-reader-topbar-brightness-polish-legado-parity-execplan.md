# 阅读器顶部栏与亮度栏优化（基于 IMG_6992，对照 legado）ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心阅读 UI 排版与可读性优化）`

## 背景与目标

### 背景

需求方要求：参考根目录最新截图 `IMG_6992.PNG`，优化阅读器顶部栏与亮度栏。  
本轮 legacy 对照基准（已完整读取）：

- `../legado/app/src/main/res/layout/view_read_menu.xml`（`title_bar_addition`、`ll_brightness`）
- `../legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`（顶部信息更新与亮度栏状态逻辑）

当前 soupreader 对应实现：

- `lib/features/reader/widgets/reader_menus.dart`（`ReaderTopMenu`）
- `lib/features/reader/widgets/reader_bottom_menu.dart`（`_buildBrightnessPanel`）

### 目标（Success Criteria）

1. 顶部栏在窄屏与常规屏均保证书名/章节信息可读，不出现信息区被过度挤压。
2. 亮度栏在浅色主题下视觉干扰降低，同时保持 legacy 同义交互（自动亮度、滑杆、左右切换）。
3. 顶部栏与亮度栏间距关系更稳定，不与正文或底栏形成突兀遮挡。
4. 不改动业务链路与设置持久化语义。

### 非目标（Non-goals）

1. 不改动四入口菜单（目录/朗读/界面/设置）行为。
2. 不改动快捷动作区功能语义。
3. 不改动阅读内容渲染与翻页逻辑。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| TB1 | `reader_menus.dart:ReaderTopMenu` | `view_read_menu.xml:title_bar_addition` | 顶部信息区在窄屏下章节 URL 与书源按钮竞争宽度 | 章节信息可读性下降 |
| TB2 | `reader_menus.dart` 渐变与文本层级 | `ReadMenu.kt:initView` | 顶部栏对正文对比度保护偏弱 | 叠层场景下辨识度下降 |
| BR1 | `reader_bottom_menu.dart:_buildBrightnessPanel` | `view_read_menu.xml:ll_brightness` | 浅色主题亮度栏仍偏亮、存在感偏强 | 正文阅读干扰 |
| BR2 | `reader_bottom_menu.dart` 固定 top/bottom offset | `view_read_menu.xml` 约束布局 | 顶部附加信息开关变化时亮度栏顶端间距不够自适应 | 局部设备下视觉拥挤 |

## 逐项检查清单（强制）

- 入口：顶部栏显示时书名/章节/书源操作区结构稳定可读。
- 状态：`showReadTitleAddition` 开/关都不走样。
- 异常：窄屏下 URL 降级策略生效，不影响章节名与书源可见性。
- 文案：不新增业务文案，不改现有语义。
- 排版：亮度栏在浅色主题存在感降低，且与顶部/底部区块间距稳定。
- 交互触发：章节链接点击/长按、亮度开关/滑杆/位置切换语义保持同义。

## 实施步骤

### Step 1（串行，前置）

- 目标：落盘差异清单与检查清单。
- 验证方式：ExecPlan 创建 + `PLANS.md` 索引登记。
- 状态：`completed`

### Step 2（串行，依赖 Step 1）

- 目标：优化顶部栏排版策略（信息优先 + 窄屏 URL 降级）。
- 涉及：
  - `lib/features/reader/widgets/reader_menus.dart`
- 验证方式：编译通过 + 手工可读性检查。
- 状态：`completed`

### Step 3（串行，依赖 Step 2）

- 目标：优化亮度栏视觉参数与定位策略（附加信息开关联动）。
- 涉及：
  - `lib/features/reader/widgets/reader_bottom_menu.dart`
- 验证方式：亮度栏行为与现有测试一致。
- 状态：`completed`

### Step 4（串行，依赖 Step 3）

- 目标：补测试并执行定向回归。
- 涉及：
  - `test/reader_top_menu_test.dart`（新增）
  - `test/reader_bottom_menu_new_test.dart`（增补）
- 验证方式：`flutter test` 定向命令。
- 状态：`completed`

### Step 5（串行，收尾）

- 目标：回填逐项对照、检查清单结果、Progress 并关闭计划。
- 状态：`completed`

## 风险与回滚

### 失败模式

1. 顶部栏 URL 降级阈值设置不当，导致正常宽度下信息展示过少。
2. 亮度栏 alpha 过低导致暗色主题对比不足。

### 阻塞条件（触发即 `blocked`）

1. 若在保持 legacy 语义前提下无法同时满足“可读性 + 可操作性”，需暂停并确认。

### 回滚策略

1. 文件级回滚：
   - `lib/features/reader/widgets/reader_menus.dart`
   - `lib/features/reader/widgets/reader_bottom_menu.dart`
   - `test/reader_top_menu_test.dart`
   - `test/reader_bottom_menu_new_test.dart`

## 验收与证据

## 逐项对照清单（实现后）

| 编号 | 对照项 | 结果 | 说明 |
|---|---|---|---|
| TB1 | 顶部信息区宽度竞争 | 已同义（优化后） | 顶部栏改为“章节名优先，窄屏 URL 降级”，避免章节信息被书源按钮挤压 |
| TB2 | 顶部对比度保护 | 已同义（优化后） | 渐变与控制区底色透明度收敛，信息区辨识度提升 |
| BR1 | 亮度栏浅色观感 | 已同义（优化后） | 使用混色收敛浅色亮度栏白度，减少正文干扰 |
| BR2 | 亮度栏顶端适配 | 已同义（优化后） | `showReadTitleAddition=true` 时亮度栏自动下移，避免顶部信息区拥挤 |

### 手工回归路径

1. 呼出阅读菜单，确认顶部栏书名/章节名可读，URL 在窄屏下按预期降级。
2. 切换标题附加信息开关，确认顶部栏与亮度栏相对位置稳定。
3. 切换自动亮度、拖动亮度滑杆、左右切换亮度栏位置，确认功能同义。

### 命令验证

- 开发过程不执行 `flutter analyze`。
- 本轮执行：
  - `flutter test test/reader_top_menu_test.dart`
  - `flutter test test/reader_bottom_menu_new_test.dart`
  - `flutter test test/simple_reader_view_compile_test.dart`

### 逐项检查清单回填（结果）

- 入口：通过。顶部栏书名/章节/书源结构稳定，且与 legacy 信息层级一致。
- 状态：通过。`showReadTitleAddition` 开/关下顶部栏与亮度栏布局均稳定。
- 异常：通过。窄屏下 URL 自动降级隐藏，章节名与书源按钮可见。
- 文案：通过。未新增业务文案，原有文案语义保持不变。
- 排版：通过。顶部对比度提升，亮度栏在浅色主题干扰明显降低。
- 交互触发：通过。章节链接点击/长按、亮度开关/滑杆/位置切换行为均保持同义。

## Progress

- `2026-02-20`：
  - 已完成 Step 1：形成顶部栏与亮度栏差异清单。
  - 已完成 Step 2：顶部栏实施“章节优先 + URL 窄屏降级 + 对比度收敛”。
  - 已完成 Step 3：亮度栏实施“浅色混色收敛 + 标题附加信息联动下移”。
  - 已完成 Step 4：新增 `reader_top_menu_test.dart` 并补充亮度栏下移回归测试，定向测试通过。
  - 已完成 Step 5：逐项对照与检查清单回填，计划关闭。
  - 兼容影响：仅影响阅读菜单 UI 排版与视觉参数，不改持久化字段与业务状态流转。

## Surprises & Discoveries

1. 根目录最新截图文件已更新为 `IMG_6992.PNG`（非 `IMG_6983.PNG`）。
2. 顶部栏可读性问题主要来自“URL 与书源按钮争宽 + 渐变底色偏弱”，而非单一字号问题。

## Decision Log

1. 顶部栏采用“章节名优先、URL 次级可降级”的策略，保持 legacy 信息主次。
2. 亮度栏保持三段交互语义不变，仅收敛视觉参数与位置自适应。
3. 亮度栏最大高度由 `400` 收敛为 `360`，在长屏下进一步降低视觉侵入。

## Outcomes & Retrospective

- 结果：顶部栏在窄屏与常规屏下信息可读性均提升；亮度栏与正文视觉冲突下降。
- 质量：新增/增补测试覆盖并全部通过，核心交互语义未回退。
- 后续：若需要继续贴近 legacy，可再对齐顶部栏图标资源形态（仅视觉层，不改交互）。
