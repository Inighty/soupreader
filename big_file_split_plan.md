---
name: 大文件拆分后续方案
description: 对仍 >500 行的核心 view 文件的拆分计划：每个文件的瓶颈分析、推荐拆法、风险点与验收标准
type: project
originSessionId: 0e99460c-a794-41f4-a7b5-2fc52722b8bd
---
# 后续拆分方案（已完成）

## 当前状态（2026-05-21）

| 文件 | 当前 | 目标 | 已用模式 |
|------|------|------|---------|
| `replace_rule_list_view.dart` | 184 | ≤300 | ✅ 已拆分为 public State + 多 extension |
| `bookshelf_view.dart` | 272 | ≤300 | ✅ 已拆分为 public State + 多 extension |
| `search_book_info_view.dart` | 253 | ≤300 | ✅ 已拆分为 public State + part extensions |
| `lib/features/reader/widgets/paged_reader_widget.dart` | 205 | ≤500 | ✅ 已拆分为 public API + State 壳 + 多 part extension |

`search_view.dart` 已通过 "public State + session_extension" 模式从 1630 降到 440 ✅，可复用此模板。

---

## 通用模板（已验证可用）

复制 `search_view → search_session_extension` 的步骤：

1. **bulk rename**：用 `python3` + `re.sub(r'\b_xxx\b', 'xxx', content)` 把 State 私有字段/方法去掉前缀；State 类名 `_FooState` → `FooState`。常量（`static const _foo`）只挑被 extension 使用的改公开，其余保持私有。
2. **抽 extension**：按主题分若干 `extension Xyz on FooState { ... }`；每个 extension 文件首加
   `// ignore_for_file: invalid_use_of_protected_member`
   以允许 extension 内 `setState(...)`。
3. **修复重名**：renaming 经常和导入的顶层函数撞名（如 `showReplaceRuleHelp`），用 `openReplaceRuleHelp` 之类前缀化别名解决。
4. **删除主文件中已被 extension 接管的方法**：`sed -i 'A,Bd' file.dart`，再补全孤儿 `}`。
5. **去多余 import**：`flutter analyze` 会列出，逐条删。
6. **`flutter analyze` 必须 0 issues 才提交**。

---

## 1. replace_rule_list_view.dart（652 → 184，已完成）

已完成本阶段拆分：

- `replace_rule_list_body.dart`：主体 build / 顶部栏 / 多选底栏装配。
- `replace_rule_list_filtering.dart`：分组构建、分组过滤、搜索过滤。
- `replace_rule_list_group_actions.dart`：分组筛选入口与分组管理动作。
- `replace_rule_list_selection_state.dart`：多选状态维护。
- `replace_rule_list_bulk_actions.dart`：批量删除 / 启禁用 / 置顶置底 / 导出。
- `replace_rule_list_actions.dart`：收敛为顶部菜单与单条规则菜单。

验收：`flutter analyze` 通过，No issues found。

---

## 2. bookshelf_view.dart（3070 → 272，已完成）

已完成本阶段拆分：

- `bookshelf_body_widgets.dart`：标题、页面壳、空态/错误态、body sliver 装配。
- `bookshelf_group_bar_widgets.dart`：style1 分组栏与分组 chip。
- `bookshelf_grid_widgets.dart` / `bookshelf_list_widgets.dart`：网格与列表渲染。
- `bookshelf_book_status_helpers.dart` / `bookshelf_text_helpers.dart`：未读、更新中、阅读/最新行文案。
- `bookshelf_local_import.dart` / `bookshelf_scan_import*.dart`：本地导入、文件夹选择、智能扫描。
- `bookshelf_add_by_url.dart` / `bookshelf_booklist_io.dart`：网址添加、书单导入导出。
- `bookshelf_layout_options.dart` / `bookshelf_layout_dialog.dart`：布局选项保存与弹窗。
- `bookshelf_more_menu.dart`：更多菜单派发。
- `bookshelf_sort_layout_engine.dart` / `bookshelf_group_store_engine.dart` /
  `bookshelf_display_engine.dart`：排序、分组上下文、展示数据源。
- `bookshelf_navigation.dart` / `bookshelf_catalog_actions.dart`：页面跳转、长按动作、目录更新。

验收：`flutter analyze` 通过，No issues found。

---

## 3. search_book_info_view.dart（3558 → 253，已完成）

已完成本阶段拆分：

- `search_book_info_session_cache.dart` / `search_book_info_error_helpers.dart`：
  会话缓存 key、缓存读写、错误文本压缩与分享错误文案。
- `search_book_info_context_models.dart` / `search_book_info_bookshelf_context.dart` /
  `search_book_info_context_loader.dart`：上下文加载、书架缓存复用、章节构建与
  fallback detail。
