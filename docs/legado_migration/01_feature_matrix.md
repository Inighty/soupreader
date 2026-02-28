# 01 — 功能对照矩阵（Legado -> SoupReader）

> 本文件是迁移验收的唯一台账。任何“已对齐”的结论必须能在此逐项查到，并附带验收步骤与回归记录。

## 状态图例

- 待对齐
- 已存在待核对
- 已对齐
- blocked
- 排除

## A. 主导航 / 首页 Tab

| 模块/页面 | Legado 入口 | Legado 关键文件 | 交互语义要点（摘要） | SoupReader 对应入口 | SoupReader 关键文件 | 当前状态 | 验收步骤（手工回归） |
|---|---|---|---|---|---|---|---|
| 主界面 Tab | BottomNavigation + ViewPager | `ui/main/MainActivity.kt` | Tab 显示受设置控制；双击重按 300ms：书架回顶、发现折叠/回顶 | CupertinoTabScaffold | `lib/main.dart` | 已存在待核对（双击时序已按 legado 对齐） | 1) 双击书架 Tab 回顶；2) 双击发现 Tab 折叠/回顶；3) 关闭发现入口后 Tab 数变化且当前 Tab 迁移合理 |
| 默认主页 | AppConfig.defaultHomePage | `ui/main/MainActivity.kt` | 默认主页受 showDiscovery/showRSS 约束 | defaultHomePage | `lib/core/models/app_settings.dart`, `lib/main.dart` | 已存在待核对 | 设置默认主页为发现/我的/书架，重启后落在对应 Tab（排除项应被隐藏且不会落入） |

## B. 发现（Explore）

| 模块/页面 | Legado 入口 | Legado 关键文件 | 交互语义要点（摘要） | SoupReader 对应入口 | SoupReader 关键文件 | 当前状态 | 验收步骤（手工回归） |
|---|---|---|---|---|---|---|---|
| 发现列表 | 首页 Tab「发现」 | `ui/main/explore/ExploreFragment.kt` | 搜索框即时过滤；`group:` 分组过滤；分组菜单动态生成；空态提示；项操作：打开/编辑源/置顶/删除/搜索 | 发现 Tab | `lib/features/discovery/views/discovery_view.dart`, `lib/features/discovery/services/discovery_filter_helper.dart` | 已存在待核对 | 1) 输入关键字过滤；2) 输入 `group:xxx` 过滤；3) 分组选择动作；4) 空态/非空态切换；5) 对单项执行置顶/删除/编辑/搜索 |
| 发现二级页 | ExploreShowActivity | `ui/book/explore/ExploreShowActivity.kt` | 单源单发现入口结果页，支持继续浏览/加入书架等 | DiscoveryExploreResultsView | `lib/features/discovery/views/discovery_explore_results_view.dart` | 已存在待核对 | 打开二级发现页：列表展示、加载/错误/空态、点击条目进入详情/阅读 |

## C. 书架（Bookshelf）

| 模块/页面 | Legado 入口 | Legado 关键文件 | 交互语义要点（摘要） | SoupReader 对应入口 | SoupReader 关键文件 | 当前状态 | 验收步骤（手工回归） |
|---|---|---|---|---|---|---|---|
| 书架（分组样式1） | 首页 Tab「书架」 | `ui/main/bookshelf/style1/BookshelfFragment1.kt` | 顶部 TabLayout 分组；长按分组编辑；重按分组 toast 显示“组名(数量)”；排序变更刷新策略 | BookshelfView | `lib/features/bookshelf/views/bookshelf_view.dart` | 已存在待核对 | 1) 分组切换；2) 长按分组入口；3) 重按 toast；4) 排序切换与刷新；5) 列表/网格切换 |
| 书架（分组样式2） | 首页 Tab「书架」 | `ui/main/bookshelf/style2/BookshelfFragment2.kt` | 已读取并补齐关键语义：子分组 Back 先返回根态；根态显示“分组卡 + 书籍列表”；根态仅展示有内容分组（全部分组除外） | BookshelfView | `lib/features/bookshelf/views/bookshelf_view.dart` | 已存在待核对（代码补齐） | 1) 样式二根态确认分组卡与书籍同屏；2) 进入子分组后按返回键回到根态；3) 无匹配书籍分组不显示；4) 双击书架 Tab 回顶 |
| 远程书籍（WebDav） | 书架菜单 | `ui/book/import/remote/**` | WebDav 服务器、远程列表、下载导入、已导入判定 | Remote books | `lib/features/bookshelf/services/remote_books_*` | 已存在待核对 | 1) 配置 WebDav；2) 浏览远程列表；3) 下载导入；4) 已导入状态正确；5) 异常提示与日志 |

