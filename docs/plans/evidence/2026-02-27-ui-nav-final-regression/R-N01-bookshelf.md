# R-N01 书架页大标题导航证据（N-01）

- 入口: `底部导航 -> 书架`
- 目标: 满足 `N-AC-01~N-AC-03`，并回填“排版布局一致性”结论。
- 步骤:
  1. 首帧观察 large title（“书架”）是否展示；右侧 `搜索/更多` 图标是否可见且可点击。
  2. 上滑列表：large title 是否平滑折叠为 inline 标题；滚动过程中无闪烁/抖动/错位。
  3. 回滚到顶部：large title 是否恢复展开态。
  4. 双击底部“书架”tab：触发回顶/展开（对齐 legacy reselect 语义）；折叠状态应同步恢复展开态。
  5. 进入二级页面（任意书籍详情/阅读/设置等链路）后验证 iOS 侧滑返回可用；返回到书架后滚动状态不异常。
  6. 排版布局一致性：空态/列表态/错误态（如可触发）在 Cupertino 视觉下间距、对齐、热区符合预期且无明显偏差。
- 结果: `待验证`
- 处理动作: `owner:UI-NAV|截止:2026-02-27|状态:待回填|R-N01 未回归`
- 验证命令: `rg -n "useSliverNavigationBar:\\s*true" lib/features/bookshelf/views/bookshelf_view.dart`
- 命中摘要: `bookshelf_view.dart:1693`
- 关联锚点: `#ui-nav-r-n01`

