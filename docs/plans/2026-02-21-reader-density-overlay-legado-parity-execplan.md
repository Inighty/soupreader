# 2026-02-21 阅读器正文铺满与菜单分层对齐 legado（content C5）

状态：`active`（含 `blocked` 例外项）

## 背景与目标
用户反馈阅读器与参考图（`IMG_6995.PNG`、`IMG_6996.PNG`）相比存在三类偏差：
1. 正文字体与边距偏松，单屏内容密度不足。
2. 进入配置状态时遮挡感偏重。
3. 顶部与底部菜单层和正文分隔不够清晰，易混淆。

本批次按迁移级别对齐 legado 语义，优先修正默认排版、菜单层视觉分层和配置弹层遮挡策略。

## 范围
- `lib/features/reader/models/reading_settings.dart`
- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/reader/widgets/reader_menus.dart`
- `lib/features/reader/widgets/reader_bottom_menu.dart`
- `lib/features/reader/widgets/reader_menu_surface_style.dart`
- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/reader/widgets/paged_reader_widget.dart`
- `test/reading_settings_test.dart`
- `test/reader_bottom_menu_new_test.dart`
- `test/reader_top_menu_test.dart`
- `test/paged_reader_widget_non_simulation_test.dart`
- `test/paged_reader_widget_simulation_image_test.dart`

## 非目标
- 不改书源解析链路（search/explore/bookInfo/toc/content 抓取与规则执行）。
- 不引入新的业务入口或扩展开关。
- 不执行 `flutter analyze`（遵循仓库约束）。

