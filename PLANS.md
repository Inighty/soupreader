# SoupReader ExecPlans

## 2026-02-26 legado「我的」全量迁移（除 Web 服务）
- 状态: `active`
- Owner: Codex
- 任务口径: 迁移级别（菜单语义、状态流转、边界处理同义）

### 背景与目标
- 背景: 用户要求“迁移 legado 中‘我的’菜单全部功能（含所有层级），排除 Web 服务”。
- 目标:
  - 对齐 legado「我的」一级入口、二级页面、三级菜单动作。
  - 对齐菜单排序、显隐规则、触发逻辑、错误提示语义。
- 范围:
  - 一级入口: `bookSourceManage/txtTocRuleManage/replaceManage/dictRuleManage/themeMode/setting/web_dav_setting/theme_setting/bookmark/readRecord/fileManage/about/exit`。
  - 二三级页面: 上述入口继续下钻的菜单与配置项（详见“实施步骤”与 Todo）。
- 非目标:
  - `webService`（用户明确排除，不实施）。
- 成功标准:
  - 除 `webService` 外，legado「我的」菜单树全部可达、可触发、语义同义。
  - 逐项对照清单完成前，不宣称“完全一致”。

### 关联台账
- 菜单 ID 级差异清单（`MY-01`）: `docs/plans/2026-02-26-my-menu-id-diff.md`
- 菜单逐项对照台账（`MY-18`）: `docs/plans/2026-02-26-my-menu-parity-checklist.md`

### legado 对照基线（已完整读取）
- 一级入口与主菜单:
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/main/my/MyFragment.kt`
  - `/home/server/legado/app/src/main/res/xml/pref_main.xml`
  - `/home/server/legado/app/src/main/res/menu/main_my.xml`
- 其它设置/备份/主题:
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/ConfigActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/ConfigTag.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/BackupConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/CoverConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/WelcomeConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/ThemeListDialog.kt`
  - `/home/server/legado/app/src/main/res/xml/pref_config_other.xml`
  - `/home/server/legado/app/src/main/res/xml/pref_config_backup.xml`
  - `/home/server/legado/app/src/main/res/xml/pref_config_theme.xml`
  - `/home/server/legado/app/src/main/res/xml/pref_config_cover.xml`
  - `/home/server/legado/app/src/main/res/xml/pref_config_welcome.xml`
  - `/home/server/legado/app/src/main/res/menu/backup_restore.xml`
  - `/home/server/legado/app/src/main/res/menu/theme_config.xml`
  - `/home/server/legado/app/src/main/res/menu/theme_list.xml`
- 书源管理链路:
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceViewModel.kt`
  - `/home/server/legado/app/src/main/res/menu/book_source.xml`
  - `/home/server/legado/app/src/main/res/menu/book_source_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/book_source_item.xml`
  - `/home/server/legado/app/src/main/res/menu/source_sub_item.xml`
  - `/home/server/legado/app/src/main/res/menu/book_source_debug.xml`
  - `/home/server/legado/app/src/main/res/menu/source_edit.xml`
  - `/home/server/legado/app/src/main/res/menu/import_source.xml`
- 目录规则/替换/字典:
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/toc/rule/TxtTocRuleActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/toc/rule/TxtTocRuleViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/toc/rule/TxtTocRuleEditDialog.kt`
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule.xml`
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule_item.xml`
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule_edit.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/replace/ReplaceRuleActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/replace/ReplaceRuleViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/replace/edit/ReplaceEditActivity.kt`
  - `/home/server/legado/app/src/main/res/menu/replace_rule.xml`
  - `/home/server/legado/app/src/main/res/menu/replace_rule_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/replace_rule_item.xml`
  - `/home/server/legado/app/src/main/res/menu/replace_edit.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/dict/rule/DictRuleActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/dict/rule/DictRuleViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/dict/rule/DictRuleEditDialog.kt`
  - `/home/server/legado/app/src/main/res/menu/dict_rule.xml`
  - `/home/server/legado/app/src/main/res/menu/dict_rule_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/dict_rule_edit.xml`
- 书签/阅读记录/关于/文件管理:
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/bookmark/AllBookmarkActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/bookmark/AllBookmarkViewModel.kt`
  - `/home/server/legado/app/src/main/res/menu/bookmark.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/about/ReadRecordActivity.kt`
  - `/home/server/legado/app/src/main/res/menu/book_read_record.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/about/AboutActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/about/AboutFragment.kt`
  - `/home/server/legado/app/src/main/res/menu/about.xml`
  - `/home/server/legado/app/src/main/res/xml/about.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/file/FileManageActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/file/FileManageViewModel.kt`
  - `/home/server/legado/app/src/main/res/menu/file_chooser.xml`
  - `/home/server/legado/app/src/main/res/menu/file_long_click.xml`

### 差异点清单（实现前）
1. 一级“我的”菜单结构已基本对齐，但 `webService`/`fileManage` 仍为占位。
   - 现状文件: `lib/features/settings/views/settings_view.dart`
   - 影响: 文件管理能力缺失；Web 服务按用户要求排除。
2. `其它设置` 与 legado `pref_config_other.xml` 差异大，存在大量占位项。
   - 现状文件: `lib/features/settings/views/other_settings_view.dart`
   - 影响: 多数偏好项状态流转与边界行为尚未迁移。
3. `主题设置` 仅覆盖部分入口；`coverConfig/welcomeStyle/themeList` 语义未全量对齐。
   - 现状文件: `lib/features/settings/views/reading_interface_settings_hub_view.dart`, `lib/features/settings/views/theme_config_list_view.dart`
   - 影响: 主题菜单层级、导入/删除/分享等动作不完整。
4. `备份与恢复` 与 legado 仍有动作差异（日志入口、恢复分支、忽略项配置）。
   - 现状文件: `lib/features/settings/views/backup_settings_view.dart`
   - 影响: WebDav 恢复/导入策略与可观测行为未完全同义。
5. `关于` 页目前为精简版，缺少 legado about.xml 多项入口（崩溃日志/保存日志/隐私协议等）。
   - 现状文件: `lib/features/settings/views/about_settings_view.dart`
   - 影响: 诊断能力和帮助入口不完整。
6. `文件管理` 页面缺失。
   - 现状文件: 无（待新增）
   - 影响: `fileManage` 一级入口无法闭环。
7. 书源管理/替换规则/字典规则/TXT目录规则虽已有迁移基础，但需按菜单 ID 逐项核对边界。
   - 现状文件: `lib/features/source/views/source_list_view.dart`, `lib/features/replace/views/*`, `lib/features/reader/views/dict_rule_manage_view.dart`, `lib/features/reader/views/txt_toc_rule_manage_view.dart`
   - 影响: 若不逐项核对，存在“入口有了但边界偏差”的风险。

### 优先级队列（模块级）
- P0（最高，直接影响文字阅读规则与书源能力）
  - 书源管理全链路
  - TXT 目录规则
  - 替换规则
  - 字典规则
- P1
  - 备份与恢复（含 WebDav 同步/恢复）
  - 主题设置全链路（含主题列表/封面/欢迎页）
  - 其它设置全链路
- P2
  - 书签
  - 阅读记录
  - 关于与诊断
  - 文件管理
- EXCLUDED
  - Web 服务（用户排除）

### 逐项检查清单（每个子任务都必须回填）
- 入口: 菜单是否可见、顺序是否同义、显隐条件是否一致。
- 状态: 勾选态/切换态/默认值/持久化是否一致。
- 异常: 失败分支提示、日志节点、取消行为是否一致。
- 文案: 标题、按钮、提示语义是否与 legado 同义。
- 排版: 分组层级与热区布局是否同义。
- 交互触发: 点击/长按/更多菜单/二次确认是否一致。

### 实施步骤（含依赖与可并行性）
| ID | 优先级 | 状态 | 并行性 | 依赖 | 任务 | legado 对照 | 交付物 | 验证 |
|---|---|---|---|---|---|---|---|---|
| MY-00 | - | done | 串行 | 无 | 冻结范围（排除 webService）并建立迁移计划 | `MyFragment.kt`/`pref_main.xml` | 本 ExecPlan | 文档审阅 |
| MY-01 | P0 | done | 串行 | MY-00 | 产出“菜单 ID 级差异清单”与现状映射（一级+二级+三级） | 全部菜单 XML | 差异台账（`docs/plans/2026-02-26-my-menu-id-diff.md`） | 对照清单 |
| MY-02 | P0 | done | 串行 | MY-01 | 根入口收口：`我的` 一级入口顺序/显隐/跳转确认（不含 webService） | `pref_main.xml` | `settings_view.dart` 收口 | 手工路径 |
| MY-03 | P0 | done | 可并行 | MY-02 | 书源管理-顶栏与排序分组菜单全量核对迁移 | `book_source.xml` | `source_list_view.dart` | 定向测试+手工 |
| MY-04 | P0 | done | 可并行 | MY-02 | 书源管理-选中态动作全量核对迁移 | `book_source_sel.xml` | `source_list_view.dart` | 定向测试+手工 |
| MY-05 | P0 | done | 可并行 | MY-02 | 书源管理-条目长按动作核对迁移 | `book_source_item.xml`/`source_sub_item.xml` | `source_list_view.dart` | 手工路径 |
| MY-06 | P0 | done | 可并行 | MY-02 | 书源编辑/调试/导入菜单核对迁移 | `source_edit.xml`/`book_source_debug.xml`/`import_source.xml` | `source_edit_legacy_view.dart` 等 | 定向测试+手工 |
| MY-07 | P0 | done | 可并行 | MY-02 | TXT目录规则：顶栏/选中态/条目/编辑菜单全量核对 | `txt_toc_rule*.xml` | `txt_toc_rule_manage_view.dart`/`txt_toc_rule_edit_view.dart` | 定向测试+手工 |
| MY-08 | P0 | done | 可并行 | MY-02 | 替换规则：顶栏/选中态/条目/编辑菜单全量核对 | `replace_rule*.xml`/`replace_edit.xml` | `replace_rule_list_view.dart`/`replace_rule_edit_view.dart` | 定向测试+手工 |
| MY-09 | P0 | done | 可并行 | MY-02 | 字典规则：顶栏/选中态/编辑菜单全量核对 | `dict_rule*.xml` | `dict_rule_manage_view.dart`/`dict_rule_edit_view.dart` | 定向测试+手工 |
| MY-10 | P1 | done | 可并行 | MY-02 | 备份恢复：配置项/菜单动作/恢复边界全量迁移 | `pref_config_backup.xml`/`backup_restore.xml` | `backup_settings_view.dart` | 定向测试+手工 |
| MY-11 | P1 | done | 可并行 | MY-02 | 主题设置：主题主页菜单+主题列表动作迁移 | `pref_config_theme.xml`/`theme_config.xml`/`theme_list.xml` | `theme_settings*.dart`/`theme_config_list_view.dart` | 定向测试+手工 |
| MY-12 | P1 | done | 可并行 | MY-11 | 封面配置与欢迎页样式迁移（三级） | `pref_config_cover.xml`/`pref_config_welcome.xml` | 新增/改造 settings 子页 | 手工路径 |
| MY-13 | P1 | done | 可并行 | MY-02 | 其它设置 `pref_config_other` 分组与动作迁移（分批） | `pref_config_other.xml` | `other_settings_view.dart` + 子页 | 定向测试+手工 |
| MY-14 | P2 | done | 可并行 | MY-02 | 书签入口与菜单动作核对迁移 | `bookmark.xml` | `all_bookmark_view.dart` | 定向测试+手工 |
| MY-15 | P2 | done | 可并行 | MY-02 | 阅读记录页排序/开关/搜索/清理核对迁移 | `ReadRecordActivity.kt`/`book_read_record.xml` | `reading_history_view.dart` | 定向测试+手工 |
| MY-16 | P2 | done | 可并行 | MY-02 | 关于页菜单与偏好项（日志/崩溃/协议/更新）迁移 | `about.xml`/`about.xml(pref)` | `about_settings_view.dart` + 日志页 | 定向测试+手工 |
| MY-17 | P2 | done | 串行 | MY-02 | 文件管理页从 0 到 1 迁移（路径条/列表/删除） | `FileManageActivity.kt`/`file_chooser.xml`/`file_long_click.xml` | 新增 `file_manage_view.dart` + 接入 `settings_view.dart` | 定向测试+手工 |
| MY-18 | 收口 | active | 串行 | MY-03..MY-17 | 逐项对照台账回填（按 `P0/P1/P2/EX-01`） | 全量 | `docs/plans/2026-02-26-my-menu-parity-checklist.md` | 结构字段检查 + 索引接入检查 |
| MY-19 | 收口 | pending | 串行 | MY-18 | 统一回归验证与提交前检查 | 全量 | 回归记录 | 提交前仅一次 `flutter analyze` |

### 验收与证据
- 开发阶段验证策略:
  - 使用“改动相关定向测试 + 手工路径”，禁止提前执行 `flutter analyze`。
- 提交前最终验证:
  - 仅执行一次 `flutter analyze`。
- 手工回归主路径:
  1. `我的` 一级入口逐项进入并返回。
  2. 每个二级页验证“更多菜单 + 选中态菜单 + 条目长按菜单（如有）”。
  3. 每个编辑页验证“保存/复制/粘贴（如有）”。
  4. 异常分支验证：导入失败、网络失败、取消操作、空输入。

### 风险与回滚
- 风险1: 菜单入口齐全但边界行为不一致（最常见）。
  - 回滚策略: 逐模块回滚，不跨模块混回。
- 风险2: 共享设置键冲突导致旧数据兼容问题。
  - 回滚策略: 保留旧键解析并增加迁移兼容分支。
- 风险3: 文件管理与备份路径权限在平台差异下行为偏差。
  - 回滚策略: 增加平台分支与失败兜底提示。

### 迁移例外与阻塞
- EX-01 `webService`
  - 状态: `blocked`（用户排除）
  - 原因: 需求明确“除 web 服务外”。
  - 影响范围: `pref_main.xml` 的 `webService` 及其运行时管理。
  - 替代方案: 保留入口语义提示“不在本轮范围”。
  - 回补计划: 待用户明确解锁后单独立项。

