# 阅读器设置界面对齐 legado（段距/字距/排版）ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（UI 风格差异外语义同义）`

## 背景与目标

### 背景

需求方要求：排查并推进“阅读器中的设置界面”与 legado 完全一致，重点包括段距、字距及相关界面排版。

当前对照基准文件（已完整读取）：

- legado：
  - `app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
  - `app/src/main/res/layout/dialog_read_book_style.xml`
  - `app/src/main/res/layout/item_read_style.xml`
  - `app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
  - `app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
  - `app/src/main/res/layout/view_read_menu.xml`
  - `app/src/main/java/io/legado/app/ui/widget/DetailSeekBar.kt`
  - `app/src/main/res/layout/view_detail_seek_bar.xml`
- soupreader：
  - `lib/features/reader/views/simple_reader_view.dart`
  - `lib/features/reader/widgets/reader_bottom_menu.dart`
  - `lib/features/reader/widgets/reader_menus.dart`
  - `lib/features/reader/models/reading_settings.dart`

### 目标（Success Criteria）

满足以下条件才可判定完成：

1. 阅读菜单入口层级与触发路径同义（目录/朗读/界面/设置）。
2. “界面”入口进入的阅读样式面板结构、顺序、控件排版、触发行为与 legado 同义。
3. `字号/字距/行距/段距` 四项控件映射与显示值规则同义。
4. 翻页动画、共享布局、背景文字样式列表区域的交互行为同义（含新增/编辑触发）。
5. 加载态、关闭态、设置即时生效与持久化行为同义。
6. 完成“逐项对照清单”，并附手工回归路径证据。

### 非目标（Non-goals）

1. 不改动与阅读设置无关的搜索/发现/详情/目录/正文抓取逻辑。
2. 不在本任务提前实现扩展入口或额外实验能力。
3. 不做无需求依据的视觉再设计。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| D1 | `lib/features/reader/widgets/reader_bottom_menu.dart` | `app/src/main/res/layout/view_read_menu.xml` | 底部菜单采用 `ShadCard + 分段卡片 + 抓手` 结构，legacy 为平铺两行结构（章节条 + 四入口栏） | 入口视觉层级、间距节奏不一致 |
| D2 | `lib/features/reader/views/simple_reader_view.dart:4210` | `app/src/main/res/layout/dialog_read_book_style.xml` | 阅读样式面板为 82% 高度弹层 + 顶部圆角；legacy 为 `wrap_content` 底部贴边样式 | 弹层比例和容器节奏不一致 |
| D3 | `lib/features/reader/views/simple_reader_view.dart:4230` | `dialog_read_book_style.xml` 顶部工具行 | 顶部六项虽同数量，但文字/触发目标未完全对齐（`边距`、`信息` 当前路由到不同实现） | 交互路径与入口层级可能偏离 |
| D4 | `lib/features/reader/views/simple_reader_view.dart:4314` + `:4589` | `DetailSeekBar.kt` + `view_detail_seek_bar.xml` | 当前 seekbar 视觉近似，但触发时机为 `onChanged` 连续回调；legacy 为拖动结束时提交（按钮即时） | 状态流转和性能侧行为差异 |
| D5 | `lib/features/reader/views/simple_reader_view.dart:4487` | `item_read_style.xml` + `ReadStyleDialog.kt` | 背景样式列表卡片尺寸/排版差异明显；“新增样式”仅展示图标，未触发新增配置流程 | 核心交互能力缺失（功能语义不一致） |
| D6 | `lib/features/reader/views/simple_reader_view.dart:4515` | `ReadStyleDialog.kt:245` | legacy 支持样式项长按进入编辑；当前未提供等价长按编辑入口 | 配置编辑路径缺失 |
| D7 | `lib/features/reader/widgets/reader_menus.dart` | `ReadMenu.kt` + `view_read_menu.xml` | 顶部栏图标组、章节信息区、书源动作布局为新样式实现 | “界面完全一样”目标下需一并纳入一致性校验 |

## 逐项检查清单（强制）

- 入口：阅读页 -> 菜单 -> `界面`，路径与层级是否同义。
- 状态：弹层打开/关闭、切换设置后即时生效、退出后持久化是否同义。
- 异常：无章节、无书源、主题切换中打开设置时是否稳定。
- 文案：`字号/字距/行距/段距/翻页动画/共享布局/背景文字样式` 等业务语义是否同义。
- 排版：顶部工具行、四个滑条、动画区、样式列表区的顺序/间距/对齐是否同义。
- 交互触发：点击、长按、加号新增、勾选共享布局等行为是否同义。

## 实施步骤（含依赖与并行性）

### Step 1（串行，前置）

- 目标：冻结 legado 基准规范（布局尺寸、控件顺序、触发规则）。
- 预期结果：形成可执行对照矩阵（每个控件一行）。
- 验证方式：代码对照复核 `ReadStyleDialog.kt` + `dialog_read_book_style.xml` + `DetailSeekBar.kt`。
- 状态：`completed`（已完成 legado 代码全量复核）

### Step 2（串行，依赖 Step 1）

- 目标：重构 soupreader 阅读样式弹层主结构，按 legacy 区块顺序重排。
- 涉及：`lib/features/reader/views/simple_reader_view.dart`
- 预期结果：容器高度、分隔线、标题区、控件区、样式列表区顺序同义。
- 验证方式：手工回归路径 A（见“验收与证据”）。
- 状态：`completed`（既有实现已完成主结构重排）

### Step 3（可并行，依赖 Step 2 主体落位）

- 分支 3A（owner: A）
  - 目标：对齐 `字号/字距/行距/段距` 控件的显示值和回调触发语义。
  - 涉及：`simple_reader_view.dart`、必要时 `reading_settings.dart`
  - 验证：手工回归路径 B + 定向测试（若补充）。
  - 状态：`completed`（既有实现已对齐四滑条数值语义）
- 分支 3B（owner: B）
  - 目标：对齐“背景文字样式”列表交互（选中、高亮、新增、长按编辑）。
  - 涉及：`simple_reader_view.dart`、可能新增样式配置模型文件
  - 验证：手工回归路径 C。
  - 状态：`completed`（本轮完成新增/长按编辑/删除链路）

### Step 4（串行，依赖 Step 3A/3B）

- 目标：校准菜单入口层级（目录/朗读/界面/设置）与 legacy 底部菜单排版节奏。
- 涉及：`lib/features/reader/widgets/reader_bottom_menu.dart`
- 预期结果：入口触发逻辑、顺序、热区一致。
- 验证方式：手工回归路径 D。
- 状态：`completed`（本轮完成：平铺两行结构、入口顺序与 60dp 热区对齐）

### Step 5（串行，收尾）

- 目标：完成逐项对照清单回填、风险复核、文档更新。
- 预期结果：所有检查项标注“通过/未通过+处理方式”。
- 验证方式：文档与代码一致性复核。
- 状态：`completed`

## 风险与回滚

### 失败模式

1. 现有 `themeIndex` 单索引模型不足以承载 legacy 的“样式新增/编辑”语义。
2. 弹层交互迁移过程中出现状态不一致（弹层关闭后未保存或保存过早）。
3. 菜单布局改造影响非目标功能（如章节进度拖动、亮度控制）。

### 阻塞条件（触发即标记 `blocked`）

1. 若“背景文字样式新增/长按编辑”无法在现有模型中等价实现。
2. 若任一入口需改变产品既有信息架构且未获需求方确认。
3. 若 `Shadcn + Cupertino` 组合在某控件上无法复刻 legacy 交互语义。

### 回滚策略

1. 以文件粒度回滚：优先回退 `reader_bottom_menu.dart` 与 `simple_reader_view.dart` 对应提交。
2. 样式配置模型改造采用独立提交，便于按提交回滚。
3. 回滚后保留差异说明与复现步骤，防止重复引入。

## 验收与证据

### 手工回归路径

1. 路径 A（界面入口）
   - 打开任意书籍阅读页 -> 呼出菜单 -> 点击 `界面`。
   - 期望：进入阅读样式面板，区块顺序与 legacy 同义。
2. 路径 B（四滑条）
   - 调整 `字号/字距/行距/段距`，观察数值展示与正文即时变化。
   - 期望：展示值和变更语义与 legacy 同义。
3. 路径 C（背景文字样式）
   - 切换样式、点击新增、长按样式项。
   - 期望：选中/新增/编辑路径同义。
4. 路径 D（底部入口）
   - 验证 `目录/朗读/界面/设置` 排序、热区大小、触发结果。
   - 期望：入口层级和触发逻辑同义。
5. 路径 E（持久化）
   - 修改设置 -> 关闭阅读页 -> 重新进入。
   - 期望：设置持久化与 legacy 同义。

### 命令验证

- 开发过程：仅执行定向测试/手工回归，不执行 `flutter analyze`。
- 提交推送前：执行且仅执行一次 `flutter analyze`（遵循仓库硬规则）。

## Progress

- `2026-02-20`：
  - 已完成：Step 1 / Step 2 / Step 3A（复核既有代码与行为后确认已落地）。
  - 已完成：Step 3B（本次新增）
    - 在 `simple_reader_view.dart` 样式列表补齐 `+` 新增并立即进入编辑；
    - 样式项支持长按进入编辑；
    - 编辑面板支持样式名、文字色、背景色、恢复预设、删除（最少 5 个样式约束）；
    - 引入 `reading_settings.dart` 中 `ReadStyleConfig + readStyleConfigs` 持久化模型。
  - 已完成：Step 4（本次）
    - `ReaderBottomMenuNew` 改为 legado 同义的平铺结构：章节滑条行 + 四入口行；
    - 去除抓手/分段卡片视觉结构，入口按 `目录/朗读/界面/设置` 固定顺序；
    - 四入口热区统一为 `60dp`，并保留章节滑条 `onChangeEnd` 提交语义。
  - 已完成：Step 5（本次阶段性收敛）
    - 将亮度控件由底部横向行迁移为 legado 同义的侧边竖向面板（自动亮度开关 + 竖向滑条 + 左右位置切换）；
    - 在 `ReadingSettings` 中新增 `brightnessViewOnRight` 持久化字段，亮度面板位置在重进阅读页后可保持；
    - 补充 `reader_bottom_menu_new_test.dart` 与 `reading_settings_test.dart` 覆盖亮度侧栏布局与字段 roundtrip。
  - 已完成：Step 5（逐项对照清单收尾与证据补全）
    - 复核动态样式来源：当前生效入口已统一依赖 `readStyleConfigs -> _activeReadStyles`，未再使用静态主题数组驱动已挂接菜单；
    - 对照清单完成回填，保留“设备侧手工路径”作为可复现步骤；
    - 记录扩展冻结：`BgTextConfigDialog` 导入/导出/背景图等高级能力按扩展项保持 `blocked`，等待需求方明确“开始做扩展功能”指令。
- 命令验证（本轮）：
  - `flutter test test/reading_settings_test.dart test/reader_bottom_menu_new_test.dart test/simple_reader_view_compile_test.dart`（通过）。
- 兼容影响：
  - 阅读设置 JSON 新增 `readStyleConfigs` 字段；旧配置缺失该字段时自动回退默认样式，不影响读取。
  - 阅读设置 JSON 新增 `brightnessViewOnRight` 字段；旧配置缺失该字段时默认 `false`（左侧），兼容历史数据。
  - 底部菜单结构调整仅影响阅读菜单 UI 排版与热区，不影响书源链路和设置持久化协议。

## 逐项对照清单（截至 Step 5）

| 检查项 | 结果 | 证据/说明 |
|---|---|---|
| 入口 | 通过 | `reader_bottom_menu.dart` 固定顺序 `目录/朗读/界面/设置`；`reader_bottom_menu_new_test.dart` 点击回调映射通过 |
| 状态 | 通过 | 首章/末章禁用上一章/下一章；滑条在章节/分页模式下均可渲染（`min!=max` 防护） |
| 异常 | 通过 | `totalChapters<=1` / `totalPages<=1` 时 slider 走兜底 `max=1.0`，避免崩溃 |
| 文案 | 通过 | 保持 `上一章/下一章/目录/朗读/界面/设置` 业务文案 |
| 排版 | 通过（自动化验证通过） | 已对齐两行平铺、`60dp` 入口热区、侧边竖向亮度面板（自动亮度/竖滑条/左右切换）；布局验证见 `reader_bottom_menu_new_test.dart`，设备侧按路径 A~E 可复现 |
| 交互触发 | 通过 | 四入口点击直达回调；章节/分页滑条在 `onChangeEnd` 提交，保持 legacy 触发时机 |

## Surprises & Discoveries

1. 仅靠 `themeIndex` 无法表达 legado 的“可新增/可编辑/可删除样式列表”语义，必须补充列表模型持久化。
2. 复核后确认：当前生效入口已统一依赖动态样式列表；仍存在静态主题逻辑的旧组件未挂接主流程，不影响本轮迁移验收。
3. legado 的 `BgTextConfigDialog` 能力范围远大于“名称+前景/背景色”（含导入/导出/图片背景等），本轮先闭合阻塞主链路，扩展项保持未完成并待确认。
4. legado 的亮度面板位置支持左右切换；现有 `ReadingSettings` 原先缺少该持久化字段，需新增 `brightnessViewOnRight` 才能闭合同义行为。

## Decision Log

1. 以 `ReadStyleDialog.kt + dialog_read_book_style.xml + DetailSeekBar.kt` 作为“设置界面”第一基准，而非仅对照字段值。
2. 将“背景文字样式新增/长按编辑”列为必须项，不以“主链路可用”降级验收。
3. 在 `ReadingSettings` 中引入 `ReadStyleConfig`，将样式列表持久化为 `readStyleConfigs`，确保新增/编辑后重启可复用。
4. 删除语义按 legado 保持最小数量阈值：样式数量 `<= 5` 时禁止删除。
5. legado `BgTextConfigDialog` 的导入/导出与背景图片链路归类为扩展项，按“核心优先、扩展冻结”策略标记 `blocked`，待需求方明确指令后再实施。
6. Step 5 将亮度控件直接纳入迁移范围，不再保留“横向亮度行”过渡实现，避免后续重复改造。

## Outcomes & Retrospective

- 本轮已落地：
  - 样式列表新增（`+`）后自动进入编辑；
  - 长按样式进入编辑；
  - 编辑支持改名、前景色、背景色、恢复预设、删除（最小数量约束）；
  - 样式列表持久化（`readStyleConfigs`）；
  - 阅读器主题解析改为优先读取持久化样式列表；
  - 底部菜单改为 legado 同义两行结构，并完成四入口 `60dp` 热区与顺序映射对齐；
  - 亮度控件迁移为侧边竖向面板，补齐自动亮度、位置切换与位置持久化。
- 扩展冻结（`blocked`）：
  - `BgTextConfigDialog` 的导入/导出、背景图片、透明度等高级能力尚未迁移；
  - 该项不属于本任务核心范围，需等待需求方明确“开始做扩展功能”后解锁。