## legado 对照文件（已读取）
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/provider/TextChapterLayout.kt`
- `/home/server/legado/app/src/main/res/layout/view_read_menu.xml`
- `/home/server/legado/app/src/main/res/layout/dialog_tip_config.xml`

## 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D1 | `ReadingSettings` 默认值 | `ReadBookConfig.Config` 默认排版 | 默认字号/行距/段距/边距更松 | 单屏内容量偏少 |
| D2 | 阅读菜单透明策略 | `view_read_menu.xml` + `ReadMenu` | 顶部菜单渐变透出正文 | 顶部/正文边界不清 |
| D3 | 配置弹层遮挡 | `ReadStyleDialog`/`MoreConfigDialog` | iOS 弹层 dim 与高度偏大 | 配置态遮挡感偏重 |
| D4 | 顶部/底部菜单配色来源 | `ReadMenu.initView()` 同一 `bgColor/textColor` | 顶部存在写死深色分支，底部走 token 体系 | 上下栏观感割裂 |
| D5 | 信息->正文标题模式 | `TipConfigDialog` `RadioGroup` + `TextChapterLayout` 标题居中逻辑 | 选中态文案可读性差；滚动模式居中不明显 | 标题模式交互与展示不一致 |
| D6 | 翻页模式页脚提示与底部菜单 | `ReadMenu` 打开时页面菜单层优先 | 翻页模式提示条持续绘制，菜单打开时与底部菜单层叠 | 底部进度/菜单视觉重叠 |
| D7 | 底部进度拖动条与四入口间距 | `view_read_menu.xml` 章节行上下 5dp 节奏 | 拖动条与下方入口区视觉过近 | 底栏观感拥挤 |
| D8 | 自动阅读速度/面板语义 | `AutoReadDialog.kt` + `AutoPager.kt` + `dialog_auto_read.xml` | 速度语义偏离“秒/页”，面板缺少目录/主菜单/停止/设置联动入口 | 自动阅读反馈弱、用户感知“点击无反应” |

## 逐项检查清单（实现后）
- 入口：界面/设置/信息入口可达且语义未改。
- 状态：菜单展开、弹层开启/关闭、阅读设置实时生效。
- 异常：旧配置反序列化与字段缺失兼容不崩溃。
- 文案：按钮与配置文案业务语义不变。
- 排版：正文密度提升，顶/底菜单分层明显。
- 交互触发：点击、滑杆、关闭流程可用。

## 实施步骤与结果
1. `ReadingSettings` 默认排版对齐 legado
   - 新增 `layoutPresetVersion`（`1 -> 2`）
   - 新增 v1/v2 默认常量，并将构造默认改为 legado v2（字号 20、行高 1.2、段距 2、正文左右边距 16、上下边距 6）。

2. 历史设置一次性迁移
   - `fromJson` 在 `layoutPresetVersion < 2` 时，仅对仍等于 v1 旧默认的字段执行迁移；用户自定义值保持原样。
   - 迁移后版本提升至 `2`，`toJson` 持久化。

3. 菜单分层与遮挡优化
   - `ReaderTopMenu` 改为实体背景层 + 明确下边界 + 阴影，降低正文穿透。
   - `ReaderBottomMenuNew` 提升底栏实体度，增加滑杆区与四入口区分隔线。
   - `ReadStyle/MoreConfig/TipConfig` 弹层 `barrierColor` 设为透明；`ReadStyle/TipConfig` 高度收敛至 `0.74` 屏高语义，减轻配置态遮挡。

4. 顶部/底部样式统一到同一解析器
   - 新增 `reader_menu_surface_style.dart`，收敛 `panel/text/border/divider/shadow/control` 统一计算。
   - `ReaderTopMenu` 移除写死深色 `0xFF1F2937`，改为与底部同源的 `resolveReaderMenuSurfaceStyle`。
   - `ReaderBottomMenuNew` 改用同一解析器，保证顶部/底部颜色与层级参数不再分叉。

5. 信息弹层正文标题模式修复
   - `SimpleReaderView._buildLegacyTitleModeSegment` 调整分段控件选中态文本颜色，避免选中项被 `thumbColor` 覆盖后不可读。
   - `SimpleReaderView._buildScrollSegment` 将标题 `Text` 扩展为 `SizedBox(width: double.infinity)`，保证 `titleMode=居中` 在滚动模式按 legado 语义生效。

6. 翻页模式底部重叠修复
   - `PagedReaderWidget` 新增 `showTipBars`，用于菜单态控制页眉页脚提示可见性。
   - `SimpleReaderView._buildPagedContent` 在菜单/搜索/自动阅读面板打开时传入 `showTipBars=false`。
   - `PagedReaderWidget` 保持页眉页脚占位逻辑独立于提示条绘制，隐藏提示条时正文不发生上下跳动。

7. 底部进度拖动条间距优化
   - `ReaderBottomMenuNew` 在进度拖动区与入口区之间新增垂直留白。
   - 章节滑杆行顶部间距从 4 调整为 5，贴近 legado 章节区 `5dp` 节奏。

8. 自动阅读链路对齐 legado
   - `AutoPager` 速度语义改为“秒/页”，范围 `1-120`；翻页模式按秒触发，滚动模式按“视口高度/秒”推进。
   - `AutoReadPanel` 改为 legado 同义结构：速度滑杆 + `目录/主菜单/停止/设置` 四入口。
   - `SimpleReaderView` 增加自动阅读面板回调（主菜单/目录/设置/停止）并补齐开启/停止反馈文案。
   - 设置页“自动阅读速度”统一为 `1-120（秒/页）`，显示值带 `s`。

## 验收与证据
- 自动化测试（通过）：
  - `flutter test test/reading_settings_test.dart test/simple_reader_view_compile_test.dart test/reader_top_menu_test.dart test/reader_bottom_menu_new_test.dart test/app_settings_test.dart`
  - `flutter test test/reader_bottom_menu_new_test.dart`（含底部安全区贴底回归用例）
  - `flutter test test/reader_top_menu_test.dart test/reader_bottom_menu_new_test.dart test/simple_reader_view_compile_test.dart`（通过）
  - `flutter test test/simple_reader_view_compile_test.dart test/reader_top_menu_test.dart test/reader_bottom_menu_new_test.dart`（通过）
  - `flutter test test/simple_reader_view_compile_test.dart test/paged_reader_widget_non_simulation_test.dart test/paged_reader_widget_simulation_image_test.dart`（通过）
  - `flutter test test/reader_bottom_menu_new_test.dart`（通过）
  - `flutter test test/auto_pager_test.dart test/simple_reader_view_compile_test.dart`（通过）
  - `flutter test test/reading_settings_test.dart`（通过）
- 手工回归路径（待真机截图补充）：
  - C5：阅读页 -> 正文阅读 -> 打开菜单 -> 顶部栏/底部栏分层观察。
  - C5：阅读页 -> 界面/设置/信息弹层 -> 观察遮挡面积与关闭恢复。

## 兼容影响
- 低到中：
  - `ReadingSettings` 新增 `layoutPresetVersion` 字段；对旧默认值会执行一次迁移（用户自定义值不覆盖）。
  - 自动阅读速度上限由 `100` 调整为 `120`，并统一为“秒/页”语义；旧值会按新边界安全收敛。
  - 不涉及数据库结构、书源协议、网络接口。

## Progress
- [done] 默认排版参数对齐 legado v2。
- [done] 历史默认值迁移与版本化落盘。
- [done] 顶/底菜单分层与配置态遮挡优化。
- [done] 底部菜单背景贴底到安全区，消除底部正文漏出。
- [done] 顶部/底部菜单统一到同一样式解析器，移除顶部写死色值分支。
- [done] 信息弹层正文标题模式可读性修复，滚动模式“居中”对齐恢复生效。
- [done] 翻页模式菜单态隐藏页眉页脚提示，消除底部进度与菜单层叠。
- [done] 底部进度拖动条与四入口间距优化，缓解视觉拥挤。
- [done] 自动阅读速度语义、控制面板入口和状态反馈对齐 legado。
- [done] 定向测试与计划记录回填。

## Surprises & Discoveries
- legacy 的菜单 dim 语义更接近“无遮罩”，而非 iOS 默认半透明遮罩；直接使用默认 `showCupertinoModalPopup` 会放大遮挡体感。
- 仅靠改 UI 透明度无法解决“内容不满”，默认排版参数与历史数据迁移必须一起做。
- Flutter 中将底栏 `Container` 置于 `SafeArea` 内部时，安全区本身是透明区域；若不把 inset 合并进容器 padding，就会出现“底部漏底色”。
- 顶部与底部分散维护配色逻辑会持续漂移；只有统一样式解析入口才能稳定保持同义。
- Flutter `TextAlign.center` 只有在标题容器存在足够宽度时才可见；滚动模式标题若不占满宽度会表现为“看起来没居中”。
- 翻页模式提示条绘制与正文占位应分离；仅隐藏提示条而不调整占位，才能避免菜单开合时正文跳动。
- 底部工具栏拥挤感主要由“滑杆区与入口区贴得过紧”引发，增加小幅垂直留白即可缓解，不需改控件尺寸。
- 自动阅读若仅“定时翻页”而无面板反馈，用户容易误判为点击无效；需保留 legado 的底部控制面板语义来提供可观测状态。

## Decision Log
- 决策 1：保留用户自定义值，只迁移“旧默认值”字段，避免强制覆盖。
- 决策 2：按 legado 语义优先，配置弹层减少 dim，优先保证正文可见。
- 决策 3：不引入新入口，限定在阅读器 C5 路径收敛。
- 决策 4：底栏改为“容器直接贴底 + 安全区 inset 合并进容器内边距”，确保背景连续覆盖到底部。
- 决策 5：顶部/底部统一使用 `resolveReaderMenuSurfaceStyle`，禁止顶部继续维护写死颜色分支。
- 决策 6：信息弹层正文标题模式保持 legado 三档语义，分段控件只修正可读性，不更改配置项结构。
- 决策 7：翻页模式菜单态隐藏提示条但保留页眉页脚占位，优先消除重叠并保持阅读区域稳定。
- 决策 8：底部进度拖动条间距采用“小幅放松”策略（+3/+4dp 过渡），不调整功能热区。
- 决策 9：自动阅读速度改回 legado 的“秒/页”模型，并以 `1-120` 范围对齐 `dialog_auto_read.xml` 的滑杆边界。

## Outcomes & Retrospective
- 做了什么：完成正文密度参数与菜单分层联动收敛，补齐旧设置兼容迁移。
- 为什么：提升阅读信息密度，减少菜单/配置态干扰，贴近 legado 行为。
- 如何验证：模型/编译/组件/设置服务相关定向测试均通过。
- 增量收敛：修复底部菜单安全区漏底，并以测试锁定该视觉边界行为。
- 增量收敛：完成顶部/底部菜单样式同源化，消除“上深下浅”视觉割裂。
- 增量收敛：修复正文标题模式选中态可读性与滚动模式居中生效问题。
- 增量收敛：修复翻页模式底部进度提示与菜单层叠问题，菜单态层级与 legado 语义一致。
- 增量收敛：优化底部进度拖动区与四入口区间距，底栏观感更松弛。
- 增量收敛：自动阅读入口反馈、速度模型与控制面板结构完成 legado 同义回补。

## 2026-02-21 增量：界面/设置选项排查（第 23 批）

### 差异点清单（实现前）
| ID | 位置 | legado 对照 | 差异 | 影响 |
|---|---|---|---|---|
| D9 | `MoreConfigDialog` -> 底部对齐 | `TextPage.upLinesPosition()` | `textBottomJustify` 在 soupreader 仅存储状态，未进入分页渲染 | 用户开关可见但视觉无变化 |
| D10 | `ReadStyleDialog` -> 共享布局 | `ReadBookConfig.shareLayout`（共享/独立布局切换） | soupreader `ReadStyleConfig` 无布局参数承载，`shareLayout` 仅切值不生效 | 样式切换期望与实际不一致 |
| D11 | `MoreConfigDialog` -> 翻页按键 | legado 按键映射配置入口 | soupreader 仍为占位提示 | 平台按键映射能力缺口 |

### 逐项检查清单（本轮）
- 入口：`界面`（`_showReadStyleDialog`）与 `设置`（`_showLegacyMoreConfigDialog`）入口均可达。
- 状态：`底部对齐` 改为真实生效；`共享布局` 与 `翻页按键` 标记为待迁移/占位，不再伪装为可用。
- 异常：未实现项统一走 `_showReaderActionUnavailable` 可观测提示。
- 文案：保持 legado 业务语义（底部对齐/共享布局/翻页按键）不变。
- 排版：`共享布局` 行改为“待迁移”标签，避免误导性勾选状态。
- 交互触发：`底部对齐` 开关触发分页渲染变化；其余阻塞项触发明确提示。

### 实施结果
1. 补齐 `textBottomJustify` 渲染语义  
   - 文件：`lib/features/reader/widgets/legacy_justified_text.dart`、`lib/features/reader/widgets/paged_reader_widget.dart`。  
   - 对齐策略：复刻 legado “仅在页面接近装满时分摊行间余量”语义。  
   - 关键点：
     - 新增 `composeContentLines` 与 `computeBottomJustifyGap`。
     - `paintContentOnCanvas` 与 `LegacyJustifiedTextBlock` 共用同一底部对齐计算。
     - `PagedReaderWidget` 普通渲染与 Picture 预渲染两条路径同步接入 `textBottomJustify`。

2. `shareLayout` 进入例外阻塞态（避免假生效）  
   - 文件：`lib/features/reader/views/simple_reader_view.dart`。  
   - 处理：将“共享布局”改为“待迁移”提示入口，点击输出不可用原因，不再切换无效状态值。

3. 补充定向测试  
   - 文件：`test/legacy_justified_text_highlight_test.dart`。  
   - 新增断言：底部对齐仅在“接近满页”条件下生效；页面留白过大时不拉伸。

### 验证与证据
- `flutter test test/legacy_justified_text_highlight_test.dart test/paged_reader_widget_non_simulation_test.dart test/simple_reader_view_compile_test.dart`（通过）

### 兼容影响
- 中：`底部对齐` 从“仅存储”变为“真实影响分页页内行间距”；仅影响翻页模式文本呈现，不改章节索引与进度存储。
- 低：`共享布局` 入口由伪开关改为待迁移提示，不影响既有书源/阅读进度数据。

### 迁移例外（按 1.1.2 记录）
- 例外 E1：`shareLayout` 暂无法等价复刻  
  - 原因：当前 `ReadStyleConfig` 仅含背景/文字样式字段，缺少 legado `Config` 中的排版参数承载。  
  - 影响范围：仅“界面 -> 背景文字样式 -> 共享布局”开关语义。  
  - 替代方案：本轮改为明确“待迁移”提示，避免误导用户。  
  - 回补计划：后续扩展 `ReadStyleConfig` 的布局快照字段，并在 `themeIndex` 切换时按 `shareLayout` 应用共享/独立排版。
- 例外 E2：`翻页按键` 仍为占位  
  - 原因：跨平台硬件按键映射能力尚未补齐。  
  - 影响范围：仅“设置 -> 翻页按键”配置项。  
  - 替代方案：保留可观测占位提示。  
  - 回补计划：补齐按键映射配置模型与平台分发链路后开放入口。

### Progress（增量）
- [done] `textBottomJustify` 对齐 legado 语义，已进入渲染链路。
- [blocked] `shareLayout`（E1）待样式布局模型扩展。
- [blocked] `翻页按键`（E2）待平台按键映射能力补齐。