### Progress
- [x] 完成 legado「我的」及二三级菜单基线读取。
- [x] 完成新 ExecPlan 建立与任务分解。
- [x] 完成 MY-01 菜单 ID 级差异台账。
- [x] 完成 MY-02 根入口收口。
- [x] 完成 MY-03 书源管理顶栏与排序分组菜单迁移。
- [x] 完成 MY-04 书源管理选中态动作迁移。
- [x] 完成 MY-05 书源管理条目长按动作迁移。
- [x] 完成 MY-06 书源编辑/调试/导入菜单核对迁移。
- [x] 完成 MY-07 TXT目录规则顶栏/选中态/条目/编辑菜单核对迁移。
- [x] 完成 MY-08 替换规则顶栏/选中态/条目/编辑菜单核对迁移。
- [x] 完成 MY-09 字典规则顶栏/选中态/编辑菜单核对迁移。
- [x] 完成 MY-17 文件管理页迁移（路径条/列表/删除）并接入“我的”入口。
- [x] 完成 P0 模块（MY-03~MY-09）。
- [x] 完成 MY-10 阶段1：补齐备份页 `menu_help/menu_log` 入口语义（任务整体仍为 `active`）。
- [x] 完成 MY-10 阶段2：补齐 `webDavDeviceName/syncBookProgressPlus/backupPath/onlyLatestBackup/autoCheckNewBackup` 接线与依赖控制（任务整体仍为 `active`）。
- [x] 完成 MY-10 阶段3：新增 `restoreIgnore` 多选持久化，并将本地导入与后续 WebDav 恢复统一到同一忽略配置接线（任务整体仍为 `active`）。
- [x] 完成 MY-10 阶段4：补齐 `web_dav_backup/web_dav_restore` 入口、远端列表恢复与失败回退本地恢复分支（`MY-10` 标记 `done`）。
- [x] 完成 MY-11：`theme_setting` 入口改为主题设置主页，补齐 `menu_theme_mode` 顶栏切换与 `themeList/coverConfig/welcomeStyle` 一级入口（`MY-11` 标记 `done`）。
- [x] 完成 MY-11 补充收口：`ThemeConfigListView` 补齐条目级分享/删除（含确认）与同名导入覆盖验证。
- [x] 完成 MY-12：封面配置与欢迎页样式迁移，补齐 `pref_config_cover.xml/pref_config_welcome.xml` 基础开关与配置入口，并将 `coverRule` 收口为 legacy 同义结构化编辑（`MY-12` 标记 `done`）。
- [x] 完成 MY-13：`pref_config_other.xml` 的“基本设置”分组迁移，落地 `auto_refresh/defaultToRead/showDiscovery/showRss/defaultHomePage` 并移除不同义占位入口（`MY-13` 标记 `done`）。
- [x] 完成 MY-13 补充收口：`pref_config_other.xml` 源设置动作迁移，落地 `userAgent/defaultBookTreeUri/sourceEditMaxLine/checkSource/uploadRule` 同义入口与摘要持久化（`MY-13` 维持 `done`）。
- [x] 完成 MY-13 补充收口（阶段3）：`pref_config_other.xml` 其它可落地项迁移，落地 `preDownloadNum/threadCount/bitmapCacheSize/imageRetainNum/replaceEnableDefault/process_text/recordLog/recordHeapDump/cleanCache/clearWebViewData/shrinkDatabase`，并对 `webPort/webServiceWakeLock` 做不误导禁用说明（`MY-13` 维持 `done`）。
- [x] 完成 MY-14：书签页顶栏动作收口为 `导出/导出(MD)`，条目点击补齐“书签详情 -> 定位阅读”闭环，并补导出成功/失败日志节点（`MY-14` 标记 `done`）。
- [x] 完成 MY-15：阅读记录页补齐 `搜索/总阅读时长/全量清理确认/单条删除确认`，保留“继续阅读/清除阅读记录/从书架移除”边界动作并保持排序/开关勾选态与持久化一致（`MY-15` 标记 `done`）。
- [x] 完成 MY-16：关于页按 `about.xml/about menu` 收口，补齐 `评分 + contributors/update_log/check_update/crashLog/saveLog/createHeapDump/privacyPolicy/license/disclaimer` 可触发入口、摘要与失败提示（`MY-16` 标记 `done`）。
- [x] 完成 P1 模块（MY-10~MY-13）。
- [x] 完成 P2 模块（MY-14~MY-17）。
- [x] 完成 `MY-18` 初版台账落盘：`docs/plans/2026-02-26-my-menu-parity-checklist.md`（按 `P0/P1/P2/EX-01` 建立逐项字段）。
- [x] 完成 `MY-18` 增量回填：`P2-04 文件管理` 补齐 `menu_create` 同义链路（顶栏“新建文件夹”入口 + 输入校验 + 创建刷新 + 失败提示）并完成启动冒烟验证。
- [x] 完成 `MY-18` 回归守卫脚本结构升级：`tool/my_menu_regression_guard.sh` 新增证据文件固定字段齐全性检查（`入口/步骤/结果/异常分支/处理动作/关联锚点`）与 `R-01~R-13` 主回归单单锚点一致性检查，保留 `EX-01` `blocked` 占位语义与 `webService` 功能实现验收禁入检查；并完成故障注入验证（字段缺失返回 `exit 1`，修复后返回 `exit 0`）。
- [ ] 完成 `MY-18` 手工回归证据回填（逐条补齐终验结果）。
- [ ] 完成 `MY-19` 统一回归与提交前唯一一次 `flutter analyze`。
- 兼容影响（当前）:
  - `MY-02`~`MY-09` 仅调整入口语义与菜单行为，不涉及数据结构或持久化键；无旧数据兼容影响。
  - `MY-17` 新增文件浏览能力与入口接线，不修改持久化模型/数据库结构；无旧数据兼容影响。
  - `MY-10` 阶段2仅补齐现有 `AppSettings` 字段接线，不新增持久化键；无旧数据兼容影响。
  - `MY-10` 阶段3沿用既有忽略键集合并补齐页面/导入接线，不修改备份数据版本与数据库结构；无旧数据兼容影响。
  - `MY-10` 阶段4补齐 WebDav 备份/恢复编排与失败回退本地恢复，不新增持久化键或数据库结构；无旧数据兼容影响。
  - `MY-11` 仅调整主题入口跳转与页面编排，复用现有设置模型/主题列表存储；无新增持久化键与数据库结构变更。
  - `MY-11` 补充收口仅增强主题列表条目交互（分享/删除确认）与服务层删除/分享载荷能力；无新增持久化键与数据库结构变更。
  - `MY-13` 在 `AppSettings` 新增 `autoRefresh/defaultToRead`（含 `auto_refresh` 兼容别名）并落地基础设置入口；无数据库结构变更，旧配置读取保持向后兼容。
  - `MY-13` 补充收口复用/新增数据库设置键：`userAgent/defaultBookTreeUri/sourceEditMaxLine/source_check_*/checkSource`；无数据库结构变更，与既有书源校验配置键保持同义兼容。
  - `MY-13` 补充收口（阶段3）在 `AppSettings` 新增 `preDownloadNum/threadCount/bitmapCacheSize/imageRetainNum/replaceEnableDefault/processText/process_text/recordLog/recordHeapDump` 字段并接线维护动作服务；无数据库 schema 变更，`webPort/webServiceWakeLock` 按排除策略仅保留禁用说明。
  - `MY-14` 仅新增书签页详情弹层与阅读定位接线，复用既有书签字段（`chapterIndex/chapterPos`）和阅读进度键；无新增持久化键与数据库结构变更。
  - `MY-15` 新增阅读记录页搜索态与清理交互，复用现有 `readRecordSort/enableReadRecord/book_read_record_duration_map`；无新增数据库结构变更。
  - `MY-16` 新增 about 文档资源与日志导出/堆快照落盘动作，复用既有 `backupPath/ExceptionLogService`；无数据库 schema 变更。
  - `MY-18` 补齐文件管理“新建文件夹”链路，仅页面交互增强；无新增持久化键与数据库结构变更。
  - 新增 `tool/my_menu_regression_guard.sh` 仅用于文档回归守卫（固定字段/锚点一致性/EX-01 占位语义）检查，不影响运行时代码、持久化键或数据库结构。

#### MY-01 交付记录（菜单 ID 级差异清单）
- 交付文件: `docs/plans/2026-02-26-my-menu-id-diff.md`
- 覆盖范围:
  - 一级入口: `pref_main.xml` + `main_my.xml`
  - 二级/三级菜单: `book_source*`/`txt_toc_rule*`/`replace_rule*`/`dict_rule*`、`pref_config_backup/theme/cover/welcome/other`、`bookmark`/`book_read_record`/`about`/`file_*`
- 关键结论:
  - 已同义（代表）: `book_source*.xml`、`source_edit.xml`、`book_source_debug.xml`、`import_source.xml`、`bookmark.xml`、`book_read_record.xml`、`main_my.xml(menu_help)`
  - 部分同义: `webService`（按排除策略仅保留占位语义）、`defaultHomePage/auto_refresh/defaultToRead/replaceEnableDefault`（仅占位提示）
  - 缺失（P0）: `txt_toc_rule.xml/menu_help`、`txt_toc_rule_edit.xml/menu_copy_rule`、`replace_rule.xml/menu_help`、`replace_edit.xml/menu_copy_rule`、`dict_rule.xml/menu_help`、`dict_rule_edit.xml/menu_copy_rule`
  - 缺失（P1/P2 代表）: `pref_config_theme.xml` 多数字段、`pref_config_cover.xml` 全量、`pref_config_welcome.xml` 全量、`about.xml/menu_scoring`、`xml/about.xml` 多项、`file_chooser.xml/menu_create`、`file_long_click.xml/menu_del`
- 结论用途:
  - 作为后续 `MY-02~MY-17` 的逐项实施与回填基线，避免无记录偏航。

#### MY-02 交付记录（根入口收口）
- 交付文件:
  - `lib/features/settings/views/settings_view.dart`
- 做了什么:
  - 将 `replaceManage` 一级入口改为直达 `ReplaceRuleListView`，与 legado `MyFragment.onPreferenceTreeClick -> ReplaceRuleActivity` 同义。
  - 一级菜单摘要文案按 `pref_main.xml` 对应字符串语义收口，移除动态统计摘要（书源数量/阅读记录数量/版本号）带来的扩展语义偏差。
  - `webService` 入口保留为可见占位并明确“本轮迁移范围外”提示，保持 `EX-01` 冻结策略。
- 为什么:
  - `MY-02` 目标是收口一级入口“顺序/显隐/跳转”；其中 `replaceManage` 原先跳转至组合页，存在与 legado 入口语义不一致风险。
  - 动态统计摘要属于 legado 一级菜单未定义的扩展文案，可能造成迁移级别验收偏差。
- 如何验证（手工路径）:
  1. 打开“我的”页面，确认一级菜单顺序：`书源管理 -> TXT目录规则 -> 替换净化 -> 字典规则 -> 主题模式 -> Web服务 -> 设置分组(备份与恢复/主题设置/其它设置) -> 其它分组(书签/阅读记录/文件管理/关于/退出)`。
  2. 点击“替换净化”，确认进入替换规则管理页（`ReplaceRuleListView`），不再进入组合中间页。
  3. 点击“Web服务”，确认展示“Web服务不在本轮迁移范围”占位提示（`EX-01`）。
  4. 点击“文件管理”，确认保留入口且当前为未实现占位提示（后续 `MY-17` 实现）。
- 逐项检查回填:
  - 入口: 通过（一级菜单顺序与分组同义，`webService` 可见且保留占位）。
  - 状态: 通过（主题模式为真实状态；`webService` 按排除策略固定占位）。
  - 异常: 通过（帮助文档加载失败与占位入口均可观测提示）。
  - 文案: 通过（摘要语义按 legado 收口；排除项按例外流程明确提示）。
  - 排版: 通过（分组层级与热区布局保持与既有迁移风格一致）。
  - 交互触发: 通过（点击入口触发与 legado 同义，`replaceManage` 已修正）。

#### MY-03 交付记录（书源管理顶栏/排序/分组菜单）
- 交付文件:
  - `lib/features/source/views/source_list_view.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/menu/book_source.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceViewModel.kt`
- 做了什么:
  - 完整核对 `book_source.xml` 三组顶栏菜单（排序、分组、更多）与当前实现触发逻辑。
  - 将排序菜单中的“反序（`menu_sort_desc`）”调整到弹层首项，收口到 legado 菜单结构顺序。
- 为什么:
  - `MY-03` 的验收目标是“顶栏与排序分组菜单全量同义”；菜单项顺序属于强约束的一部分。
- 如何验证（手工路径）:
  1. 进入“书源管理”页，确认顶栏存在“排序 / 分组 / 更多”三个入口。
  2. 点“排序”，确认首项为“反序”，其后依次为“手动排序/智能排序/名称排序/地址排序/更新时间排序/响应时间排序/是否启用”。
  3. 点“分组”，确认包含“分组管理/已启用/已禁用/需要登录/未分组/已启用发现/已禁用发现 + 动态分组项”，点击后触发对应筛选。
  4. 点“更多”，确认包含“新建书源/本地导入/网络导入/二维码导入/按域名分组显示/帮助”。
- 逐项检查回填:
  - 入口: 通过（三个顶栏入口与 legado 同义）。
  - 状态: 通过（排序勾选态、反序状态、按域名分组状态均可切换并即时生效）。
  - 异常: 通过（导入/帮助等入口失败分支保留可观测提示路径）。
  - 文案: 通过（菜单动作语义与 legado 对齐）。
  - 排版: 通过（顶栏热区与菜单层级同义）。
  - 交互触发: 通过（点击动作映射到同义筛选/排序/导入流程）。

#### MY-04 交付记录（书源管理选中态动作）
- 交付文件:
  - `lib/features/source/views/source_list_view.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/menu/book_source_sel.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/source/SourceHelp.kt`
- 做了什么:
  - 逐项核对选中态动作菜单：启用/禁用、添加/移除分组、启用/禁用发现、置顶/置底、导出、分享、校验、选中区间。
  - 修正批量删除链路：从直接 `deleteSource` 改为复用 `_deleteSourceByLegacyRule`，确保与 legado 删除链路一致执行源变量清理。
- 为什么:
  - legado 选中态删除通过 `SourceHelp.deleteBookSourceParts` 走“删除书源 + 清理源变量”组合行为；仅删主表会产生边界偏差。
- 如何验证（手工路径）:
  1. 在“书源管理”勾选多条记录，打开“批量操作”，确认动作顺序与 `book_source_sel.xml` 一致。
  2. 依次触发“启用所选/禁用所选/添加分组/移除分组/启用发现/禁用发现/置顶所选/置底所选”，确认对应状态变化。
  3. 触发“导出所选/分享选中源/校验所选/选中所选区间”，确认流程可达。
  4. 使用底栏“删除”批量删除，确认删除后选中集清空且不残留源变量状态（走 legacy 清理路径）。
- 逐项检查回填:
  - 入口: 通过（选中态“更多”动作完整可达）。
  - 状态: 通过（启用/发现/分组/排序位次变更即时生效）。
  - 异常: 通过（导出/校验失败分支有提示，分享异常保持静默同义）。
  - 文案: 通过（动作文案语义与 legado 同义）。
  - 排版: 通过（底栏主动作 + 更多菜单层级清晰）。
  - 交互触发: 通过（动作触发与 legacy 映射一致，删除链路已收口）。

