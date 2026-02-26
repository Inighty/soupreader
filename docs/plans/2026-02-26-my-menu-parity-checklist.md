# 2026-02-26 「我的」菜单逐项对照台账（MY-18）

- 状态: `active`
- 关联计划: `PLANS.md` -> `2026-02-26 legado「我的」全量迁移（除 Web 服务）` -> `MY-18`
- 对照口径: 迁移级别（除 UI 风格差异外，交互语义、状态流转、边界处理同义）
- 记录规则: 每条必须包含 `legado 对照项`、`当前实现文件`、`检查维度`（入口/状态/异常/文案/排版/交互触发）、`结论`、`原因`、`处理动作`

## P0（核心链路）

### P0-01 书源管理全链路
- legado 对照项:
  - `/home/server/legado/app/src/main/res/menu/book_source.xml`
  - `/home/server/legado/app/src/main/res/menu/book_source_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/book_source_item.xml`
  - `/home/server/legado/app/src/main/res/menu/source_sub_item.xml`
  - `/home/server/legado/app/src/main/res/menu/source_edit.xml`
  - `/home/server/legado/app/src/main/res/menu/book_source_debug.xml`
  - `/home/server/legado/app/src/main/res/menu/import_source.xml`
- 当前实现文件:
  - `lib/features/source/views/source_list_view.dart`
  - `lib/features/source/views/source_edit_legacy_view.dart`
  - `lib/features/source/views/source_debug_legacy_view.dart`
- 检查维度:
  - 入口: 一级入口、顶栏菜单、选中态菜单、条目菜单、编辑/调试/导入入口均可达。
  - 状态: 排序/分组/启用态/发现态/选中态流转与持久化同义。
  - 异常: 导入失败、删除取消、调试帮助失败分支均有可观测提示。
  - 文案: 菜单标题、确认文案与 legacy 业务语义一致。
  - 排版: 顶栏、列表、底栏分层与交互热区同义。
  - 交互触发: 点击/长按/更多/二次确认的触发路径与 legacy 同义。
- 结论: `已同义`
- 原因: `MY-03~MY-06` 已收口排序顺序、删除链路与扩展菜单移除，菜单结构与触发逻辑已对齐。
- 处理动作: 维持现状；在 `MY-19` 按手工路径补最终回归证据。

