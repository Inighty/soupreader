# R-05 备份与恢复证据

- 入口: `我的 -> 备份与恢复`
- 步骤:
  1. 进入页面并检查本地备份、本地恢复、WebDav 相关入口可达性。
  2. 记录本地备份/恢复可达性与提示信息。
  3. 执行定向检索并记录 WebDav 失败回退链路命中。
- 结果: `通过`
- 异常分支: WebDav 列表失败、无可用备份、下载/导入失败均进入 `_showWebDavRestoreFallback`；弹窗文案明确“将从本地备份恢复”，并通过“回退本地恢复”触发 `_import(overwrite: false)` 完成本地恢复回退。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-05 无偏差`
- 验证命令: `rg -n "_import\\(overwrite: false\\)|_showWebDavRestoreFallback|WebDavError|回退本地恢复|失败可回退本地恢复|WebDav 备份失败|WebDav 恢复失败|导入失败|帮助文档加载失败" lib/features/settings/views/backup_settings_view.dart lib/core/services/backup_service.dart lib/core/services/webdav_service.dart`
- 命中摘要: `backup_settings_view.dart:223,455,462,544,559,566,574,581`；`backup_settings_view.dart:434,404,308`；`backup_service.dart:193,211,358`
- 关联锚点: `#my-final-regression-r-05`