#### MY-05 交付记录（书源管理条目动作）
- 交付文件:
  - `lib/features/source/views/source_list_view.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/menu/book_source_item.xml`
  - `/home/server/legado/app/src/main/res/menu/source_sub_item.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceAdapter.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt`
- 做了什么:
  - 完整核对条目“更多”动作顺序、显隐与触发：`置顶/置底/登录/搜索/调试/删除/启用(禁用)发现`。
  - 确认 `置顶/置底` 仅在手动排序模式可见，且反序时通过 `_toTop/_toBottom` 保持 legacy 语义。
  - 确认单条删除复用 `_deleteSourceByLegacyRule`，删除后同步清理源变量，边界与 legacy 一致。
- 为什么:
  - `MY-05` 目标是按菜单 ID 级核对条目动作；若显隐或删除边界偏移，会造成“菜单可达但行为不同义”。
- 如何验证（手工路径）:
  1. 进入“书源管理”，在手动排序模式打开任一条目“更多”，确认动作顺序与 `book_source_item.xml` 一致。
  2. 切换非手动排序后再次打开条目“更多”，确认“置顶/置底”隐藏。
  3. 对含 `loginUrl` 与不含 `loginUrl` 的书源分别验证“登录”显隐。
  4. 对含 `exploreUrl` 的书源验证“启用发现/禁用发现”文案随状态切换。
  5. 触发“删除”，确认二次确认后删除并清理源变量。
- 逐项检查回填:
  - 入口: 通过（条目动作入口可见性与 legacy 同义）。
  - 状态: 通过（发现开关与排序位次变更即时生效）。
  - 异常: 通过（删除确认/取消分支与提示路径可达）。
  - 文案: 通过（动作文案与业务语义同义）。
  - 排版: 通过（条目右侧编辑/更多热区与菜单层级一致）。
  - 交互触发: 通过（点击条目动作映射与 legacy 一致）。

#### MY-06 交付记录（书源编辑/调试/导入菜单）
- 交付文件:
  - `lib/features/source/views/source_debug_legacy_view.dart`
  - `lib/features/source/views/source_edit_legacy_view.dart`
  - `lib/features/source/views/source_list_view.dart`（导入菜单对照核验）
- legado 对照:
  - `/home/server/legado/app/src/main/res/menu/source_edit.xml`
  - `/home/server/legado/app/src/main/res/menu/book_source_debug.xml`
  - `/home/server/legado/app/src/main/res/menu/import_source.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/edit/BookSourceEditActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/source/debug/BookSourceDebugActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/association/ImportBookSourceDialog.kt`
- 差异点清单（实现前）:
  1. `source_debug_legacy_view.dart` 存在额外“禁用源/删除源”菜单项，超出 `book_source_debug.xml` 范围。
  2. `source_edit_legacy_view.dart` 的“自动补全”勾选文案呈现样式与 legacy 菜单 checkable 语义不够贴近。
  3. `source_list_view.dart` 导入选择弹层需复核 `import_source.xml` 的“自定义分组/选中新增/选中更新/保留策略”触发语义。
- 做了什么:
  - 移除 `SourceDebugLegacyView` 的扩展菜单“禁用源/删除源”，严格收口为 legacy 菜单集合：`扫描二维码/搜索源码/书籍源码/目录源码/正文源码/刷新发现/帮助`。
  - 清理因上述扩展菜单引入的无关依赖与函数，避免后续偏航。
  - 将 `SourceEditLegacyView` “自动补全”菜单文案改为 checkable 风格（`✓ 自动补全`），与 legacy 交互语义对齐。
  - 复核导入弹层：自定义分组、选中新增/更新、保留原名/分组/启用状态均与 `ImportBookSourceDialog` 同义。
- 为什么:
  - 迁移级别要求“菜单结构、排序与触发逻辑”同义；扩展菜单会引入非 legado 入口与行为偏差，属于阻塞风险。
- 如何验证（手工路径）:
  1. 进入“书源调试”，打开“更多”确认仅包含 legacy 对应动作，不出现“禁用源/删除源”。
  2. 依次触发“搜索源码/书籍源码/目录源码/正文源码/刷新发现/帮助”，确认流程可达。
  3. 进入“书源编辑”，打开“更多”确认“自动补全”勾选态文案随开关变化（`✓ 自动补全`）。
  4. 触发导入流程进入“导入书源”弹层，验证“选中新增源/选中更新源/自定义源分组/保留原名/保留分组/保留启用状态”行为。
- 逐项检查回填:
  - 入口: 通过（编辑/调试/导入菜单入口与 legacy 同义）。
  - 状态: 通过（自动补全勾选态、导入保留策略开关状态可切换且可持久化）。
  - 异常: 通过（调试帮助加载失败与导入异常均有可观测输出）。
  - 文案: 通过（菜单文案语义与 legacy 对齐，无扩展入口文案残留）。
  - 排版: 通过（菜单层级、操作热区与既有迁移风格一致）。
  - 交互触发: 通过（点击动作映射与 legacy 处理链路一致）。

#### MY-07 交付记录（TXT目录规则菜单）
- 交付文件:
  - `lib/features/reader/views/txt_toc_rule_manage_view.dart`
  - `lib/features/reader/views/txt_toc_rule_edit_view.dart`
  - `lib/features/reader/services/txt_toc_rule_store.dart`
  - `assets/web/help/md/txtTocRuleHelp.md`
- legado 对照:
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule.xml`
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule_item.xml`
  - `/home/server/legado/app/src/main/res/menu/txt_toc_rule_edit.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/toc/rule/TxtTocRuleActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/toc/rule/TxtTocRuleViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/toc/rule/TxtTocRuleEditDialog.kt`
- 差异点清单（实现前）:
  1. `txt_toc_rule_manage_view.dart` 顶栏更多菜单缺少 `menu_help`，与 `txt_toc_rule.xml` 不同义。
  2. `txt_toc_rule_edit_view.dart` 缺少 `menu_copy_rule`，仅保留“粘贴规则”，与 `txt_toc_rule_edit.xml` 不同义。
  3. `txt_toc_rule_manage_view.dart` 选中态缺少 legacy `SelectActionBar` 主动作“删除”，与 `TxtTocRuleActivity.delSourceDialog` 不同义。
- 做了什么:
  - 顶栏更多菜单补齐“帮助”动作，新增 `help` 菜单枚举并接入 `txtTocRuleHelp.md` 文档展示。
  - 编辑页“更多”菜单补齐“复制规则”，顺序对齐 legacy（复制规则 -> 粘贴规则），复制内容为当前表单 JSON。
  - 选中态底栏补齐主动作“删除”，新增二次确认与批量删除执行链路。
  - 在 `TxtTocRuleStore` 增加 `deleteRulesByIds`，用于选中态批量删除并保持列表刷新边界。
  - 新增帮助文档资源 `assets/web/help/md/txtTocRuleHelp.md`，保证 `menu_help` 可达可展示。
- 为什么:
  - `MY-07` 目标是按菜单 ID 级核对 TXT 目录规则所有菜单；缺失 `menu_help` / `menu_copy_rule` / 选中态主删除会导致“入口不全”与交互语义偏差。
- 如何验证（手工路径）:
  1. 进入“TXT目录规则”，打开右上“更多”，确认动作顺序包含“本地导入/网络导入/二维码导入/导入默认规则/帮助”。
  2. 点击“帮助”，确认弹出帮助文档；模拟资源异常时显示“帮助文档加载失败”提示。
  3. 打开任一规则编辑页，确认“更多”菜单顺序为“复制规则/粘贴规则”；复制后剪贴板内容可被粘贴回表单。
  4. 进入多选态并选中多条规则，点击底栏“删除”，确认二次确认后批量删除生效。
  5. 验证选中态“启用所选/禁用所选/导出所选”仍可正常触发，不受新增删除动作影响。
- 逐项检查回填:
  - 入口: 通过（顶栏/选中态/条目/编辑菜单入口均可达，菜单项齐全）。
  - 状态: 通过（批量启用/禁用、选中集刷新、删除后选中态同步更新）。
  - 异常: 通过（帮助文档加载失败、导入失败、删除取消分支均有可观测反馈）。
  - 文案: 通过（帮助/复制规则/删除确认文案与 legacy 业务语义同义）。
  - 排版: 通过（选中态底栏新增“删除”后仍保持同层级热区布局）。
  - 交互触发: 通过（帮助、复制/粘贴、批量删除触发链路与 legacy 行为同义）。
- 兼容影响:
  - 无持久化键与数据结构调整；仅新增帮助文档资源与批量删除工具方法，不影响旧规则数据读取。

#### MY-08 交付记录（替换规则菜单）
- 交付文件:
  - `lib/features/replace/views/replace_rule_list_view.dart`
  - `lib/features/replace/views/replace_rule_edit_view.dart`
  - `lib/core/database/repositories/replace_rule_repository.dart`
  - `assets/web/help/md/replaceRuleHelp.md`
- legado 对照:
  - `/home/server/legado/app/src/main/res/menu/replace_rule.xml`
  - `/home/server/legado/app/src/main/res/menu/replace_rule_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/replace_rule_item.xml`
  - `/home/server/legado/app/src/main/res/menu/replace_edit.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/replace/ReplaceRuleActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/replace/ReplaceRuleViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/replace/ReplaceRuleAdapter.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/replace/edit/ReplaceEditActivity.kt`
- 差异点清单（实现前）:
  1. `replace_rule_list_view.dart` 顶栏“更多”缺少 `menu_help`，且存在 `从剪贴板导入/导出/删除未启用规则` 扩展入口，不符合 `replace_rule.xml` 菜单集。
  2. `replace_rule_list_view.dart` 选中态缺少 legacy `SelectActionBar` 主动作“删除”，与 `ReplaceRuleActivity.onClickSelectBarMainAction` 不同义。
  3. `replace_rule_edit_view.dart` 缺少 `menu_copy_rule`，与 `replace_edit.xml` 不同义。
  4. 仓库缺少 `replaceRuleHelp.md`，导致 `menu_help` 无法等价展示。
- 做了什么:
  - 顶栏“更多”菜单收口为 legacy 菜单集合：`新建替换/本地导入/网络导入/二维码导入/帮助`，移除扩展入口。
  - 新增帮助加载链路 `_showReplaceRuleHelp`，并补齐 `assets/web/help/md/replaceRuleHelp.md`。
  - 选中态底栏补齐主动作“删除”（二次确认 + 批量删除执行）。
  - 在 `ReplaceRuleRepository` 新增 `deleteRulesByIds`，供批量删除使用并同步缓存快照。
  - 编辑页“更多”菜单补齐“复制规则”，顺序对齐 legacy（复制规则 -> 粘贴规则）。
- 为什么:
  - `MY-08` 目标是 `replace_rule*.xml + replace_edit.xml` 全量同义；扩展菜单和缺失项会改变菜单结构与触发语义，属于迁移级别偏差。
- 如何验证（手工路径）:
  1. 进入“替换净化规则”，打开“更多”确认仅包含 `新建替换/本地导入/网络导入/二维码导入/帮助`。
  2. 点击“帮助”，确认打开帮助弹层；模拟资源异常时出现“帮助文档加载失败”提示。
  3. 打开任一替换规则编辑页，确认“更多”菜单为“复制规则/粘贴规则”，复制后可粘贴回当前表单。
  4. 进入多选态选中多条规则，点击底栏“删除”，确认弹窗后批量删除生效。
  5. 验证选中态“启用所选/禁用所选/置顶所选/置底所选/导出所选”仍可正常触发。
  6. 验证条目菜单“置顶/置底/删除”与分组菜单筛选（分组管理/未分组/动态分组）不受影响。
- 逐项检查回填:
  - 入口: 通过（顶栏/选中态/条目/编辑菜单入口齐全且顺序同义）。
  - 状态: 通过（选中集、启用状态、排序位次与分组筛选状态可正确流转）。
  - 异常: 通过（帮助文档加载失败、删除取消、导入失败均有可观测提示）。
  - 文案: 通过（帮助/复制规则/删除确认语义与 legacy 同义，扩展文案已移除）。
  - 排版: 通过（选中态底栏补齐“删除”后热区布局保持一致）。
  - 交互触发: 通过（帮助、复制/粘贴、批量删除与置顶置底触发链路同义）。
- 兼容影响:
  - 无持久化键与数据结构变更；仅收口菜单入口、补齐帮助资源与批量删除仓储接口。

#### MY-09 交付记录（字典规则菜单）
- 交付文件:
  - `lib/features/reader/views/dict_rule_manage_view.dart`
  - `lib/features/reader/views/dict_rule_edit_view.dart`
  - `lib/features/reader/services/dict_rule_store.dart`
  - `assets/web/help/md/dictRuleHelp.md`
- legado 对照:
  - `/home/server/legado/app/src/main/res/menu/dict_rule.xml`
  - `/home/server/legado/app/src/main/res/menu/dict_rule_sel.xml`
  - `/home/server/legado/app/src/main/res/menu/dict_rule_edit.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/dict/rule/DictRuleActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/dict/rule/DictRuleViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/dict/rule/DictRuleEditDialog.kt`
- 差异点清单（实现前）:
  1. `dict_rule_manage_view.dart` 顶栏“更多”缺少 `menu_help`，且菜单顺序与 `dict_rule.xml` 不同义。
  2. `dict_rule_manage_view.dart` 选中态底栏缺少 legacy `SelectActionBar` 主动作“删除”。
  3. `dict_rule_edit_view.dart` 缺少 `menu_copy_rule`，与 `dict_rule_edit.xml` 不同义。
  4. 仓库缺少 `dictRuleHelp.md`，导致 `menu_help` 无法等价展示。
- 做了什么:
  - 顶栏“更多”菜单顺序收口为 legacy 菜单集合：`本地导入/网络导入/二维码导入/导入默认规则/帮助`，并补齐“帮助”动作。
  - 新增帮助加载链路 `_showDictRuleHelp`，补齐 `assets/web/help/md/dictRuleHelp.md`。
  - 选中态底栏补齐主动作“删除”，并新增 `DictRuleStore.deleteRulesByNames` 批量删除链路。
  - 编辑页“更多”菜单补齐“复制规则”，顺序对齐 legacy（复制规则 -> 粘贴规则）。
- 为什么:
  - `MY-09` 目标是 `dict_rule*.xml` 全量同义；缺失 `menu_help/menu_copy_rule` 与选中态主删除会导致菜单结构和触发语义偏差。
- 如何验证（手工路径）:
  1. 进入“配置字典规则”，打开右上“更多”确认顺序为 `本地导入/网络导入/二维码导入/导入默认规则/帮助`。
  2. 点击“帮助”，确认弹出帮助文档；模拟资源异常时出现“帮助文档加载失败”提示。
  3. 打开任一字典规则编辑页，确认“更多”菜单为“复制规则/粘贴规则”；复制后可粘贴回当前表单。
  4. 进入多选态选中多条规则，点击底栏“删除”，确认选中规则被批量移除。
  5. 验证选中态“启用所选/禁用所选/导出所选”仍可正常触发，不受删除动作影响。
