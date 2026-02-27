# 2026-02-27 UI Cupertino 差异迁移台账（shadcn 清退）

- 状态: `active`
- 任务口径: 本轮执行“差异重扫 + 台账回填 + N-01~N-04 可执行迁移口径固化 + N-01~N-04 实施 + N-VAL-01 回归收口（证据回填）”，并补充清退 `lib/` 下残留 `package:flutter/material.dart` 导入（`M-01`）。
- 本轮实施冻结: 仅执行 `N-01~N-04` 与 `N-VAL-01` 收口链路 + `M-01`（`lib/` 下 `material.dart` 残留导入清退）；`N-PRE-01` 仅保留为已完成前置能力记录。
- 适用范围: `lib/` UI 迁移（`shadcn_ui`、非 Cupertino 弹窗、核心页面大标题导航）。
- 强约束:
  - 本台账是本轮唯一执行基线。
  - 迁移级任务先跑差异清单，再开实现分支。
  - 例外项必须按 AGENTS `1.1.2` 记录原因、影响范围、替代方案、回补计划。

## 0. 跨台账状态对齐（2026-02-27，基于当前代码复扫）

- `D-03=done`（owner: `MY-22`，依赖: `无（串行首项）`；5 个子项“入口可操作 + 保存接口调用 + 页面回显”代码证据已回填）
- `D-04=done`（owner: `MY-23`，依赖: `D-03` 已满足；`pref_config_other` non-Web 键已接线闭环（含 `updateToVariant`），`updateToVariant` 口径以 legado 四值 `default/official/beta_release/beta_releaseA` 为准；Web 区仅只读回显且无可操作入口）
- `N-01~N-04=done`（大标题导航实现已完成；收口证据已回填至 `R-N01~R-N04`）
- `N-VAL-01=blocked`（owner: `UI-NAV`，依赖: `C6-T01` 证据终态（`R-N01~R-N04`）；状态定义：证据终态为 `blocked`，待可交互环境回补后再收口）
- `NAV-DIFF-01=done`（`RssSubscriptionView` 空态 `noEnabled` 分支按钮已对齐为 `_openSourceSettings`，语义为“进入订阅源管理”，不再作为 `N-03` / `N-VAL-01` 前置阻塞）
- `EX-01=blocked`（仅占位，不进入 `WebService` 运行态实现）
- 唯一串行依赖固定：`D-03 -> D-04`
- 顺序约束补充：本台账只承接 UI 导航收口链路（`N-01~N-04` -> `N-VAL-01` 仅作为状态门）；与 my 菜单差异链路并行记录但不改写 `D-03 -> D-04` 唯一串行顺序。
- `D-03` 证据明细已回填至 `docs/plans/2026-02-26-my-menu-parity-checklist.md` 的 D-03 子项表（白天/夜间背景图、白天/夜间模糊度、日夜主题保存）。
- `D-04` 复扫结论已回填至 `docs/plans/2026-02-26-my-menu-parity-checklist.md` 的 D-04 差异表（当前无剩余代码项，仅维持 `EX-01 blocked` 边界约束）。

## 1. 扫描基线与统计（2026-02-27，复扫）

### 1.1 本轮定向检索命令

```bash
rg -n "shadcn_ui" lib
rg -n "showGeneralDialog" lib
rg -n "useSliverNavigationBar" lib
rg -n "useSliverNavigationBar:\s*true" lib
rg -n "CupertinoSliverNavigationBar" lib
rg -n "ShadTheme|ShadButton|ShadCard" lib
rg -n "package:flutter/material.dart" lib
```

本轮复扫结论：
- `showGeneralDialog` 仍为 `0`，`C-01` 维持“已清退”状态。
- `shadcn_ui` 已归零：`lib/` 未命中（命中 `0`）。
- `ShadTheme|ShadButton|ShadCard` 仅剩 `1` 处注释文本命中（不涉及组件依赖），不作为阻塞项。
- `package:flutter/material.dart` 已归零：`lib/` 未命中（命中 `0`）。
- 壳层 `CupertinoSliverNavigationBar` 能力已存在（命中 `1`）；核心页 `N-01~N-04` 均已接入 `useSliverNavigationBar: true`（大标题导航）。

### 1.2 当前代码扫描统计（soupreader）

> 本次复核（2026-02-27）已按当前代码重新检索并回填。

- `shadcn_ui` 命中: `0`（文件数 `0`）
- `showGeneralDialog` 命中: `0`（文件数 `0`）
- `useSliverNavigationBar` 命中: `7`（文件数 `5`）
- `useSliverNavigationBar: true` 命中: `4`（文件数 `4`）
- `CupertinoSliverNavigationBar` 命中: `1`（文件数 `1`）
- `ShadTheme|ShadButton|ShadCard` 命中: `1`（文件数 `1`）
- `package:flutter/material.dart` 命中: `0`（文件数 `0`）

