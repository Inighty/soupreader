# 2026-02-20 阅读器四项回归修复（取色器/自动阅读/正文搜索高亮/字体切换）对齐 legado

状态：`done`

## 背景与目标
用户在前一轮“已完成”后仍反馈 4 项核心体验问题：
1. 颜色取色器可选色能力不足（体感仍接近“少量样例色”）。
2. 自动阅读入口点击无明显反馈，且没有直接出现速度设置界面。
3. 正文搜索仅在搜索面板预览高亮，章节正文内没有匹配高亮。
4. 字体切换体感无变化，用户感知为“无反应”。

本任务按迁移级别对齐 legado：
- 交互路径与入口层级同义；
- 状态流转与边界处理同义；
- 用户可见语义同义（允许平台 UI 差异）。

## 范围
- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/reader/widgets/reader_color_picker_dialog.dart`
- `lib/features/reader/widgets/paged_reader_widget.dart`
- `lib/features/reader/widgets/legacy_justified_text.dart`
- `lib/features/reader/widgets/scroll_segment_paint_view.dart`
- `lib/app/theme/typography.dart`
- 相关定向测试文件（按改动增补）

## 非目标
- 不改动书源五段链路（search/explore/bookInfo/toc/content）的抓取协议与规则执行层。
- 不引入新的扩展入口（例如新的阅读器外置页面）。
- 不在开发中执行 `flutter analyze`（保留到提交推送前阶段）。

## 成功标准
1. 自动阅读入口点击后可观测，且可直接进入速度调节面板；运行/停止状态可感知。
2. 搜索正文命中后，章节正文可看到匹配高亮（至少当前章节渲染层可见）。
3. 字体切换后，正文排版立即刷新并有可感知差异。
4. 取色器提供更完整辅助选择能力，不再仅依赖少量样例色。

## legado 对照文件（已读取）
- 取色器：
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/BgTextConfigDialog.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/TipConfigDialog.kt`
- 自动阅读：
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/AutoReadDialog.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/AutoPager.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- 搜索：
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/SearchMenu.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/searchContent/SearchResult.kt`
- 字体：
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/font/FontSelectDialog.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/font/FontAdapter.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/page/provider/ChapterProvider.kt`

## 差异点清单（实现前）
| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| RG-1 | `simple_reader_view.dart:_toggleAutoPageFromQuickAction` | `ReadMenu.kt:fABAutoPage + ReadBookActivity.showActionMenu + AutoReadDialog.kt` | soupreader 快捷入口只做 toggle，不保证进入速度面板 | 用户感知“点击无反应/无法调速” |
| RG-2 | `simple_reader_view.dart` + `paged_reader_widget.dart` + `scroll_segment_paint_view.dart` | `ReadBookActivity.jumpToPosition`（选区高亮）+ `SearchResult.kt` | soupreader 正文渲染层未接入命中高亮，仅菜单预览高亮 | 搜索定位后正文不可见反馈 |
| RG-3 | `typography.dart:ReadingFontFamily` | `ChapterProvider.getTypeface + systemTypefaces` | soupreader 字体映射虽然有索引，但用户体感差异弱；缺少更稳定 fallback 语义 | 用户感知字体切换无效 |
| RG-4 | `reader_color_picker_dialog.dart` | `BgTextConfigDialog/TipConfigDialog` 的 ColorPickerDialog | soupreader 可视化选色存在，但预设色维度不足，辅助能力不完整 | 颜色配置效率与可见性不足 |

## 逐项检查清单（实现前）
- 入口：自动阅读、搜索正文、字体选择、取色器入口均可达。
- 状态：自动阅读运行/停止、搜索命中索引、字体索引、取色确认状态。
- 异常：空搜索词、无命中、非法 hex 输入、章节边界。
- 文案：按钮与提示语义不偏离 legado。
- 排版：面板布局与正文显示在深浅色主题下可读。
- 交互触发：点击/拖动/关闭动作均有反馈。

## 实施步骤
1. 自动阅读入口修复（串行）
   - 预期结果：入口点击后可观测，且可进入速度面板。
   - 验证方式：`flutter test` 相关定向用例 + 手工点击路径。
2. 正文搜索高亮接入（翻页 + 滚动）
   - 预期结果：命中词在正文渲染层高亮可见。
   - 验证方式：构造章节文本命中样例，验证渲染高亮存在。
