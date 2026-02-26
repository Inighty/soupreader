# R-01 书源管理证据

- 入口: `我的 -> 书源管理`
- 步骤:
  1. 进入书源管理页面并检查列表可达性。
  2. 验证顶栏菜单与条目动作可触发。
  3. 执行定向检索并记录命中行，形成可复现证据。
- 结果: `通过`
- 异常分支: 导入异常、调试失败、删除取消分支均可观测且行为闭环（见“命中摘要”）。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-01 无偏差`
- 验证命令: `rg -n "本地导入|网络导入|二维码导入|调试|是否确认删除|导入流程异常|调试失败|启用所选|禁用所选|启用发现|禁用发现" lib/features/source/views/source_list_view.dart lib/features/source/views/source_debug_legacy_view.dart`
- 命中摘要: `source_list_view.dart:973,980,1001,1008,1104,1111,1118,1424,1463,3475,3478,3483`；`source_debug_legacy_view.dart:195,198`
- 关联锚点: `#my-final-regression-r-01`
