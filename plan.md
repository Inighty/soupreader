# Cupertino iOS 风格统一计划（Taskmaster 完成版）

## 任务信息
- Taskmaster 任务目录：`.codex-tasks/20260304-planmd-execution`
- 执行模式：FULL
- 当前状态：已完成
- 完成时间：2026-03-04 20:50

## 目标与边界
### 目标
1. 以 Flutter Cupertino 语义统一全项目视觉风格，重点修复阅读器菜单与全站观感割裂。
2. 保持功能行为、交互路径、legacy 语义不变，仅重构视觉表达与样式来源。
3. 将样式来源收敛到 `AppUiTokens`、`App UI Kit`、`ReaderMenuUiTokens`。

### 非目标
1. 不改业务数据流、数据库结构、网络协议与功能逻辑。
2. 不引入 Material 组件体系或第三方 UI 框架。
3. 不做大规模信息架构重排，仅做视觉与层级重整。

### 约束
1. UI 主体系必须保持 Flutter Cupertino。
2. 字体继续使用 SF 语义（`AppTypography`）。
3. 弹层入口保持 `showCupertinoBottomDialog` / `showCupertinoBottomSheetDialog`。
4. 每个批次改造后必须执行 `flutter analyze`。

## 里程碑执行清单（已完成）

| ID | 任务 | 验收标准 | 验证命令 | 状态 | 完成时间 | 备注 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 生成全量 iOS 风格差异审计并冻结重设计规则 | 形成 `ui-ios-audit.md` 与 `ui-ios-rules.md` | `test -s .codex-tasks/20260304-planmd-execution/raw/ui-ios-rules.md` | DONE | 2026-03-04 20:27 | 已完成审计与规则冻结 |
| 2 | 重构全局主题与 UI Kit 以强化 iOS 基线 | 全局主题与基础组件完成收敛且可编译 | `flutter analyze` | DONE | 2026-03-04 20:49 | 全局基线复核通过并完成门禁回归 |
| 3 | 重设计阅读器菜单视觉语法并统一 token 来源 | `reader_top/bottom/menu_surface` 完成统一并可编译 | `flutter analyze` | DONE | 2026-03-04 20:49 | 阅读器菜单链路弹层入口统一 |
| 4 | 重设计阅读器目录与快速设置等核心弹层 | `reader_catalog/quick_settings` 统一并可编译 | `flutter analyze` | DONE | 2026-03-04 20:49 | 目录与快速设置弹层入口统一 |
| 5 | 批量修复阅读器残留硬编码样式分叉 | 阅读器高频硬编码样式显著收敛且可编译 | `flutter analyze` | DONE | 2026-03-04 20:49 | 修复阅读器 zero minimumSize 残留 |
| 6 | 执行全项目 iOS 一致性复核并修正 settings/search/bookshelf 残差 | 跨模块视觉与入口规则一致 | `flutter analyze` | DONE | 2026-03-04 20:49 | 跨模块入口规则收敛完成 |
| 7 | 执行全量规则扫描与分析门禁 | analyze 与规则扫描全部通过 | `flutter analyze` | DONE | 2026-03-04 20:49 | 规则扫描三项均 0 命中 |
| 8 | 产出最终总结与无遗漏证据 | 形成 `ui-ios-final-summary.md` | `test -s .codex-tasks/20260304-planmd-execution/raw/ui-ios-final-summary.md` | DONE | 2026-03-04 20:50 | 最终总结文档已落地 |
