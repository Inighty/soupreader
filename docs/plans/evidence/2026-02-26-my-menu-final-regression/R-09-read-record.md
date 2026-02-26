# R-09 阅读记录证据

- 入口: `我的 -> 阅读记录`
- 步骤:
  1. 进入页面并检查搜索、总阅读时长、清空入口可见。
  2. 验证单条删除与全量清空的取消/确认分支。
  3. 执行定向检索并记录清理/排序/回显链路命中。
- 结果: `通过`
- 异常分支: 单条删除与全量清空均经“是否确认删除”确认分支后执行，取消不生效；清空后同时调用 `clearAllBookReadRecordDuration` 清理总时长，单条删除/移除时调用 `clearBookReadRecordDuration`；空态与搜索空态文案可观测（`暂无阅读记录` / `无匹配记录`）。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-09 无偏差`
- 验证命令: `rg -n "总阅读时间|清空|无匹配记录|暂无阅读记录|是否确认删除|清除阅读记录|clearAllBookReadRecordDuration|clearBookReadRecordDuration|开启记录|排序" lib/features/bookshelf/views/reading_history_view.dart lib/core/services/settings_service.dart`
- 命中摘要: `reading_history_view.dart:159,185,204,295,302,324,410,419,427,449,460`；`settings_service.dart:691,704`
- 关联锚点: `#my-final-regression-r-09`
