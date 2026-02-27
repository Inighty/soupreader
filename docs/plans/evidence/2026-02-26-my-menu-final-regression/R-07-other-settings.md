# R-07 其它设置证据

- 入口: `我的 -> 其它设置`
- 步骤:
  1. 进入其它设置并检查基础开关、源设置、维护动作入口。
  2. 修改一项开关与一项数值配置并记录重进回显。
  3. 进入“检查更新查找版本”，依次切换 `当前/default_version`、`正式版/official_version`、`测试版/beta_release_version`、`共存版/beta_releaseA_version`，每次选择后返回条目核对回显。
  4. 重进其它设置确认 `updateToVariant` 回显保持最后一次选择；执行定向检索并记录维护动作确认/失败分支命中。
- 结果: `通过（含 updateToVariant 回归）`
- 回归结论: `updateToVariant` 四值切换可用、条目回显正确、重进后保持；`Web 服务（未启用）` 边界描述保持“当前构建排除了 Web 服务，以下配置仅保留说明，不可操作。”不变。
- 异常分支: “清理缓存/清除 WebView 数据/压缩数据库”均有二次确认（“是否继续？”）；维护服务失败分支明确返回“清理缓存失败/清除 WebView 数据失败/压缩数据库失败”；执行层有“执行失败”兜底；其它设置本身包含目录选择失败与输入下限校验提示。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-07 无偏差`
- 验证命令: `rg -n "检查更新查找版本|return '当前'|正式版|测试版|共存版|default_version|official_version|beta_release_version|beta_releaseA_version|updateToVariant|下载与缓存|清理缓存|清除 WebView 数据|压缩数据库|是否继续|执行失败|清理缓存失败|清除 WebView 数据失败|压缩数据库失败|选择保存书籍的文件夹失败|不能小于 10|Web 服务（未启用）|当前构建排除了 Web 服务，以下配置仅保留说明，不可操作。" lib/features/settings/views/other_settings_view.dart lib/features/settings/views/storage_settings_view.dart lib/features/settings/services/other_maintenance_service.dart lib/features/settings/services/other_source_settings_service.dart lib/core/models/app_settings.dart lib/core/services/settings_service.dart`
- 命中摘要: `other_settings_view.dart:150,186,242,252,262,272,535,630,632,633,647,648`；`storage_settings_view.dart:57,88,99,105,136,163,190,241`；`other_maintenance_service.dart:83,117,133`；`app_settings.dart:183-186,211,214,216,218,221,245,310,529-530,685,776,844`；`settings_service.dart:296,1154,1157,1278,1281`
- 关联锚点: `#my-final-regression-r-07`
