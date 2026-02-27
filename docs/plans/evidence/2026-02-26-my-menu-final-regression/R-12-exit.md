# R-12 退出证据

- 入口: `我的 -> 退出`
- 步骤:
  1. 在我的页点击“退出”。
  2. 观察是否立即触发应用退出，不出现确认弹窗。
  3. 执行定向检索并记录退出绑定命中。
- 结果: `通过`
- 异常分支: 无。`my_menu_exit` 点击后直接调用 `SystemNavigator.pop()`；代码中不存在 `_confirmExit` 与“确定退出应用吗”确认文案，符合“点击即退出”预期。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-12 无偏差`
- 验证命令: `rg -n "_confirmExit|确定退出应用吗|SystemNavigator.pop|my_menu_exit" lib/features/settings/views/settings_view.dart`
- 命中摘要: `_confirmExit/确定退出应用吗 无命中；my_menu_exit 与 SystemNavigator.pop 命中退出入口绑定`
- 关联锚点: `#my-final-regression-r-12`
