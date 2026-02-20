# 阅读样式配置扩展（导入/导出/网络导入）对齐 legado ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`扩展任务（已由需求方“continue to next task”解锁）`

## 背景与目标

### 背景

在上一轮“阅读器设置界面对齐”任务完成后，`BgTextConfigDialog` 的高级能力仍处于冻结状态，主要缺口是：

- 导入配置（本地 zip / 网络地址）
- 导出配置（zip）
- 背景图能力链路（选择图片、预设图片、透明度渲染）

本轮先推进可在当前 Flutter 架构下闭环且不破坏主链路的扩展能力：导入/导出/网络导入。

legado 对照基准（已完整读取）：

- `app/src/main/java/io/legado/app/ui/book/read/config/BgTextConfigDialog.kt`
- `app/src/main/java/io/legado/app/ui/book/read/config/BgAdapter.kt`
- `app/src/main/res/layout/dialog_read_bg_text.xml`
- `app/src/main/res/layout/item_bg_image.xml`
- `app/src/main/java/io/legado/app/help/config/ReadBookConfig.kt`

### 目标（Success Criteria）

1. 在 soupreader 阅读样式编辑弹层中提供与 legado 同语义的 `导入 / 导出 / 网络导入` 入口。
2. 导出产物为 zip，内含 `readConfig.json`，可被本项目导入回放。
3. 导入支持 legacy `readConfig.json` 关键字段兼容（样式名、前景色、背景色）。
4. 导入成功后即时生效并持久化，不影响阅读主链路稳定性。
5. 完成逐项对照清单，并明确本轮未闭合差异（背景图、透明度渲染）。

### 非目标（Non-goals）

1. 本轮不实现背景图渲染链路等价（`bgType=1/2` 显示、图片透明度叠加）。
2. 不改动搜索/发现/详情/目录/正文五段链路。
3. 不重构既有阅读排版引擎与 `PagedReaderWidget` 渲染协议。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| E1 | `simple_reader_view.dart` 样式编辑弹层 | `dialog_read_bg_text.xml` + `BgTextConfigDialog.kt` | 缺少导入/导出/网络导入入口与流程 | 样式迁移与复用能力缺失 |
| E2 | `reading_settings.dart` 的 `ReadStyleConfig` | `ReadBookConfig.Config` | 仅保留颜色与名称字段，缺少背景图与透明度字段 | 无法完整复刻 `BgTextConfigDialog` |
| E3 | 无等价 service | `ReadBookConfig.import/getExportConfig` | 当前无 zip 序列化、兼容导入解析能力 | 扩展能力无法闭环 |
| E4 | 渲染层仅颜色背景 | `curBgDrawable`（颜色/asset/外部图片） | 不支持背景图样式渲染 | UI 行为与 legado 有语义差异 |

## 逐项检查清单（强制）

- 入口：样式编辑弹层是否可触发导入/导出/网络导入。
- 状态：导入后是否即时生效并持久化。
- 异常：空文件、损坏 zip、非法颜色、网络失败是否有可观测提示。
- 文案：`导入/导出/网络导入/导入成功/导出成功` 等语义是否正确。
- 排版：新增入口不破坏既有弹层信息层级与热区。
- 交互触发：点击导入、输入地址、确认导出的链路是否闭环。

## 实施步骤（依赖与并行）

### Step 1（串行，前置）

- 目标：新增扩展 ExecPlan 并落盘差异清单、阻塞项。
- 状态：`completed`
- 验证：`PLANS.md` 索引可追踪；本文件可独立执行。

### Step 2（串行，依赖 Step 1）

- 目标：实现阅读样式导入/导出 service（zip 打包与解析）。
- 涉及：
  - `lib/features/reader/services/read_style_import_export_service.dart`（新增）
  - `test/read_style_import_export_service_test.dart`（新增）
- 预期结果：
  - 导出 zip 含 `readConfig.json`
  - 可解析 legacy `readConfig.json` 并映射到 `ReadStyleConfig`
- 验证：定向测试 + 手工路径 A/B。
- 状态：`completed`

### Step 3（串行，依赖 Step 2）

- 目标：在样式编辑弹层接入 `导入/导出/网络导入` 入口。
- 涉及：`lib/features/reader/views/simple_reader_view.dart`
- 预期结果：三入口均可触发并反馈结果。
- 验证：手工路径 C/D/E。
- 状态：`completed`

### Step 4（串行，收尾）

- 目标：回填逐项对照清单、记录阻塞项、输出验证证据。
- 涉及：
  - `docs/plans/2026-02-20-read-style-import-export-extension-execplan.md`
  - `PLANS.md`
- 状态：`completed`

## 风险与回滚

### 失败模式

1. legacy `readConfig.json` 字段兼容不全导致导入失败或颜色异常。
2. zip 读写失败引起 UI 卡顿或无反馈。
3. 与现有 `readStyleConfigs` 持久化链路冲突导致主题索引错乱。

### 阻塞条件（触发即标记 `blocked`）

1. 背景图与透明度语义要求本轮必须等价，但当前渲染协议不支持。
2. 需求方要求本轮覆盖 `bgType=1/2` 的完整渲染能力（需跨模块重构）。