### 1.3 命中文件清单

`A. shadcn_ui 命中`
- 无

`B. showGeneralDialog 命中`
- 无

`C. useSliverNavigationBar 命中`
- `lib/features/bookshelf/views/bookshelf_view.dart:1693`
- `lib/features/settings/views/settings_view.dart:159`
- `lib/features/rss/views/rss_subscription_view.dart:65`
- `lib/features/discovery/views/discovery_view.dart:506`
- `lib/app/widgets/app_cupertino_page_scaffold.dart:16`
- `lib/app/widgets/app_cupertino_page_scaffold.dart:31`
- `lib/app/widgets/app_cupertino_page_scaffold.dart:112`

`C-1. useSliverNavigationBar: true 命中`
- `lib/features/bookshelf/views/bookshelf_view.dart:1693`
- `lib/features/settings/views/settings_view.dart:159`
- `lib/features/discovery/views/discovery_view.dart:506`
- `lib/features/rss/views/rss_subscription_view.dart:65`

`D. CupertinoSliverNavigationBar 命中`
- `lib/app/widgets/app_cupertino_page_scaffold.dart:153`

`E. Shad 相关命中（迁移相关）`
- `lib/app/theme/cupertino_theme_adapter.dart:8`（注释含 `ShadTheme` 文本）

`F. package:flutter/material.dart 命中`
- 无

### 1.4 legado 对照锚点（沿用）

- 书源链路:
  - `../legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/source/edit/BookSourceEditActivity.kt`
- 阅读设置链路:
  - `../legado/app/src/main/java/io/legado/app/ui/book/read/config/PaddingConfigDialog.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadAloudConfigDialog.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/book/read/config/BgTextConfigDialog.kt`
- 主导航/核心页:
  - `../legado/app/src/main/java/io/legado/app/ui/main/MainActivity.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/main/bookshelf/BaseBookshelfFragment.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/main/rss/RssFragment.kt`
  - `../legado/app/src/main/java/io/legado/app/ui/main/my/MyFragment.kt`

## 2. 执行拆分（依赖与并行性）

1. 串行：重扫 `shadcn_ui`、`showGeneralDialog`、`useSliverNavigationBar`（并补充校验 `CupertinoSliverNavigationBar`）并冻结统计。`done`
2. 串行：按复扫结果回填 `S-*` / `C-*` 条目状态。`done`
3. 串行：将 `N-01~N-04` 从待确认描述改为可执行迁移口径并固化验收标准。`done`
4. 串行前置：`N-PRE-01` 壳层导航能力已具备（`AppCupertinoPageScaffold` 已支持 `useSliverNavigationBar` / `sliverBodyBuilder` / `sliverScrollController`）。`done`
5. 并行：`N-01~N-04` 四个核心页接入大标题导航（本轮核心实施项）。`done`（`N-01~N-04` 均已接入 `useSliverNavigationBar: true` + `sliverBodyBuilder`，实现侧已完成）
6. 收口步骤：`N-VAL-01` 手工回归证据回填并收口（本轮最终收口项）。`blocked`（状态：依据 `C6-T01` 证据终态，`R-N01~R-N04` 均为 `blocked`；待可交互环境完成回补后更新）

> Owner 约定
- `UI-CORE`: 应用壳层/导航容器（`N-PRE-01`）
- `UI-SOURCE`: 书源链路
- `UI-SETTINGS`: 设置与阅读配置链路
- `UI-NAV`: 大标题导航专项（`N-01~N-04`）

## 3. 迁移台账

### 3.1 `shadcn_ui` 清退归零条目（4 文件）

> 说明：`S-01~S-04` 条目维持 `done`；按 1.2 复扫基线（`rg -n "shadcn_ui" lib`）已归零（命中 `0`），不再存在 `N-01` 相关阻塞。