### P0-02 TXT 目录规则
- legado 对照项:
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule.xml`
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule_item.xml`
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule_edit.xml`
- 当前实现文件:
  - `lib/features/reader/views/txt_toc_rule_manage_view.dart`
  - `lib/features/reader/views/txt_toc_rule_edit_view.dart`
  - `lib/features/reader/services/txt_toc_rule_store.dart`
  - `assets/web/help/md/txtTocRuleHelp.md`
- 检查维度:
  - 入口: 顶栏、选中态、条目、编辑页菜单入口齐全。
  - 状态: 启用态、选中态、批量删除后的列表刷新状态一致。
  - 异常: 导入失败、帮助加载失败、删除取消均有提示。
  - 文案: `帮助/复制规则/粘贴规则/删除确认` 文案同义。
  - 排版: 选中态底栏新增主删除后层级与热区保持一致。
  - 交互触发: `menu_help/menu_copy_rule`、批量删除触发链路已闭环。
- 结论: `已同义`
- 原因: `MY-07` 已补齐缺失菜单项与批量删除执行链路。
- 处理动作: 维持现状；`MY-19` 补充导入与帮助加载手工回归证据。

### P0-03 替换规则
- legado 对照项:
  - `/home/server/legado/app/src/main/res/menu/replace_rule.xml`
  - `/home/server/legado/app/src/main/res/menu/replace_rule_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/replace_rule_item.xml`
  - `/home/server/legado/app/src/main/res/menu/replace_edit.xml`
- 当前实现文件:
  - `lib/features/replace/views/replace_rule_list_view.dart`
  - `lib/features/replace/views/replace_rule_edit_view.dart`
  - `lib/core/database/repositories/replace_rule_repository.dart`
  - `assets/web/help/md/replaceRuleHelp.md`
- 检查维度:
  - 入口: 顶栏、选中态、条目、编辑页菜单入口齐全且顺序同义。
  - 状态: 选中态批量操作、排序位次、分组筛选状态一致。
  - 异常: 导入失败、帮助加载失败、删除取消分支可观测。
  - 文案: 移除非 legacy 扩展文案后语义一致。
  - 排版: 选中态与条目动作布局保持同层级热区。
  - 交互触发: 批量删除、复制/粘贴规则、帮助入口触发一致。
- 结论: `已同义`
- 原因: `MY-08` 已收口菜单集合并补齐 `menu_help/menu_copy_rule` 与批量删除。
- 处理动作: 维持现状；`MY-19` 回归核对“导入/帮助/批量操作”三条路径。

### P0-04 字典规则
- legado 对照项:
  - `/home/server/legado/app/src/main/res/menu/dict_rule.xml`
  - `/home/server/legado/app/src/main/res/menu/dict_rule_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/dict_rule_edit.xml`
- 当前实现文件:
  - `lib/features/reader/views/dict_rule_manage_view.dart`
  - `lib/features/reader/views/dict_rule_edit_view.dart`
  - `lib/features/reader/services/dict_rule_store.dart`
  - `assets/web/help/md/dictRuleHelp.md`
- 检查维度:
  - 入口: 顶栏、选中态、编辑页菜单入口齐全且顺序同义。
  - 状态: 启用态与选中态批量操作流转一致。
  - 异常: 导入失败、帮助加载失败、剪贴板格式错误均可观测。
  - 文案: 帮助、复制/粘贴、删除确认语义一致。
  - 排版: 列表与选中态底栏布局同义。
  - 交互触发: `menu_help/menu_copy_rule`、批量删除触发链路同义。
- 结论: `已同义`
- 原因: `MY-09` 已补齐缺失入口、菜单顺序与批量删除链路。
- 处理动作: 维持现状；`MY-19` 执行手工路径补证据。

### MY-19 终验证据位（P0）
- 入口: `我的 -> 书源管理 / TXT目录规则 / 替换净化 / 字典规则`（待回填）
- 步骤: `待回填（按 P0-01~P0-04 逐条执行主链路 + 关键菜单动作）`
- 结果: `待回填（记录是否同义、是否存在偏差）`
- 异常分支: `待回填（导入失败/帮助加载失败/删除取消等分支）`
- 证据位置: `docs/plans/evidence/2026-02-26-my-menu-final-regression/R-01-book-source.md`、`docs/plans/evidence/2026-02-26-my-menu-final-regression/R-02-txt-toc-rule.md`、`docs/plans/evidence/2026-02-26-my-menu-final-regression/R-03-replace-rule.md`、`docs/plans/evidence/2026-02-26-my-menu-final-regression/R-04-dict-rule.md`
- 处理动作: `待回填（同义=维持；差异=登记原因/影响并回补计划）`

## P1（设置链路）

### P1-01 备份与恢复（含 WebDav）
- legado 对照项:
  - `/home/server/legado/app/src/main/res/xml/pref_config_backup.xml`
  - `/home/server/legado/app/src/main/res/menu/backup_restore.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/BackupConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/AppWebDav.kt`
- 当前实现文件:
  - `lib/features/settings/views/backup_settings_view.dart`
  - `lib/core/services/settings_service.dart`
  - `lib/core/services/backup_service.dart`
  - `lib/core/services/backup_restore_ignore_service.dart`
  - `lib/core/services/webdav_service.dart`
  - `lib/core/models/backup_restore_ignore_config.dart`
- 检查维度:
  - 入口: `menu_help/menu_log/web_dav_backup/web_dav_restore/restoreIgnore` 等入口均可达。
  - 状态: 设备名、备份路径、同步增强、忽略项配置可持久化并回显。
  - 异常: WebDav 失败可观测且可回退本地恢复，导入失败有提示。
  - 文案: 备份/恢复/忽略项说明与 legacy 语义一致。
  - 排版: 备份恢复分组结构和条目层级同义。
  - 交互触发: 本地导入、WebDav 上传下载、失败回退链路闭环。
- 结论: `已同义`
- 原因: `MY-10` 四个阶段已补齐菜单、配置项、忽略配置与 WebDav 恢复边界。
- 处理动作: 维持现状；`MY-19` 重点回归“远端恢复失败回退本地恢复”分支。

### P1-02 主题设置全链路
- legado 对照项:
  - `/home/server/legado/app/src/main/res/xml/pref_config_theme.xml`
  - `/home/server/legado/app/src/main/res/xml/pref_config_cover.xml`
  - `/home/server/legado/app/src/main/res/xml/pref_config_welcome.xml`
  - `/home/server/legado/app/src/main/res/menu/theme_config.xml`
  - `/home/server/legado/app/src/main/res/menu/theme_list.xml`
- 当前实现文件:
  - `lib/features/settings/views/settings_view.dart`
  - `lib/features/settings/views/theme_settings_view.dart`
  - `lib/features/settings/views/theme_config_list_view.dart`
  - `lib/features/settings/views/cover_config_view.dart`
  - `lib/features/settings/views/welcome_style_settings_view.dart`
  - `lib/features/settings/views/reading_interface_settings_hub_view.dart`
  - `lib/features/settings/services/theme_config_service.dart`
  - `lib/features/settings/models/theme_config_entry.dart`
- 检查维度:
  - 入口: 主题主页、主题模式、主题列表、封面设置、启动界面样式入口齐全。
  - 状态: 主题模式切换、主题列表应用/删除、封面/欢迎页配置持久化一致。
  - 异常: 导入失败、资源缺失、规则校验失败均有提示。
  - 文案: 一级入口与菜单动作文案对齐 legacy 语义。
  - 排版: 主题主页与子页分组层级同义。
  - 交互触发: 顶栏切换、条目应用、条目分享/删除确认、规则编辑触发一致。
- 结论: `已同义`
- 原因: `MY-11~MY-12` 已收口入口路由、主题列表动作、封面/欢迎页配置与结构化规则编辑。
- 处理动作: 维持现状；`MY-19` 回归主题模式切换与封面/欢迎页依赖联动。

### P1-03 其它设置全链路
- legado 对照项:
  - `/home/server/legado/app/src/main/res/xml/pref_config_other.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/CheckSourceConfig.kt`
- 当前实现文件:
  - `lib/features/settings/views/other_settings_view.dart`
  - `lib/features/settings/views/storage_settings_view.dart`
  - `lib/features/settings/views/check_source_settings_view.dart`
  - `lib/features/settings/views/direct_link_upload_config_view.dart`
  - `lib/core/models/app_settings.dart`
  - `lib/core/services/settings_service.dart`
  - `lib/features/settings/services/other_source_settings_service.dart`
  - `lib/features/settings/services/check_source_settings_service.dart`
  - `lib/features/settings/services/other_maintenance_service.dart`
- 检查维度:
  - 入口: 基本设置、源设置、缓存维护、调试开关入口齐全；Web 服务项保留禁用说明。
  - 状态: 新增数值项与开关项可持久化并正确回显。
  - 异常: 输入越界、目录选择失败、维护动作失败均可观测。
  - 文案: 标题、摘要、操作提示与 legacy 语义一致。
  - 排版: 分组层级与热区布局保持同义。
  - 交互触发: 编辑弹层、确认保存、维护动作二次确认链路完整。
- 结论: `已同义`
- 原因: `MY-13` 三阶段已完成基础设置、源设置、缓存维护项的收口并移除非同义占位入口。
- 处理动作: 维持现状；`MY-19` 重点回归校验设置联动与维护动作提示。

### MY-19 终验证据位（P1）
- 入口: `我的 -> 备份与恢复 / 主题设置 / 其它设置`（待回填）
- 步骤: `待回填（按 P1-01~P1-03 执行关键配置编辑、保存与重进回显）`
- 结果: `待回填（记录持久化、回显、联动结果）`
- 异常分支: `待回填（WebDav 失败回退、导入失败、输入越界等分支）`
- 证据位置: `docs/plans/evidence/2026-02-26-my-menu-final-regression/R-05-backup-restore.md`、`docs/plans/evidence/2026-02-26-my-menu-final-regression/R-06-theme-settings.md`、`docs/plans/evidence/2026-02-26-my-menu-final-regression/R-07-other-settings.md`
- 处理动作: `待回填（同义=维持；差异=登记原因/影响并回补计划）`

## P2（辅助链路）

### P2-01 书签
- legado 对照项:
  - `/home/server/legado/app/src/main/res/menu/bookmark.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/bookmark/AllBookmarkActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/bookmark/BookmarkDialog.kt`
- 当前实现文件:
  - `lib/features/reader/views/all_bookmark_view.dart`
  - `lib/features/reader/services/reader_bookmark_export_service.dart`
- 检查维度:
  - 入口: 顶栏 `导出/导出(MD)` 与条目点击详情入口可达。
  - 状态: 导出结果、详情展示与定位阅读状态流转正常。
  - 异常: 导出失败、定位失败均有提示与日志节点。
  - 文案: 导出与确认提示语义同义。
  - 排版: 列表与详情弹层信息层级清晰，空态布局一致。
  - 交互触发: `导出 JSON/MD -> 条目详情 -> 定位阅读` 链路完整。
- 结论: `已同义`
- 原因: `MY-14` 已收口菜单与条目点击闭环，并补齐日志可观测性。
- 处理动作: 维持现状；`MY-19` 回归导出后文件与定位阅读路径。

### P2-02 阅读记录
- legado 对照项:
  - `/home/server/legado/app/src/main/res/menu/book_read_record.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/about/ReadRecordActivity.kt`
- 当前实现文件:
  - `lib/features/bookshelf/views/reading_history_view.dart`
  - `lib/core/services/settings_service.dart`
- 检查维度:
  - 入口: 搜索、总阅读时长、清空、条目动作入口齐全。
  - 状态: 排序/开关勾选态、搜索过滤态、清空后的状态回落一致。
  - 异常: 全量清理与单条删除均有二次确认及取消分支。
  - 文案: 搜索、清空、删除确认文案语义同义。
  - 排版: 搜索区、统计区、列表区在加载/空态/成功态层级一致。
  - 交互触发: 排序切换、清空、单条删除、继续阅读触发链路完整。
- 结论: `已同义`
- 原因: `MY-15` 已补齐搜索、总时长、清空与单条确认逻辑。
- 处理动作: 维持现状；`MY-19` 回归排序/开关/清理边界。

### P2-03 关于与诊断
- legado 对照项:
  - `/home/server/legado/app/src/main/res/xml/about.xml`
  - `/home/server/legado/app/src/main/res/menu/about.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/about/AboutFragment.kt`
- 当前实现文件:
  - `lib/features/settings/views/about_settings_view.dart`
  - `lib/features/settings/views/exception_logs_view.dart`
  - `lib/features/settings/views/app_help_dialog.dart`
  - `assets/docs/update_log.md`
  - `assets/docs/privacy_policy.md`
  - `assets/docs/disclaimer.md`
  - `assets/docs/LICENSE.md`
  - `pubspec.yaml`
- 检查维度:
  - 入口: 顶栏 `分享/评分` 与 9 个 about 列表入口均可达。
  - 状态: 更新日志版本摘要、崩溃日志摘要、日志落盘结果状态可观测。
  - 异常: 市场跳转失败、文档加载失败、日志写入失败均有提示。
  - 文案: about 入口文案与 legacy 业务语义一致。
  - 排版: `关于/其它` 分组层级同义，弹层布局保持一致。
  - 交互触发: 文档展示、日志清理、保存日志、创建堆转储触发链路完整。
- 结论: `已同义`
- 原因: `MY-16` 已补齐菜单结构、文档资源与诊断动作闭环。
- 处理动作: 维持现状；`MY-19` 回归日志落盘与文档入口可达性。

### P2-04 文件管理
- legado 对照项:
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/file/FileManageActivity.kt`
  - `/home/server/legado/app/src/main/res/menu/file_chooser.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/file/FilePickerDialog.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/file/FilePickerViewModel.kt`
  - `/home/server/legado/app/src/main/res/menu/file_long_click.xml`
