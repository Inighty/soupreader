# SoupReader ExecPlans

## 2026-02-27 UI 台账二次复扫与 N 口径固化（本轮唯一基线）
- 状态: `active`
- 范围: 复扫基线 + `N-01~N-04` 大标题接入 + `N-VAL-01` 回归收口（证据回填）。
- 本轮实施边界: 仅执行 `N-01~N-04 -> N-VAL-01` + `M-01`（`lib/` 下 `material.dart` 残留导入清退）；`N-PRE-01` 为已完成前置记录。
- 关联文档:
  - `docs/plans/2026-02-27-ui-cupertino-diff.md`

### 执行拆分（依赖与并行性）
1. 串行：重扫 `shadcn_ui`、`showGeneralDialog`、`useSliverNavigationBar`（并补充校验 `CupertinoSliverNavigationBar`）命中并冻结统计。`done`
2. 串行：按复扫结果回填 `S-01~S-04`、`C-01` 状态（归零收口）。`done`
3. 串行：将 `N-01~N-04` 固化为可执行迁移口径并补齐 `N-AC-01~N-AC-03` 验收标准。`done`
4. 串行前置：`N-PRE-01`（壳层大标题容器能力改造）。`done`
5. 并行：`N-01~N-04`（四个核心页大标题接入）。`in_progress`（`N-02~N-04` 已接入；待 `N-VAL-01` 收口）
6. 串行：`N-VAL-01`（四页手工回归证据回填）。`pending`（前置实现已具备，待回填证据）

### 依赖关系
- `N-PRE-01 -> N-01/N-02/N-03/N-04 -> N-VAL-01`
- `N-01/N-02/N-03/N-04 -> N-VAL-01`（本轮实施链）
- `S-01~S-04`、`C-01` 已归零，不再占用本轮依赖链。

## 2026-02-27 UI 差异台账重扫回填（串行前置，复核）
- 状态: `done`
- 范围: 仅执行 `lib/` 定向检索与台账回填，不改动功能代码。
- 关联文档:
  - `docs/plans/2026-02-27-ui-cupertino-diff.md`

### 执行拆分（依赖与并行性）
1. 串行：重扫 `shadcn_ui`、`Shad*`、`showGeneralDialog`、`CupertinoSliverNavigationBar` 命中并固化计数。`done`
2. 串行：按扫描结果回填“待迁移文件/计数/状态”，清理过期条目。`done`
3. 串行：复核台账文件列表与统计数字一致，作为后续实现唯一基线。`done`（本轮复核）

## 2026-02-26 我的菜单迁移前置基线重建
- 状态: `active`
- 范围: 仅重建台账与清单，不在本任务实现功能。
- 关联文档:
  - `docs/plans/2026-02-26-my-menu-id-diff.md`
  - `docs/plans/2026-02-26-my-menu-parity-checklist.md`

### 执行拆分（依赖与并行性）
1. 串行：完成 legado 基线对照读取（`pref_main.xml/main_my.xml` + 相关 `menu/xml`）并形成差异点清单。`done`
2. 并行：按 14 个 `my_menu_*` 一级入口建立“入口 -> 关键二级链路”映射。`done`
3. 并行：归并二级链路关键差异，产出可执行回补项。`done`
4. 串行：记录无法等价项，按 AGENTS `1.1.2` 标记 `blocked` 并补齐四要素。`done`
5. 串行：后续实现任务以台账为唯一基线推进。`pending`

## 2026-02-26 D-01~D-05 当前实现锚点复核
- 状态: `done`
- 范围: 仅校准差异台账文档，不实现功能。
- 关联文档:
  - `docs/plans/2026-02-26-my-menu-id-diff.md`
  - `docs/plans/2026-02-26-my-menu-parity-checklist.md`

### 执行拆分（依赖与并行性）
1. 串行：基于当前仓库代码复核 `D-01~D-05` 的“当前实现”描述。`done`
2. 并行：为每个差异项回填实现锚点（目标文件/函数）与验收口径。`done`
3. 串行：复核并固定 `EX-01` 仍为 `blocked`，且仅占位验证。`done`

### 当前阻塞项
- `EX-01 Web服务`
  - 状态: `blocked`
  - 说明: 仅占位验证，不进入 webService 实现；需先完成服务生命周期与宿主能力确认后才能等价迁移。
  - 详情: 见 `docs/plans/2026-02-26-my-menu-id-diff.md` 的 `EX-01` 记录。

## 2026-02-27 UI Cupertino 差异迁移台账（shadcn 清退）
- 状态: `active`
- 范围: 迁移台账 + `N-01~N-04` 实施 + `N-VAL-01` 回归收口（证据回填）。
- 本轮实施边界: 仅执行 `N-01~N-04 -> N-VAL-01` + `M-01`（`lib/` 下 `material.dart` 残留导入清退）；`N-PRE-01` 为已完成前置记录。
- 关联文档:
  - `docs/plans/2026-02-27-ui-cupertino-diff.md`

### 执行拆分（依赖与并行性）
1. 串行：冻结 `shadcn_ui`、`showGeneralDialog`、`useSliverNavigationBar`（并补充校验 `CupertinoSliverNavigationBar`）差异清单。`done`
2. 串行：按最新基线收口 `S-01~S-04` 与 `C-01`。`done`
3. 串行：固化 `N-01~N-04` 可执行迁移口径与 `N-AC-01~N-AC-03` 验收标准。`done`
4. 串行前置：`N-PRE-01` 壳层大标题导航能力改造。`done`
5. 并行：核心页面大标题导航专项（`N-01~N-04`）。`in_progress`（`N-02~N-04` 已接入；待 `N-VAL-01` 收口）
6. 串行：手工回归证据回填并收口（`N-VAL-01`）。`pending`（前置实现已具备，待回填证据）

### 依赖关系
- `N-PRE-01 -> N-01/N-02/N-03/N-04 -> N-VAL-01`
- `N-01/N-02/N-03/N-04 -> N-VAL-01`（本轮实施链）

### 当前例外记录
- `EX-NAV-01 legacy Toolbar 与 iOS Large Title 映射`
  - 状态: `tracked`
  - 说明: 采用 Cupertino 官方大标题折叠语义作为迁移口径，legacy 用于页面职责/入口对照。
  - 详情: 见 `docs/plans/2026-02-27-ui-cupertino-diff.md` 的 `EX-NAV-01` 记录。