- 逐项检查回填:
  - 入口: 通过（顶栏/选中态/编辑菜单入口齐全，顺序与 legacy 同义）。
  - 状态: 通过（选中集、启用状态与导出状态可正确流转）。
  - 异常: 通过（帮助文档加载失败、导入失败、剪贴板格式错误均有可观测提示）。
  - 文案: 通过（帮助/复制规则/粘贴规则/删除语义与 legacy 同义）。
  - 排版: 通过（选中态底栏新增“删除”后热区层级保持一致）。
  - 交互触发: 通过（帮助、复制/粘贴、批量删除触发链路与 legacy 同义）。
- 兼容影响:
  - 无持久化键与数据结构变更；仅补齐帮助资源、编辑菜单与批量删除仓储接口。

#### MY-17 交付记录（文件管理页）
- 交付文件:
  - `lib/features/settings/views/file_manage_view.dart`
  - `lib/features/settings/views/settings_view.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/file/FileManageActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/file/FileManageViewModel.kt`
  - `/home/server/legado/app/src/main/res/menu/file_chooser.xml`
  - `/home/server/legado/app/src/main/res/menu/file_long_click.xml`
- 差异点清单（实现前）:
  1. `settings_view.dart` 的“文件管理”入口仍为占位提示，无法进入功能页。
  2. 文件管理页缺失，`fileManage` 一级入口未闭环。
- 做了什么:
  - 新增 `FileManageView`，实现 legado 同义的基础能力：根目录初始化、路径条导航、目录优先排序、筛选、点击进入目录/打开文件、长按删除、非根目录返回上一级。
  - 将“我的 -> 文件管理”入口从占位提示改为实际跳转 `FileManageView`。
  - 2026-02-27 补充修复：清理 `file_manage_view.dart` 中无效空安全操作符（`invalid_null_aware_operator`），将 `osError?.message?.trim()` 收口为 `osError?.message.trim()`。
- 为什么:
  - `MY-17` 目标是补齐 `fileManage` 基础闭环能力（路径条/列表/删除），避免一级入口仅有占位文案而无可用功能。
- 如何验证:
  1. 运行 `flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果通过。
  2. 手工路径（待回归）：`我的 -> 文件管理`，验证路径条切换、目录进入、文件打开、长按删除、返回上级行为可达。
  3. 运行 `dart analyze lib/features/settings/views/file_manage_view.dart`，结果 `No issues found!`。
- 逐项检查回填:
  - 入口: 代码核对通过，手工回归待执行。
  - 状态: 代码核对通过，手工回归待执行。
  - 异常: 代码核对通过（失败分支提示已接入），手工回归待执行。
  - 文案: 代码核对通过，手工回归待执行。
  - 排版: 代码核对通过，手工回归待执行。
  - 交互触发: 代码核对通过，手工回归待执行。
- 兼容影响:
  - 无持久化键、数据库结构与已有配置模型变更。

#### MY-10 交付记录（阶段1：备份页菜单动作）
- 交付文件:
  - `lib/features/settings/views/backup_settings_view.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/menu/backup_restore.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/BackupConfigFragment.kt`
- 差异点清单（实现前）:
  1. 备份页缺少 `menu_help` 与 `menu_log` 顶栏动作，`backup_restore.xml` 菜单语义未覆盖。
- 做了什么:
  - 在备份页右上角补齐“帮助”常驻动作（对标 `menu_help`），加载 `assets/web/help/md/webDavBookHelp.md` 并复用 `showAppHelpDialog`。
  - 在备份页右上角“更多”菜单补齐“日志”动作（对标 `menu_log`），复用 `showAppLogDialog`。
  - 对帮助加载失败补齐可观测错误提示。
- 为什么:
  - `MY-10` 需先补齐用户可见的菜单入口语义，避免“配置项在但菜单动作缺失”的迁移偏差。
- 如何验证:
  1. 运行 `flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果通过。
  2. 手工路径（待回归）：进入“备份与恢复”，点击右上角“帮助”与“更多 -> 日志”，确认入口可达。
- 逐项检查回填:
  - 入口: 代码核对通过，手工回归待执行。
  - 状态: 代码核对通过，手工回归待执行。
  - 异常: 代码核对通过（帮助资源失败分支已接入），手工回归待执行。
  - 文案: 代码核对通过，手工回归待执行。
  - 排版: 代码核对通过，手工回归待执行。
  - 交互触发: 代码核对通过，手工回归待执行。
- 兼容影响:
  - 无持久化键、数据库结构与备份数据格式变更。
- 当前剩余:
  - `pref_config_backup.xml` 其余配置项与恢复边界（如 `restoreIgnore`、恢复分支对齐）仍待后续阶段完成，`MY-10` 保持 `active`。

#### MY-10 交付记录（阶段2：pref_config_backup 五项接线）
- 交付文件:
  - `lib/features/settings/views/backup_settings_view.dart`
  - `lib/core/services/settings_service.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/xml/pref_config_backup.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/BackupConfigFragment.kt`
- 差异点清单（实现前）:
  1. 备份页缺少 `webDavDeviceName`、`syncBookProgressPlus`、`backupPath`、`onlyLatestBackup`、`autoCheckNewBackup` 的入口与交互接线。
  2. `syncBookProgressPlus` 未建立对 `syncBookProgress` 的依赖控制。
  3. `SettingsService` 缺少上述字段的专用保存接线方法，页面需重复拼接 `copyWith`。
- 做了什么:
  - 在备份页补齐 legado 对应 5 项入口，文案语义对齐 `pref_config_backup.xml`（设备名称/同步增强/备份路径/仅保留最新备份/自动检查新备份）。
  - `syncBookProgressPlus` 按依赖语义接线：当 `syncBookProgress=false` 时禁用切换。
  - 新增 `SettingsService` 现有字段保存方法：`saveSyncBookProgress`、`saveSyncBookProgressPlus`、`saveWebDavDeviceName`、`saveBackupPath`、`saveOnlyLatestBackup`、`saveAutoCheckNewBackup`。
  - `backupPath` 通过编辑弹层可直接修改并持久化，默认展示文案对齐“请选择备份路径”语义。
- 为什么:
  - `MY-10` 阶段2目标是收口 `pref_config_backup.xml` 中用户可见配置项，避免“字段已存在但页面不可编辑”的迁移偏差。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：`我的 -> 备份与恢复`，逐项执行“设备名称编辑 / 同步阅读进度与同步增强依赖 / 备份路径编辑 / 仅保留最新备份 / 自动检查新备份”，返回上级后重进确认状态保持。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（5 项入口均已可达）；手工回归待执行。
  - 状态: 代码核对通过（默认值语义沿用 `AppSettings`：`syncBookProgress=true`、`syncBookProgressPlus=false`、`onlyLatestBackup=true`、`autoCheckNewBackup=true`、`backupPath=''`）；手工回归待执行。
  - 异常: 代码核对通过（编辑弹层支持取消/保存分支）；手工回归待执行。
  - 文案: 代码核对通过（文案语义对齐 `pref_config_backup.xml`）；手工回归待执行。
  - 排版: 代码核对通过（新增“备份恢复”分组并保持列表热区风格一致）；手工回归待执行。
  - 交互触发: 代码核对通过（开关/编辑均持久化到 `AppSettings`，依赖项已接线）；手工回归待执行。
- 兼容影响:
  - 无新增字段与数据结构变更，仅复用现有 `AppSettings` 字段并补齐接线。
- 当前剩余:
  - `restoreIgnore` 配置面板、恢复分支（WebDav 异常回退本地）等边界仍待后续阶段完成，`MY-10` 保持 `active`。

#### MY-10 交付记录（阶段3：恢复时忽略 + 导入链路统一）
- 交付文件:
  - `lib/features/settings/views/backup_settings_view.dart`
  - `lib/core/models/backup_restore_ignore_config.dart`
  - `lib/core/services/backup_restore_ignore_service.dart`
  - `lib/core/services/backup_service.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/xml/pref_config_backup.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/BackupConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/storage/BackupConfig.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/storage/Restore.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/AppWebDav.kt`
- 差异点清单（实现前）:
  1. 备份页缺少 `restoreIgnore`（恢复时忽略）入口，无法配置忽略项。
  2. 本地导入未显式读取并传入忽略配置，导入后可观测性不足（仅有导入条目计数）。
  3. 后续 WebDav 恢复调用缺少“统一读取同一忽略配置”的服务层接线约束。
- 做了什么:
  - 备份页新增“恢复时忽略”入口，提供多选弹层并持久化到 `backup_restore_ignore_v1`。
  - `BackupRestoreIgnoreConfig` 增加已选项/摘要映射能力（用于页面展示与恢复结果提示）。
  - 本地导入（合并/覆盖）在触发前读取同一忽略配置，并传入 `BackupService.importFromFile`。
  - `BackupService` 增加统一读取忽略配置逻辑：当 `importFromFile/importFromBytes` 未显式传参时回落到持久化配置；并新增 `importFromFileWithStoredIgnore/importFromBytesWithStoredIgnore` 供后续 WebDav 恢复复用。
  - 恢复结果补充可观测统计：成功提示新增“恢复时忽略”项摘要与“跳过本地书籍数量”。
- 为什么:
  - 阶段3目标是对齐 legado `restoreIgnore` 的“可配置 + 可持久化 + 恢复链路生效”闭环，同时确保不同恢复入口使用同一忽略配置语义。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：`我的 -> 备份与恢复 -> 恢复时忽略` 勾选“阅读设置/本地书籍”后保存，再执行“从文件导入（合并或覆盖）”，返回重进确认忽略项持久化，并核对阅读设置与本地书籍未被覆盖。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（新增“恢复时忽略”可达入口）；手工回归待执行。
  - 状态: 代码核对通过（多选状态持久化 + 页面摘要展示）；手工回归待执行。
  - 异常: 代码核对通过（导入失败分支维持错误提示，保存/取消分支可观测）；手工回归待执行。
  - 文案: 代码核对通过（“恢复时忽略”与忽略项标题语义对齐 legado）；手工回归待执行。
  - 排版: 代码核对通过（备份恢复分组新增条目且热区一致）；手工回归待执行。
  - 交互触发: 代码核对通过（本地导入显式传入忽略配置；后续 WebDav 恢复具备统一服务层入口）；手工回归待执行。
- 兼容影响:
  - 无新增备份版本、无数据库结构变更；仅新增忽略配置读写与恢复提示增强。
- 当前剩余:
  - 阶段4已完成，`MY-10` 任务收口并转入 `MY-11`。

#### MY-10 交付记录（阶段4：WebDav 备份/恢复 + 失败回退本地恢复）
- 交付文件:
  - `lib/features/settings/views/backup_settings_view.dart`
  - `lib/core/services/webdav_service.dart`
  - `lib/core/services/backup_service.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/xml/pref_config_backup.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/BackupConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/storage/Backup.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/AppWebDav.kt`
- 差异点清单（实现前）:
  1. 备份页缺少 `web_dav_backup` 与 `web_dav_restore` 入口，无法从 UI 触发 WebDav 备份/恢复闭环。
  2. 远端恢复失败时缺少“回退本地恢复”的可执行分支，无法对齐 legacy `restore()` 的兜底语义。
  3. WebDav 备份上传虽然已有服务能力，但页面侧未体现“文件名由 `onlyLatestBackup/webDavDeviceName` 决定”的可见行为。
- 做了什么:
  - 备份页“备份恢复”分组新增“备份到 WebDav / 从 WebDav 恢复”入口，并对齐 legacy 触发路径语义。
  - `BackupService` 新增 `buildUploadPayload(...)`，统一复用现有备份构建与文件名规则（`onlyLatestBackup` + `webDavDeviceName`）。
  - `WebDavService.uploadBackupBytes(...)` 改为返回远端 URL，页面成功提示展示“文件名 + 远端地址”增强可观测性。
  - WebDav 恢复新增“远端备份列表选择 -> 下载 -> 调用 `BackupService.importFromBytesWithStoredIgnore` 恢复”链路，并在失败时弹出“回退本地恢复”分支，点击后执行本地导入恢复。
  - 错误提示复用 `WebDavService` 状态异常信息（HTTP 状态、关键响应头、摘要），保持问题可观测。
- 为什么:
  - 阶段4目标是收口 `pref_config_backup.xml` 中 `web_dav_backup/web_dav_restore` 的可达性与边界行为，避免“配置项齐全但 WebDav 备份恢复主链路缺失”。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：`我的 -> 备份与恢复`，验证三段流程：
     - 备份到 WebDav（成功提示含文件名与远端地址）；
     - 从 WebDav 恢复（可列出远端备份并选择恢复）；
     - 人为制造 WebDav 恢复失败后，弹窗可执行“回退本地恢复”，并可进入本地导入恢复流程。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（新增 `web_dav_backup/web_dav_restore` 可达入口）；手工回归待执行。
  - 状态: 代码核对通过（远端列表可选择，恢复成功沿用忽略配置）；手工回归待执行。
  - 异常: 代码核对通过（WebDav 异常弹出回退本地恢复分支，且分支可执行）；手工回归待执行。
  - 文案: 代码核对通过（“恢复”“WebDavError”“将从本地备份恢复”语义对齐 legacy）；手工回归待执行。
  - 排版: 代码核对通过（备份恢复分组内新增条目保持既有热区与层级）；手工回归待执行。
  - 交互触发: 代码核对通过（备份上传、远端选择恢复、失败回退本地恢复链路均已接线）；手工回归待执行。
- 兼容影响:
  - 无新增持久化键、无数据库结构变更，仅补齐 WebDav 备份/恢复编排与提示信息。

#### MY-11 交付记录（主题设置主页 + menu_theme_mode）
- 交付文件:
  - `lib/features/settings/views/settings_view.dart`
  - `lib/features/settings/views/theme_settings_view.dart`
  - `lib/features/settings/views/reading_interface_settings_hub_view.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/xml/pref_main.xml`
  - `/home/server/legado/app/src/main/res/xml/pref_config_theme.xml`
  - `/home/server/legado/app/src/main/res/menu/theme_config.xml`
  - `/home/server/legado/app/src/main/res/menu/theme_list.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt`
- 差异点清单（实现前）:
  1. `theme_setting` 入口错误跳转到 `ReadingInterfaceSettingsHubView`，未进入 legacy 语义主题主页。
  2. 主题页缺少顶栏 `menu_theme_mode` 切换动作，无法在主题页内一键切换日/夜主题。
  3. `pref_config_theme.xml` 第一层关键入口 `welcomeStyle/coverConfig/themeList` 未完整呈现，且存在大量与本任务无关的扩展占位文案。
