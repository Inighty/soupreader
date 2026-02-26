# 2026-02-26 「我的」菜单 ID 级差异清单（legado 对照）

- 状态: `done`
- 对照基线:
  - `pref_main.xml`
  - `main_my.xml`
  - `book_source*.xml`
  - `txt_toc_rule*.xml`
  - `replace_rule*.xml` / `replace_edit.xml`
  - `dict_rule*.xml`
  - `pref_config_backup/theme/cover/welcome/other.xml`
  - `bookmark.xml` / `book_read_record.xml` / `about.xml` / `file_*`

## 一级入口（pref_main.xml）

| legado key | 现状 | 结论 | 备注 |
|---|---|---|---|
| `bookSourceManage` | 已实现入口 | 同义 | 进入书源管理页 |
| `txtTocRuleManage` | 已实现入口 | 已同义 | `MY-18` 已回填，`MY-19` 待终验 |
| `replaceManage` | 已实现入口 | 同义（`MY-02` 已修正） | 现为直达替换规则管理 |
| `dictRuleManage` | 已实现入口 | 已同义 | `MY-18` 已回填，`MY-19` 待终验 |
| `themeMode` | 已实现入口 | 同义 | 模式选择可切换 |
| `webService` | 占位入口 | 例外 `EX-01 blocked` | 按需求排除，不进入实现 |
| `web_dav_setting` | 已实现入口 | 已同义 | `MY-10` 已收口，`MY-19` 待终验 |
| `theme_setting` | 已实现入口 | 已同义 | `MY-11~MY-12` 已收口，`MY-19` 待终验 |
| `setting` | 已实现入口 | 已同义 | `MY-13` 已收口，`MY-19` 待终验 |
| `bookmark` | 已实现入口 | 已同义 | `MY-14` 已收口，`MY-19` 待终验 |
| `readRecord` | 已实现入口 | 已同义 | `MY-15` 已收口，`MY-19` 待终验 |
| `fileManage` | 已实现入口 | 已同义 | `MY-17` 已收口，`MY-19` 待终验 |
| `about` | 已实现入口 | 已同义 | `MY-16` 已收口，`MY-19` 待终验 |
| `exit` | 已实现入口 | 同义 | 退出确认流程 |

## 二级/三级菜单状态（聚合）

- P0 已收口（`MY-03~MY-09` 完成，`MY-19` 待终验）:
  - `txt_toc_rule.xml/menu_help`、`txt_toc_rule_edit.xml/menu_copy_rule` 已补齐
  - `replace_rule.xml/menu_help`、`replace_edit.xml/menu_copy_rule` 已补齐
  - `dict_rule.xml/menu_help`、`dict_rule_edit.xml/menu_copy_rule` 已补齐
- P1 已收口（`MY-10~MY-13` 完成，`MY-19` 待终验）:
  - `pref_config_theme.xml`、`pref_config_cover.xml`、`pref_config_welcome.xml` 对照项已回填
- P2 已收口（`MY-14~MY-17` 完成，`MY-19` 待终验）:
  - 书源相关 `book_source*.xml`、`source_edit.xml`、`book_source_debug.xml`、`import_source.xml`
  - 书签 `bookmark.xml`
  - 阅读记录 `book_read_record.xml`
  - `about.xml/menu_scoring` 与 `xml/about.xml` 多项已收口
  - `file_chooser.xml/menu_create`、`file_long_click.xml/menu_del` 已收口
- 迁移例外:
  - `EX-01 webService`: `blocked`（仅保留占位入口语义）

## 后续执行映射

- `MY-03~MY-09`: P0（书源/TXT/替换/字典）`done`
- `MY-10~MY-13`: P1（备份/主题/其它）`done`
- `MY-14~MY-17`: P2（书签/阅读记录/关于/文件管理）`done`
- 当前阶段：进入 `MY-18/MY-19` 收口阶段（逐项对照回填 + 终验证据）
- 迁移例外：`EX-01 webService` 保持 `blocked`
