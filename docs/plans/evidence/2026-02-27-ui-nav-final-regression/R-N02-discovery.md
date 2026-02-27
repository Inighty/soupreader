# R-N02 发现页大标题导航证据（N-02）

- 入口: `底部导航 -> 发现`
- 目标: 满足 `N-AC-01~N-AC-03`，并回填“排版布局一致性”结论。
- 步骤:
  1. 首帧观察 large title（“发现”）是否展示；右侧分组按钮是否可点击并弹出分组 ActionSheet。
  2. 上滑列表：large title 是否折叠为 inline；滚动过程中无闪烁/抖动/错位。
  3. 回滚到顶部：large title 是否恢复展开态。
  4. 双击底部“发现”tab：触发 compress 行为（对齐 legacy `compressExplore()`）；应优先收起已展开书源，或回顶并展开 large title。
  5. 点击某书源展开/收起发现入口；再进入二级发现书单页后验证 iOS 侧滑返回可用。
  6. 排版布局一致性：搜索框/计数文案/列表卡片间距、边框、热区与现有口径一致（平台差异除外）。
- 结果: `待验证`
- 处理动作: `owner:UI-NAV|截止:2026-02-27|状态:待回填|R-N02 未回归`
- 验证命令: `rg -n "useSliverNavigationBar:\\s*true" lib/features/discovery/views/discovery_view.dart`
- 命中摘要: `discovery_view.dart:505`
- 关联锚点: `#ui-nav-r-n02`

