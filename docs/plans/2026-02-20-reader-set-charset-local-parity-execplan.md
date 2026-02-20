# 阅读器“设置编码（setCharset）”回补（对照 legado）ExecPlan

- 状态：`done`
- 日期：`2026-02-20`
- 负责人：`codex`
- 范围类型：`迁移级别（核心链路回补）`

## 背景与目标

### 背景

在现有 soupreader 中，阅读菜单 `设置编码` 仍是占位提示（`书籍级编码覆盖尚未接入正文解析链路`）。

本轮对照 legado 已完整读取以下实现文件：

- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/BaseReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/ui/book/read/ReadBookViewModel.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/model/ReadBook.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/data/entities/Book.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/model/localBook/TextFile.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/model/localBook/LocalBook.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/book/BookHelp.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/model/webBook/WebBook.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/help/http/OkHttpUtils.kt`
- `/home/server/legado/app/src/main/java/io/legado/app/constant/AppConst.kt`

legacy 基准语义（本任务相关）：

1. `设置编码` 菜单弹窗可输入/选择 charset（候选包含 `UTF-8/GB2312/GB18030/GBK/Unicode/UTF-16/UTF-16LE/ASCII`）。
2. 确认后执行 `ReadBook.setCharset(charset)`：写入 `book.charset`，并触发 `loadChapterList(book)` 重建目录/正文链路。
3. 对本地 TXT，`TextFile` 解析会使用 `book.fileCharset()` 读取与分章；修改 charset 后重载可即时生效。

### 目标（Success Criteria）

1. soupreader 阅读菜单 `设置编码` 不再占位，具备可操作弹窗与确认动作。
2. 编码设置按“书籍维度”持久化，重进阅读页后可恢复。
3. 当前书籍为本地 TXT 时，确认编码后会重解析本地文件并替换章节内容，阅读页即时刷新。
4. 非本地 TXT 书籍保持可观测提示，不引入崩溃或无响应。

### 非目标（Non-goals）

1. 不新增 `customPageKey` 自定义按键映射（仍属扩展冻结项）。
2. 不扩展朗读设置弹窗或其它与本任务无关入口。
3. 不调整 search/explore/bookInfo/toc/content 五段抓取规则本体。

## 差异点清单（实现前）

| 编号 | soupreader 位置 | legado 位置 | 差异描述 | 影响 |
|---|---|---|---|---|
| SC1 | `lib/features/reader/views/simple_reader_view.dart:_executeLegacyReadMenuAction` | `BaseReadBookActivity.showCharsetConfig` + `ReadBook.setCharset` | 现为占位提示，未提供 charset 配置弹窗与提交动作 | 功能入口不可用 |
| SC2 | `lib/features/import/txt_parser.dart` | `TextFile.kt` | 无“强制指定编码”重解析能力，导入后无法按新编码重建章节内容 | 本地 TXT 无法等价回补 |
| SC3 | `lib/features/bookshelf/models/book.dart`（无 charset 字段） | `Book.charset` | 缺少书籍级编码持久化载体（需等价替代） | 重进阅读页配置不可恢复 |

## 逐项检查清单（强制）

- 入口：阅读菜单 `设置编码` 是否可达并可提交。
- 状态：提交后当前书籍编码值是否持久化、重进是否可恢复。
- 异常：非本地 TXT、文件丢失、解析失败时是否有可观测提示且不崩溃。
- 文案：候选编码与提示语义是否与 legado 对齐（避免近义改写）。
- 排版：弹窗结构与热区是否保持当前阅读菜单风格一致。
- 交互触发：确认后是否触发章节重建与当前章节刷新。

## 实施步骤（依赖与并行）

### Step 1（串行，前置）

- 目标：落盘 ExecPlan、差异点清单、检查清单。
- 状态：`completed`
- 验证：`PLANS.md` 建立索引并能定位本文档。

### Step 2（串行，依赖 Step 1）

- 目标：实现 `设置编码` 核心链路（弹窗 + 持久化 + 本地 TXT 重解析）。
- 涉及：
  - `lib/features/reader/views/simple_reader_view.dart`
  - `lib/features/reader/services/reader_charset_service.dart`（新增）
  - `lib/features/import/txt_parser.dart`
- 状态：`completed`

### Step 3（可并行，依赖 Step 2）

- 目标：补齐定向测试。
- 涉及：
  - `test/txt_parser_*`
  - `test/reader_*`
- 状态：`completed`

### Step 4（串行，依赖 Step 2/3）

- 目标：逐项对照回填、证据落盘、兼容影响记录。
- 状态：`completed`

## 逐项对照清单（实现后）

| 编号 | 差异项 | 对照结果 | 说明 |
|---|---|---|---|
| SC1 | `设置编码` 为占位提示 | 已同义 | `simple_reader_view` 已改为可操作编码选择弹窗，菜单动作不再占位。 |
| SC2 | 无强制编码重解析能力 | 已同义 | `TxtParser` 新增 `forcedCharset` 与 `reparseFromFile`，可按指定编码重建章节。 |
| SC3 | 缺少书籍级编码持久化载体 | 已同义（实现差异） | 采用 `reader.book.charset.<bookId>` 持久化键等价承载 `Book.charset` 语义，重进可恢复。 |

## 风险与回滚

### 失败模式

1. 强制编码解析失败导致 TXT 正文乱码或章节为空。
2. 替换章节后当前章节定位漂移，阅读进度体验回退。
3. 配置持久化未生效导致重进后丢失。

### 阻塞条件（触发即标记 `blocked`）

1. 本地 TXT 解析链路无法在不破坏现有导入协议下安全重建。
2. 章节替换导致阅读主链路（目录/正文）出现不可接受回归且无可控回滚路径。

### 回滚策略

1. 文件级回滚：
   - `lib/features/reader/views/simple_reader_view.dart`
   - `lib/features/reader/services/reader_charset_service.dart`
   - `lib/features/import/txt_parser.dart`
2. 测试回滚与实现分离，确保可独立撤回。

## 验收与证据

### 手工回归路径

1. 本地 TXT 阅读页 -> 菜单 -> `设置编码` -> 切换为 `GBK`/`UTF-8`。
2. 确认后观察当前章节是否刷新，目录与正文是否可继续阅读。
3. 退出阅读页后重进，确认编码选择仍在。
4. 对 EPUB/在线书籍触发 `设置编码`，确认提示可观测且不崩溃。

### 命令验证

- 开发过程：仅执行定向测试，不执行 `flutter analyze`。
- 提交推送前：执行且仅执行一次 `flutter analyze`。
- 本轮执行：
  - `flutter test test/txt_parser_charset_override_test.dart test/txt_parser_typography_test.dart test/reader_charset_service_test.dart`
  - `flutter test test/simple_reader_view_compile_test.dart test/reader_legacy_menu_helper_test.dart`

## Progress

- `2026-02-20`：
  - 完成 Step 1：新建 ExecPlan、落盘差异清单与检查清单。
  - 完成 Step 2：实现 `setCharset` 主链路。
    - 新增 `lib/features/reader/services/reader_charset_service.dart`，提供书籍维度 charset 归一化与持久化。
    - `lib/features/reader/views/simple_reader_view.dart` 菜单动作 `setCharset` 由占位改为弹窗选择，并接入本地 TXT 重解析与章节替换刷新。
    - `lib/features/import/txt_parser.dart` 增加 `forcedCharset` 参数与 `reparseFromFile`，支持既有 `bookId` 重建章节。
    - `lib/features/import/import_service.dart` 在 TXT 导入后落盘初始 charset，保证重进恢复。
  - 完成 Step 3：新增并通过定向测试。
    - `test/txt_parser_charset_override_test.dart`
    - `test/reader_charset_service_test.dart`
  - 完成 Step 4：逐项对照与证据回填。
  - 兼容影响：
    - 新增书籍级编码持久化键：`reader.book.charset.<bookId>`；
    - 本地 TXT 在菜单修改编码后将重建章节缓存，章节 ID 保持 `<bookId>_<index>` 规则，阅读位置按标题近似回定位；
    - 非本地 TXT 仅保存编码值，不触发重解析。

## Step 4 逐项检查清单回填（`2026-02-20`）

| 检查项 | 核验方式 | 结果 | 备注 |
|---|---|---|---|
| 入口 | `simple_reader_view` 菜单动作代码复核 + `test/simple_reader_view_compile_test.dart` | 通过 | `设置编码` 可达且可提交 |
| 状态 | `test/reader_charset_service_test.dart` | 通过 | 书籍维度持久化与清理正常 |
| 异常 | 代码复核：缺少路径/重解析失败均有可观测 toast；非 TXT 分支仅保存 | 通过 | 不崩溃、不静默 |
| 文案 | 代码复核：弹窗标题 `设置编码`、候选项与 legado 一致 | 通过 | 语义同义 |
| 排版 | Cupertino ActionSheet 复用现有阅读菜单弹层风格 | 通过 | 不改变现有热区结构 |
| 交互触发 | `test/txt_parser_charset_override_test.dart` + 代码复核 | 通过 | 确认后触发章节重建与刷新 |

## Surprises & Discoveries

1. legado 的 `setCharset` 主要影响本地 TXT 读取链路（`TextFile.fileCharset`），网络正文并未直接消费 `book.charset`。
2. soupreader 当前无 `Book.charset` 字段，需采用等价持久化方案承载“书籍级编码”。

## Decision Log

1. 本轮优先对齐 legado 的“本地书籍编码设置 + 重载”核心语义，不扩大到无基准的网络扩展行为。
2. 采用“书籍维度独立持久化键 + 本地 TXT 重解析替换章节”的等价实现，避免大范围数据库 schema 迁移风险。
3. 保持 `Book` 数据结构不做 schema 迁移，降低跨模块改动风险；通过 `DatabaseService` 键值层完成等价持久化。

## Outcomes & Retrospective

- 本轮结果：
  - 阅读菜单 `设置编码` 已从占位改为可用链路；
  - 本地 TXT 支持按指定编码重解析并即时刷新阅读内容；
  - 编码选择在书籍维度持久化并覆盖重进场景。
- 后续建议：
  - 真机补充手工回归（尤其 iOS 文件路径为空场景）；
  - 提交推送前按仓库规则执行一次且仅一次 `flutter analyze`。
