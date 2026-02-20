# 阅读器“正文搜索菜单样式与命中定位”对齐 legado ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心阅读链路修复）`

## 背景与目标

### 背景

需求方反馈：阅读器“搜索正文”弹出菜单样式可用性差，且“上一个/下一个”命中定位与正文位置不稳定。

本轮已完成 legado 对照文件复核：

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/SearchMenu.kt`
- `/home/server/legado/app/src/main/res/layout/view_search_menu.xml`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/searchContent/SearchResult.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/searchContent/SearchContentViewModel.kt`

本项目对应实现：

- `lib/features/reader/views/simple_reader_view.dart`
- `lib/features/reader/services/reader_search_navigation_helper.dart`
- `test/reader_search_navigation_helper_test.dart`

### 目标（Success Criteria）

1. 搜索菜单交互语义与布局层级对齐 legado（信息条 + 主按钮区 + 上下命中导航）。
2. “上一个/下一个”在分页/滚动模式均可稳定跳转到当前命中附近，不再出现明显错位。
3. 当前命中在菜单中可被明确识别（索引与关键词上下文）。
4. 不改动阅读主链路以外能力，不新增扩展入口。

### 非目标（Non-goals）

1. 不在本轮引入“跨全书搜索结果页”完整功能复刻。
2. 不改动 search/explore/bookInfo/toc/content 抓取链路。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| S1 | `simple_reader_view.dart:_buildSearchMenuOverlay` | `SearchMenu.kt + view_search_menu.xml` | 搜索菜单按钮层级与视觉结构差异大，结果/主菜单/退出/上下按钮识别弱 | 用户操作成本高，误触率高 |
| S2 | `simple_reader_view.dart:_jumpToSearchHit` | `ReadBookActivity.jumpToPosition` | 滚动模式使用“字符占比 -> 滚动距离”粗算，不是文本布局锚点跳转 | 上下一个命中错位明显 |
| S3 | `simple_reader_view.dart:_resolveSearchHitPageIndex` | `ReadBookViewModel.searchResultPositions` | 分页模式仅按页文本长度累计推算页号，命中序号与真实页面对应不稳定 | 上下一个定位与预期不一致 |
| S4 | `simple_reader_view.dart:_collectContentSearchHits` | `SearchResult.kt` | 命中上下文仅普通文本预览，无关键词显式标识 | 用户难确认当前命中位置 |

## 逐项检查清单（强制）

- 入口：搜索正文后能进入搜索菜单并可触发结果/主菜单/退出/上下导航。
- 状态：命中为空/命中存在/首个命中/末个命中，UI 与交互都可用。
- 异常：定位映射失败时有兜底，不出现崩溃或无响应。
- 文案：信息条、按钮文案、结果索引语义清晰。
- 排版：信息条 + 主按钮区 + 悬浮导航层级稳定，无局部状态走样。
- 交互触发：上一个/下一个在边界钳制且与命中索引一致。

## 实施步骤

### Step 1（串行，前置）

- 目标：完成 legado 对照、差异清单与 ExecPlan 落盘。
- 预期结果：进入实现前具备可执行口径与检查清单。
- 验证方式：计划文件创建 + `PLANS.md` 索引登记。
- 状态：`completed`

### Step 2（串行，依赖 Step 1）

- 目标：修复命中定位准确性（分页 + 滚动）。
- 涉及：
  - `lib/features/reader/views/simple_reader_view.dart`
- 预期结果：上下一个命中跳转可重复、可解释、可兜底。
- 验证方式：定向测试 + 手工回归。
- 状态：`completed`

### Step 3（串行，依赖 Step 2）

- 目标：对齐搜索菜单布局语义并优化按钮可辨识度。
- 涉及：
  - `lib/features/reader/views/simple_reader_view.dart`
- 预期结果：搜索菜单视觉与交互结构接近 legado 语义，命中信息可读。
- 验证方式：手工回归路径。
- 状态：`completed`

### Step 4（并行，依赖 Step 2/3）

- 目标：补充定向测试覆盖命中导航与映射逻辑。
- 涉及：
  - `test/` 定向测试文件
- 验证方式：`flutter test` 定向命令。
- 状态：`completed`

### Step 5（串行，收尾）

- 目标：回填对照清单、决策记录与执行结果，关闭计划。
- 验证方式：文档章节完整性检查。
- 状态：`completed`

## 风险与回滚

### 失败模式

1. 章节排版参数变化后，命中锚点可能发生轻微偏差。
2. 搜索菜单重构引入点击区域回退问题。

### 阻塞条件（触发即 `blocked`）

1. 若 Flutter 侧无法实现与 legado 同义的稳定命中定位，需要按例外流程暂停并确认。

### 回滚策略