## D. 搜索 / 详情页 / 加入书架

| 模块/页面 | Legado 入口 | Legado 关键文件 | 交互语义要点（摘要） | SoupReader 对应入口 | SoupReader 关键文件 | 当前状态 | 验收步骤（手工回归） |
|---|---|---|---|---|---|---|---|
| 搜索 | 搜索 Activity | `ui/book/search/**` | 多书源并发、搜索范围、精准开关、分页加载、“继续加载”出现规则 | SearchView | `lib/features/search/views/search_view.dart` | 已存在待核对 | 1) 关键字搜索；2) 精准开关；3) 多源结果展示；4) 下一页加载；5) 空态与提示 |
| 详情页菜单 | BookInfoActivity | `ui/book/info/**` | 刷新/置顶/分享/加入书架/换源/缓存等菜单可见性规则 | SearchBookInfoView | `lib/features/search/views/search_book_info_view.dart`, `lib/features/search/services/*helper.dart` | 已存在待核对 | 进入详情页：菜单项出现/隐藏与 legado 同义；点击各菜单项无崩溃且提示明确 |
| 分享 | menu_share_it | `ui/book/info/**` | 分享载荷语义（如 `bookUrl#bookJson`） | share helper | `lib/features/search/services/search_book_info_share_helper.dart` | 已存在待核对 | 1) 分享到系统；2) 载荷格式符合约定；3) 无分享能力时提示明确 |

## E. 书源（导入/编辑/调试/登录）

| 模块/页面 | Legado 入口 | Legado 关键文件 | 交互语义要点（摘要） | SoupReader 对应入口 | SoupReader 关键文件 | 当前状态 | 验收步骤（手工回归） |
|---|---|---|---|---|---|---|---|
| 书源列表 | 书源管理 | `ui/book/source/manage/**` | 启用/禁用、分组、排序、导入导出、拦截域名提示、批量操作 | SourceListView | `lib/features/source/views/source_list_view.dart` | 已存在待核对 | 1) 导入 JSON/URL；2) 分组/排序；3) 启用禁用；4) 导出；5) 域名拦截提示与日志 |
| 书源编辑（Legacy） | 源编辑器 | `ui/book/source/edit/**` | 基础/规则/JSON/调试 多 Tab；保存/校验/调试；规则帮助 | SourceEditView | `lib/features/source/views/source_edit_view.dart`, `source_edit_legacy_view.dart` | 已存在待核对 | 1) 打开编辑；2) 修改保存；3) 规则调试；4) 错误提示与日志 |
| 登录流程 | loginUrl | `ui/login/**` | 有 loginUrl 才显示登录入口；支持表单/网页登录 | login views | `lib/features/source/views/source_login_*` | 已存在待核对 | 有 loginUrl 源：能走登录流程；无 loginUrl 源：不展示登录入口 |

## F. 替换/净化（Replace Rule）

| 模块/页面 | Legado 入口 | Legado 关键文件 | 交互语义要点（摘要） | SoupReader 对应入口 | SoupReader 关键文件 | 当前状态 | 验收步骤（手工回归） |
|---|---|---|---|---|---|---|---|
| 替换规则管理 | ReplaceRuleActivity | `ui/replace/**` | 列表/编辑/导入导出/测试；应用到正文 | ReplaceRuleList | `lib/features/replace/views/replace_rule_list_view.dart`, `lib/features/replace/services/*` | 已存在待核对 | 1) 导入规则；2) 开关启用；3) 测试替换；4) 阅读器正文应用验证 |