3. 字体切换可感知修复
   - 预期结果：切换字体触发重排且视觉可区分。
   - 验证方式：字体映射单测 + 视图编译测试。
4. 取色器增强
   - 预期结果：提供分组色板与最近使用等辅助，保留 HSV+Hex。
   - 验证方式：组件交互测试或行为单测（颜色解析/列表行为）。
5. 回归验证与文档回填
   - 预期结果：逐项对照清单完成，计划状态可追踪。
   - 验证方式：更新本 ExecPlan 与 `PLANS.md`。

## 风险与回滚
- 风险 1：正文高亮接入自定义绘制路径，可能带来渲染性能波动。
  - 缓解：仅在存在搜索词时启用高亮路径；复用缓存；保持可退化。
- 风险 2：字体 fallback 在不同平台差异大，可能仍有机型无明显差异。
  - 缓解：调整为更稳定的 fallback 列表与样式差异策略。
- 风险 3：自动阅读入口语义调整后，快捷栏“单击即停止”的旧行为变化。
  - 缓解：保留“运行中再次点击可停止”的分支，保证操作闭环。

回滚策略：
1. 文件级回滚：
   - `simple_reader_view.dart`
   - `reader_color_picker_dialog.dart`
   - `paged_reader_widget.dart`
   - `legacy_justified_text.dart`
   - `scroll_segment_paint_view.dart`
   - `typography.dart`
2. 若正文高亮出现性能回退，先回退高亮接线，保留其它三项修复。

## 验收与证据
- 命令验证（开发阶段定向）：
  - `flutter test test/auto_pager_test.dart test/simple_reader_view_compile_test.dart`
  - `flutter test test/reading_font_family_test.dart`
  - `flutter test test/reader_search_navigation_helper_test.dart`
  - 视改动补充新增测试文件
- 手工回归路径：
  - 路径 A：阅读页 -> 自动阅读入口 -> 速度面板 -> 调速 -> 停止。
  - 路径 B：阅读页 -> 搜索正文 -> 跳命中 -> 观察正文高亮。
  - 路径 C：阅读页 -> 界面 -> 字体 -> 切换后观察正文变化。
  - 路径 D：阅读页/页眉页脚设置 -> 取色器 -> 选色/最近色 -> 确认生效。

## Progress
- [done] 完成 legado 相关文件读取与差异归档。
- [done] Step 1 自动阅读入口修复。
- [done] Step 2 正文高亮接入（翻页 + 滚动）。
- [done] Step 3 字体切换可感知修复（字体族与 fallback）。
- [done] Step 4 取色器增强（分组色板 + 最近使用 + RGB/HSV/Hex）。
- [done] Step 5 定向验证与计划回填。

## Surprises & Discoveries
- 先前计划虽标记 done，但用户体感仍失败，说明“代码路径存在”不等于“入口语义可感知”。
- 自动阅读当前实现的快捷入口与面板入口是分离路径，属于关键可用性偏差。
- 正文高亮若仅在菜单预览层处理，用户在正文区域几乎无法确认命中位置；需要直接进入正文绘制链路。
- CJK 字体在不同平台 fallback 差异较大，单纯依赖 `serif/sans-serif/monospace` 用户感知可能不足。

## Decision Log
- 决策 1：本轮不拆为 4 份 ExecPlan，改为一份“回归包”统一追踪，避免状态碎片化。
- 决策 2：优先修自动阅读入口（用户直接阻塞），其后并行推进高亮/字体/取色器。
- 决策 3：正文高亮采用“绘制层高亮”而非仅状态层，保证翻页/滚动双模式同义可见。
- 决策 4：字体改为“主字体 + fallback 列表”并贯通到分页与滚动排版，提升跨平台可感知性。
- 决策 5：取色器保留 HSV+Hex，同时补齐分组色板与最近使用，优先优化操作效率。

## Outcomes & Retrospective
### 已完成变更
0. 后续一致性回补（界面/设置入口）
   - 用户反馈“界面”和“设置”弹层风格割裂。
   - `simple_reader_view.dart`：
     - `界面` 入口统一改为 `_showReadingSettingsSheet(title: '界面', tabs: 排版/界面/翻页)`；
     - `设置` 入口统一改为 `_showReadingSettingsSheet(title: '设置', tabs: 其他)`。
   - 结果：两入口使用同一套底部弹层外壳（标题栏、关闭按钮、圆角、间距、卡片节奏一致）。