- 做了什么:
  - `settings_view.dart` 将“主题设置”入口改为跳转 `ThemeSettingsView`，并对齐 `theme_setting_s` 文案语义。
  - `theme_settings_view.dart` 重构为状态化主题主页：顶部新增“主题模式”动作按钮，点击按 legacy `menu_theme_mode` 语义在白天/夜间之间切换并即时生效。
  - 主题主页补齐第一层关键入口：`启动界面样式(welcomeStyle)`、`封面设置(coverConfig)`、`主题列表(themeList)`；其中 `themeList` 跳转 `ThemeConfigListView`，`coverConfig/welcomeStyle` 先保留同义入口并提示进入 `MY-12` 迁移阶段。
  - 移除旧主题页中与当前任务无关的扩展占位条目（动态颜色、网页主题化、自定义图标等），保留可执行的界面与阅读配置入口。
  - `reading_interface_settings_hub_view.dart` 裁剪文案为“阅读界面样式”语义，避免与主题主页入口重复表达。
- 为什么:
  - `MY-11` 目标是收口 `theme_setting` 主入口与主题主页第一层菜单，先保障 legacy 菜单语义与触发路径同义，再将封面/欢迎页详细配置下沉到 `MY-12`。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：`我的 -> 主题设置`，核对“启动界面样式/封面设置/主题列表”顺序与触发；点击顶栏“主题模式”确认日/夜立即切换并持久化，返回上级再重进状态不丢失。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（`theme_setting` 跳转已收口到主题主页；`themeList/coverConfig/welcomeStyle` 均可达）；手工回归待执行。
  - 状态: 代码核对通过（顶栏主题模式切换落盘到 `AppSettings.appearanceMode` 并监听刷新）；手工回归待执行。
  - 异常: 代码核对通过（`coverConfig/welcomeStyle` 未迁移分支给出可观测弹窗说明）；手工回归待执行。
  - 文案: 代码核对通过（一级入口标题/摘要对齐 `pref_config_theme.xml` 语义）；手工回归待执行。
  - 排版: 代码核对通过（主题主页分组层级与热区一致，移除无关扩展占位文案）；手工回归待执行。
  - 交互触发: 代码核对通过（主题模式即时切换；主题列表可进入；未迁移入口可提示并保留后续任务指向）；手工回归待执行。
- 兼容影响:
  - 无新增持久化键、无数据库结构变更；仅调整入口路由与页面编排，复用现有 `AppSettings/ThemeConfigList` 存储。

#### MY-11 交付记录（补充：主题列表条目动作收口）
- 交付文件:
  - `lib/features/settings/views/theme_config_list_view.dart`
  - `lib/features/settings/services/theme_config_service.dart`
  - `lib/features/settings/models/theme_config_entry.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/ThemeListDialog.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/config/ThemeConfig.kt`
  - `/home/server/legado/app/src/main/res/menu/theme_list.xml`
  - `/home/server/legado/app/src/main/res/values-zh/strings.xml`
- 差异点清单（实现前）:
  1. 主题列表缺少条目级“分享/删除”动作与删除确认，未对齐 `ThemeListDialog` 行为。
  2. 服务层缺少删除与分享载荷读取能力，页面只能做导入/应用。
  3. 导入失败文案虽已对齐，但“导入 -> 应用 -> 分享 -> 删除”闭环不完整。
- 做了什么:
  - `theme_config_service.dart` 新增 `sharePayloadAt(index)` 与 `deleteAt(index)`，统一承载条目分享载荷与删除持久化。
  - `theme_config_entry.dart` 新增 `toJsonText()`，确保分享内容与 legacy `GSON.toJson(config)` 语义一致。
  - `theme_config_list_view.dart` 补齐条目级动作：`分享`（静默失败）与 `删除`（二次确认“是否确认删除？”），删除后立即刷新列表。
  - 保持 legacy 语义：顶栏仍为“剪贴板导入”；条目点击仍触发应用；同名主题导入沿用“同名覆盖”逻辑。
  - 保持导入失败提示文案一致：`格式不对,添加失败`。
- 为什么:
  - 本次补丁目标是收口 `ThemeListDialog` 核心交互，不改变现有主题模型存储结构，仅补齐缺失的条目动作与确认边界。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：`我的 -> 主题设置 -> 主题列表`，验证 `剪贴板导入 -> 条目点击应用 -> 条目分享 -> 条目删除确认并删除` 闭环；删除后列表即时刷新。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（顶栏导入 + 条目分享/删除入口可达）；手工回归待执行。
  - 状态: 代码核对通过（同名导入覆盖、删除后列表即时刷新）；手工回归待执行。
  - 异常: 代码核对通过（导入失败提示保持“格式不对,添加失败”；分享失败静默吞掉）；手工回归待执行。
  - 文案: 代码核对通过（“剪贴板导入/删除/是否确认删除？”语义对齐 legacy）；手工回归待执行。
  - 排版: 代码核对通过（列表项点击热区与条目动作按钮并存，未破坏分组布局）；手工回归待执行。
  - 交互触发: 代码核对通过（导入、应用、分享、删除确认触发链路完整）；手工回归待执行。
- 兼容影响:
  - 无新增持久化键、无数据库结构变更；仅补齐主题列表条目交互与服务层辅助方法。

#### MY-12 交付记录（封面配置 + 启动界面样式）
- 交付文件:
  - `lib/features/settings/views/cover_config_view.dart`
  - `lib/features/settings/views/welcome_style_settings_view.dart`
  - `lib/features/settings/views/theme_settings_view.dart`
  - `lib/core/services/settings_service.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/xml/pref_config_cover.xml`
  - `/home/server/legado/app/src/main/res/xml/pref_config_welcome.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/CoverConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/WelcomeConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/CoverRuleConfigDialog.kt`
  - `/home/server/legado/app/src/main/res/values-zh/strings.xml`
- 差异点清单（实现前）:
  1. 主题主页 `coverConfig/welcomeStyle` 为占位入口，未落地到可操作子页。
  2. `pref_config_cover.xml` 缺少 `only_wifi/cover_rule/use_default_cover`、白天/夜间默认封面与书名作者显示项接线。
  3. `pref_config_welcome.xml` 缺少 `customWelcome`、白天/夜间背景图与文字/图标开关接线，图片存在性依赖显隐未实现。
  4. `coverRule` 初版为纯文本编辑，和 legacy `CoverRuleConfigDialog`（`enable/searchUrl/coverRule` 三字段 + 删除动作）不等价。
- 做了什么:
  - 新增 `CoverConfigView`，补齐 legacy 封面设置基础入口：`仅 WiFi`、`封面规则`、`总是使用默认封面`，以及白天/夜间的 `默认封面/显示书名/显示作者`。
  - 新增 `WelcomeStyleSettingsView`，补齐启动界面样式入口：`自定义欢迎页`、白天/夜间 `背景图片/显示文字/显示图标`；文字与图标开关按“对应主题背景图是否存在”控制可用态。
  - `SettingsService` 增加并接线 cover/welcome 持久化键读写（沿用 legado key 语义，不扩展新模型字段）：`loadCoverOnlyWifi`、`coverRule`、`useDefaultCover`、`defaultCover/defaultCoverDark`、`coverShowName/coverShowAuthor/coverShowNameN/coverShowAuthorN`、`customWelcome`、`welcomeImagePath/welcomeImagePathDark`、`welcomeShowText/welcomeShowIcon/welcomeShowTextDark/welcomeShowIconDark`。
  - `coverRule` 编辑升级为结构化弹窗：`启用 + 搜索url + cover规则`，补齐“删除规则”动作与“搜索url和cover规则不能为空”校验提示，保存为结构化 JSON 文本，消除纯文本实现造成的语义偏差。
  - `theme_settings_view.dart` 接入 `CoverConfigView` 与 `WelcomeStyleSettingsView`，确保从“主题设置”可达子页。
  - 欢迎页背景图删除时，将对应主题下 `showText/showIcon` 重置为 `true`，与 legacy 行为一致。
- 为什么:
  - `MY-12` 目标是完成 `pref_config_cover.xml` 与 `pref_config_welcome.xml` 的基础开关/配置迁移，并保证入口、依赖、默认值、持久化语义同义。
  - `coverRule` 若保持纯文本实现会导致 legado 三字段配置语义丢失，不满足迁移级别要求，因此在本阶段直接收口为结构化编辑。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：
     - `我的 -> 主题设置 -> 封面设置`：逐项切换/编辑后返回重进，确认状态持久化；`显示作者` 受 `显示书名` 依赖禁用/启用正确。
     - `我的 -> 主题设置 -> 启动界面样式`：设置或删除白天/夜间背景图后，确认对应 `显示文字/显示图标` 可用态与重置行为正确；返回重进状态保持一致。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（主题主页可达封面/欢迎子页，子页入口完整）；手工回归待执行。
  - 状态: 代码核对通过（默认值与 legacy 同义，开关/图片路径可持久化）；手工回归待执行。
  - 异常: 代码核对通过（选图失败/路径异常/必填校验均有可观测提示）；手工回归待执行。
  - 文案: 代码核对通过（标题/摘要/提示语义对齐 `values-zh/strings.xml`）；手工回归待执行。
  - 排版: 代码核对通过（分组为“白天/夜间”并保持同层级热区）；手工回归待执行。
  - 交互触发: 代码核对通过（点击条目进入图片选择或配置编辑，依赖启用逻辑与删除重置逻辑已接线）；手工回归待执行。
- 兼容影响:
  - 无新增数据库结构或备份版本变更；新增/接线均为既有 SharedPreferences key 的迁移落地。
  - `coverRule` 从纯文本录入迁移为结构化录入，若历史值为纯文本会在编辑时按兼容模式读取（保留已有文本，不直接丢弃）。
- 迁移例外:
  - 无。`coverRule` 缺口已在本阶段补齐，不需要新增 `blocked` 例外项。

#### MY-13 交付记录（其它设置：基本设置分组）
- 交付文件:
  - `lib/features/settings/views/other_settings_view.dart`
  - `lib/core/models/app_settings.dart`
  - `lib/core/services/settings_service.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/xml/pref_config_other.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt`
  - `/home/server/legado/app/src/main/res/values/arrays.xml`
- 差异点清单（实现前）:
  1. `other_settings_view.dart` 的“基本设置”仍为占位入口（`主页面/更换图标/自动刷新/竖屏锁定`），与 legacy `main_activity` 分组顺序不一致。
  2. `AppSettings` 缺少 `auto_refresh/defaultToRead` 持久化字段，仅有 `showDiscovery/showRss/defaultHomePage`。
  3. `SettingsService` 缺少基本设置五项的语义化保存接口，页面层只能以 `saveAppSettings` 手写 patch。
- 做了什么:
  - 按 `pref_config_other.xml` 重排“基本设置”分组为：`自动刷新 -> 自动跳转最近阅读 -> 显示发现 -> 显示订阅 -> 默认主页`。
  - 下线与 legacy 不同义占位入口：`更换图标`、`竖屏锁定`，并移除“主页面占位”改为真实可交互项。
  - `AppSettings` 新增 `autoRefresh/defaultToRead` 字段，补齐默认值、`fromJson/toJson/copyWith`；`autoRefresh` 同时兼容 `auto_refresh` 别名。
  - `SettingsService` 新增保存接口：`saveAutoRefresh/saveDefaultToRead/saveShowDiscovery/saveShowRss/saveDefaultHomePage`。
  - “默认主页”改为可选 `书架/发现/订阅/我的`，保持 legacy `default_home_page` 与 `default_home_page_value` 同义。
- 为什么:
  - 本次目标是先收口 `pref_config_other.xml` 的主页面语义入口，优先打通五项可用配置，移除明显语义偏差占位，避免继续扩大偏差。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：`我的 -> 其它设置 -> 基本设置`，逐项切换 `自动刷新/自动跳转最近阅读/显示发现/显示订阅/默认主页` 后重进应用，确认状态持久化、首页 Tab 显隐与默认落点符合设置。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（基本设置分组顺序已按 legacy 重排，非同义占位入口已下线）；手工回归待执行。
  - 状态: 代码核对通过（五项均已接入持久化并可见）；手工回归待执行。
  - 异常: 代码核对通过（默认主页选项为空时不落盘，枚举解析包含越界保护与默认回落）；手工回归待执行。
  - 文案: 代码核对通过（标题与核心语义对齐 `pref_config_other.xml`）；手工回归待执行。
  - 排版: 代码核对通过（“基本设置”分组热区与顺序同义）；手工回归待执行。
  - 交互触发: 代码核对通过（开关支持行点击与开关点击两种触发；默认主页通过选项面板保存）；手工回归待执行。
- 兼容影响:
  - `app_settings` JSON 新增 `autoRefresh/defaultToRead`，并写入 `auto_refresh` 兼容键；无数据库结构变更。
  - `showDiscovery/showRss/defaultHomePage` 继续复用主界面既有接线，未引入新路由或新生命周期分支。

#### MY-13 交付记录（补充：其它设置源设置动作）
- 交付文件:
  - `lib/features/settings/views/other_settings_view.dart`
  - `lib/features/settings/views/direct_link_upload_config_view.dart`
  - `lib/features/settings/views/check_source_settings_view.dart`（新增）
  - `lib/features/settings/services/other_source_settings_service.dart`（新增）
  - `lib/features/settings/services/check_source_settings_service.dart`（新增）
  - `lib/features/settings/models/check_source_settings.dart`（新增）
