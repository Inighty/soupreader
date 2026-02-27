# 2026-02-26 我的菜单 ID 差异台账（迁移前置）

- 状态: `active`
- 任务口径: 仅记录差异，不在本任务实现功能。
- 用途: 后续实现任务唯一基线（一级入口 + 关键二级链路 + `EX-01`）。

## 1. legado 对照基线（本次已完整读取）

### 1.1 一级入口与顶栏
- `../legado/app/src/main/res/xml/pref_main.xml`
- `../legado/app/src/main/res/menu/main_my.xml`
- `../legado/app/src/main/java/io/legado/app/ui/main/my/MyFragment.kt`

### 1.2 关键二级链路（my 菜单直达）
- `../legado/app/src/main/res/menu/book_source.xml`
- `../legado/app/src/main/res/menu/book_source_sel.xml`
- `../legado/app/src/main/res/menu/txt_toc_rule.xml`
- `../legado/app/src/main/res/menu/txt_toc_rule_sel.xml`
- `../legado/app/src/main/res/menu/replace_rule.xml`
- `../legado/app/src/main/res/menu/replace_rule_sel.xml`
- `../legado/app/src/main/res/menu/dict_rule.xml`
- `../legado/app/src/main/res/menu/dict_rule_sel.xml`
- `../legado/app/src/main/res/menu/bookmark.xml`
- `../legado/app/src/main/res/menu/book_read_record.xml`
- `../legado/app/src/main/res/menu/about.xml`
- `../legado/app/src/main/res/xml/about.xml`
- `../legado/app/src/main/res/menu/file_long_click.xml`
- `../legado/app/src/main/res/xml/pref_config_backup.xml`
- `../legado/app/src/main/res/menu/backup_restore.xml`
- `../legado/app/src/main/res/xml/pref_config_theme.xml`
- `../legado/app/src/main/res/menu/theme_config.xml`
- `../legado/app/src/main/res/xml/pref_config_other.xml`

## 2. 顶栏 main_my 对照

| legacy | legado 行为 | soupreader 行为 | 判定 |
|---|---|---|---|
| `menu_help` | `main_my.xml` + `MyFragment.kt` 打开 `appHelp` | `settings_view.dart` 顶栏问号按钮打开 `appHelp.md` | `A-已接通` |

## 3. 一级入口 + 关键二级链路差异台账（14 项）

判定说明:
- `A-已接通`: 已找到同义入口和关键二级链路，不代表终验已完成。
- `D-有差异`: 已确认存在语义/链路差异，后续实现需回补。
- `blocked`: 当前无法等价，按例外流程冻结。

