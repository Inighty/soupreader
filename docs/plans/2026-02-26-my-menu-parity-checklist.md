# 2026-02-26 我的菜单同义核对清单（唯一基线）

- 状态: `active`
- 基线来源:
  - `docs/plans/2026-02-26-my-menu-id-diff.md`
  - `../legado/app/src/main/res/xml/pref_main.xml`
  - `../legado/app/src/main/res/menu/main_my.xml`
- 使用规则:
  - 后续实现任务仅以本清单和 ID 台账为准。
  - 未完成本清单逐项回填前，不得使用“完全一致/已一致”结论。

## 0. 跨台账状态对齐（2026-02-27，基于当前代码复扫）

- `D-03=done`（5 个子项代码证据已回填）
- `D-04=done`（`D-03` 前置依赖已满足并收口；`pref_config_other` non-Web 键已接线闭环（含 `updateToVariant`，口径以 legado 四值 `default/official/beta_release/beta_releaseA` 为准），Web 区仅只读回显且无可操作入口）
- `N-01~N-04=done`（大标题导航实现已完成）
- `N-VAL-01=blocked`（owner: `UI-NAV`；依赖: `C6-T01` 证据终态（`R-N01~R-N04`）；状态定义：证据终态为 `blocked`，待可交互环境回补后再收口）
- `NAV-DIFF-01=done`（`RssSubscriptionView` 空态 `noEnabled` 分支按钮语义已对齐 `_openSourceSettings`，不再作为 `N-03` / `N-VAL-01` 前置阻塞）
- `EX-01=blocked`
- 串行依赖固定：`D-03 -> D-04`
- 说明：`D-03` 已完成“入口可操作 + 保存接口调用 + 页面回显”代码闭环；`D-04` 已收口完成：`updateToVariant` 以 legado 四值 `default/official/beta_release/beta_releaseA` 为准，Web 区为只读回显且无操作入口；`N-01~N-04` 已完成大标题导航实现；`NAV-DIFF-01` 已修复完成，不再作为前置差异；`N-VAL-01` 当前按 `C6-T01` 证据终态标记为 `blocked`，待可交互环境回补后再收口；`EX-01` 仅占位，不进入 `WebService` 运行态实现。

## 1. 执行顺序（核心项串行依赖）

1. 本轮核心差异项复扫结论：`D-04` 已完成收口，当前不再存在代码层剩余项（`D-03` 仅保留已完成证据记录）。
2. `D-01`、`D-02`、`D-05` 已接通，状态统一为 `A-已接通（待终验）`，不再进入“回补实现”分支。
3. 复扫状态（2026-02-27，基于当前代码）：`D-03=done`（主题底层 5 子项代码链路闭环并已回填证据）；`D-04=done`（`updateToVariant` 以 legado 四值 `default/official/beta_release/beta_releaseA` 为准；Web 区只读回显无入口）。
4. 串行顺序保持 `D-03 -> D-04`；当前两项均已收口完成。
5. `D-04` 当前剩余项：`无`（仅维持 `EX-01 blocked` 项目边界，不扩展为运行态实现）。
6. 串行：`N-VAL-01` 证据终态当前为 `blocked`（依据 `C6-T01`），待可交互环境完成回补后再收口（含 `D-01`、`D-02`、`D-05` 终验）。
7. 全程保持 `EX-01 blocked`，仅占位，不进 WebService 运行态实现。

## 2. 一级入口核对清单（`my_menu_*` 14 项）

