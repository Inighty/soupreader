# R-N04 我的页大标题导航证据（N-04）

- 入口: `底部导航 -> 我的`
- 目标: 满足 `N-AC-01~N-AC-03`，并回填“排版布局一致性”结论。
- 步骤:
  1. 首帧观察 large title（“我的”）是否展示；右侧帮助按钮是否可点击并弹出帮助对话框。
  2. 上滑设置列表：large title 是否折叠为 inline；滚动过程中无闪烁/抖动/错位。
  3. 回滚到顶部：large title 是否恢复展开态。
  4. 进入任意二级页面（如“书源管理/备份与恢复/关于”），验证 iOS 侧滑返回可用且返回后列表状态正常。
  5. 排版布局一致性：各 `CupertinoListSection.insetGrouped` 的间距、圆角、分组标题、热区与当前口径一致（平台差异除外）。
- 结果: `待验证`
- 处理动作: `owner:UI-NAV|截止:2026-02-27|状态:待回填|R-N04 未回归`
- 验证命令: `rg -n "useSliverNavigationBar:\\s*true" lib/features/settings/views/settings_view.dart`
- 命中摘要: `settings_view.dart:159`
- 关联锚点: `#ui-nav-r-n04`