| # | `my_menu_*` | legacy key | legado 关键二级链路 | soupreader 当前链路 | 判定 | 差异 ID / 备注 |
|---|---|---|---|---|---|---|
| 1 | `my_menu_bookSourceManage` | `bookSourceManage` | `MyFragment.kt` -> `BookSourceActivity` -> `book_source.xml` + `book_source_sel.xml` | `settings_view.dart` -> `SourceListView`（含排序/分组/导入/帮助/批量动作） | `A-已接通` | 结构未见台账级缺口，留终验回归 |
| 2 | `my_menu_txtTocRuleManage` | `txtTocRuleManage` | `TxtTocRuleActivity` -> `txt_toc_rule.xml` + `txt_toc_rule_sel.xml` | `settings_view.dart` -> `TxtTocRuleManageView`（含导入默认/本地/网络/二维码/帮助/批量） | `A-已接通` | 结构未见台账级缺口，留终验回归 |
| 3 | `my_menu_replaceManage` | `replaceManage` | `ReplaceRuleActivity` -> `replace_rule.xml` + `replace_rule_sel.xml` | `settings_view.dart` -> `ReplaceRuleListView`（含分组/导入/帮助/批量） | `A-已接通` | 结构未见台账级缺口，留终验回归 |
| 4 | `my_menu_dictRuleManage` | `dictRuleManage` | `DictRuleActivity` -> `dict_rule.xml` + `dict_rule_sel.xml` | `settings_view.dart` -> `DictRuleManageView`（含导入默认/本地/网络/二维码/帮助/批量） | `A-已接通` | 结构未见台账级缺口，留终验回归 |
| 5 | `my_menu_themeMode` | `themeMode` | `pref_main.xml:35-43` `NameListPreference`（单一入口），值映射见 `arrays.xml:50-55` + `array_values.xml:22-27`（`0/1/2/3`）；变更监听见 `MyFragment.kt:105-110`，统一走 `ThemeConfig.applyDayNight` | `settings_view.dart` 的 `_pickThemeMode` 已承接四值（含 `E-Ink`）；`theme_settings_view.dart` 顶栏、`appearance_settings_view.dart` 外观开关、`theme_config_list_view.dart` 主题应用已改为提示“到我的-主题模式操作”，不再并行写 `appearanceMode` | `A-已接通` | `D-01`：已接通，保留终验回归（四值展示/持久化/回显） |
| 6 | `my_menu_webService` | `webService` | 开关控制 `WebService.start/stop`，运行态显示地址，长按可“复制地址/浏览器打开” | 入口存在，但为“本轮未实现”占位提示 | `blocked` | `EX-01` |
| 7 | `my_menu_web_dav_setting` | `web_dav_setting` | `ConfigTag.BACKUP_CONFIG` -> `pref_config_backup.xml:84,95`（`web_dav_restore` + `import_old`）；`backup_restore.xml:7-16` 提供 `menu_help/menu_log` 顶栏菜单；`BackupConfigFragment.kt:232` 点击 `web_dav_restore` 走云端恢复、`:136` 长按直达 `restoreFromLocal()`（`:387`）、`import_old` 点击见 `:238` 并在 `:103` 回调 `ImportOldData.importUri()` | `settings_view.dart:222-229` -> `BackupSettingsView`；`backup_settings_view.dart` 已对齐帮助/日志动作，`从 WebDav 恢复` 支持点击云端 + 长按本地，且已补 `import_old` 独立入口并接线旧版目录导入 | `A-已接通` | `D-02`：已接通，保留终验回归（云端/本地双语义 + 旧版导入） |
| 8 | `my_menu_theme_setting` | `theme_setting` | `ConfigTag.THEME_CONFIG` -> `pref_config_theme.xml:5-170` + `theme_config.xml:5-8`；`ThemeConfigFragment.kt:166` 处理主题项，`:238` 处理日/夜背景图，`:215` 保存日/夜主题，`:122` 菜单切换主题模式 | `settings_view.dart:232-239` -> `ThemeSettingsView`；`theme_settings_view.dart:107-175` 当前仍是“导航枢纽 + 顶栏提示”，未承载 `theme_config` 底层项；`AppSettings` 与 `SettingsService` 未承载 `launcherIcon/transparentStatusBar/immNavigationBar/barElevation/fontScale` 对应键值链路 | `D-有差异` | `D-03`：legacy `theme_config` 底层配置项与持久化回显链路存在系统性缺口 |
| 9 | `my_menu_setting` | `setting` | `ConfigTag.OTHER_CONFIG` -> `pref_config_other.xml:62-199`；Web 服务相关键为 `webServiceWakeLock(:73)`、`webPort(:178)`，行为由 `OtherConfigFragment.kt:88,114,175`（含端口变更触发服务重启）与 `WebService.kt:62` 承接 | `settings_view.dart:242-249` -> `OtherSettingsView`；`other_settings_view.dart:326-507` 仅覆盖基本/源/缓存/调试子集，`:510-522` Web 区为静态“未启用”；`AppSettings/SettingsService` 未覆盖 `Cronet/antiAlias/mediaButtonOnExit/readAloudByMediaButton/ignoreAudioFocus/autoClearExpired/showAddToShelfAlert/updateToVariant/showMangaUi` 等 `pref_config_other` 键 | `D-有差异` | `D-04`：`pref_config_other` 缺口未补齐；Web 服务相关仅按 `EX-01` 记录边界，不进入运行态实现 |
| 10 | `my_menu_bookmark` | `bookmark` | `AllBookmarkActivity` -> `bookmark.xml`（导出/导出MD） | `settings_view.dart` -> `AllBookmarkView`（导出/导出MD） | `A-已接通` | 结构未见台账级缺口，留终验回归 |
| 11 | `my_menu_readRecord` | `readRecord` | `ReadRecordActivity` -> `book_read_record.xml`（排序 + 开启记录） | `settings_view.dart` -> `ReadingHistoryView`（排序 + 开启记录 + 搜索/清空） | `A-已接通` | 结构未见台账级缺口，留终验回归 |
| 12 | `my_menu_fileManage` | `fileManage` | `FileManageActivity` + `file_long_click.xml`（长按删除） | `settings_view.dart` -> `FileManageView`（搜索/长按动作） | `A-已接通` | 结构未见台账级缺口，留终验回归 |
| 13 | `my_menu_about` | `about` | `AboutActivity` `about.xml(menu)` + `AboutFragment` `about.xml(xml)` | `settings_view.dart` -> `AboutSettingsView`（分享/评分 + about 列表） | `A-已接通` | 结构未见台账级缺口，留终验回归 |
| 14 | `my_menu_exit` | `exit` | `MyFragment.kt` 直接 `activity?.finish()` | `settings_view.dart:302-305` 直接 `SystemNavigator.pop()`（无确认分支） | `A-已接通` | `D-05`：已接通，保留平台生命周期终验核对 |

