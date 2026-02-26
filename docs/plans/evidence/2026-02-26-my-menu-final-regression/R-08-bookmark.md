# R-08 书签证据

- 入口: `我的 -> 书签`
- 步骤:
  1. 进入书签页并检查导出、导出(MD)入口。
  2. 点击书签详情并验证定位阅读动作可达。
  3. 执行定向检索并记录导出/定位阅读命中。
- 结果: `通过`
- 异常分支: 导出链路具备成功与失败提示（`导出成功` / `导出失败`），并写入 `all_bookmark.menu_export(_md)` 日志节点；定位阅读失败写入 `all_bookmark.item_open_reader` 且提示“定位阅读失败”；书籍缺失时提示“书籍不存在，无法定位阅读”。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-08 无偏差`
- 验证命令: `rg -n "menu_export|menu_export_md|导出\\(MD\\)|导出失败|导出成功|item_open_reader|定位阅读失败|书籍不存在，无法定位阅读|定位阅读" lib/features/reader/views/all_bookmark_view.dart lib/features/reader/services/reader_bookmark_export_service.dart`
- 命中摘要: `all_bookmark_view.dart:70,85,95,113,115,147,185,210,211,222,272`；`reader_bookmark_export_service.dart:293,297`
- 关联锚点: `#my-final-regression-r-08`