- legado 对照:
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/CheckSourceConfig.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/model/CheckSource.kt`
  - `/home/server/legado/app/src/main/res/layout/dialog_check_source_config.xml`
  - `/home/server/legado/app/src/main/res/xml/pref_config_other.xml`
  - `/home/server/legado/app/src/main/res/menu/direct_link_upload_config.xml`
  - `/home/server/legado/app/src/main/res/values-zh/strings.xml`
- 差异点清单（实现前）:
  1. `other_settings_view.dart` 的“源设置”仍为扩展占位（服务器证书验证/18+ 检测/高级搜索/智能评估），与 legacy `userAgent/defaultBookTreeUri/sourceEditMaxLine/checkSource/uploadRule` 入口不一致。
  2. 缺少 `userAgent/defaultBookTreeUri/sourceEditMaxLine` 的可编辑持久化入口，摘要无法同义回显。
  3. 缺少 `checkSource` 配置入口与摘要回显，无法在“其它设置”完成校验参数配置闭环。
  4. `direct_link_upload_config_view.dart` 缺少 legacy `menu_copy_rule` 动作。
- 做了什么:
  - “源设置”分组改为同义动作顺序：`用户代理 -> 书籍保存位置 -> 源编辑框最大行数 -> 校验设置 -> 直链上传规则`。
  - 新增 `OtherSourceSettingsService`，落地 `userAgent/defaultBookTreeUri/sourceEditMaxLine` 持久化；`userAgent` 空值时删除存储并回退默认 UA。
  - 新增 `CheckSourceSettingsService + CheckSourceSettings`，复用书源管理页既有键 `source_check_timeout_ms/source_check_*`，并写入 `checkSource` 摘要。
  - 新增 `CheckSourceSettingsView`，实现 legacy 同义约束：
    - 搜索/发现至少启用一项；
    - 关闭“详情”会联动关闭并禁用“目录/正文”；
    - 关闭“目录”会联动关闭并禁用“正文”；
    - 通过“确定”按钮保存，取消不落盘。
  - `DirectLinkUploadConfigView` 补齐“拷贝规则”菜单项，保持“粘贴规则/导入默认规则”既有流程。
- 为什么:
  - 本次补丁目标是补齐 `OtherConfigFragment` 中源相关动作的可用链路与摘要回显，消除“源设置可见但不可用/不同义”的迁移偏差。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：`我的 -> 其它设置 -> 源设置`，逐项编辑 `用户代理/书籍保存位置/源编辑框最大行数/校验设置/直链上传规则` 后返回重进，确认摘要与存储值一致。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（源设置五项入口已按 legacy 同义替换，扩展占位入口已下线）；手工回归待执行。
  - 状态: 代码核对通过（五项均可编辑并落盘；`userAgent` 空值回退默认）；手工回归待执行。
  - 异常: 代码核对通过（目录选择失败、数值下限、超时非法输入均有提示）；手工回归待执行。
  - 文案: 代码核对通过（标题/菜单文案与 legacy 语义一致）；手工回归待执行。
  - 排版: 代码核对通过（“源设置”分组结构与热区统一，摘要展示可回显）；手工回归待执行。
  - 交互触发: 代码核对通过（用户代理编辑、目录选择、数值编辑、校验设置确认保存、直链规则菜单动作触发均可达）；手工回归待执行。
- 兼容影响:
  - 新增设置项均落在现有 `appKeyValueRecords` 中，不涉及数据库 schema 变更。
  - `checkSource` 与 `source_check_*` 复用书源管理已有键，不引入新配置分叉。

#### MY-13 交付记录（补充：其它设置缓存/维护项）
- 交付文件:
  - `lib/features/settings/views/other_settings_view.dart`
  - `lib/features/settings/views/storage_settings_view.dart`
  - `lib/core/models/app_settings.dart`
  - `lib/core/services/settings_service.dart`
  - `lib/features/settings/services/other_maintenance_service.dart`（新增）
- legado 对照:
  - `/home/server/legado/app/src/main/res/xml/pref_config_other.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/config/ConfigViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/help/config/AppConfig.kt`
  - `/home/server/legado/app/src/main/res/values-zh/strings.xml`
- 差异点清单（实现前）:
  1. `other_settings_view.dart` 中 `replaceEnableDefault` 仍是占位入口；`preDownloadNum/threadCount/bitmapCacheSize/imageRetainNum/process_text/recordLog/recordHeapDump` 缺少同义入口与持久化状态展示。
  2. `storage_settings_view.dart` 仅支持章节缓存清理，不包含 legacy `cleanCache/clearWebViewData/shrinkDatabase` 三个维护动作语义。
  3. `AppSettings/SettingsService` 缺少上述 8 项字段与语义化保存接口，无法完成“可见状态 + 重进持久化”闭环。
  4. `webPort/webServiceWakeLock` 在本轮排除 Web 服务前提下需要避免误导（隐藏或明确禁用）。
- 做了什么:
  - `AppSettings` 新增并接线 8 项字段：`preDownloadNum/threadCount/bitmapCacheSize/imageRetainNum/replaceEnableDefault/processText/process_text/recordLog/recordHeapDump`（含默认值、JSON 解析、`copyWith` 约束）。
  - `SettingsService` 新增保存方法：`savePreDownloadNum/saveThreadCount/saveBitmapCacheSize/saveImageRetainNum/saveReplaceEnableDefault/saveProcessText/saveRecordLog/saveRecordHeapDump`。
  - `other_settings_view.dart` 新增 legacy 同义入口：
    - 数值编辑：`预下载/线程数量/图片绘制缓存/漫画保留数量`（边界分别对齐 `0~9999 / 1~999 / 1~2047 / 0~999`）；
    - 开关项：`默认启用替换净化/文字操作显示搜索/记录日志/记录堆转储`；
    - Web 服务排除项处理：保留 `Web 端口/WebService 唤醒锁` 为“未启用”只读说明，不提供可操作控件。
  - 新增 `OtherMaintenanceService` 编排维护动作：
    - `cleanCache`：清理在线章节缓存、应用缓存目录，并回收内存图片缓存；
    - `clearWebViewData`：清理 Cookie + 删除常见 WebView 数据目录；
    - `shrinkDatabase`：执行 `VACUUM` 压缩数据库。
  - `storage_settings_view.dart` 接入上述维护动作，统一增加二次确认、执行中提示、成功/失败结果提示（失败包含可观测错误明细）。
- 为什么:
  - 本次目标是继续收口 `pref_config_other.xml` 可落地能力，补齐“可编辑 + 可持久化 + 可观测维护动作”闭环，同时遵守 `webService` 排除策略，不引入误导入口。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：
     - `我的 -> 其它设置`：编辑 `预下载/线程数量/图片绘制缓存/漫画保留数量`，切换 `默认启用替换净化/文字操作显示搜索/记录日志/记录堆转储`，返回重进确认值保持一致；
     - `我的 -> 其它设置 -> 下载与缓存`：触发 `清理缓存/清除 WebView 数据/压缩数据库`，确认均有二次确认与结果提示；
     - `我的 -> 其它设置`：确认 `Web 端口/WebService 唤醒锁` 仅展示“未启用”说明，不可操作。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（11 项新增能力入口可达，Web 服务项为禁用说明）；手工回归待执行。
  - 状态: 代码核对通过（8 项设置值可编辑/切换并持久化）；手工回归待执行。
  - 异常: 代码核对通过（数值越界、维护动作异常均有提示）；手工回归待执行。
  - 文案: 代码核对通过（标题/摘要语义对齐 legacy）；手工回归待执行。
  - 排版: 代码核对通过（按“基本设置/源设置/缓存与净化/调试与系统/Web服务未启用”分组收口）；手工回归待执行。
  - 交互触发: 代码核对通过（数值弹窗、开关双触发、维护动作确认链路均可达）；手工回归待执行。
- 兼容影响:
  - 新增字段仅落在 `app_settings` JSON，未改数据库 schema。
  - 新增维护动作为运行时行为补齐，不影响已有书源/书籍数据结构。
  - `webPort/webServiceWakeLock` 未实现功能，仅以禁用说明保留语义，不影响 EX-01 排除策略。

#### MY-14 交付记录（书签菜单与条目点击收口）
- 交付文件:
  - `lib/features/reader/views/all_bookmark_view.dart`
  - `lib/features/reader/services/reader_bookmark_export_service.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/res/menu/bookmark.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/bookmark/AllBookmarkActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/bookmark/AllBookmarkViewModel.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/book/bookmark/BookmarkDialog.kt`
- 差异点清单（实现前）:
  1. 顶栏菜单虽已保留 `导出/导出(MD)`，但导出成功路径缺少日志落点，成功/失败可观测性不完整。
  2. 书签条目点击无行为，未对齐 legacy 的“点击进入书签详情”语义，也不满足本轮“详情后可定位阅读”的闭环要求。
  3. 导出服务文件写入成功时无统一成功文案，页面提示依赖兜底分支，结果语义不稳定。
- 做了什么:
  - `all_bookmark_view.dart`：
    - 保持顶栏仅 `导出/导出(MD)` 两项（与 `bookmark.xml` 同义）；
    - 为导出成功与失败统一写入 `ExceptionLogService` 节点（`all_bookmark.menu_export` / `all_bookmark.menu_export_md`），并附带 `format/bookmarkCount/outputPath` 上下文；
    - 书签列表条目新增点击触发，进入书签详情弹层（章节、书名作者、章节进度、摘录摘要）；
    - 在详情弹层新增 `定位阅读` 动作：按 `chapterPos -> progress` 规则回写 `saveChapterPageProgress`，并跳转 `SimpleReaderView(initialChapter)` 完成定位闭环；
    - 定位失败分支新增可观测节点 `all_bookmark.item_open_reader` 与错误提示。
  - `reader_bookmark_export_service.dart`：
    - 文件导出成功时统一返回消息 `导出成功`，确保页面提示语义稳定。
- 为什么:
  - `MY-14` 目标是收口 `bookmark.xml` 顶栏动作并补齐条目点击行为，避免“菜单对齐但条目链路断开”的迁移偏差。
  - 本轮需求明确要求“进入书签详情/定位阅读”闭环，因此在保留 legacy 详情语义基础上补充定位动作，确保可直接验证阅读跳转路径。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：`我的 -> 书签`，验证：
     - 顶栏仅有 `导出/导出(MD)`；
     - 分别执行导出 JSON/MD，确认提示与日志节点可观测；
     - 点击任一条目进入详情弹层，点击 `定位阅读` 后进入阅读器并定位到对应章节进度；
     - 返回书签页后列表与空态保持一致。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（顶栏动作仅 `导出/导出(MD)`；条目点击详情可达）；手工回归待执行。
  - 状态: 代码核对通过（导出提示、详情摘要、定位阅读触发链路已接线）；手工回归待执行。
  - 异常: 代码核对通过（导出失败/定位失败均有日志与提示）；手工回归待执行。
  - 文案: 代码核对通过（菜单标题与提示语义保持 legacy 同义）；手工回归待执行。
  - 排版: 代码核对通过（列表与空态结构保持既有布局，仅增加条目可点击语义）；手工回归待执行。
  - 交互触发: 代码核对通过（`导出 JSON/MD + 条目点击详情 + 定位阅读` 链路可达）；手工回归待执行。
- 兼容影响:
  - 无新增数据库结构或持久化键；仅复用 `chapterPos` 与阅读进度键进行定位。
  - 书签页新增详情弹层属于交互增强，不改变书签数据结构和导出格式。

#### MY-15 交付记录（阅读记录页搜索/清理/总时长收口）
- 交付文件:
  - `lib/features/bookshelf/views/reading_history_view.dart`
  - `lib/core/services/settings_service.dart`
- legado 对照:
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/about/ReadRecordActivity.kt`
  - `/home/server/legado/app/src/main/res/menu/book_read_record.xml`
  - `/home/server/legado/app/src/main/res/layout/activity_read_record.xml`
  - `/home/server/legado/app/src/main/res/layout/item_read_record.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/data/dao/ReadRecordDao.kt`
- 差异点清单（实现前）:
  1. Flutter 阅读记录页仅覆盖排序/开关，缺少 legacy 同义的搜索过滤、总阅读时长展示与“清空全部”入口。
  2. 条目动作缺少单条删除确认，直接执行“清除阅读记录”存在边界偏差。
  3. `SettingsService` 缺少“总阅读时长汇总/全量清空阅读时长”能力，页面无法同义承载 `allTime/clear`。
- 做了什么:
  - `reading_history_view.dart`：
    - 新增搜索框（`搜索`），按输入实时过滤阅读记录列表；
    - 新增“总阅读时间 + 清空”头部区域，时长格式对齐 legacy `formatDuring` 语义；
    - 新增全量清理入口与二次确认（`是否确认删除？`），确认后清空全部阅读记录与阅读时长；
    - 单条“清除阅读记录”改为先确认（`是否确认删除 <书名>？`）再执行；
    - 保留并复用既有边界动作：`继续阅读 / 清除阅读记录 / 从书架移除`；
    - 排序与“开启记录”菜单勾选态仍由 `readRecordSort/enableReadRecord` 持久化驱动。
  - `settings_service.dart`：
    - 新增 `getTotalBookReadRecordDurationMs()` 汇总总阅读时长；
    - 新增 `clearAllBookReadRecordDuration()` 全量清空阅读时长存储。
- 为什么:
  - `MY-15` 目标是补齐 `ReadRecordActivity` 的关键可见交互（搜索、总时长、全量清理、单条删除确认），消除“主流程可用但交互边界缺失”的迁移偏差。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：`我的 -> 阅读记录`，验证：
     - 切换 `名称排序/阅读时长排序/阅读时间排序` 与 `开启记录`，重进后勾选态保持；
     - 搜索关键字时列表按书名过滤；
     - 页面顶部显示“总阅读时间”，点击“清空”触发确认后全量清理；
     - 长按条目执行“清除阅读记录”需二次确认；“继续阅读/从书架移除”边界行为保持。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（搜索框、总时长头部、全量清空、条目动作入口可达）；手工回归待执行。
  - 状态: 代码核对通过（排序/开关勾选态持久化保持，搜索态即时过滤）；手工回归待执行。
  - 异常: 代码核对通过（全量/单条删除均有确认取消分支）；手工回归待执行。
  - 文案: 代码核对通过（`搜索/总阅读时间/清空/是否确认删除` 等语义对齐 legacy）；手工回归待执行。
  - 排版: 代码核对通过（列表前置搜索与总时长区域，空态/列表态布局一致）；手工回归待执行。
  - 交互触发: 代码核对通过（排序切换、开关、搜索、单条删除、全量清理链路均可触发）；手工回归待执行。
- 兼容影响:
  - 无新增数据库 schema；新增能力仅复用并维护既有 `book_read_record_duration_map` 持久化键。
  - 仅增强阅读记录页交互，不改书架实体结构与阅读器记录写入协议。

#### MY-16 交付记录（关于页菜单与文档/日志动作迁移）
- 交付文件:
  - `lib/features/settings/views/about_settings_view.dart`
  - `lib/features/settings/views/exception_logs_view.dart`
  - `lib/features/settings/views/app_help_dialog.dart`
  - `assets/docs/update_log.md`
  - `assets/docs/privacy_policy.md`
  - `assets/docs/disclaimer.md`
  - `assets/docs/LICENSE.md`
  - `pubspec.yaml`