1. 文件级回滚：`simple_reader_view.dart`。
2. 保留本 ExecPlan 的差异与验证记录，避免重复排障。

## 验收与证据

### 手工回归路径

1. 路径 A：阅读器 -> 搜索正文 -> 输入关键词 -> 连续点击上一个/下一个，核对命中索引与正文跳转一致。
2. 路径 B：分别在滚动模式与翻页模式执行路径 A。
3. 路径 C：搜索菜单点击“结果/主菜单/退出”，核对菜单状态流转。

### 命令验证

- 开发阶段仅执行定向测试，不执行 `flutter analyze`。
- 提交前才执行一次 `flutter analyze`（本轮尚未到提交阶段）。
- 已执行：
  - `flutter test test/reader_search_navigation_helper_test.dart`
  - `flutter test test/simple_reader_view_compile_test.dart`

## 逐项对照清单（实现后）

| 项目 | legado 基准 | 当前实现 | 结论 |
|---|---|---|---|
| 搜索菜单结构 | 顶部结果信息条 + 底部主按钮区 + 左右悬浮导航 | 搜索菜单改为信息条（含上下快捷）+ 高亮预览 + 主按钮区 + 左右悬浮导航 | 已同义（平台样式差异） |
| 命中导航语义 | 上下命中按序切换并在边界钳制 | `SimpleReaderView` 改为边界钳制（首项继续上一个保持首项，末项继续下一个保持末项） | 已同义 |
| 分页定位方式 | 按命中序号计算页/行/字符 | 引入 `ReaderSearchNavigationHelper.resolvePageIndexByOccurrence`，优先按命中序号映射页号，偏移法兜底 | 关键语义已同义 |
| 滚动定位方式 | 基于内容位置而非粗略比例 | 滚动模式改为章节区间 + 文本布局行锚点定位，失败时才回退比例兜底 | 关键语义已同义 |
| 命中可观测性 | 搜索结果可识别当前命中 | 菜单内新增“结果索引 + 位置 + 关键词高亮预览” | 已同义（不含全书结果页扩展） |

## Progress

- `2026-02-20`：
  - 已完成 Step 1：完成 legado 对照、差异清单、ExecPlan 落盘与索引登记。
  - 已完成 Step 2（定位修复）：
    - `simple_reader_view.dart`：搜索命中增加 `occurrenceIndex`，分页模式按“命中序号”映射页号，偏移法兜底；
    - `simple_reader_view.dart`：滚动模式改为“章节区间 + 行锚点”定位，不再默认比例滚动。
    - `simple_reader_view.dart`：正文搜索匹配改为大小写敏感（与 legacy `indexOf(pattern)` 同义）。
    - `reader_search_navigation_helper.dart`：新增命中索引边界钳制方法，替换循环导航。
  - 已完成 Step 3（菜单 UI）：
    - `simple_reader_view.dart`：搜索菜单改为 legado 语义结构，优化“结果/主菜单/退出/上一个/下一个”按钮可辨识度；
    - `simple_reader_view.dart`：预览改为关键词高亮，补充位置文案。
  - 已完成 Step 4（定向测试）：
    - 新增 `test/reader_search_navigation_helper_test.dart`，覆盖页号映射、标题前缀剥离与偏移兜底。
  - 已完成 Step 5（收尾）：
    - 同步回填本 ExecPlan 与 `PLANS.md` 状态。
  - 兼容影响：
    - 仅影响阅读器内正文搜索的导航/样式，不影响旧书源解析与五段链路抓取逻辑。

## Surprises & Discoveries

1. 当前滚动模式命中跳转使用“字符占比”估算滚动位置，偏差在长段落下放大明显。
2. 当前分页模式页号推算仅基于页文本长度累计，缺少命中序号级校准。
3. legacy 搜索匹配依赖 `indexOf(pattern)`，是大小写敏感语义。
4. legacy 边界导航采用钳制，不做循环跳转。

## Decision Log

1. 先修复命中定位准确性，再做菜单视觉重构，减少 UI 修改掩盖定位问题的风险。
2. 保留失败兜底路径（定位映射失败时回退到保守跳转），优先保证可用性。
3. 将“页号映射算法”下沉到 `ReaderSearchNavigationHelper`，以便独立测试和后续复用。
4. 导航语义按 legacy 改为边界钳制，不做循环。
5. 命中匹配保持大小写敏感，避免命中序号与页码映射漂移。

## Outcomes & Retrospective

1. 搜索菜单核心交互已收敛到 legado 语义：结果信息、主操作、上下导航入口更清晰。
2. “上一个/下一个”定位从粗略估算改为序号/锚点驱动，并在边界按 legacy 语义钳制，命中一致性明显提升。
3. 尚未实现“跨全书搜索结果页”完整迁移，当前仍是章节内搜索（已在非目标中明确）。
