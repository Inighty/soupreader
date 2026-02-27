# 2026-02-26 我的菜单同义核对清单（唯一基线）

- 状态: `active`
- 基线来源:
  - `docs/plans/2026-02-26-my-menu-id-diff.md`
  - `../legado/app/src/main/res/xml/pref_main.xml`
  - `../legado/app/src/main/res/menu/main_my.xml`
- 使用规则:
  - 后续实现任务仅以本清单和 ID 台账为准。
  - 未完成本清单逐项回填前，不得使用“完全一致/已一致”结论。

## 1. 执行顺序（核心项串行依赖）

1. 本轮范围仅核心未完成差异项：`D-03`、`D-04`。
2. `D-01`、`D-02`、`D-05` 已接通，状态统一为 `A-已接通（待终验）`，不再进入“回补实现”分支。
3. 串行：先执行 `D-03`（主题底层配置链路），`D-03` 未闭环时 `D-04` 统一 `blocked`。
4. 串行：执行 `D-04`（Other 非 Web 键闭环）。
5. 串行：统一手工回归与证据回填后收口（含 `D-01`、`D-02`、`D-05` 终验）。
6. 全程保持 `EX-01 blocked`，Web 服务仅占位验证，不进入实现分支。

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
| 8 | `my_menu_theme_setting` | `theme_setting` | 入口同义 | `theme_config` 底层主题项与持久化回显同义 | `D-03` | 回补实现 |
| 9 | `my_menu_setting` | `setting` | 入口同义 | `pref_config_other` 全量键同义（Web 仅按 `EX-01` 保持边界） | `D-04` | 回补实现 |
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

### 3.2 待实现差异（本轮唯一实现基线）

### D-03（`theme_setting`）
- 当前实现状态:
  1. `theme_settings_view.dart` 仍以导航枢纽为主，`theme_config` 底层项不可编辑。
  2. `app_settings.dart`、`settings_service.dart` 未完整覆盖 `launcherIcon/transparentStatusBar/immNavigationBar/barElevation/fontScale` 等键的持久化与回显。
  3. legacy `pref_config_theme.xml` 的背景图与“保存主题配置”链路尚未等价承接。
- 目标状态:
  1. 在 `theme_setting` 下补齐 legacy 主题底层项编辑能力（背景图、`barElevation`、`fontScale`、日夜主题保存等）。
  2. 补齐底层键读写与回显，保持页面生命周期语义同义。
  3. 主题模式写入口保持 `D-01` 已收敛状态，不新增并行写入口。
- 本轮 owner 与落地文件:
  - owner: `MY-22`
  - 目标文件: `lib/features/settings/views/theme_settings_view.dart`
  - 目标文件: `lib/features/settings/views/appearance_settings_view.dart`
  - 目标文件: `lib/core/models/app_settings.dart`
  - 目标文件: `lib/core/services/settings_service.dart`
  - legacy 锚点: `../legado/app/src/main/res/xml/pref_config_theme.xml:5-170`、`../legado/app/src/main/res/menu/theme_config.xml:5-8`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:74`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:122`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:166`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:215`、`../legado/app/src/main/java/io/legado/app/ui/config/ThemeConfigFragment.kt:238`
- 阻塞边界:
  - 本项未闭环前，`D-04` 维持 `blocked`。
  - 本项只覆盖 `theme_setting`，不并入 `pref_config_other` / Web 服务需求。

### D-04（`setting`）
- 当前实现状态:
  1. `other_settings_view.dart` 仅覆盖基本/源设置/缓存维护/调试子集。
  2. `app_settings.dart`、`settings_service.dart` 未覆盖 `Cronet/antiAlias/mediaButtonOnExit/readAloudByMediaButton/ignoreAudioFocus/autoClearExpired/showAddToShelfAlert/updateToVariant/showMangaUi` 等键。
  3. Web 区仍为静态占位，`webPort/webServiceWakeLock` 未接入运行态联动。
- 目标状态:
  1. 补齐非 Web 服务缺口键的“可配置 + 持久化 + 回显”闭环。
  2. `webPort/webServiceWakeLock` 仅保留语义锚点与占位提示，遵循 `EX-01`，不实现运行态。
  3. 禁止新增 `WebService.start/stop`、运行地址摘要、端口改动触发重启等能力。
- 本轮 owner 与落地文件:
  - owner: `MY-23`
  - 目标文件: `lib/features/settings/views/other_settings_view.dart`
  - 目标文件: `lib/core/models/app_settings.dart`
  - 目标文件: `lib/core/services/settings_service.dart`
  - legacy 锚点: `../legado/app/src/main/res/xml/pref_config_other.xml:62-226`、`../legado/app/src/main/res/xml/pref_config_other.xml:73`、`../legado/app/src/main/res/xml/pref_config_other.xml:178`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:60`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:88`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:114`、`../legado/app/src/main/java/io/legado/app/ui/config/OtherConfigFragment.kt:175`、`../legado/app/src/main/java/io/legado/app/service/WebService.kt:62`
- 阻塞边界:
  - 本项依赖 `D-03` 已闭环；`D-03` 未完成时，`D-04` 维持 `blocked`。
  - 本项严格遵循 `EX-01 blocked`，不得接线 Web 服务启停、地址摘要、端口重启。
  - 仅允许记录与展示 Web 相关键语义，不接入运行时生效链路。

## 4. 关键二级链路核对矩阵

| 模块 | legacy 关键文件 | 必核对动作 | 当前判定 |
|---|---|---|---|
| 书源管理 | `book_source.xml` `book_source_sel.xml` | 排序/分组/导入/帮助/批量动作 | `A-已接通` |
| TXT目录规则 | `txt_toc_rule.xml` `txt_toc_rule_sel.xml` | 新建/导入/帮助/批量启停与导出 | `A-已接通` |
| 替换规则 | `replace_rule.xml` `replace_rule_sel.xml` | 分组/导入/帮助/批量启停与置顶置底导出 | `A-已接通` |
| 字典规则 | `dict_rule.xml` `dict_rule_sel.xml` | 新建/导入默认与多源导入/帮助/批量导出 | `A-已接通` |
| 备份恢复 | `pref_config_backup.xml` `backup_restore.xml` | WebDav 配置 + `web_dav_restore` 点击云端/长按本地 + `import_old` 独立入口 + 失败回退链路 | `A-已接通（D-02 待终验）` |
| 主题设置 | `pref_config_theme.xml` `theme_config.xml` | `barElevation/fontScale/背景图/日夜主题保存` 等主题底层项 | `D-03` |
| 其它设置 | `pref_config_other.xml` | 基本/源设置/缓存维护/调试全量键；Web 服务仅记录边界（`webPort/webServiceWakeLock`），本轮不实现运行态 | `D-04` |
| 书签 | `bookmark.xml` | 导出 JSON/MD | `A-已接通` |
| 阅读记录 | `book_read_record.xml` | 排序三态 + 开启记录 | `A-已接通` |
| 关于 | `about.xml(menu)` `about.xml(xml)` | 分享/评分 + about 列表入口 | `A-已接通` |
| 文件管理 | `file_long_click.xml` | 长按删除与状态刷新 | `A-已接通` |

## 5. blocked 记录（AGENTS 1.1.2）

### EX-01（Web服务）
- 状态: `blocked`
- 执行结论: `仅占位，不实现`（本轮不得新增任何 WebService 运行态能力）。
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
