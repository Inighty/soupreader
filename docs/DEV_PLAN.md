# SoupReader 开发计划（2026-02-11）

> 目标：在当前 AGENTS 约束下，完成“功能梳理 + 可执行 Todo”，并以同级项目 `legado` 的**实际功能行为与边界处理**为参照持续推进兼容。
>
> 说明：本计划按“功能”组织内容（搜索/发现/书籍详情/目录/正文等），不使用抽象表述。

## 0. 计划依据（已完成）

### 0.1 强制规则对齐
- 全程中文沟通。
- 书源处理与规则执行：以 `legado` 的功能行为为第一标准。
- 开发前先确认并读取 legado 中对应实现（读完相关文件再下结论）。

### 0.2 已读取的 legado 参考文件（完整）
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeRule.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/RuleAnalyzer.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeUrl.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeByJSoup.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeByXPath.kt`
- `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeByJSonPath.kt`
- `app/src/main/java/io/legado/app/data/entities/BookSource.kt`
- `app/src/main/java/io/legado/app/data/entities/BaseSource.kt`
- `app/src/main/java/io/legado/app/data/entities/rule/*.kt`

---

## 1. 功能梳理（现状总览）

> 状态说明：
> - ✅ 已有可用实现
> - 🟡 已实现但需要补齐/对齐
> - ⛔ 尚未落地

### 1.1 启动与基础
- ✅ 应用启动：数据库、设置、CookieStore 初始化。
- ✅ 主导航：书架 / 发现 / 搜索 / 书源 / 设置。
- ✅ 主题：亮/暗模式，统一页面容器。

### 1.2 数据层与存储
- ✅ Hive 数据层：书籍、章节、书源、书签、替换规则。
- ✅ Repository 封装：`BookRepository` / `ChapterRepository` / `SourceRepository`。
- 🟡 书源持久化存在字段丢失风险（如 `ruleReview` 等）：仍需做“全字段保真”。

### 1.3 书源管理（导入/编辑/导出）
- ✅ 书源导入：剪贴板 / 文件 / URL，支持对象/数组/嵌套字符串 JSON。
- ✅ 冲突处理：覆盖/跳过/取消，导入摘要与告警提示。
- ✅ 书源编辑：基础字段、规则字段、JSON 模式、调试模式。
- ✅ 书源导出：LegadoJson 风格（剥离 null）。
- 🟡 `exploreScreen` / `ruleReview` 等字段目前仅“存储与编辑可见”，尚未形成完整使用场景。

### 1.4 五个核心功能（均需可调试）

#### 1.4.1 搜索（search）
- ✅ 多书源聚合、按权重稳定排序。
- ✅ 结果去重（同源同书链接）。
- ✅ 失败书源摘要与原因提示。
- ✅ 调试输出：支持抓取快照与结构化结果。

#### 1.4.2 发现（explore）
- ✅ 基于 `exploreUrl + ruleExplore` 拉取列表并聚合展示。
- ✅ 失败书源摘要与原因提示。
- ✅ 调试输出：支持抓取快照与结构化结果。

#### 1.4.3 书籍详情（bookInfo）
- ✅ 已具备解析方法：`getBookInfo` / `getBookInfoDebug`。
- 🟡 仍需回归：复杂站点字段缺失/空字段时的提示与回退策略。

#### 1.4.4 目录（toc）
- ✅ 已具备解析方法：`getToc` / `getTocDebug`。
- ✅ 目录去重、空章节过滤、异常回滚。
- 🟡 仍需回归：目录分页、分卷等复杂目录形态。

#### 1.4.5 正文（content）
- ✅ 已具备解析方法：`getContent` / `getContentDebug`。
- 🟡 仍需回归：正文分页、下一章/下一页规则、阻断规则等复杂场景。

### 1.5 规则解析与兼容点（摘要）
- ✅ 已覆盖常见兼容点：
  - 规则分割（`&&` / `||` / `%%`）
  - CSS nth
  - URL option
  - nextTocUrl / nextContentUrl
  - 变量规则、跨阶段变量、阶段 JS
- 🟡 与 legado 仍有差距（见 P0）：
  - `concurrentRate` 未接入请求并发/频率控制。
  - `loginUrl/loginUi/loginCheckJs` 未形成可用的登录闭环。
  - `coverDecodeJs` 尚未形成统一封面解密流程。

### 1.6 调试与诊断
- ✅ 控制台日志、源码快照（list/book/toc/content）、结构化诊断。
- ✅ 调试包导出（zip/json/txt），可带源码与摘要。
- ✅ 书源可用性批量检测（仅启用/全部）。

### 1.7 阅读器
- ✅ 章节加载、分页/滚动、目录、书签、进度保存。
- ✅ 快捷设置：主题、排版、翻页、状态栏、自动阅读、点击区域。
- ✅ 换源：按书名/作者匹配候选并切换。
- 🟡 部分实现仍是占位或简化逻辑（如繁简转换 TODO、局部边界 TODO）。

### 1.8 本地导入（TXT/EPUB）
- ✅ TXT/EPUB 导入、章节落库、TXT 排版归一化处理。
- ✅ 清理缓存时保护本地书籍缓存。

### 1.9 替换净化
- ✅ 替换规则管理、作用域过滤、正则替换超时隔离。
- ✅ 阅读时可应用净化（章节标题/正文内容）。

### 1.10 备份恢复
- ✅ 备份导出/导入（设置、书源、书籍、章节），支持合并与覆盖。
- 🟡 可继续增强：版本演进与字段保真校验。

### 1.11 设置中心
- ✅ 已有：主题、阅读设置、备份、缓存、书源入口等。
- ⛔ 仍为占位：订阅管理、语音管理、广告屏蔽、部分高级设置等。

---

## 2. 差距优先级（按兼容影响排序）

### P0（必须先做）
1. `concurrentRate`：接入请求并发/频率控制。
2. 登录：落地 `loginUrl/loginUi/loginCheckJs` 的执行与校验闭环。
3. 封面：统一落地 `coverDecodeJs`（封面解密/后处理）。
4. 书源字段保真：导入/编辑/存储全流程不丢字段。

### P1（主流程稳定）
1. 目录/正文复杂分页场景回归（分页、阻断规则等）。
2. 调试信息更好用（错误分类 + 更准确的定位提示）。
3. 搜索/发现/加书一致性回归（跨源同书匹配稳定性）。

### P2（体验补齐）
1. 设置中的占位项分批落地（优先订阅/语音入口的最小可用版）。
2. 阅读器 TODO 收敛（繁简转换真实实现、边界交互完善）。

---

## 3. 分阶段计划

### 阶段 A（第 1 周）：兼容基线冻结
- 输出 `legado → soupreader` 对照清单（字段、规则、请求与边界处理）。
- 建立 P0 的验收标准与回归样本。
- 完成一轮“先核对差异，不改动现有逻辑”的基线核验。

**阶段验收**
- P0 项均有“已对齐/待补齐”的明确结论。
- `flutter analyze` 通过。

### 阶段 B（第 2-3 周）：P0 落地
- 落地 `concurrentRate`。
- 落地登录闭环（含 `loginCheckJs`）。
- 落地 `coverDecodeJs`。
- 完成书源字段保真修复。

**阶段验收**
- 以上四项均有可演示路径。
- 回归用例通过（本项目规则：至少 `flutter analyze`）。

### 阶段 C（第 4-5 周）：P1 稳定性强化
- 目录/正文复杂分页场景回归与修正。
- 调试定位体验提升。
- 搜索/发现/加书一致性优化。

**阶段验收**
- 批量书源可用性检测错误率下降。
- 核心失败场景日志能直接定位问题点。

### 阶段 D（第 6 周+）：P2 体验补齐
- 分批实现设置中的高价值占位项。
- 阅读器剩余 TODO 收敛。

**阶段验收**
- 至少 2~3 个长期占位项转为可用功能。

---

## 4. 本周启动 Todo（可直接执行）

1. `P0-1 concurrentRate`：设计并实现请求并发/频率控制（解析引擎内集中落地）。
2. `P0-2 登录闭环`：实现 `loginUrl/loginUi/loginCheckJs`（含调试输出）。
3. `P0-3 封面后处理`：实现 `coverDecodeJs`。
4. `P0-4 字段保真`：修复书源导入/编辑/存储一致性，避免丢字段。
5. 每完成一项立即更新 `docs/DEV_PROGRESS.md`。

---

## 5. 验证与交付约定

- 本项目当前规则：改动后至少执行 `flutter analyze`。
- 每个可交付点需要记录：
  - 做了什么
  - 为什么
  - 如何验证
  - 兼容影响