| # | `my_menu_*` | legacy key | 一级入口验收口径 | 关键二级链路验收口径 | 当前判定 | 后续动作 |
|---|---|---|---|---|---|---|
| 1 | `my_menu_bookSourceManage` | `bookSourceManage` | 顺序、标题、可达性同义 | `book_source.xml` + `book_source_sel.xml` 动作可达 | `A-已接通` | 终验回归 |
| 2 | `my_menu_txtTocRuleManage` | `txtTocRuleManage` | 顺序、标题、可达性同义 | `txt_toc_rule.xml` + `txt_toc_rule_sel.xml` 动作可达 | `A-已接通` | 终验回归 |
| 3 | `my_menu_replaceManage` | `replaceManage` | 顺序、标题、可达性同义 | `replace_rule.xml` + `replace_rule_sel.xml` 动作可达 | `A-已接通` | 终验回归 |
| 4 | `my_menu_dictRuleManage` | `dictRuleManage` | 顺序、标题、可达性同义 | `dict_rule.xml` + `dict_rule_sel.xml` 动作可达 | `A-已接通` | 终验回归 |
| 5 | `my_menu_themeMode` | `themeMode` | 主题模式入口同义 | `themeMode` 单入口；值域/状态流转/持久化同义（含 `E-Ink(3)`） | `A-已接通（D-01）` | 待终验 |
| 6 | `my_menu_webService` | `webService` | 保留入口但不误导 | 不进入服务实现，仅占位提示 | `EX-01 blocked` | 仅占位验证（不进入 webService 实现） |
| 7 | `my_menu_web_dav_setting` | `web_dav_setting` | 入口同义 | `backup_restore` 页面关键动作同义：help/log + `web_dav_restore` 点击云端/长按本地 + `import_old` | `A-已接通（D-02）` | 待终验 |
| 8 | `my_menu_theme_setting` | `theme_setting` | 入口同义 | `theme_config` 底层主题项与持久化回显同义（含背景图/模糊度/日夜主题保存） | `D-03=done` | 收口完成，转入 `D-04` |
| 9 | `my_menu_setting` | `setting` | 入口同义 | `pref_config_other` 全量键同义（Web 仅按 `EX-01` 保持边界） | `D-04=done` | 进入终验回归 |
| 10 | `my_menu_bookmark` | `bookmark` | 入口同义 | `bookmark.xml` 导出链路同义 | `A-已接通` | 终验回归 |
| 11 | `my_menu_readRecord` | `readRecord` | 入口同义 | `book_read_record.xml` 排序/记录开关同义 | `A-已接通` | 终验回归 |
| 12 | `my_menu_fileManage` | `fileManage` | 入口同义 | `file_long_click.xml` 长按删除链路同义 | `A-已接通` | 终验回归 |
| 13 | `my_menu_about` | `about` | 入口同义 | `about.xml(menu+xml)` 入口链路同义 | `A-已接通` | 终验回归 |
| 14 | `my_menu_exit` | `exit` | 入口同义 | 退出触发语义与边界处理同义 | `A-已接通（D-05）` | 待终验 |

## 3. 状态锚点（当前实现复核）

### 3.1 已接通待终验（不进入本轮回补）

### D-01（`themeMode`）
- 当前判定: `A-已接通（待终验）`
- 复核结论:
  1. `settings_view.dart` 的 `_pickThemeMode` 已承接 `0/1/2/3` 四值（含 `E-Ink`）并持久化写入。
  2. `theme_settings_view.dart`、`appearance_settings_view.dart`、`theme_config_list_view.dart` 均改为提示“到我的-主题模式切换”，不再并行写 `appearanceMode`。
- 终验重点:
  1. 四值切换后的摘要展示、重启回显与备份恢复回显保持一致。
  2. 不出现隐式降级到三态的回退路径。

### D-02（`web_dav_setting`）
- 当前判定: `A-已接通（待终验）`
- 复核结论:
  1. `backup_settings_view.dart` 已提供 `help/log` 顶栏动作。
  2. `web_dav_restore` 已对齐“点击云端恢复 + 长按本地恢复”双语义。
  3. `import_old` 独立入口与旧版目录导入链路已接通。
- 终验重点:
  1. WebDav 成功/失败场景下，双语义入口与兜底提示一致。
  2. 旧版导入的成功/失败提示与计数回显一致。

### D-05（`exit`）
- 当前判定: `A-已接通（待终验）`
- 复核结论:
  1. `my_menu_exit` 维持“点击即退出”，当前实现为 `SystemNavigator.pop()` 且无确认分支。
- 终验重点:
  1. 与 legacy `activity?.finish()` 的生命周期边界（前后台、返回栈）同义。

### 3.2 差异项状态（`D-03`、`D-04` 已闭环）

