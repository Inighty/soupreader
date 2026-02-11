# SoupReader 开发进度日志

## 2026-02-11（开发计划文档重整：按功能组织）

### 已完成
- 按当前 AGENTS 规则完成功能全盘梳理，并建立 `docs/DEV_PLAN.md`。
- 以 legado 的功能行为与边界处理为参照，完成关键参考实现阅读并形成差距优先级（P0/P1/P2）。
- 输出分阶段开发计划（阶段 A~D）与本周启动 Todo。

### 为什么
- 需求要求“根据规则梳理所有功能并开始建立开发计划”。
- 在“legado 优先”的前提下，先明确差距与优先级，避免后续改动偏离兼容目标。

### 验证方式
- 文档检查：`docs/DEV_PLAN.md`
- 文档检查：`docs/DEV_PROGRESS.md`

### 兼容影响
- 本次仅新增计划与进度文档，不涉及运行时代码改动。
- 对旧书源兼容性无直接行为影响。

## 2026-02-11（UI/UX 重构：接入 Shadcn + Cupertino）

### 已完成
- 引入 `shadcn_ui`，应用入口改为 `ShadApp.custom + CupertinoApp`，统一亮/暗配色（`lib/app/theme/shadcn_theme.dart`）。
- 页面容器 `AppCupertinoPageScaffold` 改为读取 `ShadTheme` 的色板与边框，减少自绘样式分叉。
- 书架/发现/搜索/书源/设置 等主页面替换为 shadcn 组件（`ShadInput`/`ShadButton`/`ShadCard`/`ShadSwitch`/`ShadDialog`），保留原有业务逻辑与数据流。

### 为什么
- 按 AGENTS UI 规范统一使用 `Shadcn + Cupertino`，提升一致性并降低后续页面样式维护成本。

### 验证方式
- `flutter analyze`

### 兼容影响
- 本次为 UI 与主题层调整，未改动书源解析、网络请求、规则执行、数据库结构。
- 对旧书源兼容性无直接影响（仅界面控件与样式变化）。