- 当前实现文件:
  - `lib/features/settings/views/file_manage_view.dart`
  - `lib/features/settings/views/settings_view.dart`
- 检查维度:
  - 入口: 一级 `fileManage` 入口可达；顶栏新增 `新建文件夹`，同义对齐 `file_chooser.xml/menu_create`。
  - 状态: 路径切换、列表刷新、删除后刷新、创建成功后刷新并可见新目录一致。
  - 异常: 空名称、名称非法、名称已存在、IO 异常、删除失败分支均具备可观测提示。
  - 文案: `新建文件夹/文件夹名/文件夹名不能为空/文件夹名非法/名称已存在` 与 legacy 业务语义一致。
  - 排版: 路径栏、列表区、空态布局同层级。
  - 交互触发: 条目点击、长按菜单删除、顶栏创建文件夹（输入 -> 校验 -> 创建 -> 刷新）链路同义。
- 结论: `已同义`
- 原因: 在 `MY-17` 基础上补齐 legacy `menu_create` 语义，新增顶栏创建入口与校验/刷新/失败提示闭环。
- 处理动作:
  - 代码已落地：`file_manage_view.dart` 新增顶栏“新建文件夹”动作、输入弹窗、名称校验与创建后刷新。
  - 命令核验：`rg -n "新建文件夹|_showCreateFolderDialog|_createFolder|文件夹名不能为空|名称已存在" lib/features/settings/views/file_manage_view.dart`。
  - 冒烟验证：`flutter test test/widget_test.dart --plain-name "App launches correctly"` 通过。
  - `MY-19` 继续补手工路径终验（目录层级切换 + 新建/删除边界）。