### 回滚策略

1. 新增 service 独立文件，按文件粒度回滚。
2. UI 入口改动集中在 `_editReadStyleFromDialog`，可函数级回滚。
3. 回滚后保留导入样例与失败日志，避免重复回归问题。

## 验收与证据

### 手工回归路径

1. 路径 A（导出）
   - 阅读页 -> 菜单 -> 界面 -> 背景文字样式（长按）-> 导出配置。
   - 期望：选择保存路径后提示导出成功。
2. 路径 B（本地导入）
   - 使用路径 A 导出的 zip，再执行导入配置。
   - 期望：样式名/前景色/背景色立即生效并持久化。
3. 路径 C（网络导入）
   - 点击网络导入，输入可访问 zip 地址。
   - 期望：导入成功并即时生效。
4. 路径 D（异常）
   - 导入损坏 zip / 非法 json / 非法颜色。
   - 期望：提示失败原因，不崩溃。
5. 路径 E（持久化）
   - 修改后退出阅读页并重新进入。
   - 期望：导入结果仍存在。

### 命令验证

- 开发过程：仅执行定向测试，不执行 `flutter analyze`。
- 提交推送前：执行且仅执行一次 `flutter analyze`（本轮未到提交阶段，不执行）。

## Progress

- `2026-02-20`：
  - 已完成：Step 1（ExecPlan 新建 + 差异清单落盘）。
  - 已完成：Step 2（服务层导入导出实现）
    - 新增 `read_style_import_export_service.dart`，实现：
      - zip 导出（`readConfig.json`）
      - 本地 zip 导入
      - 网络 zip 导入
      - legacy 关键字段兼容解析（`name/textColor/bgType/bgStr/backgroundColor`）。
  - 已完成：Step 3（UI 接入）
    - 在 `simple_reader_view.dart` 的样式编辑弹层新增：
      - `导入配置`（本地文件）
      - `网络导入`（URL 输入）
      - `导出配置`（保存 zip）。
    - 导入后即时应用样式并持久化，失败/降级路径均 toast 可观测。
  - 已完成：Step 4（收尾回填）
    - 新增测试 `test/read_style_import_export_service_test.dart`。
    - 补齐逐项对照清单与阻塞项记录。
  - 命令验证：
    - `flutter test test/read_style_import_export_service_test.dart test/reading_settings_test.dart test/simple_reader_view_compile_test.dart`（通过）。
  - 兼容影响：
    - 未新增 `ReadingSettings` 持久化字段，不影响历史阅读配置反序列化。
    - 新增 zip 导入导出仅为可选扩展入口，不影响核心阅读链路默认行为。

## 逐项对照清单（本轮）

| 检查项 | 结果 | 证据/说明 |
|---|---|---|
| 入口 | 通过 | 样式编辑弹层已新增 `导入配置/网络导入/导出配置` 入口 |
| 状态 | 通过 | 导入成功后调用 `applyStyle` 写回 `readStyleConfigs` 并持久化 |
| 异常 | 通过 | 空地址、HTTP 非 2xx、损坏 zip、缺失 `readConfig.json` 均有失败提示 |
| 文案 | 通过 | 维持 `导入配置/网络导入/导出配置/导入成功/导出失败` 语义 |
| 排版 | 通过 | 新入口以 `OptionRow` 形式并入现有编辑弹层，不改变主结构 |
| 交互触发 | 通过 | 文件导入、URL 导入、导出保存链路均可触发且有结果反馈 |
| 保留差异 | blocked | `bgType=1/2` 背景图渲染与 `bgAlpha` 透明度链路未等价（见下方阻塞说明） |

## Surprises & Discoveries

1. 当前 `ReadStyleConfig` 仅有 `name/backgroundColor/textColor`，与 legado 的 `Config` 差异较大。
2. 阅读渲染层目前仅支持颜色背景，暂不支持背景图渲染与透明度合成。
3. legacy `readConfig.json` 在实际输入中可能混用十六进制字符串、十进制有符号整型，需统一做颜色归一化。

## Decision Log

1. 本轮优先实现“导入/导出/网络导入”可闭环能力，背景图渲染保持 `blocked`。
2. 导入兼容策略采用“关键字段优先”（名称、文字色、背景色），其余字段不破坏现有设置。
3. 导出格式保持 `zip + readConfig.json`，尽量贴近 legado 协议，便于后续扩展背景图文件打包。
4. 对 `bgType!=0` 的导入数据执行显式降级：回退默认背景色并给出 warning，避免静默错误。

## Outcomes & Retrospective

- 本轮已完成：
  - 样式配置 zip 导入/导出与网络导入链路；
  - legado 关键字段兼容解析；
  - UI 入口接入与定向测试覆盖。
- 本轮仍 blocked：
  - 背景图（assets/外部图片）与透明度渲染链路未等价。
- 回补计划：
  - 后续独立扩展任务中补齐 `ReadStyleConfig` 背景图字段建模、阅读渲染层背景图协议、以及导入包背景文件落地策略。
