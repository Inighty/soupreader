# ACTIVE CONTEXT

- 最后更新时间: 2026-02-26
- 主计划: `PLANS.md`
- 当前阶段: `2026-02-26 legado「我的」全量迁移（除 Web 服务）`
- 当前状态: `active`

## 当前任务
- ID: `MY-18`
- 目标: 在 `docs/plans/2026-02-26-my-menu-parity-checklist.md` 按 `P0/P1/P2/EX-01` 回填逐项结论（已同义/差异）、原因与处理动作，并持续补齐终验证据
- 依赖: `MY-03`~`MY-17`（已完成）
- 交付物: `docs/plans/2026-02-26-my-menu-parity-checklist.md`、`tool/my_menu_regression_guard.sh`
- 验证: 结构字段检查（`legado 对照项/当前实现文件/检查维度/结论/原因/处理动作`）+ `PLANS.md` 索引接入检查 + 回归守卫脚本（`tool/my_menu_regression_guard.sh`）+ 手工路径终验（`MY-19`）

## 当前任务拆解（台账执行）
1. `P0`（书源/TXT/替换/字典）: `done`（已完成初次回填，待 `MY-19` 补手工证据）
2. `P1`（备份/主题/其它设置）: `done`（已完成初次回填，待 `MY-19` 补手工证据）
3. `P2`（书签/阅读记录/关于/文件管理）: `done`（已完成初次回填，待 `MY-19` 补手工证据）
4. `EX-01`（`webService`）: `blocked`（按范围冻结，保留占位语义）
5. 台账终验回填: `in_progress`（按手工路径逐条补证据）
6. 回归守卫脚本: `done`（新增固定字段齐全性 + `R-01~R-13` 单锚点一致性 + `EX-01` blocked 语义禁入检查，支持“字段缺失非 0 / 修复后 0”）

## 下一任务
- ID: `MY-19`
- 目标: 统一回归验证与提交前检查（提交前仅一次 `flutter analyze`）
- 依赖: `MY-18`

## 阻塞项
- `EX-01 webService`: `blocked`
  - 原因: 需求明确“除 Web 服务外”
  - 处理: 仅保留一级入口占位语义，不进入实现

## 最近交付（最多 5 条）
1. `MY-18` 进行中：升级回归守卫脚本 `my_menu_regression_guard.sh`（结构门禁）
   - 变更文件：`tool/my_menu_regression_guard.sh`
   - 新增字段齐全性检查：逐文件强制 `入口/步骤/结果/异常分支/处理动作/关联锚点` 六字段单定义
   - 新增锚点一致性检查：`R-01~R-13` 证据 `关联锚点` 与主回归单 `台账引用锚点` 一一对应且单锚点
   - 保留 EX-01 专项守卫：`R-13` 仅允许 `blocked` 占位语义，禁止出现 webService 功能实现验收描述
   - 运行验证1：`tool/my_menu_regression_guard.sh` 当前仓库输出逐项 `PASS/FAIL` 与命中行号，返回 `exit 0`
   - 运行验证2（故障注入）：临时移除 `R-01` 的 `处理动作` 字段后脚本返回 `exit 1`；恢复字段后返回 `exit 0`
   - 兼容影响: 仅文档结构守卫升级，不影响运行时代码、持久化键或数据库结构
2. `MY-18` 进行中：P2-04 文件管理补齐 `menu_create` 同义链路
   - 变更文件：`lib/features/settings/views/file_manage_view.dart`
   - 顶栏新增“新建文件夹”入口（对应 legado `file_chooser.xml/menu_create`）
   - 新增输入弹窗与创建流程：默认在当前目录创建子文件夹，成功后清空筛选并刷新列表
   - 新增异常提示分支：空名称、名称非法、名称已存在、IO 异常均可观测
   - 命令验证：`rg -n "新建文件夹|_showCreateFolderDialog|_createFolder|文件夹名不能为空|名称已存在" lib/features/settings/views/file_manage_view.dart`
   - 启动冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"` 通过
   - 兼容影响: 仅页面交互增强，不新增数据库结构与持久化键
3. `MY-16` 完成：关于页菜单与偏好项（日志/崩溃/协议/更新）迁移
   - 顶栏补齐 legacy `about.xml` 菜单：保留 `分享` 并新增 `评分`（`market://details` + Web 回退）
   - 列表补齐 `contributors/update_log/check_update/crashLog/saveLog/createHeapDump/privacyPolicy/license/disclaimer` 全入口
   - `更新日志` 摘要改为 `版本 <versionName>`；文档入口统一接入 `assets/docs/*.md`
   - `崩溃日志` 接入 `ExceptionLogsView(title: 崩溃日志)`；清空动作补确认与结果提示
   - `保存日志/创建堆转储` 落地到备份目录（`logs/*.json`、`heapDump/*.json`），未设目录/写入失败分支均有明确提示与日志节点
   - `app_help_dialog` 支持自定义标题，about 文档可按入口语义展示
   - 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"` 通过
   - 手工路径：`我的 -> 关于` 逐项点击校验可达与提示语义（CLI 环境待终端外执行）
   - 兼容影响: 新增静态资源 `assets/docs/*`，复用既有 `backupPath/ExceptionLogService`，无数据库结构变更
4. `MY-15` 完成：阅读记录页搜索/总时长/清理交互收口
   - 新增搜索过滤（书名关键字实时过滤）与空搜索态文案
   - 新增“总阅读时间 + 清空”头部区域，时长格式对齐 legacy `formatDuring`
   - 新增全量清理确认（`是否确认删除？`），确认后清空全部阅读记录与阅读时长
   - 单条“清除阅读记录”补齐二次确认（`是否确认删除 <书名>？`）
   - 保留“继续阅读/清除阅读记录/从书架移除”边界动作与排序/开关勾选态持久化
   - `SettingsService` 新增 `getTotalBookReadRecordDurationMs/clearAllBookReadRecordDuration`
   - 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"` 通过
   - 手工路径：`我的 -> 阅读记录` 验证排序切换、开启记录、搜索、单条删除与全量清理流程（CLI 环境待终端外执行）
   - 兼容影响: 复用既有 `book_read_record_duration_map`，无数据库结构变更
5. `MY-14` 完成：书签页菜单与条目点击闭环
   - 书签页顶栏动作收口并保持仅 `导出/导出(MD)`（对齐 `bookmark.xml`）
   - 条目点击新增“书签详情”弹层，展示章节/书籍/进度/摘录摘要
   - 详情弹层新增 `定位阅读`，按 `chapterPos -> chapterProgress` 写入后跳转 `SimpleReaderView` 完成定位
   - 导出成功/失败均写入 `all_bookmark.menu_export(_md)` 日志节点；定位失败写入 `all_bookmark.item_open_reader`
   - `ReaderBookmarkExportService` 成功返回统一文案 `导出成功`，提示语义稳定
   - 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"` 通过
   - 手工路径：`我的 -> 书签` 验证 `导出 JSON/MD + 条目点击详情 + 定位阅读` 闭环（CLI 环境待终端外执行）
   - 兼容影响: 仅复用既有书签字段与阅读进度键，无数据库结构变更
## 备注
- 迁移级别口径保持不变：交互路径、状态流转、边界处理、菜单结构、文案语义需与 legado 同义（UI 风格差异除外）。
- 若出现无法等价复现，先在 `PLANS.md` 标记 `blocked` 并记录原因/影响/替代方案/回补计划，再继续其它分支。