| ID | 文件 | 本轮差异结论 | 对应 legado 锚点 | 负责人 | 手工回归路径 | 状态 |
|---|---|---|---|---|---|---|
| S-01 | `lib/features/source/views/source_list_view.dart` | 复扫未命中 `shadcn_ui`，保留 legacy 对照作为回归基线 | `../legado/app/src/main/java/io/legado/app/ui/book/source/manage/BookSourceActivity.kt:83` | `UI-SOURCE` | R-S01: 书源启停/筛选/批量动作 | `done` |
| S-02 | `lib/features/source/views/source_edit_view.dart` | 复扫未命中 `shadcn_ui`，迁移项已落地 | `../legado/app/src/main/java/io/legado/app/ui/book/source/edit/BookSourceEditActivity.kt:60` | `UI-SOURCE` | R-S02: 编辑书源字段 -> 保存 -> 列表回显 | `done` |
| S-03 | `lib/features/settings/views/reading_behavior_settings_hub_view.dart` | 复扫未命中 `shadcn_ui`，迁移项已落地 | `../legado/app/src/main/java/io/legado/app/ui/book/read/config/MoreConfigDialog.kt:35`、`../legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadAloudConfigDialog.kt:33` | `UI-SETTINGS` | R-S03: 行为设置入口 -> 更多设置/朗读设置 -> 返回 | `done` |
| S-04 | `lib/features/settings/views/reading_interface_settings_hub_view.dart` | 复扫未命中 `shadcn_ui`，迁移项已落地 | `../legado/app/src/main/java/io/legado/app/ui/book/read/config/ReadStyleDialog.kt:36`、`../legado/app/src/main/java/io/legado/app/ui/book/read/config/BgTextConfigDialog.kt:69` | `UI-SETTINGS` | R-S04: 界面设置入口 -> 样式/背景/间距跳转与回退 | `done` |

### 3.2 非 Cupertino 弹窗清退条目（1 文件）

| ID | 文件 | 本轮差异结论 | 对应 legado 锚点 | 负责人 | 手工回归路径 | 状态 |
|---|---|---|---|---|---|---|
| C-01 | `lib/features/reader/widgets/reader_padding_config_dialog.dart` | 复扫未命中 `showGeneralDialog`，已迁移至 Cupertino 弹窗链路 | `../legado/app/src/main/java/io/legado/app/ui/book/read/config/PaddingConfigDialog.kt:17`、`../legado/app/src/main/java/io/legado/app/ui/book/read/config/PaddingConfigDialog.kt:29` | `UI-SETTINGS` | R-C01: 阅读页打开边距设置 -> 调整数值 -> 关闭回显 | `done` |

### 3.3 核心页面大标题导航（可执行迁移口径）

> 当前仓库 `CupertinoSliverNavigationBar` 命中为 `1`（壳层能力已具备）；`useSliverNavigationBar` 全量命中为 `7`（其中 `: true` 为 `4`）；核心页 `N-01~N-04` 均已接入 `useSliverNavigationBar: true`（大标题导航）。

`N-AC-01 标题折叠`
- 页面首帧展示 large title；上滑进入 inline 标题；回滚到顶部后恢复 large title。

`N-AC-02 滚动行为`
- 标题折叠由主滚动容器驱动，滚动过程中不出现标题闪烁、抖动、错位。
- 顶部 tab 重点按触发的回顶行为（如已有 `reselect/compress` 信号）应与大标题状态同步回到展开态。

`N-AC-03 返回手势不回退`
- 四个核心页作为 `CupertinoTabView` 根页面，右滑返回手势不得触发根路由 `pop` 或页面回退。
- 从核心页进入二级页面后，二级页面仍保持 iOS 侧滑返回能力。

| ID | 文件 | 执行口径 | 对应 legado 锚点 | 负责人 | 依赖关系 | 手工回归路径 | 状态 |
|---|---|---|---|---|---|---|---|
| N-01 | `lib/features/bookshelf/views/bookshelf_view.dart` | 已接入大标题壳层能力（`useSliverNavigationBar: true` + `sliverBodyBuilder`），需保持现有 trailing/菜单行为；验收按 `N-AC-01~03` | `../legado/app/src/main/java/io/legado/app/ui/main/MainActivity.kt:141`、`../legado/app/src/main/java/io/legado/app/ui/main/bookshelf/BaseBookshelfFragment.kt:42` | `UI-NAV` | 前置 `N-PRE-01` 已完成；实现侧已完成，证据由 `N-VAL-01` 统一回填 | R-N01: 书架首屏滚动、折叠/展开、侧滑返回校验 + 空态/列表 Cupertino 一致性校验 | `done` |
| N-02 | `lib/features/discovery/views/discovery_view.dart` | 已接入大标题壳层能力（`useSliverNavigationBar: true` + `sliverBodyBuilder`，单滚动容器驱动折叠）；验收按 `N-AC-01~03` | `../legado/app/src/main/java/io/legado/app/ui/main/MainActivity.kt:141`、`../legado/app/src/main/java/io/legado/app/ui/main/explore/ExploreFragment.kt:50` | `UI-NAV` | 与其余 `N-*` 并行实施已完成，证据由 `N-VAL-01` 统一回填 | R-N02: 发现页滚动、折叠稳定性、侧滑返回校验 | `done` |
| N-03 | `lib/features/rss/views/rss_subscription_view.dart` | 已接入大标题壳层能力（`useSliverNavigationBar: true` + `sliverBodyBuilder`，单滚动容器驱动折叠）；空态 `noEnabled` 分支按钮已改为调用 `_openSourceSettings`（进入订阅源管理），语义已对齐 legado；验收按 `N-AC-01~03` | `../legado/app/src/main/java/io/legado/app/ui/main/MainActivity.kt:141`、`../legado/app/src/main/java/io/legado/app/ui/main/rss/RssFragment.kt:48` | `UI-NAV` | 与其余 `N-*` 并行实施已完成；`NAV-DIFF-01` 已修复，证据由 `N-VAL-01` 统一回填 | R-N03: 订阅页滚动、折叠稳定性、侧滑返回校验 + 空态 `noEnabled` 按钮语义校验 | `done` |
| N-04 | `lib/features/settings/views/settings_view.dart` | 已接入大标题壳层能力（`useSliverNavigationBar: true` + `sliverBodyBuilder`，单滚动容器驱动折叠）；验收按 `N-AC-01~03` | `../legado/app/src/main/java/io/legado/app/ui/main/MainActivity.kt:141`、`../legado/app/src/main/java/io/legado/app/ui/main/my/MyFragment.kt:43` | `UI-NAV` | 与其余 `N-*` 并行实施已完成，证据由 `N-VAL-01` 统一回填 | R-N04: 我的页滚动、折叠行为、侧滑返回校验 | `done` |

