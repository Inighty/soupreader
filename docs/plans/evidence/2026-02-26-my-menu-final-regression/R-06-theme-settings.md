# R-06 主题设置证据

- 入口: `我的 -> 主题设置`
- 步骤:
  1. 进入主题设置并检查主题模式、主题列表、封面设置、启动样式入口。
  2. 执行主题切换并记录回显结果。
  3. 执行定向检索并记录主题导入/删除/资源异常命中。
- 结果: `通过`
- 异常分支: 主题列表剪贴板导入失败返回“格式不对,添加失败”；主题资源异常覆盖“图片文件不存在”“选择图片失败”；主题列表删除具备“是否确认删除？”确认分支，分享失败按 legacy 语义静默处理。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-06 无偏差`
- 验证命令: `rg -n "主题列表|剪贴板导入|格式不对,添加失败|是否确认删除|图片文件不存在|选择图片失败|主题分享|分享失败静默吞掉|暂无主题配置" lib/features/settings/views/theme_settings_view.dart lib/features/settings/views/theme_config_list_view.dart lib/features/settings/views/cover_config_view.dart lib/features/settings/views/welcome_style_settings_view.dart`
- 命中摘要: `theme_settings_view.dart:132`；`theme_config_list_view.dart:69,103,171,183,90,94`；`cover_config_view.dart:238,260`；`welcome_style_settings_view.dart:155,178`
- 关联锚点: `#my-final-regression-r-06`