### D-03（`theme_setting`）
- 当前判定: `done`（代码链路闭环已完成）
- 闭环结论:
  1. `theme_settings_view.dart` 已提供“保存白天主题/保存夜间主题”入口与命名弹窗，并调用 `ThemeConfigService.saveCurrentTheme`。
  2. `appearance_settings_view.dart` 已接通“白天/夜间背景图、白天/夜间模糊度”入口；背景图支持“选择图片/清空”，模糊度支持范围校验与默认值恢复。
  3. `settings_service.dart` 与 `app_settings.dart` 已完成相关字段的持久化写入、序列化、启动加载与 `appSettingsListenable` 回推，页面可回显。
- D-03 5 子项证据（入口可操作 + 保存接口调用 + 页面回显）:

| D-03 子项 | legacy 锚点 | 页面入口（可操作） | 保存接口调用（代码锚点） | 页面回显（代码锚点） | 当前结论 |
|---|---|---|---|---|---|
| 白天背景图 | `pref_config_theme.xml:104-106`；`ThemeConfigFragment.kt:197`、`ThemeConfigFragment.kt:238-274`、`ThemeConfigFragment.kt:339-352` | `theme_settings_view.dart:360-365`（进入外观页）+ `appearance_settings_view.dart:518-525`（白天背景图入口），动作面板在 `appearance_settings_view.dart:215-248`（选择/清空） | `appearance_settings_view.dart:259-272` 调用 `SettingsService.saveBackgroundImage`；实现位于 `settings_service.dart:1279-1283` | `appearance_settings_view.dart:39-51`（监听）+ `518-522`（行摘要）；`theme_settings_view.dart:284-297`（汇总摘要）；持久化写入与重启加载链路：`settings_service.dart:1144-1156`、`settings_service.dart:228-260`、`app_settings.dart:524-529`、`app_settings.dart:662-665` | `done` |
| 夜间背景图 | `pref_config_theme.xml:158-160`；`ThemeConfigFragment.kt:198`、`ThemeConfigFragment.kt:238-274`、`ThemeConfigFragment.kt:339-352` | `theme_settings_view.dart:360-365`（进入外观页）+ `appearance_settings_view.dart:535-541`（夜间背景图入口），动作面板在 `appearance_settings_view.dart:215-248`（选择/清空） | `appearance_settings_view.dart:259-272` 调用 `SettingsService.saveBackgroundImageNight`；实现位于 `settings_service.dart:1286-1290` | `appearance_settings_view.dart:39-51`（监听）+ `535-538`（行摘要）；`theme_settings_view.dart:284-297`（汇总摘要）；持久化写入与重启加载链路：`settings_service.dart:1144-1156`、`settings_service.dart:228-260`、`app_settings.dart:530-535`、`app_settings.dart:662-665` | `done` |
| 白天背景模糊度 | `ThemeConfigFragment.kt:240`、`ThemeConfigFragment.kt:250`、`ThemeConfigFragment.kt:276-301` | `appearance_settings_view.dart:527-533`（白天模糊度入口）+ `appearance_settings_view.dart:334-357`（输入、范围校验、默认恢复） | `appearance_settings_view.dart:360-368` 调用 `SettingsService.saveBackgroundImageBlurring`；实现位于 `settings_service.dart:1293-1296` | `appearance_settings_view.dart:39-51`（监听）+ `527-530`（数值行回显）；`theme_settings_view.dart:295-296`（汇总摘要）；持久化与重启加载：`settings_service.dart:1144-1156`、`settings_service.dart:228-260`、`app_settings.dart:536-542`、`app_settings.dart:664-665` | `done` |
| 夜间背景模糊度 | `ThemeConfigFragment.kt:240`、`ThemeConfigFragment.kt:250`、`ThemeConfigFragment.kt:276-301` | `appearance_settings_view.dart:543-549`（夜间模糊度入口）+ `appearance_settings_view.dart:334-357`（输入、范围校验、默认恢复） | `appearance_settings_view.dart:360-366` 调用 `SettingsService.saveBackgroundImageNightBlurring`；实现位于 `settings_service.dart:1299-1302` | `appearance_settings_view.dart:39-51`（监听）+ `543-546`（数值行回显）；`theme_settings_view.dart:295-296`（汇总摘要）；持久化与重启加载：`settings_service.dart:1144-1156`、`settings_service.dart:228-260`、`app_settings.dart:543-549`、`app_settings.dart:664-665` | `done` |
| 主题保存入口（日/夜） | `pref_config_theme.xml:108-114`、`pref_config_theme.xml:162-168`；`ThemeConfigFragment.kt:200-201`、`ThemeConfigFragment.kt:215-236` | `theme_settings_view.dart:343-354`（保存白天/夜间主题入口）+ `theme_settings_view.dart:99-130`（命名输入与取消/保存操作） | `theme_settings_view.dart:62-97` 调用 `ThemeConfigService.saveCurrentTheme`；实现位于 `theme_config_service.dart:43-64`、`theme_config_service.dart:66-77`、`theme_config_service.dart:95-97` | `theme_config_list_view.dart:30-35`（进入页面触发 `_reloadConfigs`）+ `theme_config_list_view.dart:51-57`（加载列表）+ `theme_config_list_view.dart:189-190`（主题名/日夜标记回显，标记逻辑 `theme_config_list_view.dart:131-137`） | `done` |
- 本轮 owner 与落地文件:
  - owner: `MY-22`
  - 目标文件: `lib/features/settings/views/theme_settings_view.dart`
  - 目标文件: `lib/features/settings/views/appearance_settings_view.dart`
  - 目标文件: `lib/features/settings/views/theme_config_list_view.dart`
  - 目标文件: `lib/features/settings/services/theme_config_service.dart`
  - 目标文件: `lib/features/settings/models/theme_config_entry.dart`
  - 目标文件: `lib/core/models/app_settings.dart`
  - 目标文件: `lib/core/services/settings_service.dart`
  - legacy 锚点: `../legado/app/src/main/res/xml/pref_config_theme.xml:5-170`、`../legado/app/src/main/res/xml/pref_config_theme.xml:104-114`、`../legado/app/src/main/res/xml/pref_config_theme.xml:158-168`、`../legado/app/src/main/res/menu/theme_config.xml:5-8`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:74`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:166`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:197-201`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:215-236`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:238-301`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:339-352`
