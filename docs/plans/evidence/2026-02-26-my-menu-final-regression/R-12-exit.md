# R-12 退出证据

- 入口: `我的 -> 退出`
- 步骤:
  1. 触发退出动作并检查确认弹窗。
  2. 先执行取消分支并记录会话状态。
  3. 执行定向检索并记录退出确认链路命中。
- 结果: `通过`
- 异常分支: 退出入口绑定 `_confirmExit`，弹窗包含“确定退出应用吗？/取消/退出”；取消分支返回 `false` 并中止退出，确认分支为 `true` 后执行 `SystemNavigator.pop()`，符合退出确认语义。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-12 无偏差`
- 验证命令: `rg -n "_confirmExit|确定退出应用吗|取消|退出|SystemNavigator.pop|my_menu_exit" lib/features/settings/views/settings_view.dart`
- 命中摘要: `settings_view.dart:149,153,154,158,163,169,319,320,322`
- 关联锚点: `#my-final-regression-r-12`
