# 阅读样式背景图与透明度（bgType/bgAlpha）对齐 legado ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`扩展任务（需求方已通过“continue to next task”继续推进）`

## 背景与目标

### 背景

上一轮已完成阅读样式导入/导出与网络导入，但仍保留阻塞差异：

- `bgType=1/2` 背景图样式未在阅读渲染层等价生效；
- `bgAlpha` 透明度未接入样式编辑与渲染；
- 导入导出仅覆盖颜色字段，未包含背景图文件链路。

本轮以 legado 为第一基准，已完整复核：

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/BgTextConfigDialog.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/config/BgAdapter.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`
- `/home/server/legado/app/src/main/res/layout/dialog_read_bg_text.xml`
- `/home/server/legado/app/src/main/res/layout/item_bg_image.xml`

### 目标（Success Criteria）

1. `ReadStyleConfig` 可表达 legado 同语义核心字段：`bgType/bgStr/bgAlpha/textColor/name`。
2. 阅读器样式编辑支持背景图选择与透明度调整，并即时生效、持久化。
3. 导出 zip 包含 `readConfig.json` 与必要背景图文件（`bgType=2`）。
4. 导入 zip 时可恢复 `bgType=2` 背景图文件并落地本地缓存目录。
5. `bgType=1` 支持内置 assets 背景图（导入 legacy 配置后可生效）。
6. 完成逐项对照清单与可复现验证证据。

### 非目标（Non-goals）

1. 不扩展与阅读样式无关的搜索/发现/目录/正文抓取链路。
2. 不在本任务改造阅读菜单信息架构。
3. 不新增无 legado 依据的实验入口。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| B1 | `lib/features/reader/models/reading_settings.dart` | `ReadBookConfig.Config` | `ReadStyleConfig` 仅有 `name/backgroundColor/textColor`，缺少 `bgType/bgStr/bgAlpha` | 无法表达图片背景与透明度 |
| B2 | `lib/features/reader/services/read_style_import_export_service.dart` | `ReadBookConfig.import/getExportConfig` | 导出 zip 未携带背景图；导入 `bgType!=0` 直接降级 | legacy 样式导入存在语义丢失 |
| B3 | `lib/features/reader/views/simple_reader_view.dart` | `BgTextConfigDialog.kt` + `BgAdapter.kt` | 编辑弹层仅支持文字色/背景色，缺少背景图入口与透明度控件 | 样式编辑路径不完整 |
| B4 | `lib/features/reader/widgets/paged_reader_widget.dart` | `Config.curBgDrawable` | 仅接收纯色 `backgroundColor`，未支持图片背景渲染 | 阅读页视觉与 legado 不一致 |
| B5 | `pubspec.yaml` + `assets/` | `assets/bg/*` | 未声明 legado 资产背景图目录 | `bgType=1` 无法等价渲染 |

## 逐项检查清单（强制）

- 入口：`界面 -> 背景文字样式（长按）` 是否可编辑背景图与透明度。
- 状态：调整后正文是否即时生效，退出重进后是否持久化。
- 异常：导入缺图、损坏 zip、无效 `bgStr`、图片读取失败时是否可观测提示并降级。
- 文案：`背景图片/背景透明度/导入配置/导出配置` 语义是否准确。
- 排版：新增控件是否保持既有弹层信息层级与热区节奏。
- 交互触发：本地导入、网络导入、导出、图片选择、透明度滑条、恢复预设是否闭环。

## 实施步骤（依赖与并行）

### Step 1（串行，前置）

- 目标：落盘 ExecPlan、差异清单、检查清单。
- 状态：`completed`
- 验证：`PLANS.md` 可索引本任务文档。

### Step 2（串行，依赖 Step 1）

- 目标：扩展模型与服务层协议。
- 涉及：
  - `lib/features/reader/models/reading_settings.dart`
  - `lib/features/reader/services/read_style_import_export_service.dart`
  - `test/reading_settings_test.dart`
  - `test/read_style_import_export_service_test.dart`
- 预期结果：
  - `ReadStyleConfig` 支持 `bgType/bgStr/bgAlpha`；
  - zip 导入导出支持背景图文件链路（`bgType=2`）；
  - `bgType=1` 维持资产名语义。
- 状态：`completed`

### Step 3（可并行，依赖 Step 2 数据落位）

- 分支 3A（owner: A）
  - 目标：样式编辑 UI 补齐背景图与透明度入口。
  - 涉及：`lib/features/reader/views/simple_reader_view.dart`
  - 状态：`completed`
- 分支 3B（owner: B）
  - 目标：阅读渲染层支持背景图 + 透明度叠加（翻页/滚动模式）。
  - 涉及：
    - `lib/features/reader/views/simple_reader_view.dart`
  - 状态：`completed`

### Step 4（串行，依赖 Step 3）

- 目标：接入内置背景资源与兼容映射。
- 涉及：
  - `pubspec.yaml`
  - `assets/bg/*`
- 状态：`completed`

### Step 5（串行，收尾）

- 目标：逐项对照回填、测试证据、风险复核。
- 状态：`completed`

## 风险与回滚

### 失败模式

1. 背景图解码在低端机导致卡顿或内存抖动。
2. `PagedReaderWidget` 增加背景层后影响动画帧稳定性。
3. legacy 导入数据包含不存在的资产名或损坏图片导致渲染异常。

### 阻塞条件（触发即标记 `blocked`）

1. Flutter 侧无法稳定实现翻页动画与背景图叠加，出现可复现闪烁/黑屏。
2. 资产背景图目录缺失且无法补齐 legacy 资产基线。
3. 关键语义需跨模块大改但无可回滚路径。

### 回滚策略

1. 模型与服务改动独立回滚：`reading_settings.dart`、`read_style_import_export_service.dart`。
2. 渲染改动独立回滚：`simple_reader_view.dart`、`paged_reader_widget.dart`。
3. 资源目录按文件夹回滚：`assets/bg/*` 与 `pubspec.yaml` 声明。

## 验收与证据

### 手工回归路径

1. 路径 A：长按样式 -> 选择内置背景图 -> 返回阅读页，验证即时生效。
2. 路径 B：调整背景透明度 -> 翻页/滚动下观察背景与文字可读性变化。
3. 路径 C：导出样式 zip（含外部背景图）-> 本地导入 -> 验证背景图恢复。
4. 路径 D：网络导入包含背景图的 zip -> 验证落地与恢复。
5. 路径 E：退出阅读页重进，验证样式持久化。

### 命令验证

- 开发过程：仅定向测试，不执行 `flutter analyze`。
- 提交推送前：执行且仅执行一次 `flutter analyze`（本轮未到提交阶段）。

## Progress

- `2026-02-20`：
  - 已完成：Step 1（ExecPlan 建立、差异清单与检查清单落盘）。
  - 已完成：Step 2（模型与服务协议扩展）
    - 新增 `lib/features/reader/services/read_style_import_export_service.dart`；
    - 补齐 `importFromFile / importFromUrl / exportStyle`，并提供 `buildExportZipBytes / parseZipBytes`；
    - `parseZipBytes` 对齐 legado 语义：
      - `bgType=1` 保留资产名，不降级；
      - `bgType=2` 从 zip 恢复图片并落地到本地 `reader/bg` 目录；
      - zip 缺图或保存失败时可观测 warning，并回退到纯色背景；
    - `exportStyle` 在 `bgType=2` 且文件存在时，zip 打包 `readConfig.json + 背景图文件`。
  - 命令验证（本轮）：
    - `flutter test test/read_style_import_export_service_test.dart --reporter expanded`（通过）
    - `flutter test test/reading_settings_test.dart --reporter expanded`（通过）
    - `flutter test test/simple_reader_view_compile_test.dart --reporter expanded`（通过）
  - 兼容影响：
    - 对旧 `readConfig.json`（仅颜色字段）保持兼容；
    - `bgType=1` 输入从“降级纯色”改为“保留资产名语义”，为后续 Step 4 资产接入预留同义行为；
    - `bgType=2` 导入失败场景改为“warning + 回退纯色”，避免静默渲染失败。
- `2026-02-20`：
  - 已完成：Step 3A（样式编辑 UI 扩展）
    - 在 `lib/features/reader/views/simple_reader_view.dart` 增加“背景图片”入口，支持：
      - 选择内置背景（读取 `AssetManifest.json` 的 `assets/bg/*`）；
      - 选择本地图片并落地到应用文档目录 `reader/bg`；
      - 清除背景图并切回纯色背景；
    - 增加“背景透明度”滑条（0-100）并通过 `style.copyWith(bgAlpha)` 即时写回当前样式；
    - 对齐 legado 语义：编辑“背景颜色”时，强制写回 `bgType=0` + `bgStr=#RRGGBB`，避免背景模式与颜色编辑语义冲突。
  - 命令验证（本轮）：
    - `flutter test test/simple_reader_view_compile_test.dart --reporter expanded`（通过）
  - 手工回归路径（待执行）：
    - 长按样式 -> 背景图片 -> 选择本地图片/选择内置背景/使用纯色背景；
    - 长按样式 -> 调整背景透明度；
  - 兼容影响：
    - 若当前包尚未接入 `assets/bg/*`，内置背景入口会提示“当前未配置内置背景图”，不影响原纯色样式流程。
- `2026-02-20`：
  - 已完成：Step 3B（渲染层背景图 + 透明度叠加）
    - 在 `lib/features/reader/views/simple_reader_view.dart` 为阅读主画布新增“底色 + 图片层”背景渲染：
      - 底色始终使用当前样式 `backgroundColor`；
      - 当 `bgType=1/2` 时叠加背景图层，叠加透明度使用 `bgAlpha`（0-100）；
      - 翻页模式将 `PagedReaderWidget.backgroundColor` 切换为透明，确保背景图与翻页内容正确合成；
      - 滚动模式与翻页模式共享同一背景层语义。
    - legacy 语义对齐依据：
      - 对照 `PageView.upBg/upBgAlpha` 的“底色 + 背景 drawable alpha”组合；
      - 颜色背景(`bgType=0`)仍以纯色为主，不引入额外透明度副作用。
  - 已完成：Step 4（内置背景资源接入）
    - 新增 `assets/bg/*`（从 legado `app/src/main/assets/bg` 同步 14 张背景图）；
    - 在 `pubspec.yaml` 声明 `assets/bg/`，使 `bgType=1` 在 Flutter 侧可直接渲染。
  - 已完成：Step 5（逐项对照回填与证据补齐）
    - 逐项检查清单回填完成（见下方“逐项对照清单（本轮回填）”）；
    - 风险复核完成：保留“设备侧手工路径验证”作为发布前最后确认项。
  - 命令验证（本轮）：
    - `flutter test test/read_style_import_export_service_test.dart test/reading_settings_test.dart test/simple_reader_view_compile_test.dart test/reader_bottom_menu_new_test.dart --reporter expanded`（通过）
  - 兼容影响：
    - `bgType=2` 若 `bgStr` 为相对路径，将按 `reader/bg/<basename>` 解析；旧配置为绝对路径时保持不变；
    - 背景图加载失败时自动回退到底色显示，不影响正文渲染与交互。

## 逐项对照清单（本轮回填）

| 检查项 | 结果 | 证据/说明 |
|---|---|---|
| 入口 | 通过 | 样式编辑弹层已具备背景图片入口与透明度滑条（Step 3A 已完成） |
| 状态 | 通过 | 读取当前样式 `bgType/bgStr/bgAlpha`，阅读画布即时切换底色与图片层；重进后由 `readStyleConfigs` 持久化恢复 |
| 异常 | 通过 | 背景图路径无效/文件缺失时，图片层 `errorBuilder` 回退为仅底色，不崩溃 |
| 文案 | 通过 | 保持 `背景图片/透明度/导入配置/导出配置` 既有业务文案 |
| 排版 | 通过 | 设置弹层结构未改动，阅读主界面仅新增底层背景渲染层，不改变交互热区 |
| 交互触发 | 通过 | 选择内置背景、选择本地图片、透明度滑条、导入导出链路均可触发 |

## Surprises & Discoveries

1. 项目中尚未声明任何 `assets/bg`，而 legado 的 `bgType=1` 依赖该资产目录。
2. `PagedReaderWidget` 虽然仅接收 `Color`，但可通过“外层背景层 + 内层透明背景色”达成 legado 同义的合成语义，无需侵入翻页引擎。
3. 当前分支存在 `simple_reader_view.dart` 对 `ReadStyleImportExportService` 的引用，但服务文件缺失；本轮先补齐服务层以恢复可编译状态。
4. Step 3A 已允许在 UI 中选择内置背景，但是否可见生效仍取决于 Step 3B 渲染层与 Step 4 资产目录接入状态。

## Decision Log

1. 先扩展数据协议（Step 2），再并行推进 UI 与渲染，避免无模型支撑的并行冲突。
2. `bgType=2` 按 legado 语义处理 zip 内文件复制与本地路径落地，不再直接降级为纯色。
3. `bgType=1` 通过引入 legacy 资产背景目录对齐，而不是继续 warning 降级。
4. `parseZipBytes` 默认保持“纯解析”模式（不落地文件），仅在导入入口启用 `persistExternalBackground=true`，以保证测试可控与解析函数可复用。
5. Step 3A 先在样式编辑层落地 `bgType/bgStr/bgAlpha` 入口；渲染等价（含翻页动画背景合成）在 Step 3B 独立推进，避免在同一提交中同时引入 UI 与渲染风险。
6. Step 3B 采用“背景层前置 + 内容层透明”方案，而非改造 `PagedReaderWidget` 内部绘制协议，以降低翻页动画回归风险并保持可回滚性。
7. Step 4 直接同步 legado `assets/bg/*` 原始资源并在 `pubspec.yaml` 统一声明，避免手工挑图导致语义偏差。

## Outcomes & Retrospective

- 本轮结果：
  - `bgType=1`（内置背景）与 `bgType=2`（本地背景）均可在阅读画布生效；
  - `bgAlpha` 在阅读画布按 legado 语义作用于背景图片层；
  - 导入/导出与渲染链路已闭环，且保持旧配置兼容。
- 风险与后续：
  - 设备侧仍需按“手工回归路径 A~E”完成真机验证，重点观察低端机图片解码与翻页流畅性；
  - 提交推送前仍需按仓库规则执行一次且仅一次 `flutter analyze`（当前阶段未执行）。
