# 00 — 迁移范围与规则（Legado -> SoupReader）

## 1. 迁移目标

以 `/home/server/legado`（Legado）为语义第一标准，在 `/home/server/soupreader`（SoupReader）实现交互语义、状态流转、边界处理同义对齐。

## 2. 明确排除项（本轮不迁移、不补齐、UI 隐藏入口）

> 排除项处理方式：**仅隐藏入口**（UI 不展示），但底层结构保留。

- TTS / 朗读
- 漫画
- WebService（远程服务/局域网服务等）
- 订阅源（RSS）

### 2.1 SoupReader 的排除开关（集中式）

- 文件：`lib/core/config/migration_exclusions.dart`
- 开关：
  - `excludeRss`（默认 true）
  - `excludeTts`（默认 true）
  - `excludeManga`（默认 true）
  - `excludeWebService`（默认 true）

> 本轮要求：当 `excludeX=true` 时，对应模块入口 **不渲染**（隐藏），而不是仅保留“不可用锚点”或 toast。

## 3. 启动阶段交互策略（本轮固定）

不对齐 Legado 的“启动阶段弹窗链路”（隐私协议确认、首次帮助、更新日志弹窗、崩溃提示弹窗、首次设置本地密码等）。  
相关内容仅放在 SoupReader 的“设置/关于/开发者工具”等入口，避免冷启动打断。

## 4. 压缩包导入策略（本轮固定）

- 仅支持 `zip`
- `rar/7z` 作为 `blocked` 差异项记录到 `03_blocked_log.md`，并在 UI 侧保持一致提示与必要日志

## 5. 迁移条目来源（确定性，避免凭经验）

### 5.1 Legado 侧（必须完整阅读后再结论）

主导航/入口：
- `app/src/main/java/io/legado/app/ui/main/MainActivity.kt`

书架：
- `app/src/main/java/io/legado/app/ui/main/bookshelf/style1/BookshelfFragment1.kt`
- `app/src/main/java/io/legado/app/ui/main/bookshelf/style2/BookshelfFragment2.kt`
- 以及其子模块（BooksFragment/分组编辑等）

发现：
- `app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt`
- `app/src/main/java/io/legado/app/ui/book/explore/ExploreShowActivity.kt`

阅读器（排除朗读后仍需对齐菜单/亮度/进度/搜索/选择菜单）：
- `app/src/main/java/io/legado/app/ui/book/read/ReadMenu.kt`
- `app/src/main/java/io/legado/app/ui/book/read/TextActionMenu.kt`
- `app/src/main/java/io/legado/app/ui/book/read/SearchMenu.kt`
- `app/src/main/java/io/legado/app/ui/book/read/ReadBookActivity.kt`（体量大，按功能点切片确认）

书源/净化/替换/备份：
- `app/src/main/java/io/legado/app/ui/book/source/manage/**`
- `app/src/main/java/io/legado/app/ui/book/source/edit/**`
- `app/src/main/java/io/legado/app/ui/book/source/debug/**`
- `app/src/main/java/io/legado/app/ui/replace/**`
- `app/src/main/java/io/legado/app/help/storage/Backup.kt`
- `app/src/main/java/io/legado/app/help/storage/Restore.kt`

### 5.2 SoupReader 侧（关键入口）

主导航：
- `lib/main.dart`

核心模块目录：
- `lib/features/bookshelf/**`
- `lib/features/discovery/**`
- `lib/features/search/**`
- `lib/features/source/**`
- `lib/features/replace/**`
- `lib/features/reader/**`
- `lib/features/import/**`
- `lib/features/settings/**`

规则解析/书源引擎：
- `lib/features/source/services/rule_parser_engine.dart`

阅读排版设置：
- `lib/features/reader/models/reading_settings.dart`

## 6. 状态定义（用于矩阵与验收）

- **待对齐**：尚未实现或已知语义不一致
- **已存在待核对**：SoupReader 已有实现/代码路径，但尚未逐项对照 legado 行为
- **已对齐**：逐项对照完成（含边界与错误处理），并有手工回归记录
- **blocked**：本轮明确无法等价复现，已记录原因/影响/替代/回补计划
- **排除**：明确不迁移（见第 2 节）