## 4. 差异项聚合（后续实现唯一基线）

### 4.0 本轮范围（仅核心未完成项）

- 本轮仅保留未完成核心差异：`D-03`、`D-04`。
- `D-01`、`D-02`、`D-05` 已完成接通，状态统一为 `A-已接通（待终验）`，不再纳入“回补实现”差异基线。
- 执行顺序固定为串行依赖：`D-03 -> D-04`。
- 上游未闭环时下游统一 `blocked`：`D-04` 依赖 `D-03`。
- `EX-01` 继续 `blocked`（2026-02-26 本轮延续），Web 服务仅占位验证，不进入实现。
- 任何扩展项（含 Web 服务运行态）统一标记 `blocked`，不并行启动。

### 4.1 已接通待终验项（不进入本轮回补）

| 差异 ID | 当前实现状态（摘要） | 终验动作（摘要） | 目标文件 |
|---|---|---|---|
| `D-01` | `themeMode` 已由 `my_menu_themeMode` 承接四值（含 `E-Ink`）；`theme_settings/appearance/theme_list` 已改为引导提示，不再并行写入 `appearanceMode` | 回归核对四值展示、持久化、恢复后回显与跨页面一致性 | `lib/features/settings/views/settings_view.dart`、`lib/features/settings/views/theme_settings_view.dart`、`lib/features/settings/views/appearance_settings_view.dart`、`lib/features/settings/views/theme_config_list_view.dart`、`lib/core/models/app_settings.dart`、`lib/core/services/settings_service.dart` |
| `D-02` | `backup_restore` 已具备 `help/log` 顶栏动作，`web_dav_restore` 已对齐“点击云端恢复 + 长按本地恢复”，且 `import_old` 独立入口已接通 | 回归核对云端恢复、长按本地恢复、旧版导入三条链路在成功/失败场景下的语义一致性 | `lib/features/settings/views/backup_settings_view.dart`、`lib/core/services/backup_service.dart` |
| `D-05` | `my_menu_exit` 已保持“点击即退出”，当前实现为 `SystemNavigator.pop()` 且无确认分支 | 回归核对与 legacy `activity?.finish()` 的平台生命周期同义边界 | `lib/features/settings/views/settings_view.dart` |

### 4.2 未完成差异项（本轮唯一实现基线）

| 差异 ID | 当前实现状态（摘要） | 目标状态（摘要） | 本轮 owner | 阻塞边界 | 目标文件 |
|---|---|---|---|---|---|
| `D-03` | `theme_setting` 仍是导航枢纽，缺少 legacy `theme_config` 底层项与对应键链路 | 补齐 `theme_config` 底层项和读写/回显链路 | `MY-22` | 当前首个待实现差异项；不得回退 `D-01` 的主题模式单入口收敛结果 | `lib/features/settings/views/theme_settings_view.dart`、`lib/features/settings/views/appearance_settings_view.dart`、`lib/core/models/app_settings.dart`、`lib/core/services/settings_service.dart` |
| `D-04` | `pref_config_other` 仅覆盖子集，Web 区仍为占位 | 补齐非 Web 键闭环；Web 相关键仅保留锚点与占位 | `MY-23` | 串行依赖 `D-03`；严格遵循 `EX-01 blocked`，不得接线 `WebService.start/stop` 与端口重启 | `lib/features/settings/views/other_settings_view.dart`、`lib/core/models/app_settings.dart`、`lib/core/services/settings_service.dart` |

### 4.3 D-03~D-04 可执行条目（串行依赖）

### D-03（`theme_setting`）
- 当前实现状态:
  1. `theme_settings_view.dart` 仍以导航枢纽为主，未承载 `theme_config` 底层配置项。
  2. `app_settings.dart` 与 `settings_service.dart` 仍未覆盖 `launcherIcon/transparentStatusBar/immNavigationBar/barElevation/fontScale` 等键的完整读写与回显。
  3. legacy `pref_config_theme.xml` 的日/夜背景图与“保存主题配置”链路尚未等价承接。
- 目标状态:
  1. 在 `theme_setting` 下补齐 legacy 主题底层项（含背景图、`barElevation`、`fontScale`、日/夜主题保存）。
  2. 补齐底层键的读写、回显、生命周期语义。
  3. 主题模式相关入口遵循 `D-01` 收敛结果，不新增并行写入口。