0.1 统一风格二次审计（其他入口）
   - 针对阅读器内残留旧函数入口再统一：
     - `simple_reader_view.dart:_showReadStyleDialog` 统一改为 `ReadingSettingsSheet`；
     - `simple_reader_view.dart:_showLegacyMoreConfigDialog` 统一改为 `ReadingSettingsSheet`；
     - `simple_reader_view.dart:_showLegacyTipConfigDialog` 统一改为 `ReadingSettingsSheet`；
     - 字体选择弹层 `_buildFontSelectDialog` 统一头部（抓手 + 标题 + 关闭按钮）与圆角节奏。
   - 结果：即使走旧入口，也不会再出现“界面像 A 页面、设置像 B 页面”的分叉体验。

1. 自动阅读入口
   - `simple_reader_view.dart`：`_toggleAutoPageFromQuickAction` 改为三态语义：
     - 未运行：启动自动阅读并直接打开速度面板；
     - 已运行且面板未开：打开速度面板；
     - 已运行且面板已开：停止自动阅读并关闭面板。
2. 正文搜索高亮
   - `simple_reader_view.dart`：新增高亮参数派发。
   - `paged_reader_widget.dart` + `legacy_justified_text.dart`：翻页渲染链路接入命中高亮。
   - `scroll_segment_paint_view.dart`：滚动渲染链路接入命中高亮。
3. 字体切换
   - `typography.dart`：阅读字体改为“主字体 + fallback 列表”。
   - `simple_reader_view.dart`、`page_factory.dart`、`reader_page_agent.dart`：
     字体 fallback 贯通到滚动/分页排版与正文绘制。
4. 取色器增强
   - `reader_color_picker_dialog.dart`：
     - 新增分组色板；
     - 新增最近使用色；
     - 新增 RGB 精调；
     - 扩展 Hex 解析（支持 `#RGB`、`#RRGGBB`、`AARRGGBB`）。

### 逐项检查清单（实现后）
| 项目 | 结果 | 说明 |
|---|---|---|
| 入口 | 通过 | 自动阅读/搜索正文/字体/取色器入口均可达；自动阅读入口点击有可见反馈。 |
| 状态 | 通过 | 自动阅读运行态、搜索高亮态、字体索引与取色确认均可正确切换。 |
| 异常 | 通过 | 空搜索词、无命中、非法 Hex 都有兜底文案；章节边界自动停止。 |
| 文案 | 通过 | 保持 legado 语义文案，不引入扩展文案。 |
| 排版 | 通过 | 高亮与取色器在深浅色下可读；自动阅读面板结构保持同义。 |
| 交互触发 | 通过 | 点击/滑动/确认/关闭动作均已验证。 |

### 逐项对照清单（差异项闭环）
| 编号 | 对照结论 | 结果 |
|---|---|---|
| RG-1 | 自动阅读入口点击后可直接进入速度面板，且可停止 | 已同义 |
| RG-2 | 搜索命中在正文可见高亮（翻页+滚动） | 已同义 |
| RG-3 | 字体切换联动排版与渲染，具备更稳定 fallback | 已同义（平台字体资源仍受系统差异影响） |
| RG-4 | 取色器从少量样例提升为完整辅助选色 | 已同义 |

### 验证证据（本次执行）
- `flutter test test/auto_pager_test.dart test/reading_font_family_test.dart test/simple_reader_view_compile_test.dart test/paged_reader_widget_non_simulation_test.dart`（通过）
- `flutter test test/reader_color_picker_dialog_test.dart test/legacy_justified_text_highlight_test.dart test/auto_pager_test.dart test/reading_font_family_test.dart test/simple_reader_view_compile_test.dart test/paged_reader_widget_non_simulation_test.dart`（通过）
- `flutter test test/legacy_justified_text_highlight_test.dart`（通过）
- `flutter test test/simple_reader_view_compile_test.dart`（通过，覆盖入口改线后的编译回归）
- `flutter test test/simple_reader_view_compile_test.dart test/reading_font_family_test.dart`（通过，覆盖统一风格二次改线）

### 兼容影响
- 数据协议未变更（`fontFamilyIndex`、颜色字段与自动阅读速度字段均保持兼容）。
- 仅增强渲染与交互，不影响旧书源解析链路。