### 3.4 导航专项前置与收口条目（状态）

`导航差异复扫结论（2026-02-27）`
- `NAV-DIFF-01=done`：`RssSubscriptionView` 空态 `noEnabled` 分支按钮已改为 `_openSourceSettings` 进入订阅源管理，与 legado 对照语义一致；该项不再作为 `N-03` 与 `N-VAL-01` 的前置阻塞。

| ID | 条目 | 执行口径 | 负责人 | 状态 |
|---|---|---|---|---|
| N-PRE-01 | 壳层导航能力前置 | `AppCupertinoPageScaffold` 已具备 `useSliverNavigationBar` / `sliverBodyBuilder` / `sliverScrollController`，前置能力已满足 | `UI-CORE` | `done` |
| N-VAL-01 | 导航专项回归收口 | 统一回填 `N-AC-01~03` 与“排版布局一致性”证据；依据 `C6-T01` 证据终态（`R-N01~R-N04`），当前结论为 `blocked`，待可交互环境完成回补后再更新为收口终态 | `UI-NAV` | `blocked（证据终态同步）` |

`本轮依赖与收口约束（执行冻结）`
- 跨台账唯一串行依赖：`D-03 -> D-04`
- UI 导航专项收口约束：`N-01~N-04` 已完成且 `NAV-DIFF-01` 已修复完成；`N-VAL-01` 已按 `C6-T01` 证据终态同步为 `blocked`，待可交互环境完成回补后再更新。

## 4. 例外记录（AGENTS 1.1.2）

### EX-NAV-01（legacy Toolbar 与 iOS Large Title 映射）

- 状态: `tracked`（非阻塞）
- 原因:
  - legado 主导航为 Android `Toolbar/TitleBar` 语义，无法直接提供 iOS `Large Title` 折叠阈值锚点。
  - 已可确认“页面入口与功能语义”对照关系，故采用 Cupertino 官方折叠语义作为迁移口径。
- 影响范围:
  - `N-01`~`N-04`（书架/发现/订阅/我的四个核心页面）。
- 替代方案:
  - 以 `CupertinoSliverNavigationBar` 官方行为落实 `N-AC-01~03`；
  - legacy 仅用于页面职责、入口与动作语义对照，不用于折叠阈值反推。
- 回补计划:
  1. 若后续需求方提供更细折叠策略，更新 `N-AC-*` 并追补回归记录。
  2. `N-VAL-01` 收口时，逐页回填标题折叠、滚动行为、返回手势三项证据。

## 5. 后续实现准入规则

1. 任何 UI 改造任务必须先引用本台账 ID（`S-*`/`C-*`/`N-*`）。
2. 本台账为本轮唯一基线；新增差异需先补录条目再进入实现。
3. `S-01~S-04` 与 `C-01` 条目维持 `done`；按 1.2 复扫基线（`rg -n "shadcn_ui" lib`）已归零，后续实现以 `N-01~N-04` 完成后进入 `N-VAL-01` 收口为唯一推进链路。
4. `N-01~N-04` 必须满足 `N-AC-01~N-AC-03` 后方可标记 `done`。
5. 导航专项本轮实施冻结为 `N-01~N-04(并行) -> N-VAL-01(统一收口)`；`N-PRE-01` 为已完成前置记录，不计入本轮实施项。
6. 回归记录必须包含“排版布局一致性”结论，不得只记录功能可用性。