### P2-05 退出（exit）
- legado 对照项:
  - `/home/server/legado/app/src/main/res/xml/pref_main.xml` -> `exit`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/main/my/MyFragment.kt`
- 当前实现文件:
  - `lib/features/settings/views/settings_view.dart`
- 检查维度:
  - 入口: `我的` 一级菜单 `退出` 入口可达并位于 `其它` 分组。
  - 状态: 触发后弹出确认对话框，`取消` 返回当前页，`退出` 触发应用退出。
  - 异常: 连续点击入口、对话框关闭、取消返回分支均可观测且不崩溃。
  - 文案: `退出/确定退出应用吗？/取消/退出` 与 legacy 业务语义一致。
  - 排版: `CupertinoAlertDialog` 标题、正文、按钮层级与 legacy 退出确认语义同义。
  - 交互触发: `点击退出 -> 确认弹窗 -> 取消返回 或 确认退出` 链路闭环。
- 结论: `已同义`
- 原因: `settings_view.dart` 已实现 `_confirmExit` 并绑定一级菜单 `退出`，流程与 legacy `exit` 语义一致。
- 处理动作: 维持现状；在 `MY-19` 终验补齐“取消返回/确认退出”双分支证据。

### MY-19 终验证据位（P2）
- 入口: `我的 -> 书签 / 阅读记录 / 关于 / 文件管理 / 退出`（待回填）
- 步骤: `待回填（按 P2-01~P2-05 覆盖导出、清理、日志、文件操作、退出确认）`
- 结果: `待回填（记录主流程可达性与结果提示）`
- 异常分支: `待回填（导出失败、删除取消、文档加载失败、退出取消分支）`
- 证据位置: `docs/plans/evidence/2026-02-26-my-menu-final-regression/R-08-bookmark.md`、`docs/plans/evidence/2026-02-26-my-menu-final-regression/R-09-read-record.md`、`docs/plans/evidence/2026-02-26-my-menu-final-regression/R-10-file-manage.md`、`docs/plans/evidence/2026-02-26-my-menu-final-regression/R-11-about.md`、`docs/plans/evidence/2026-02-26-my-menu-final-regression/R-12-exit.md`
- 处理动作: `待回填（同义=维持；差异=登记原因/影响并回补计划）`

## EX-01（迁移例外）

### EX-01 webService（用户明确排除）
- legado 对照项:
  - `/home/server/legado/app/src/main/res/xml/pref_main.xml` -> `webService`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/main/my/MyFragment.kt`
