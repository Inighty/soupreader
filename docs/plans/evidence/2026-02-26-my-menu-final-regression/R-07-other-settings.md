# R-07 其它设置证据

- 入口: `我的 -> 其它设置`
- 步骤:
  1. 进入其它设置并检查基础开关、源设置、维护动作入口。
  2. 修改一项开关与一项数值配置并记录重进回显。
  3. 执行定向检索并记录维护动作确认/失败分支命中。
- 结果: `通过`
- 异常分支: “清理缓存/清除 WebView 数据/压缩数据库”均有二次确认（“是否继续？”）；维护服务失败分支明确返回“清理缓存失败/清除 WebView 数据失败/压缩数据库失败”；执行层有“执行失败”兜底；其它设置本身包含目录选择失败与输入下限校验提示。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-07 无偏差`
- 验证命令: `rg -n "下载与缓存|清理缓存|清除 WebView 数据|压缩数据库|是否继续|执行失败|清理缓存失败|清除 WebView 数据失败|压缩数据库失败|选择保存书籍的文件夹失败|不能小于 10" lib/features/settings/views/other_settings_view.dart lib/features/settings/views/storage_settings_view.dart lib/features/settings/services/other_maintenance_service.dart lib/features/settings/services/other_source_settings_service.dart`
- 命中摘要: `other_settings_view.dart:149,185,461`；`storage_settings_view.dart:57,88,99,105,136,163,190,241`；`other_maintenance_service.dart:83,117,133`
- 关联锚点: `#my-final-regression-r-07`
