# R-N03 订阅页大标题导航证据（N-03）

- 入口: `底部导航 -> 订阅`
- 目标: 满足 `N-AC-01~N-AC-03`，并回填“排版布局一致性”结论。
- 步骤:
  1. 首帧观察 large title（“订阅”）是否展示；右侧 `收藏/分组/设置` 图标是否可见且可点击。
  2. 上滑订阅源列表：large title 是否折叠为 inline；滚动过程中无闪烁/抖动/错位。
  3. 回滚到顶部：large title 是否恢复展开态。
  4. 点击“规则订阅”入口、任意订阅源条目，进入二级页面后验证 iOS 侧滑返回可用。
  5. 输入搜索词、清除筛选：列表可正确过滤；空态/无匹配结果提示与按钮行为闭环。
  6. 排版布局一致性：搜索框、统计文案、规则订阅入口卡片、列表项圆角/间距符合当前 Cupertino 口径。
- 结果: `待验证`
- 处理动作: `owner:UI-NAV|截止:2026-02-27|状态:待回填|R-N03 未回归`
- 验证命令: `rg -n "useSliverNavigationBar:\\s*true" lib/features/rss/views/rss_subscription_view.dart`
- 命中摘要: `rss_subscription_view.dart:65`
- 关联锚点: `#ui-nav-r-n03`