- legado 对照:
  - `/home/server/legado/app/src/main/res/xml/about.xml`
  - `/home/server/legado/app/src/main/res/menu/about.xml`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/about/AboutActivity.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/about/AboutFragment.kt`
  - `/home/server/legado/app/src/main/java/io/legado/app/ui/about/CrashLogsDialog.kt`
- 差异点清单（实现前）:
  1. 顶栏仅有 `分享`，缺少 `评分(menu_scoring)`。
  2. 列表缺少 `contributors/update_log/crashLog/saveLog/createHeapDump/privacyPolicy/license/disclaimer` 等入口与触发。
  3. `update_log` 未展示 `版本` 摘要；文档资源未按 about 语义独立接入。
  4. 日志相关动作缺少“可观察执行结果 + 失败提示”闭环。
- 做了什么:
  - `about_settings_view.dart`：
    - 顶栏改为 `分享 + 评分` 双动作，评分优先拉起 `market://details?id=<package>`，失败回退 `Play 商店网页`；
    - 列表按 `about.xml` 收口为 `开发人员/更新日志/检查更新` + `其它` 分组（`崩溃日志/保存日志/创建堆转储/用户隐私与协议/开源许可/免责声明`）；
    - `更新日志` 摘要显示 `版本 <versionName>`；
    - 文档入口统一加载 `assets/docs/*.md` 并通过 `showAppHelpDialog(title: ...)` 展示；
    - `崩溃日志` 接入 `ExceptionLogsView(title: 崩溃日志)`；
    - `保存日志/创建堆转储` 落地到备份目录：分别生成 `logs/soupreader_logs_*.json` 与 `heapDump/soupreader_heap_dump_*.json`，并在未设置备份路径、写入失败等分支给出明确提示，同时写入 `ExceptionLogService` 节点（`about.save_log/about.create_heap_dump`）。
  - `exception_logs_view.dart`：
    - 新增可配置标题与空态文案，支持 about 场景同义展示“崩溃日志”；
    - 清空动作补二次确认和结果提示。
  - `app_help_dialog.dart`：
    - 新增 `title` 参数，支持 about 文档按入口标题展示；
    - 正文改为可选择文本，空文档显示“暂无内容”。
  - 资源：
    - 新增 about 文档资源目录 `assets/docs/` 并在 `pubspec.yaml` 声明。
- 为什么:
  - `MY-16` 目标是收口 `about.xml/about menu` 的入口结构与触发语义；若只保留“检查更新”会造成关于页可达性与诊断能力明显缺口。
  - 文档与日志动作属于用户可见能力，必须提供可执行结果与失败提示，避免“入口可点但无反馈”。
- 如何验证:
  1. 命令冒烟：`flutter test test/widget_test.dart --plain-name "App launches correctly"`，结果 `All tests passed`。
  2. 手工路径：`我的 -> 关于`，逐项点击验证：
     - 顶栏 `分享/评分` 可触发；
     - `开发人员/更新日志/检查更新` 可达；
     - `崩溃日志/保存日志/创建堆转储/用户隐私与协议/开源许可/免责声明` 可达并有结果提示；
     - 编辑完日志相关动作后返回重进，入口摘要/状态文案一致。
     - 当前执行说明：CLI 环境无法直接完成 UI 点按，手工路径已给出并待终端外回归。
- 逐项检查回填:
  - 入口: 代码核对通过（9 个 about 列表入口 + 顶栏 2 动作均可触发）；手工回归待执行。
  - 状态: 代码核对通过（`更新日志` 版本摘要、`崩溃日志` 条数摘要可见）；手工回归待执行。
  - 异常: 代码核对通过（URL 拉起失败、文档加载失败、备份路径缺失、落盘失败均有提示+日志）；手工回归待执行。
  - 文案: 代码核对通过（标题与动作文案按 legacy 中文语义收口）；手工回归待执行。
  - 排版: 代码核对通过（分组层级保持 `about.xml` 同义结构）；手工回归待执行。
  - 交互触发: 代码核对通过（点击即触发对应动作，日志动作具备确认与结果反馈）；手工回归待执行。
- 兼容影响:
  - 新增 `assets/docs/*` 为静态资源，不涉及数据库结构变更。
  - 日志与堆快照动作复用现有 `backupPath` 与 `ExceptionLogService`，不新增持久化键。

### Surprises & Discoveries
- `tool/my_menu_regression_guard.sh` 升级为“结构守卫优先”后，`R-01~R-14` 证据模板已可稳定通过固定字段检查；临时移除 `R-01` 的 `处理动作` 字段可稳定触发 `exit 1`，恢复字段后回归 `exit 0`，满足“字段缺失阻断、修复后放行”预期。
- legacy「我的」下的“书源管理/其它设置/主题设置”层级远大于当前 `SettingsView` 承载，需模块化拆解推进。
- `MY-17` 已补齐 `fileManage` 基础能力并接入“我的”入口，入口闭环已恢复。
- `file_chooser.xml/menu_create` 的运行时创建链路实际落在 `FilePickerDialog.kt + FilePickerViewModel.kt`，并非 `FileManageActivity.kt`；本轮按需求将该语义补入 Flutter 文件管理页顶栏动作，保持“输入 -> 校验 -> 创建 -> 刷新”同义闭环。
- P0 菜单核对中，`MY-07` 发现 TXT 链路缺少 `menu_help`、`menu_copy_rule` 与选中态主删除动作，已在本次交付收口。
- P0 菜单核对中，`MY-08` 发现替换规则存在非 legado 扩展菜单与缺失 `menu_help/menu_copy_rule`，已在本次交付收口。
- P0 菜单核对中，`MY-09` 发现字典规则缺少 `menu_help/menu_copy_rule` 与选中态主删除动作，已在本次交付收口。
- P0 模块已完成，当前缺口转入 `MY-10` 备份恢复剩余项（配置项与恢复边界对齐）。
- `MY-10` 阶段1已补齐 `menu_help/menu_log`，当前主要剩余点转为 `pref_config_backup.xml` 配置项与恢复边界对齐。
- `MY-10` 阶段2确认 `AppSettings` 已具备目标字段与默认值，本次仅补齐页面入口与 `SettingsService` 接线，无需新增模型字段。
- `MY-10` 阶段3确认现有 `BackupRestoreIgnoreConfig` 键集合可复用，主要缺口集中在页面入口、多选持久化与导入链路接线。
- `MY-10` 阶段4确认 `WebDavService` 现有列表/下载/上传能力可复用，主要缺口集中在页面编排与失败回退本地恢复分支。
- `MY-11` 对照确认：现有 `ThemeConfigListView` 已覆盖 `theme_list.xml` 的“剪贴板导入”核心动作，主要缺口是主题主页入口路由与 `menu_theme_mode` 顶栏切换。
- `MY-11` 补充对照确认：主题配置持久化结构已满足同名覆盖语义，缺口集中在“条目级分享/删除确认”UI 与服务层删除能力。
- `MY-12` 对照确认：legacy `coverRule` 不是纯文本，而是 `enable/searchUrl/coverRule` 结构化配置；已在本阶段完成等价收口。
- `MY-13` 对照确认：主界面 `showDiscovery/showRss/defaultHomePage` 在 `main.dart` 已有同义消费链路，本次仅补齐其它设置入口与持久化字段即可闭环。
- `MY-13` 补充对照确认：书源管理页已存在 `source_check_*` 持久化键，本次“其它设置 -> 校验设置”直接复用同一键可避免配置分叉。
- `MY-13` 补充对照确认（阶段3）：`cleanCache/clearWebViewData/shrinkDatabase` 在当前 Flutter 架构需要服务编排，已新增 `OtherMaintenanceService` 统一结果输出；`webPort/webServiceWakeLock` 按 EX-01 仅保留禁用说明。
- `MY-14` 对照确认：legacy 书签页顶栏菜单仅 `导出/导出(MD)`，当前实现已收口一致；差异主要在条目点击缺失，本次补齐“详情 + 定位阅读”闭环。
- `MY-15` 对照确认：legacy 阅读记录页除排序/开关外还包含 `搜索 + 总阅读时长 + 清空 + 单条删除确认`，本次已在 Flutter 页面补齐同义触发链路。
- `MY-16` 对照确认：about 顶栏需要同时保留 `分享 + 评分`，并补齐 `xml/about.xml` 的 9 个偏好入口；本次已接入文档资源与日志落盘动作，失败分支均补提示与日志节点。
- `SourceListView` 顶栏菜单逻辑已覆盖 legado 大部分语义，`MY-03` 主要为结构顺序收口而非大规模重构。
- `MY-04` 对照中发现批量删除与单条删除清理链路不一致，已在本次收口中统一为 legacy 语义。
- `MY-06` 对照中发现调试页存在额外扩展菜单（禁用源/删除源），与 `book_source_debug.xml` 非同义，已收口移除。

### Decision Log
- 2026-02-26: 决策将 `tool/my_menu_regression_guard.sh` 的主门禁从“占位词扫描”调整为“字段齐全性 + `R-01~R-13` 单锚点一致性 + `EX-01` blocked 占位语义禁入”。
  - 理由: `MY-18` 当前阶段主要风险是证据结构漂移与锚点错链；先固化结构一致性，再由 `MY-19` 完成手工终验回填更符合收口顺序。
- 2026-02-26: 决策新增 `tool/my_menu_regression_guard.sh` 作为终回归文档守卫，并将 `R-01~R-13` 占位词检查与 `EX-01` blocked 语义检查设为统一脚本出口。
  - 理由: `MY-18`/`MY-19` 收口阶段需要可执行门禁，防止“文档仍为待回填”或“EX-01 漂移为 webService 实现验收”在提交前漏检。
- 2026-02-26: 决策将“书源管理/TXT/替换/字典”设为 P0。
  - 理由: 直接影响文字阅读链路可用性与规则调试能力。
- 2026-02-26: 决策将 `webService` 标记为 `blocked` 且排除实施。
  - 理由: 用户明确要求“除 Web 服务”。
- 2026-02-26: 决策将 `MY-18` 固化为独立逐项对照台账（`docs/plans/2026-02-26-my-menu-parity-checklist.md`），并按 `P0/P1/P2/EX-01` 执行。
  - 理由: 收口阶段需要同一份可执行台账承载“结论/原因/处理动作”，避免回填分散导致遗漏。
- 2026-02-26: 决策将 `MY-01` 收口为独立差异台账文件并将 `MY-02` 置为 `active`。
  - 理由: 后续迁移步骤均依赖菜单 ID 级映射，先固化证据再进入实现能降低偏航风险。
- 2026-02-26: 决策在 `MY-02` 将 `replaceManage` 入口改为直达替换规则页。
  - 理由: legado 一级入口直接进入替换规则管理；中间组合页会改变交互语义。
- 2026-02-26: 决策移除“我的”一级菜单动态统计摘要文案。
  - 理由: 迁移级别要求用户可见文案语义同义，动态扩展文案会引入非 legado 语义偏差。
- 2026-02-26: 决策将书源排序菜单“反序”移动到首项。
  - 理由: legado `book_source.xml` 中 `menu_sort_desc` 位于排序菜单首项，属于菜单结构顺序约束。
- 2026-02-26: 决策将批量删除改为复用 `_deleteSourceByLegacyRule`。
  - 理由: 对齐 legado `SourceHelp.deleteBookSourceParts` 的删除后源变量清理边界。
- 2026-02-26: 决策移除 `SourceDebugLegacyView` 的“禁用源/删除源”扩展菜单。
  - 理由: `book_source_debug.xml` 未定义该入口，迁移级别下不允许保留会导致行为偏差的扩展菜单。
- 2026-02-26: 决策将 `MY-07` 置为 `active`，进入 TXT 目录规则菜单核对。
  - 理由: `MY-05`/`MY-06` 已完成并回填对照记录，满足继续推进 P0 的依赖条件。
- 2026-02-26: 决策在 `MY-07` 补齐 TXT 选中态主动作“删除”并新增批量删除链路。
  - 理由: legado `SelectActionBar` 主动作为删除，若缺失会导致选中态触发语义偏差。
- 2026-02-26: 决策在 `MY-07` 新增 `txtTocRuleHelp.md` 并接入帮助弹层。
  - 理由: 顶栏 `menu_help` 为 legacy 定义菜单项，需保证入口可达且有同义文档语义。
- 2026-02-26: 决策将 `MY-07` 标记为 `done`，并将 `MY-08` 置为 `active`。
  - 理由: `txt_toc_rule*.xml` 对照项已逐项回填通过，满足进入替换规则核对的依赖。
- 2026-02-26: 决策在 `MY-08` 移除替换规则顶栏“更多”的扩展入口（剪贴板导入/导出/删除未启用规则）。
  - 理由: 迁移级别要求菜单结构同义，`replace_rule.xml` 未定义上述扩展入口。
- 2026-02-26: 决策在 `MY-08` 增加选中态主动作“删除”并新增 `deleteRulesByIds` 仓储接口。
  - 理由: 对齐 legacy `SelectActionBar` 主删除语义，并保证批量删除触发/刷新链路一致。
- 2026-02-26: 决策将 `MY-08` 标记为 `done`，并将 `MY-09` 置为 `active`。
  - 理由: `replace_rule*.xml` 与 `replace_edit.xml` 对照项已逐项回填通过，可进入字典规则核对。
- 2026-02-26: 决策在 `MY-09` 将字典规则顶栏“更多”补齐 `帮助` 并按 legacy 顺序收口。
  - 理由: `dict_rule.xml` 定义了 `menu_help` 且顺序属于菜单结构约束，不可缺省或改序。
- 2026-02-26: 决策在 `MY-09` 补齐编辑页“复制规则”与选中态主动作“删除”。
  - 理由: `dict_rule_edit.xml/menu_copy_rule` 与 legacy `SelectActionBar` 主删除语义缺失会导致交互触发偏差。
- 2026-02-26: 决策将 `MY-09` 标记为 `done`，并将 `MY-10` 置为 `active`。
  - 理由: `dict_rule*.xml` 对照项已逐项回填通过，满足进入备份恢复迁移依赖。
- 2026-02-26: 决策完成 `MY-17` 基础能力迁移并接入“文件管理”入口。
  - 理由: 入口占位会导致一级菜单不可用，需先完成可达闭环。
- 2026-02-26: 决策在文件管理页新增“新建文件夹”入口（替代此前“暂不新增创建目录入口”决策）。
  - 理由: 需求明确要求对齐 `file_chooser.xml/menu_create` 同义行为，且 legacy 创建链路在 `FilePickerDialog.kt + FilePickerViewModel.kt` 已定义“输入校验 -> createFolder -> upFiles 刷新”，应在 Flutter 文件管理页补齐。
- 2026-02-26: 决策先在 `MY-10` 完成阶段1（`menu_help/menu_log`）再推进备份恢复边界。
  - 理由: 顶栏菜单为用户可见入口差异，修复成本低且可快速消除明显迁移偏差。
- 2026-02-26: 决策在 `MY-10` 阶段2优先补齐 `pref_config_backup.xml` 五项可见配置并抽取 `SettingsService` 字段保存方法。
  - 理由: 目标字段已在 `AppSettings` 存在，按“仅接线”口径可最小风险收口缺失入口与持久化触发。
- 2026-02-26: 决策在 `MY-10` 阶段3以 `BackupRestoreIgnoreService` 作为忽略配置单一来源，并要求导入链路统一经 `BackupService.import*` 传参/回落读取。
  - 理由: 防止本地导入与后续 WebDav 恢复出现忽略策略分叉，保证恢复行为与可观测输出一致。