- 当前实现文件:
  - `lib/features/settings/views/settings_view.dart`
  - `PLANS.md`（`迁移例外与阻塞` 章节）
- 检查维度:
  - 入口: 一级菜单保留 `Web 服务` 入口语义。
  - 状态: 功能实现状态保持 `blocked`，不进入扩展开发。
  - 异常: 点击后给出“本轮迁移范围外”提示，避免无反馈。
  - 文案: 占位文案明确排除范围，不误导为可用功能。
  - 排版: 入口位置与菜单层级保持同义，不插入额外扩展入口。
  - 交互触发: 点击只触发范围提示，不触发服务启动或配置流程。
- 结论: `blocked（占位验证）`
- 原因: 需求已明确“除 Web 服务外”，按规则 `EX-01` 必须保持冻结并仅做占位验证。
- 处理动作: 保持 `blocked`；仅验证入口占位提示与重复点击稳定性，待需求方明确“开始做扩展功能”后再单独立项回补。

### MY-19 终验证据位（EX-01）
- 入口: `我的 -> Web服务`（仅占位入口）
- 步骤: `仅点击入口验证“范围外占位提示”语义；重复点击与返回重进后再次点击，确认 blocked 状态稳定；不执行 webService 启停、配置、网络流程`
- 结果: `blocked（占位验证）`
- 异常分支: `重复点击、返回重进后仍仅提示占位；blocked 状态不变化；未进入 webService 实现链路`
- 证据位置: `docs/plans/evidence/2026-02-26-my-menu-final-regression/R-13-ex-01.md`（仅记录 `blocked` 占位提示与重复点击稳定性证据；禁止记录 webService 实现流程证据）
- 处理动作: `保持 blocked，仅维护占位提示语义与重复点击稳定性验证；待需求方明确解锁扩展后再单独立项实现 webService`

## 执行与回填约束

- 当前台账用于 `MY-18` 执行，更新结论时必须同步改写对应条目的“原因/处理动作”。
- 对于 `结论=差异` 的条目，未记录可执行处理动作前，不得标记 `MY-18` 完成。
- 本台账完成后，在 `MY-19` 统一回归中补齐手工路径证据，再执行提交前唯一一次 `flutter analyze`。