- 阻塞边界:
  - `D-03` 前置已闭环，`D-04` 已解除 `blocked` 依赖并按序收口为 `done`。
  - 本项只覆盖 `theme_setting`，不并入 `pref_config_other` / Web 服务需求。

### D-04（`setting`）
- 当前实现状态:
  1. 当前执行状态 `done`：`D-03 -> D-04` 串行依赖已满足并完成收口。
  2. `other_settings_view.dart` 已覆盖基本/源设置/缓存维护/调试分组，并保留 `非 Web 其它设置` 分组。
  3. non-Web 9 键（8 个布尔开关 + `updateToVariant`）均具备“可配置 + 持久化 + 回显”闭环。
  4. Web 区为只读回显：`webPort/webServiceWakeLock` 仅展示“未启用（当前值）”，无 `onTap`、无编辑入口，按 `EX-01` 保持边界。
- D-04 对照清单（2026-02-27，11 键）:

| 键 | 分类 | 当前状态 | 证据与差异 |
|---|---|---|---|
| `cronet` | non-Web | `已实现` | `other_settings_view.dart:531-536` 已提供开关并绑定 `_settingsService.saveCronet`；`settings_service.dart:1227-1231` 完成持久化写入。 |
| `antiAlias` | non-Web | `已实现` | `other_settings_view.dart:537-542` 已提供开关并绑定 `_settingsService.saveAntiAlias`；`settings_service.dart:1233-1237` 完成持久化写入。 |
| `mediaButtonOnExit` | non-Web | `已实现` | `other_settings_view.dart:543-548` 已提供开关并绑定 `_settingsService.saveMediaButtonOnExit`；`settings_service.dart:1239-1243` 完成持久化写入。 |
| `readAloudByMediaButton` | non-Web | `已实现` | `other_settings_view.dart:549-554` 已提供开关并绑定 `_settingsService.saveReadAloudByMediaButton`；`settings_service.dart:1245-1249` 完成持久化写入。 |
| `ignoreAudioFocus` | non-Web | `已实现` | `other_settings_view.dart:555-560` 已提供开关并绑定 `_settingsService.saveIgnoreAudioFocus`；`settings_service.dart:1251-1255` 完成持久化写入。 |
| `autoClearExpired` | non-Web | `已实现` | `other_settings_view.dart:561-566` 已提供开关并绑定 `_settingsService.saveAutoClearExpired`；`settings_service.dart:1257-1261` 完成持久化写入。 |
| `showAddToShelfAlert` | non-Web | `已实现` | `other_settings_view.dart:567-572` 已提供开关并绑定 `_settingsService.saveShowAddToShelfAlert`；`settings_service.dart:1263-1267` 完成持久化写入。 |
| `updateToVariant` | non-Web | `已实现（legado 四值同义）` | `other_settings_view.dart:232-286` 提供四值 ActionSheet（`default_version`、`official_version`、`beta_release_version`、`beta_releaseA_version`），并在 `other_settings_view.dart:629-638` 提供入口与回显；值域常量见 `app_settings.dart:183-191`；保存调用 `settings_service.dart:1277-1283`，归一化逻辑见 `settings_service.dart:296-330`。 |
| `showMangaUi` | non-Web | `已实现` | `other_settings_view.dart:573-577` 已提供开关并绑定 `_settingsService.saveShowMangaUi`；`settings_service.dart:1281-1284` 完成持久化写入。 |
| `webPort` | Web 边界键 | `已实现（只读回显）` | `other_settings_view.dart:647-653` 仅展示“Web 端口 / 未启用（当前值）”；无 `onTap`、无编辑控件，符合“仅只读回显”。 |
| `webServiceWakeLock` | Web 边界键 | `已实现（只读回显）` | `other_settings_view.dart:647-659` 仅展示“WebService 唤醒锁 / 未启用（当前值）”；无 `onTap`、无编辑控件，符合“仅只读回显”。 |