- `search_book_info_display_helpers.dart` / `search_book_info_toc_actions.dart` /
  `search_book_info_toc_refresh.dart`：展示字段、目录标题、TXT 目录规则、目录刷新。
- `search_book_info_share_actions.dart` / `search_book_info_book_actions.dart` /
  `search_book_info_sync_actions.dart` / `search_book_info_shelf_actions.dart`：
  分享、编辑、登录、变量设置、同步、书架加入/移除。
- `search_book_info_reader_actions.dart`：阅读器与目录页跳转、书签导出。
- `search_book_info_more_menu_items.dart` / `search_book_info_more_menu_actions.dart`：
  更多菜单项、菜单动作解析与安全执行。
- `search_book_info_source_switch_helpers.dart` /
  `search_book_info_source_switch_actions.dart`：换源参数、迁移与候选应用。
- `search_book_info_body.dart` / `search_book_info_hero_section.dart` /
  `search_book_info_detail_section.dart` / `search_book_info_bottom_bar.dart`：
  详情页主体、封面 hero、详情内容区和底部操作栏。

验收：`flutter analyze lib/features/search/views/search_book_info_view.dart`
通过；全量 `flutter analyze` 通过，No issues found。

---

## 4. lib/features/reader/widgets/paged_reader_widget.dart（3608 → 205，已完成）

已完成本阶段拆分。执行前已核对 legado 阅读器核心链路：
`ReadView` / `PageView` / `ContentTextView` / `TextPageFactory` /
`PageDelegate` / `HorizontalPageDelegate` / `SlidePageDelegate` /
`CoverPageDelegate` / `SimulationPageDelegate` / `NoAnimPageDelegate` /
`TextPage` / `TextLine` / `ImageColumn` / `TextChapterLayout` /
`ChapterProvider`。

本阶段只做职责迁移，不改翻页状态机、缓存门闩、选区命中、图片排版或页眉页脚语义。

已拆分文件：

- `paged_reader_public_api.dart`：公开 widget、controller、长按选择模型。
- `paged_reader_state_sync.dart`：内容变更、延迟失效、shader 加载、电池状态。
- `paged_reader_metrics.dart`：阅读器派生状态、页眉页脚 slot、安全区稳定计算。
- `paged_reader_recording.dart` / `paged_reader_tip_painting.dart`：Picture 录制、页眉页脚 canvas 绘制、进度文本。
- `paged_reader_picture_cache.dart` / `paged_reader_precache.dart`：Picture/Image 缓存、相邻页预渲染、仿真翻页帧准备。
- `paged_reader_turn_programmatic.dart` / `paged_reader_turn_scroll.dart`：程序触发翻页、方向设置、动画滚动与收尾。
- `paged_reader_selection_start.dart` / `paged_reader_selection_geometry.dart` /
  `paged_reader_selection_words.dart`：长按、选区、命中测试、词边界和九宫格点击动作。
- `paged_reader_build_content.dart` / `paged_reader_slide_cover.dart` /
  `paged_reader_simulation_modes.dart`：页面壳、静态页、slide/cover/simulation/no-animation 渲染。
- `paged_reader_gestures.dart`：拖拽开始、更新、结束。
- `paged_reader_body_images.dart` / `paged_reader_image_tracking.dart`：正文 widget、图片块、图片尺寸回写。
- `paged_reader_overlay.dart` / `paged_reader_support.dart`：tip overlay、辅助类型与私有常量。

验收：`dart format lib/features/reader/widgets/paged_reader_widget.dart lib/features/reader/widgets/paged_reader_*.dart`
已执行；全量 `flutter analyze` 通过，No issues found（141.2s）。

---

## 推荐执行顺序

1. **replace_rule_list_view**（已完成）
2. **bookshelf_view**（已完成）
3. **search_book_info_view**（已完成）
4. **paged_reader_widget**（已完成）

---

## 已沉淀的最佳实践

1. **bulk rename 用 `python3` 而非 `sed -E`**：Python 正则 `\b` 比 sed 更可靠，且能避免类型名（`_settings` vs `AppSettings`）的误伤。
2. **extension 内必须加 `// ignore_for_file: invalid_use_of_protected_member`**：否则 `setState` 报警告（虽不报错）。
3. **拆出去的 helper 函数优先用 `top-level function`**（不是静态方法），调用更省字。
4. **变量名碰撞**：`bool hasMore` 字段 vs `bool hasMore` 参数，rename 时改参数为 `pageHasMore` 等显式名。
5. **constants 默认保持私有**：只把被外部 extension 引用的 1-2 个改公开（如 `onlineImportHistoryKey`）。
6. **每抽一个 extension 立即 `flutter analyze`**：分批验证比最后一起调试快得多。