## G. 阅读器（排除朗读后）

| 模块/页面 | Legado 入口 | Legado 关键文件 | 交互语义要点（摘要） | SoupReader 对应入口 | SoupReader 关键文件 | 当前状态 | 验收步骤（手工回归） |
|---|---|---|---|---|---|---|---|
| 阅读菜单（顶/底） | ReadMenu | `ui/book/read/ReadMenu.kt` | 顶部点书名进详情；亮度自动/手动；进度条 page/chapter 行为与确认；夜间模式；上一章下一章；目录；界面；设置（朗读入口排除） | reader menu | `lib/features/reader/widgets/reader_bottom_menu.dart`, `lib/features/reader/views/simple_reader_view.dart` | 已存在待核对 | 1) 菜单呼出/隐藏；2) 亮度；3) 进度条；4) 目录/书签；5) 替换规则入口；6) 异常日志记录 |
| 文本选择菜单 | TextActionMenu | `ui/book/read/TextActionMenu.kt` | 复制/分享/浏览器或搜索；系统处理文本；更多菜单折叠/展开 | selection menu | `lib/features/reader/views/simple_reader_view.dart` | 已存在待核对 | 长按选择文字：菜单项齐全且行为正确；无能力时提示明确 |
| 内容内搜索菜单 | SearchMenu | `ui/book/read/SearchMenu.kt` | 搜索结果上下跳转；返回主菜单；退出 | in-reader search | `lib/features/reader/views/simple_reader_view.dart` | 已存在待核对 | 阅读器内搜索：结果数、跳转、退出与主菜单切换 |

## H. 本地书 / 导入 / 目录规则

| 模块/页面 | Legado 入口 | Legado 关键文件 | 交互语义要点（摘要） | SoupReader 对应入口 | SoupReader 关键文件 | 当前状态 | 验收步骤（手工回归） |
|---|---|---|---|---|---|---|---|
| TXT/EPUB 导入 | import local | `ui/book/import/local/**` | 扫描/选择/导入、章节目录解析（txtTocRule） | import service | `lib/features/import/import_service.dart`, `txt_parser.dart`, `epub_parser.dart`, `lib/features/reader/models/txt_toc_rule.dart` | 已存在待核对 | 1) 导入 txt/epub；2) 目录解析正确；3) 进入阅读器；4) 进度保存 |

## I. 备份/恢复（不走启动弹窗）

| 模块/页面 | Legado 入口 | Legado 关键文件 | 交互语义要点（摘要） | SoupReader 对应入口 | SoupReader 关键文件 | 当前状态 | 验收步骤（手工回归） |
|---|---|---|---|---|---|---|---|
| 自动检查新备份 | MainActivity.backupSync | `ui/main/MainActivity.kt` | 启动后发现 WebDav 新备份则弹窗提示恢复 | BackupSettings | `lib/features/settings/views/backup_settings_view.dart`, `lib/core/services/settings_service.dart`（迁移策略改为“进入备份页后检测”） | 已存在待核对 | 进入备份页后检测远端新备份：页面内提示 -> 点击恢复 -> 二次确认 -> 执行恢复 |

## J. 排除项（入口隐藏）

| 模块/页面 | 说明 | Legado 关键文件 | SoupReader 关键文件 | 当前状态 | 验收步骤 |
|---|---|---|---|---|---|
| RSS | 本轮排除 | `ui/main/rss/**`, `ui/rss/**` | `lib/features/rss/**`, `lib/core/config/migration_exclusions.dart` | 排除 | 默认构建下 UI 看不到 RSS Tab/设置入口 |
| TTS | 本轮排除 | `service/BaseReadAloudService` 等 | `lib/features/reader/services/read_aloud_service.dart` 等 | 排除 | 默认构建下 UI 看不到朗读入口 |
| 漫画 | 本轮排除 | `ui/book/manga/**` | 相关设置入口 | 排除 | 默认构建下 UI 看不到漫画入口 |
| WebService | 本轮排除 | `app/api/**`, `app/web/**` | 相关设置入口 | 排除 | 默认构建下 UI 看不到 WebService 入口 |