- `updateToVariant` legado 四值锚点补充:
  - 定义入口：`../legado/app/src/main/res/xml/pref_config_other.xml:161-169`（`NameListPreference`，`defaultValue=default_version`）。
  - 值域锚点：`../legado/app/src/main/res/values/arrays.xml:170-174`，对照值为 `default_version`、`official_version`、`beta_release_version`、`beta_releaseA_version`。
  - 映射锚点：`../legado/app/src/main/java/io/legado/app/help/update/AppUpdateGitHub.kt:20-23`（四值输入映射到更新通道筛选；`default_version` 回落当前安装变体）。
- 收口结果:
  1. non-Web 键“可配置 + 持久化 + 回显”闭环保持稳定，`updateToVariant` 值域与 legacy 同义。
  2. `webPort/webServiceWakeLock` 仅保留只读语义锚点与当前值回显，无可操作入口。
  3. `D-04` 当前剩余项为 `无`；继续遵循 `EX-01`，不实现 Web 运行态能力。
- 本轮 owner 与落地文件:
  - owner: `MY-23`
  - 目标文件: `lib/features/settings/views/other_settings_view.dart`
  - 目标文件: `lib/core/models/app_settings.dart`
  - 目标文件: `lib/core/services/settings_service.dart`
  - legacy 锚点: `../legado/app/src/main/res/xml/pref_config_other.xml:62-226`、`../legado/app/src/main/res/xml/pref_config_other.xml:73`、`../legado/app/src/main/res/xml/pref_config_other.xml:178`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:60`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:88`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:114`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:175`、`../legado/app/src/main/java/io/legado/app/service/WebService.kt:62`
- 阻塞边界:
  - 本项不再受 `D-03` 前置阻塞；串行顺序 `D-03 -> D-04` 已按序完成并收口。
  - 本项严格遵循 `EX-01 blocked`，不得接线 Web 服务启停、地址摘要、端口重启。
  - 仅允许记录与展示 Web 相关键语义，不接入运行时生效链路。