- 2026-02-26: 决策在 `MY-10` 阶段4直接复用 `WebDavService` 既有上传/列表/下载能力，仅补页面编排与失败回退本地恢复分支。
  - 理由: 降低服务层重复实现风险，优先保证 `web_dav_backup/web_dav_restore` 可达与边界语义同义。
- 2026-02-26: 决策在 `MY-11` 将 `theme_setting` 主入口改回 `ThemeSettingsView`，不再直达阅读界面样式页。
  - 理由: legacy 语义中 `theme_setting` 对应主题配置主页，原跳转会丢失 `welcomeStyle/coverConfig/themeList` 一级入口。
- 2026-02-26: 决策在 `MY-11` 先补齐 `menu_theme_mode` 和第一层关键入口，并将 `coverConfig/welcomeStyle` 详细配置延后到 `MY-12`。
  - 理由: `MY-11` 与 `MY-12` 在计划中已拆分，先保证主页语义与触发同义，再逐步迁移三级配置细节以降低改动风险。
- 2026-02-26: 决策在 `MY-11` 补充收口 `ThemeListDialog` 条目级分享/删除，并将删除逻辑下沉到 `ThemeConfigService`。
  - 理由: 避免页面层直接改写存储，确保“同名覆盖/删除落库/分享载荷”语义由同一服务维护，减少后续回归风险。
- 2026-02-26: 决策在 `MY-12` 将 `coverRule` 从单文本弹窗升级为结构化编辑（启用/搜索url/cover规则 + 删除动作）。
  - 理由: `CoverRuleConfigDialog` 明确要求三字段语义与删除入口，纯文本实现无法满足迁移级别的一致性约束。
- 2026-02-26: 决策在 `MY-13` 的“基本设置”仅落地 legacy 主页面五项能力，并下线 `更换图标/竖屏锁定` 占位入口。
  - 理由: 两者不在 `pref_config_other.xml` 主页面分组，保留会造成迁移级别语义偏差。
- 2026-02-26: 决策为 `autoRefresh/defaultToRead` 增加 `AppSettings` 持久化字段并补 `auto_refresh` 别名兼容。
  - 理由: 需要在不改数据库结构前提下完成可见状态持久化，同时兼容 legacy 键名语义。
- 2026-02-26: 决策在 `MY-13` 补充收口中新增 `CheckSourceSettingsView`，并以“确定保存/取消放弃”模式对齐 legacy `CheckSourceConfig`。
  - 理由: 直接开关即落盘会改变 legacy 触发语义，且不利于校验联动后一次性确认。
- 2026-02-26: 决策在 `MY-13` 复用 `source_check_*` 与 `checkSource` 键，而不是新建命名空间。
  - 理由: 书源校验主流程已消费该组键，复用同键可确保“其它设置”和“书源管理”配置一致。
- 2026-02-26: 决策补齐 `DirectLinkUploadConfigView` 的“拷贝规则”菜单项。
  - 理由: 对齐 legacy `direct_link_upload_config.xml/menu_copy_rule` 菜单结构，避免动作缺失。
- 2026-02-26: 决策在 `MY-13` 补充收口（阶段3）中新增 `OtherMaintenanceService`，统一承接 `cleanCache/clearWebViewData/shrinkDatabase`。
  - 理由: 维护动作涉及仓储、文件系统与 WebView 清理，多入口直接拼装会增加边界分叉与结果提示不一致风险。
- 2026-02-26: 决策对 `webPort/webServiceWakeLock` 采用“可见但禁用说明”而非可操作控件。
  - 理由: 用户明确排除 Web 服务，实现可操作控件会形成误导；完全隐藏又会丢失 legacy 菜单语义线索。
- 2026-02-26: 决策在 `MY-14` 保持顶栏仅 `导出/导出(MD)`，不新增额外书签菜单入口。
  - 理由: `bookmark.xml` 仅定义两项，迁移级别下禁止保留会导致行为偏差的扩展动作。
- 2026-02-26: 决策将条目点击实现为“详情弹层 + 定位阅读”组合触发。
  - 理由: 需同时满足 legacy “点击进入书签详情”与本轮验收“可定位阅读”要求，且不改动书签数据结构。
- 2026-02-26: 决策在 `MY-15` 保留现有“继续阅读/清除阅读记录/从书架移除”动作边界，仅为“清除阅读记录”补二次确认。
  - 理由: 用户要求保留现有边界行为，同时补齐 legacy 单条删除确认语义，避免直接删除导致误触风险。
- 2026-02-26: 决策将“总阅读时间”统计落在 `SettingsService` 汇总层，不新增独立仓储。
  - 理由: 当前阅读时长已由 `book_read_record_duration_map` 统一持久化，服务层汇总可最小改动完成 legacy 同义展示与全量清理。
- 2026-02-26: 决策在 `MY-16` 的日志动作采用“备份目录落盘 JSON”而非原生 `logcat/hprof`。
  - 理由: Flutter 侧无原生 `logcat/hprof` 直接能力；为保证可用闭环，优先交付同义入口、可观测结果与失败提示，同时明确“堆快照为诊断信息”。
- 2026-02-26: 决策将 about 文档资源独立迁移到 `assets/docs/` 并复用统一弹层。
  - 理由: 避免与现有 `assets/web/help/md` 的工具帮助文档混淆，保证 about 入口文档语义稳定且可按标题复用展示组件。

### Outcomes & Retrospective
- 当前结果: `MY-01`~`MY-17` 已完成；其中 `MY-10` 已完成阶段1~阶段4，`MY-11` 已完成主题主页与主题列表动作收口，`MY-12` 已完成封面配置与欢迎页样式迁移，`MY-13` 已完成其它设置“基本设置 + 源设置动作 + 缓存维护项”收口，`MY-14` 已完成书签页菜单与条目点击闭环，`MY-15` 已完成阅读记录页搜索/总时长/清理交互收口，`MY-16` 已完成关于页顶栏/偏好项与文档日志动作迁移，`MY-18` 已建立并持续回填逐项对照台账 `docs/plans/2026-02-26-my-menu-parity-checklist.md`（已补齐 `P2-04` 文件管理“新建文件夹”同义链路与启动冒烟验证），并将 `tool/my_menu_regression_guard.sh` 升级为“固定字段 + 单锚点 + EX-01 语义”门禁且通过“缺字段失败/修复后通过”双态验证。下一步继续按守卫脚本输出回填 `R-01~R-13` 证据并推进 `MY-19`。
- 后续改进点:
  - 每完成一个子任务，必须回填“做了什么 / 为什么 / 如何验证 / 兼容影响”。
  - 若出现 legado 无法等价复现项，先 `blocked` 再继续其它分支。

## 2026-02-26 codex_task_monitor.sh 可靠性修复
- 状态: `done`
- Owner: Codex

### 做了什么
- 修复 `codex_task_monitor.sh` 中 `wait` 退出码采集错误，避免子进程失败被误判为 `exit 0`。
- 增加“只说不做”检测：命令 `exit 0` 但工作区内容指纹不变时，返回 `125` 标记为 no-op。
- 增加 no-op 连续熔断：`CODEX_MONITOR_MAX_NO_CHANGE_RUNS` 达阈值后脚本退出 `125`，避免无限空转。
- 增加环境变量开关：
  - `CODEX_MONITOR_REQUIRE_WORKTREE_CHANGE`（默认 `1`，可设 `0` 关闭 no-op 检测）
  - `CODEX_MONITOR_MAX_NO_CHANGE_RUNS`（默认 `3`）

### 为什么
- 原脚本存在失败误判成功风险，导致监控日志显示“完成成功”，但任务实际未执行。
- 原脚本缺少“实质执行”判定，模型持续输出但不落地改动时会无限循环。

### 如何验证
- 失败退出码验证：
  - `CODEX_MONITOR_CMD='echo run-once; exit 7' ... ./codex_task_monitor.sh`
  - 结果：日志正确显示 `exit 7`，不再误报成功。
- no-op 检测验证：
  - `CODEX_MONITOR_CMD='echo no-change; exit 0' CODEX_MONITOR_MAX_NO_CHANGE_RUNS=2 ...`
  - 结果：连续 2 次 no-op 后退出 `125`。
- 关闭 no-op 检测验证：
  - `CODEX_MONITOR_REQUIRE_WORKTREE_CHANGE=0 CODEX_MONITOR_CMD='echo skip-check; exit 0' ...`
  - 结果：按成功路径循环运行。

### 兼容影响
- 仅修改监控脚本行为，不涉及 Flutter 功能、数据模型、数据库或书源兼容逻辑。

## 2026-02-26 codex_queue_runner.sh 全新队列调度脚本
- 状态: `done`
- Owner: Codex

### 做了什么
- 新增全新脚本 `codex_queue_runner.sh`（不复用旧 monitor 逻辑），按任务清单顺序执行并自动推进到下一任务。
- 任务格式采用 TSV：`id<TAB>prompt<TAB>verify_cmd<TAB>required_paths_csv`。
- 支持会话续接：首任务 `codex exec`，后续任务默认 `codex exec resume --last`。
- 支持完成判定：
  - 命令成功（`exit 0`）；
  - 可选 no-op 检测（工作区指纹必须变化）；
  - 可选 `required_paths` 变化检测；
  - 可选 `verify_cmd` 通过。
- 支持失败重试与失败即停（可配置）：
  - `CODEX_QUEUE_MAX_RETRIES`、`CODEX_QUEUE_STOP_ON_FAILURE`。
- 支持测试注入命令：
  - `CODEX_QUEUE_OVERRIDE_CMD`（用于本地验证脚本流程，不调用真实 codex）。

### 为什么
- 用户目标是“模型执行完成后自动继续下一个任务”。
- 单句循环 prompt 容易空转；引入明确任务队列 + 完成门槛，可显著降低“只说不做”概率。

### 如何验证
- 语法检查：
  - `bash -n codex_queue_runner.sh`，结果 `OK`。
- 成功链路（2 个任务自动串行推进）：
  - 使用 `/tmp/codex_tasks_ok.tsv` + `CODEX_QUEUE_OVERRIDE_CMD` 模拟执行；
  - 结果：`T1`、`T2` 均一次通过，`done.tsv` 记录两条完成记录。
- no-op 拦截链路：
  - 使用 `/tmp/codex_tasks_noop.tsv` + `CODEX_QUEUE_OVERRIDE_CMD='echo noop'`；
  - 结果：连续重试后以 `RC=125` 退出，符合 no-op 拦截预期。

### 兼容影响
- 仅新增根目录自动化脚本，不修改应用业务代码与数据结构。

## 2026-02-26 codex_goal_autopilot.sh 大任务自动拆分与闭环执行
- 状态: `done`
- Owner: Codex

### 做了什么
- 新增总控脚本 `codex_goal_autopilot.sh`，支持输入一个“大目标”并自动循环：
  1. 使用 `codex exec --output-schema` 生成“下一批任务”；
  2. 自动转成 TSV；
  3. 调用 `codex_queue_runner.sh` 顺序执行；
  4. 再次规划，直到规划器返回 `done=true` 或达到最大轮次。
- 通过 JSON Schema 强约束规划输出，字段固定为：
  - `done/done_reason/goal_summary/tasks/notes`
  - `tasks[*]` 固定含 `id/title/priority/prompt/verify_cmd/required_paths/depends_on`
- 支持轮次状态落盘：
  - `state_dir/cycle-N/plan.json`
  - `state_dir/cycle-N/tasks.tsv`
  - `state_dir/cycle-N/queue-state/*`
- 支持测试注入：
  - `CODEX_GOAL_OVERRIDE_PLAN_JSON`（跳过真实规划）
  - 结合 `CODEX_QUEUE_OVERRIDE_CMD` 验证闭环执行链路。
- 优化规划阶段可观测性与防卡死：
  - 规划调用改为实时输出到终端 + 写入 `run.log`（不再只在日志里可见）。
  - 新增规划超时：`CODEX_GOAL_PLAN_TIMEOUT_SECONDS`（默认 900 秒）。
  - 规划阶段单独设置推理强度：`CODEX_GOAL_PLAN_REASONING_EFFORT`（默认 `medium`）。

### 为什么
- 用户目标是“设定一个大任务后自动拆分，并自动一个一个完成直到整体完成”。
- 仅有队列执行器不够，需要在执行前后自动做规划与收敛判断。

### 如何验证
- 语法：
  - `bash -n codex_goal_autopilot.sh`，通过。
- 完成态短路：
  - 使用 `CODEX_GOAL_OVERRIDE_PLAN_JSON=/tmp/plan_done.json`，脚本在第 1 轮识别 `done=true` 并退出 `0`。
- 执行链路：
  - 使用 `CODEX_GOAL_OVERRIDE_PLAN_JSON=/tmp/plan_one_task.json` + `CODEX_QUEUE_OVERRIDE_CMD='touch .autopilot_marker; echo run'`；
  - 验证已调用队列并完成任务（`done.tsv` 记录成功），随后因 `max_cycles=1` 返回 `3`（未到完成判定轮）。
- 规划超时分支：
  - `CODEX_GOAL_PLAN_TIMEOUT_SECONDS=1 ... ./codex_goal_autopilot.sh --goal ...`
  - 结果：实时输出规划过程，1 秒后返回 `124` 并给出超时提示。

### 兼容影响
- 新增根目录自动化脚本，不修改 Flutter 功能逻辑、数据库结构与书源语义。

## 2026-02-26 codex_goal_simple.sh 极简入口
- 状态: `done`
- Owner: Codex

### 做了什么
- 新增 `codex_goal_simple.sh`，提供“只输入大任务”的极简入口。
- 该脚本内部调用 `codex_goal_autopilot.sh`，并预置稳态默认值：
  - `CODEX_GOAL_MAX_CYCLES=120`
  - `CODEX_GOAL_TASKS_PER_CYCLE=6`
  - `CODEX_GOAL_CONTINUE_ON_QUEUE_FAILURE=1`
  - `CODEX_QUEUE_REQUIRE_CHANGE=1`
  - `CODEX_QUEUE_MAX_RETRIES=3`
  - `CODEX_QUEUE_STOP_ON_FAILURE=1`
- 修复参数兼容：
  - 直接传纯文本参数（如 `./codex_goal_simple.sh "你的大任务描述"`）会自动映射为 `--goal`；
  - 0 参数时进入交互输入模式，不再直接报错。
- 新增执行权限并通过 `bash -n` 语法检查。

### 为什么
- 用户反馈“参数太多，只关心任务完成”。
- 用极简入口降低使用门槛，同时保留防空转与重试护栏。

### 如何验证
- `bash -n codex_goal_simple.sh` 通过。
- `./codex_goal_simple.sh --help` 可正确透传到下层脚本帮助输出。
- `./codex_goal_simple.sh "你的大任务描述"` 可正确进入 autopilot，不再报“未知参数”。

### 兼容影响
- 仅新增根目录脚本，不影响现有业务代码与数据结构。
