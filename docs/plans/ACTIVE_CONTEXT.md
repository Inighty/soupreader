# Active Context（任务快速定位）

状态：`active`  
最后更新：`2026-02-26`

## 1) 默认读取顺序（强制）

1. 完整读取本文件（轻量快照）。
2. 仅读取 `PLANS.md` 前置索引区（快速定位主计划与 Todo）。
3. 仅按需定向读取 `docs/plans/2026-02-21-legado-all-features-one-by-one-execplan.md` 对应小节。  
4. 未触发深读条件时，禁止默认全量扫描所有计划文件与历史 Progress。

## 2) 当前执行面

- 主计划：`legado 全功能逐项迁移（One-by-One）`
- 主计划状态：`active`
- 主执行文档：`docs/plans/2026-02-21-legado-all-features-one-by-one-execplan.md`
- 跟踪台账：`docs/plans/2026-02-21-legado-feature-item-tracker.csv`
- 优先级队列：`docs/plans/2026-02-21-legado-feature-priority-queue.csv`
- 当前任务：`P3-seq92 / book_read_record.xml / @+id/menu_sort_read_time / 阅读时间排序`
- 当前任务状态：`active`
- 下一任务：`完成 P3-seq92 后按全局 detail_later 队列继续推进 P3-seq89（book_read_record/menu_sort）`

## 3) 阻塞与冻结

- `P3(book_manga)`：`blocked`（用户冻结，未收到“开始做漫画功能”指令前不解锁）
- `detail_later` 全局后置项：保持后置，不与主功能并行启动

## 4) 最近交付（仅保留近期）

- `2026-02-26`：完成 `P3-seq91`（`book_read_record/menu_sort_read_long`），对照 legado `book_read_record.xml` 与 `ReadRecordActivity(sortMode=1)` 收敛“阅读记录页阅读时长排序”语义；Flutter 侧在 `ReadingHistoryView` 右上角“更多”菜单补齐 checkable 动作“阅读时长排序”，点击后写入 `readRecordSort=1` 并按累计阅读时长降序刷新列表；`SimpleReaderView` 同步补齐阅读会话时长增量累计并持久化到 `SettingsService`，仅在 `enableReadRecord=true` 时计入，清除阅读记录时同步清理该书时长。优先级队列 `seq91` 已置 `done`，tracker 已回填 `seq91(done)` 与 `seq92(pending)` 映射行，队列推进下一项 `P3-seq92`（book_read_record/menu_sort_read_time）。

- `2026-02-26`：完成 `P3-seq86`（`book_read/menu_help`），对照 legado `book_read.xml`、`ReadBookActivity.onCompatOptionsItemSelected(menu_help)`、`ReadBookActivity.showHelp("readMenuHelp")` 与 `ActivityExtensions.showHelp(fileName)` 收敛“阅读菜单帮助入口文档化承载”语义；Flutter 侧 `SimpleReaderView` 在 `ReaderLegacyReadMenuAction.help` 分支由 toast 收敛为读取 `assets/web/help/md/readMenuHelp.md` 后弹出 `showAppHelpDialog`，关闭后保持当前阅读会话状态，失败分支提示“帮助文档加载失败：<error>”。优先级队列 `seq86` 已置 `done`，tracker 已回填 `seq86(done)` 映射行，队列推进下一项 `P3-seq91`（book_read_record/menu_sort_read_long）。

- `2026-02-26`：完成 `P3-seq85`（`book_read/menu_log`），对照 legado `book_read.xml` 与 `ReadBookActivity.onCompatOptionsItemSelected(menu_log)` 收敛“阅读菜单日志入口”语义；Flutter 侧 `SimpleReaderView` 在 `ReaderLegacyReadMenuAction.log` 分支改为直接弹出 `showAppLogDialog`，点击后无前置条件、关闭后保持当前阅读会话状态，不再跳转异常日志页。优先级队列 `seq85` 已置 `done`，tracker 已回填 `seq85(done)` 与 `seq86(pending)` 映射行，队列推进下一项 `P3-seq86`（book_read/menu_help）。

- `2026-02-26`：完成 `P2-seq170`（`book_toc/menu_log`），对照 legado `book_toc.xml` 与 `TocActivity.onCompatOptionsItemSelected(menu_log)` 收敛“目录页更多菜单日志入口”语义；Flutter 侧 `SearchBookInfoView` 的目录承载 `_SearchBookTocView` 在“目录操作”菜单补齐一级动作“日志”，点击后直接弹出 `showAppLogDialog` 且无前置条件限制，关闭后保持当前目录页状态不变。优先级队列 `seq170` 已置 `done`，tracker 已回填 `seq170(done)` 映射行，队列推进下一项 `P3-seq85`（book_read/menu_log）。

- `2026-02-26`：完成 `P10-seq407`（`web_view/menu_copy_url`），对照 legado `web_view.xml`、`WebViewActivity.onCompatOptionsItemSelected(menu_copy_url)` 与 `Context.sendToClip` 收敛“网页承载页拷贝 URL”语义；Flutter 侧 `SourceWebVerifyView` 的“更多”菜单补齐一级动作“拷贝 URL”，点击后固定复制 `initialUrl(baseUrl)` 到剪贴板并提示“复制完成”，成功路径保持当前网页承载页停留。优先级队列 `seq407` 已置 `done`，tracker 已回填 `seq407(done)` 映射行，队列推进下一项 `P2-seq170`（book_toc/menu_log）。

## 5) 深度读取触发条件

- 快照与 `PLANS.md` / 主 ExecPlan 关键信息不一致；
- 当前任务进入 `blocked`，或出现迁移例外（需走 AGENTS 1.1.2）；
- 需要切换 Phase/里程碑，且无法由当前快照判定下一项；
- 需求方明确要求全量审阅历史计划与进度。

## 6) 回填要求（每个可交付点）

- 必须同步更新：`最后更新`、`当前任务`、`下一任务`、`阻塞与冻结`、`最近交付`。
- 若与主 ExecPlan 记录冲突，先修正冲突再继续实现。