- 前置解除依据（2026-02-27）:
  1. `D-03` 映射表中的 5 个子项已全部回填“页面入口可操作 + 保存接口实际调用 + 页面回显”代码证据。
  2. 背景图与模糊度链路已具备跨生命周期持久化条件：`settings_service.dart` 统一写入 `_keyAppSettings`（`1144-1156`）并在启动时回读（`228-260`）。
  3. 日/夜主题保存入口已接线并支持命名保存，`theme_config_list_view.dart` 可回显新增主题与日/夜标记。
  4. 本台账已完成 `D-03` 代码证据回填，`D-04` 不再以“依赖 `D-03`”作为 `blocked` 前置描述。

## 4. 关键二级链路核对矩阵

| 模块 | legacy 关键文件 | 必核对动作 | 当前判定 |
|---|---|---|---|
| 书源管理 | `book_source.xml` `book_source_sel.xml` | 排序/分组/导入/帮助/批量动作 | `A-已接通` |
| TXT目录规则 | `txt_toc_rule.xml` `txt_toc_rule_sel.xml` | 新建/导入/帮助/批量启停与导出 | `A-已接通` |
| 替换规则 | `replace_rule.xml` `replace_rule_sel.xml` | 分组/导入/帮助/批量启停与置顶置底导出 | `A-已接通` |
| 字典规则 | `dict_rule.xml` `dict_rule_sel.xml` | 新建/导入默认与多源导入/帮助/批量导出 | `A-已接通` |
| 备份恢复 | `pref_config_backup.xml` `backup_restore.xml` | WebDav 配置 + `web_dav_restore` 点击云端/长按本地 + `import_old` 独立入口 + 失败回退链路 | `A-已接通（D-02 待终验）` |
| 主题设置 | `pref_config_theme.xml` `theme_config.xml` | `barElevation/fontScale/背景图/日夜主题保存` 等主题底层项 | `D-03` |
| 其它设置 | `pref_config_other.xml` | 基本/源设置/缓存维护/调试全量键；Web 服务仅记录边界（`webPort/webServiceWakeLock`），本轮不实现运行态 | `D-04（done；Web 区只读回显且无入口）` |
| 书签 | `bookmark.xml` | 导出 JSON/MD | `A-已接通` |
| 阅读记录 | `book_read_record.xml` | 排序三态 + 开启记录 | `A-已接通` |
| 关于 | `about.xml(menu)` `about.xml(xml)` | 分享/评分 + about 列表入口 | `A-已接通` |
| 文件管理 | `file_long_click.xml` | 长按删除与状态刷新 | `A-已接通` |

## 5. blocked 记录（AGENTS 1.1.2）

### EX-01（Web服务）
- 状态: `blocked`
- 执行结论: `仅占位，不实现`（本轮仅占位，不进 WebService 运行态实现）。
- 原因: 当前未具备 legacy 同义的服务启停、地址摘要与长按地址动作能力。
- 执行边界: `仅占位验证，不进入 webService 实现。`
- 执行边界补充: `D-04` 中仅保留 `webPort/webServiceWakeLock` 的 legacy 锚点记录，不接入端口修改触发服务重启链路。
- 排除项（本轮禁止实现）:
  1. `WebService.start/stop` 运行态接线与开关联动。
  2. 运行地址摘要展示与长按“复制地址/浏览器打开”。
  3. `webPort` 可编辑并触发服务重启。
  4. `webServiceWakeLock` 的持久化生效链路。
- 影响范围:
  - 一级入口 `my_menu_webService`。
  - Web 相关配置项无法形成完整运行闭环。
- 替代方案: 保留入口和“范围外”提示，不暴露伪可用能力。
- 回补计划:
  1. 建立 Web 服务运行态与地址态模型。
  2. 对齐开关启停与摘要文案。
  3. 对齐长按“复制地址/浏览器打开”。
  4. 完成回归证据后解除 `blocked`。

## 6. 交付验收门槛（给后续实现任务）

1. 14 个 `my_menu_*` 均有结论（`A` / `D` / `blocked`），不得留空。
2. 所有 `D-*` 项必须带可执行回补动作与回归路径。
3. `EX-01` 必须保持 `blocked`，直到需求方明确解锁。
4. `D-03 -> D-04` 必须按序完成；`D-01`、`D-02`、`D-05` 仅进入终验回归，不再作为回补实现链路。
5. 终验阶段需回填手工回归证据，再执行提交前检查。