- 本轮 owner 与落地文件:
  - owner: `MY-22`
  - 目标文件: `lib/features/settings/views/theme_settings_view.dart`
  - 目标文件: `lib/features/settings/views/appearance_settings_view.dart`
  - 目标文件: `lib/core/models/app_settings.dart`
  - 目标文件: `lib/core/services/settings_service.dart`
  - legacy 锚点: `../legado/app/src/main/res/xml/pref_config_theme.xml:5-170`、`../legado/app/src/main/res/menu/theme_config.xml:5-8`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:74`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:122`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:166`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:215`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:238`
- 阻塞边界:
  - 本项为本轮首个差异实现项，未完成前 `D-04` 标记 `blocked`。
  - 本项执行中不得回退 `D-01` 的单入口主题模式语义。
  - 本项仅覆盖 `theme_setting` 语义，不并入 `pref_config_other` 或 Web 服务需求。

### D-04（`setting`）
- 当前实现状态:
  1. `other_settings_view.dart` 仅覆盖基本/源设置/缓存维护/调试子集。
  2. `app_settings.dart` 与 `settings_service.dart` 未覆盖 `Cronet/antiAlias/mediaButtonOnExit/readAloudByMediaButton/ignoreAudioFocus/autoClearExpired/showAddToShelfAlert/updateToVariant/showMangaUi` 等 legacy 键。
  3. Web 区仍为静态“未启用”说明，未接入 `webPort/webServiceWakeLock` 运行态联动。
- 目标状态:
  1. 先补齐非 Web 服务缺口键的“可配置 + 持久化 + 回显”闭环。
  2. `webPort/webServiceWakeLock` 仅保留语义锚点，不引入运行态行为。
  3. 保持 `my_menu_webService` 与 Other 页 Web 区占位提示，遵循 `EX-01`。
- 本轮 owner 与落地文件:
  - owner: `MY-23`
  - 目标文件: `lib/features/settings/views/other_settings_view.dart`
  - 目标文件: `lib/core/models/app_settings.dart`
  - 目标文件: `lib/core/services/settings_service.dart`
  - legacy 锚点: `../legado/app/src/main/res/xml/pref_config_other.xml:62-226`、`../legado/app/src/main/res/xml/pref_config_other.xml:73`、`../legado/app/src/main/res/xml/pref_config_other.xml:178`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:60`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:88`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:114`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:175`、`../legado/app/src/main/java/io/legado/app/service/WebService.kt:62`
- 阻塞边界:
  - 本项必须在 `D-03` 完成后执行；`D-03` 未闭环时，`D-04` 标记 `blocked`。
  - 本项严格排除 Web 服务运行态实现，任何启停/地址/端口重启能力均标记 `blocked`。
  - 仅允许记录与展示 `webPort/webServiceWakeLock` 语义，不接入生效链路。

## 5. 迁移例外记录（必须）

### EX-01（Web服务）
- 状态: `blocked`
- 执行结论: `仅占位，不实现`（本轮禁止落地任何 WebService 运行态能力）。
- 原因:
  - legacy 要求 `webService` 具备服务启停、运行地址摘要、长按“复制地址/浏览器打开”。
  - 当前仅占位提示，未具备等价服务生命周期与地址态管理能力。
- 执行边界:
  - `仅占位验证，不进入 webService 实现`（不新增服务启停逻辑、不接入运行地址模型）。
  - `D-04` 中 `pref_config_other` 的 `webPort/webServiceWakeLock` 只记录 legacy 语义与锚点，不在本轮实现运行态联动。
  - 禁止在本轮新增以下能力：`WebService.start/stop` 接线、运行地址摘要、长按“复制地址/浏览器打开”、`webPort` 编辑触发服务重启、`webServiceWakeLock` 持久化生效链路。
- 影响范围:
  - 一级入口 `my_menu_webService`。
  - 关联设置项（例如 Other 设置中的 Web 端口/唤醒锁语义）无法形成完整闭环。
- 替代方案:
  - 保留入口与占位提示，避免用户误判为可用功能。
- 回补计划:
  1. 增加 Web 服务运行态模型（开关、地址、错误态）。
  2. 对齐开关行为（启停服务）和摘要文案（运行地址/默认说明）。
  3. 补齐长按动作（复制地址、浏览器打开）。
  4. 补齐与 Other 设置中 Web 相关项的联动与回显。
  5. 回填手工回归证据后再解除 `blocked`。

## 6. 覆盖性校验

- `my_menu_*` 一级入口覆盖数: `14/14`
- `EX-01` 是否存在 `blocked` 记录: `是`
