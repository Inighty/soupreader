import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/services/settings_service.dart';
import '../../../core/services/screen_brightness_service.dart';
import '../../../core/services/keep_screen_on_service.dart';
import '../../bookshelf/models/book.dart';
import '../controllers/reader_bookmark_controller.dart';
import '../controllers/reader_coordinator.dart';
import '../controllers/reader_read_aloud_controller.dart';
import '../controllers/reader_settings_controller.dart';
import '../controllers/reader_state.dart';
import '../services/read_aloud_service.dart' show ReadAloudChapterDirection;
import '../models/reader_view_models.dart';
import '../models/reading_settings.dart';
import '../widgets/auto_pager.dart';
import '../widgets/paged_reader_widget.dart';
import 'reader_dialog_helpers.dart';
import 'source_switch_dialogs.dart';
import '../widgets/reader_bottom_menu.dart';
import '../widgets/reader_menus.dart';
import '../widgets/reader_read_aloud_bar.dart';
import '../widgets/reader_search_overlay.dart';
import '../widgets/reader_status_bar.dart';

/// 阅读器入口 Widget（新架构）。
///
/// 职责：
/// 1. 创建状态分组 (Data Classes) + Coordinator
/// 2. 用 ListenableBuilder 监听各状态分组的变化
/// 3. 将 UI 事件分发给 Coordinator
///
/// **不包含任何业务逻辑**——所有逻辑在 [ReaderCoordinator] 中。
class ReaderView extends StatefulWidget {
  const ReaderView({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.initialChapter = 0,
    this.initialChapters,
    this.initialSourceUrl,
    this.initialSourceName,
    this.initialBookAuthor,
    this.initialBookCoverUrl,
  });

  /// 临时阅读模式（不关联书架）。
  const ReaderView.ephemeral({
    super.key,
    required String sessionId,
    required this.bookTitle,
    required this.initialChapters,
    required this.initialSourceUrl,
    this.initialSourceName,
    this.initialBookAuthor,
    this.initialBookCoverUrl,
    this.initialChapter = 0,
  }) : bookId = sessionId;

  final String bookId;
  final String bookTitle;
  final int initialChapter;
  final List<Chapter>? initialChapters;
  final String? initialSourceUrl;
  final String? initialSourceName;
  final String? initialBookAuthor;
  final String? initialBookCoverUrl;

  bool get isEphemeral => initialChapters != null;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── 状态分组（数据仓库）──
  late final ChapterState _chapter;
  late final UiState _ui;
  late final SettingsState _settings;
  late final ScrollModeState _scroll;
  late final PagedModeState _paged;
  late final ImageCacheState _image;

  // ── 逻辑委托（加工车间）──
  late final ReaderCoordinator _coordinator;

  // ── 焦点（键盘事件监听）──
  final FocusNode _focusNode = FocusNode();

  // ── 分页内容区域尺寸（用于 PageFactory 布局参数）──
  final GlobalKey _pagedContentKey = GlobalKey();

  // ── 首次进入阅读器时是否已触发首屏分页 ──
  bool _firstPaginateTriggered = false;

  // ── 动画（需要 vsync，必须在 State 中）──
  late final AnimationController _menuAnimController;
  late final Animation<double> _menuFadeAnim;
  late final Animation<Offset> _topMenuSlideAnim;
  late final Animation<Offset> _bottomMenuSlideAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. 创建状态分组
    _chapter = ChapterState();
    _ui = UiState();
    _settings = SettingsState();
    _scroll = ScrollModeState();
    _paged = PagedModeState();
    _image = ImageCacheState();

    // 2. 创建子 Controller
    final settingsCtrl = ReaderSettingsController(
      settingsService: SettingsService(),
      brightnessService: ScreenBrightnessService.instance,
      keepScreenOnService: KeepScreenOnService.instance,
      onSettingsChanged: _settings.update,
      isMounted: () => mounted,
    );

    final readAloudCtrl = ReaderReadAloudController(
      settingsService: SettingsService(),
      onRequestChapterSwitch: (direction) async {
        if (direction == ReadAloudChapterDirection.next) {
          _coordinator.nextChapter();
        } else {
          _coordinator.previousChapter();
        }
        return true;
      },
      onMessage: (msg) => _showToast(msg),
    );

    final bookmarkCtrl = ReaderBookmarkController(
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
    );

    // 3. 创建 Coordinator
    _coordinator = ReaderCoordinator(
      bookId: widget.bookId,
      bookTitle: widget.bookTitle,
      isEphemeral: widget.isEphemeral,
      chapter: _chapter,
      ui: _ui,
      settings: _settings,
      scroll: _scroll,
      paged: _paged,
      image: _image,
      settingsCtrl: settingsCtrl,
      readAloudCtrl: readAloudCtrl,
      bookmarkCtrl: bookmarkCtrl,
      postFrameCallback: (cb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cb();
        });
      },
      getPagedContentSize: () {
        final ctx = _pagedContentKey.currentContext;
        if (ctx == null) return null;
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return null;
        return box.size;
      },
    );

    // 4. 动画
    _menuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _menuFadeAnim = CurvedAnimation(
      parent: _menuAnimController,
      curve: Curves.easeOut,
    );
    _topMenuSlideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _menuAnimController,
      curve: Curves.easeOutCubic,
    ));
    _bottomMenuSlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _menuAnimController,
      curve: Curves.easeOutCubic,
    ));

    // 5. 监听菜单状态驱动动画
    _ui.addListener(_syncMenuAnimation);

    // 5b. 监听 toast 消息
    _ui.pendingToast.addListener(_onPendingToast);

    // 5c. 监听 chapter 状态：首次 isInitialized=true 时主动触发首屏分页
    _chapter.addListener(_onChapterStateChanged);

    // 6. 初始化
    unawaited(bookmarkCtrl.init());
    unawaited(readAloudCtrl.init());
    unawaited(_coordinator.init(
      initialChapter: widget.initialChapter,
      initialChapters: widget.initialChapters,
      sourceUrl: widget.initialSourceUrl,
      sourceName: widget.initialSourceName,
      bookAuthor: widget.initialBookAuthor,
      bookCoverUrl: widget.initialBookCoverUrl,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ui.pendingToast.removeListener(_onPendingToast);
    _ui.removeListener(_syncMenuAnimation);
    _chapter.removeListener(_onChapterStateChanged);
    _focusNode.dispose();
    _menuAnimController.dispose();
    _coordinator.dispose();
    _chapter.dispose();
    _ui.dispose();
    _settings.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _syncMenuAnimation() {
    if (_ui.showMenu) {
      _menuAnimController.forward();
    } else {
      _menuAnimController.reverse();
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ReaderDialogHelpers.showToast(context, message);
  }

  void _onPendingToast() {
    final message = _ui.pendingToast.value;
    if (message == null || message.isEmpty) return;
    _ui.pendingToast.value = null;
    _showToast(message);
  }

  /// 当 chapter 状态变化时被调用。
  /// 首次 [ChapterState.isInitialized] 变 true 时，PagedReaderWidget 才会被
  /// build/mount/layout。此处再 schedule 一次首屏分页，确保 RenderBox
  /// 已就绪后用真实尺寸分页（避免 init 流程中的时序竞速）。
  void _onChapterStateChanged() {
    if (_firstPaginateTriggered) return;
    if (!_chapter.isInitialized) return;
    _firstPaginateTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _coordinator.requestRepaginate(restoreOffset: true);
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // Build — 纯 UI 组合，监听各状态分组
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // 监听 chapter 状态驱动整体布局
    return ListenableBuilder(
      listenable: _chapter,
      builder: (context, _) {
        if (!_chapter.isInitialized) {
          return const CupertinoPageScaffold(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        return PopScope(
          canPop: !_ui.showMenu,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _coordinator.toggleMenu();
          },
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (event) {
              _coordinator.inputCoordinator.handleKeyEvent(
                event,
                readAloudPlaying:
                    _coordinator.readAloudController.snapshot.isPlaying,
              );
            },
            child: CupertinoPageScaffold(
              child: GestureDetector(
                onTapUp: (details) {
                  final screenSize = MediaQuery.sizeOf(context);
                  _coordinator.inputCoordinator.handleTap(
                    details.localPosition,
                    screenSize,
                  );
                },
                child: _buildStack(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStack(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        children: [
          // 背景层
          Positioned.fill(child: _buildBackground()),

          // 内容层
          Positioned.fill(child: _buildContent()),

          // 状态栏层
          _buildStatusBars(),

          // 菜单遮罩
          _buildMenuScrim(),

          // 菜单层
          _buildMenuOverlay(),

          // 搜索覆盖层
          _buildSearchOverlay(),

          // 自动阅读控制面板
          _buildAutoReadPanel(),

          // 朗读控制栏
          _buildReadAloudBar(),

          // 加载指示器
          if (_chapter.isLoading)
            const Positioned(
              top: 0, left: 0, right: 0,
              child: CupertinoActivityIndicator(),
            ),
        ],
      ),
    );
  }

  // ── 背景 ──

  Widget _buildBackground() {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final theme = _settings.themeResolver;
        return ColoredBox(color: theme.backgroundColor);
      },
    );
  }

  // ── 内容 ──

  Widget _buildContent() {
    return ListenableBuilder(
      listenable: Listenable.merge([_chapter, _settings]),
      builder: (context, _) {
        final isScroll =
            _settings.settings.pageTurnMode == PageTurnMode.scroll;
        if (isScroll) {
          return _buildScrollContent();
        }
        return _buildPagedContent();
      },
    );
  }

  Widget _buildPagedContent() {
    final theme = _settings.themeResolver;
    final readingSettings = _settings.settings;
    return KeyedSubtree(
      key: _pagedContentKey,
      child: PagedReaderWidget(
      pageFactory: _paged.pageFactory,
      pageTurnMode: readingSettings.pageTurnMode,
      textStyle: TextStyle(
        fontSize: readingSettings.fontSize,
        height: readingSettings.lineHeight,
        letterSpacing: readingSettings.letterSpacing,
        color: theme.currentTheme.text,
        fontFamily: _settings.customFontFamily,
      ),
      backgroundColor: theme.backgroundColor,
      backgroundUiImage: _settings.bgUiImage,
      padding: EdgeInsets.fromLTRB(
        readingSettings.paddingLeft,
        readingSettings.paddingTop,
        readingSettings.paddingRight,
        readingSettings.paddingBottom,
      ),
      settings: readingSettings,
      paddingDisplayCutouts: readingSettings.paddingDisplayCutouts,
      bookTitle: widget.bookTitle,
      clickActions: ClickAction.defaultZoneConfig,
      // PagedReaderWidget 内层 GestureDetector 会吃掉外层的 onTapUp，
      // 必须在这里连接 onTap，否则菜单区域点击事件被丢弃。
      onTap: () {
        final size = MediaQuery.sizeOf(context);
        _coordinator.inputCoordinator.handleTap(
          Offset(size.width / 2, size.height / 2),
          size,
        );
      },
      onAction: (action) {
        _coordinator.inputCoordinator.handleClickAction(action);
      },
      legacyImageStyle: _settings.imageStyle,
      onImageSizeResolved: (src, size) {
        _coordinator.imageCoordinator
            .handlePagedImageSizeResolved(src, size);
      },
      onImageSizeCacheUpdated: () {
        _paged.pendingImageRepagination = true;
      },
      onImageTap: (src) {
        ReaderDialogHelpers.openImagePreview(
          context: context,
          src: src,
        );
      },
      controller: _paged.pagedController,
      animDuration: readingSettings.pageAnimDuration,
      pageDirection: readingSettings.pageDirection,
      pageTouchSlop: readingSettings.pageTouchSlop,
      enableGestures: !_ui.showMenu,
    ),
    );
  }

  Widget _buildScrollContent() {
    // 滚动模式通过 ScrollController 和 ListView 驱动。
    // 段落数据来自 _scroll.segments，由 ScrollCoordinator 管理。
    return ValueListenableBuilder<int>(
      valueListenable: _scroll.segmentsVersion,
      builder: (context, _, __) {
        if (_scroll.segments.isEmpty) {
          return Center(
            child: Text(
              _chapter.currentTitle,
              style: TextStyle(
                color: _settings.themeResolver.currentTheme.text,
              ),
            ),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // ScrollCoordinator 通过 tick 机制处理，
            // 此处仅标记需要处理。
            return false;
          },
          child: ListView.builder(
            key: _scroll.viewportKey,
            controller: _scroll.controller,
            itemCount: _scroll.segments.length,
            itemBuilder: (context, index) {
              final segment = _scroll.segments[index];
              return Container(
                key: _scroll.segmentKeys.putIfAbsent(
                  segment.chapterIndex,
                  () => GlobalKey(
                    debugLabel: 'seg_${segment.chapterIndex}',
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: _settings.settings.paddingLeft,
                  vertical: 16,
                ),
                child: Text(
                  segment.content,
                  style: TextStyle(
                    fontSize: _settings.settings.fontSize,
                    height: _settings.settings.lineHeight,
                    letterSpacing: _settings.settings.letterSpacing,
                    color: _settings.themeResolver.currentTheme.text,
                    fontFamily: _settings.customFontFamily,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── 状态栏 ──

  Widget _buildStatusBars() {
    return ListenableBuilder(
      listenable: Listenable.merge([_ui, _settings]),
      builder: (context, _) {
        if (_ui.showMenu || _ui.showSearchMenu || _ui.showAutoReadPanel) {
          return const SizedBox.shrink();
        }
        final isScroll =
            _settings.settings.pageTurnMode == PageTurnMode.scroll;
        if (!isScroll) return const SizedBox.shrink();

        final readingSettings = _settings.settings;
        final theme = _settings.themeResolver.currentTheme;

        return ValueListenableBuilder<ScrollTipData>(
          valueListenable: _scroll.tipNotifier,
          builder: (context, tip, _) {
            return Stack(
              children: [
                // 底部状态栏
                if (readingSettings.shouldShowFooter())
                  ReaderStatusBar(
                    settings: readingSettings,
                    currentTheme: theme,
                    currentTime: tip.currentTime,
                    title: tip.title,
                    bookTitle: tip.bookTitle,
                    bookProgress: tip.bookProgress,
                    chapterProgress: tip.chapterProgress,
                    currentPage: tip.currentPage,
                    totalPages: tip.totalPages,
                  ),
                // 顶部状态栏
                if (readingSettings.shouldShowHeader(
                  showStatusBar: readingSettings.showStatusBar,
                ))
                  ReaderHeaderBar(
                    settings: readingSettings,
                    currentTheme: theme,
                    currentTime: tip.currentTime,
                    title: tip.title,
                    bookTitle: tip.bookTitle,
                    bookProgress: tip.bookProgress,
                    chapterProgress: tip.chapterProgress,
                    currentPage: tip.currentPage,
                    totalPages: tip.totalPages,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ── 菜单遮罩 ──

  Widget _buildMenuScrim() {
    return ListenableBuilder(
      listenable: _ui,
      builder: (context, _) {
        if (!_ui.showMenu && !_ui.showSearchMenu) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: FadeTransition(
            opacity: _menuFadeAnim,
            child: GestureDetector(
              onTap: _coordinator.closeMenu,
              child: Container(
                color: CupertinoColors.black.withValues(alpha: 0.15),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 菜单 ──

  Widget _buildMenuOverlay() {
    return ListenableBuilder(
      listenable: Listenable.merge([_ui, _chapter, _settings]),
      builder: (context, _) {
        if (!_ui.showMenu) return const SizedBox.shrink();
        final theme = _settings.themeResolver;
        final isLocal =
            _coordinator.actionsCoordinator.isCurrentBookLocal();
        final isLocalTxt =
            _coordinator.actionsCoordinator.isCurrentBookLocalTxt();

        return Stack(
          children: [
            // 顶部菜单
            ReaderTopMenu(
              onBack: () => Navigator.maybePop(context),
              bookTitle: widget.bookTitle,
              chapterTitle: _chapter.currentTitle,
              sourceName: _image.sourceName,
              currentTheme: theme.currentTheme,
              onOpenBookInfo: () {
                _coordinator.closeMenu();
                unawaited(ReaderDialogHelpers.openBookInfo(
                  context: context,
                  coordinator: _coordinator,
                ));
              },
              onOpenChapterLink: () {
                _coordinator.closeMenu();
                unawaited(ReaderDialogHelpers.openChapterLink(
                  context: context,
                  coordinator: _coordinator,
                ));
              },
              onToggleChapterLinkOpenMode: () {
                // 暂不支持 WebView/浏览器切换。
              },
              onChangeSource: () {
                _coordinator.closeMenu();
                unawaited(SourceSwitchDialogs.showSourceSwitchEntry(
                  context: context,
                  coordinator: _coordinator,
                ));
              },
              onRefresh: () {
                _coordinator.closeMenu();
                unawaited(_coordinator.loadChapter(
                  _chapter.currentIndex,
                ));
              },
              onShowSourceActions: () {
                _coordinator.closeMenu();
                unawaited(SourceSwitchDialogs.showSourceSwitchEntry(
                  context: context,
                  coordinator: _coordinator,
                ));
              },
              onShowMoreMenu: () {
                _coordinator.closeMenu();
                ReaderDialogHelpers.showMoreActionsMenu(
                  context: context,
                  coordinator: _coordinator,
                );
              },
              showChangeSourceAction: !isLocal,
              showRefreshAction: !isLocal,
              showDownloadAction: !isLocal,
              showTocRuleAction: isLocalTxt,
              showSetCharsetAction: isLocal,
              showSourceAction: !isLocal,
              showChapterLink: !isLocal,
              showTitleAddition: _settings.settings.showReadTitleAddition,
              readBarStyleFollowPage: false,
              menuFadeAnimation: _menuFadeAnim,
              menuSlideAnimation: _topMenuSlideAnim,
            ),

            // 底部菜单
            ReaderBottomMenuNew(
              currentChapterIndex: _chapter.currentIndex,
              totalChapters: _chapter.readableCount,
              currentPageIndex: _paged.pageFactory.currentPageIndex,
              totalPages:
                  _paged.pageFactory.totalPages.clamp(1, 999999),
              settings: _settings.settings,
              currentTheme: theme.currentTheme,
              onChapterChanged: (index) {
                unawaited(_coordinator.loadChapter(index));
              },
              onSeekChapterProgress: (progress) {
                unawaited(_coordinator.loadChapter(
                  progress,
                  restoreOffset: true,
                ));
              },
              onSeekPageProgress: (page) {
                _paged.pageFactory.jumpToPage(page);
              },
              onSettingsChanged: (newSettings) {
                _coordinator.updateSettings(newSettings);
              },
              onShowChapterList: () {
                _coordinator.closeMenu();
                ReaderDialogHelpers.showChapterList(
                  context: context,
                  coordinator: _coordinator,
                );
              },
              onShowReadAloud: () {
                _coordinator.closeMenu();
                unawaited(
                  _coordinator.readAloudController.toggleReadAloud(
                    chapterIndex: _chapter.currentIndex,
                    chapterTitle: _chapter.currentTitle,
                    content: _chapter.currentContent,
                  ),
                );
              },
              onShowInterfaceSettings: () {
                _coordinator.closeMenu();
                ReaderDialogHelpers.showStyleQuickSheet(
                  context: context,
                  settings: _settings.settings,
                  themes: _settings.themeResolver.activeStyles,
                  styleConfigs: _settings.settings.readStyleConfigs,
                  onSettingsChanged: (next) {
                    _coordinator.updateSettings(next);
                  },
                );
              },
              onShowBehaviorSettings: () {
                _coordinator.closeMenu();
                ReaderDialogHelpers.showBehaviorSettings(context);
              },
              onToggleAutoPage: () {
                _coordinator.closeMenu();
                unawaited(_coordinator.toggleAutoPage());
              },
              onSearchContent: () {
                _coordinator.closeMenu();
                _ui.toggleSearchMenu(true);
              },
              onToggleReplaceRule: () {
                _coordinator.closeMenu();
                unawaited(
                  _coordinator.actionsCoordinator.toggleReplaceRule(),
                );
              },
              onToggleNightMode: () {
                ReaderDialogHelpers.toggleDayNightTheme(
                  settings: _settings,
                  coordinator: _coordinator,
                );
              },
              showReadAloud: true,
              readBarStyleFollowPage: false,
              readAloudRunning:
                  _coordinator.readAloudController.snapshot.isRunning,
              readAloudPaused:
                  _coordinator.readAloudController.snapshot.isPaused,
              autoPageRunning: _ui.autoPager.isRunning,
              isNightMode: _settings.themeResolver.isDark,
              menuFadeAnimation: _menuFadeAnim,
              menuSlideAnimation: _bottomMenuSlideAnim,
            ),
          ],
        );
      },
    );
  }

  // ── 搜索覆盖层 ──

  Widget _buildSearchOverlay() {
    return ListenableBuilder(
      listenable: _ui,
      builder: (context, _) {
        if (!_ui.showSearchMenu) return const SizedBox.shrink();
        final theme = _settings.themeResolver;
        return ReaderSearchOverlay(
          visible: _ui.showSearchMenu,
          chapters: _chapter.chapters,
          currentChapterIndex: _chapter.currentIndex,
          currentChapterProgress: _coordinator.getChapterProgress(),
          isDark: theme.isDark,
          accentColor: theme.accent,
          panelBg: theme.panelBg,
          textStrong: theme.textStrong,
          textNormal: theme.textNormal,
          textSubtle: theme.textSubtle,
          borderColor: theme.border,
          searchHighlightColor: theme.accent.withValues(
            alpha: theme.isDark ? 0.28 : 0.2,
          ),
          searchHighlightTextColor:
              CupertinoColors.label.resolveFrom(context),
          fontFamily: _settings.customFontFamily,
          fontFamilyFallback: null,
          loadChapterContent: (index) async {
            if (index < 0 || index >= _chapter.chapters.length) {
              return '';
            }
            return _chapter.chapters[index].content ?? '';
          },
          processContent: (raw) async => raw,
          navigateToHit: (hit) async {
            await _coordinator.loadChapter(
              hit.chapterIndex,
              restoreOffset: true,
            );
          },
          onClose: () => _ui.toggleSearchMenu(false),
          onRequestRestoreProgress: () async => true,
        );
      },
    );
  }

  // ── 自动阅读面板 ──

  Widget _buildAutoReadPanel() {
    return ListenableBuilder(
      listenable: _ui,
      builder: (context, _) {
        if (!_ui.showAutoReadPanel) return const SizedBox.shrink();
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AutoReadPanel(
            autoPager: _ui.autoPager,
            onClose: () => _ui.toggleAutoReadPanel(false),
            onSpeedChanged: (speed) {
              _ui.autoPager.setSpeed(speed);
            },
            onShowMainMenu: () {
              _ui.toggleAutoReadPanel(false);
              _ui.autoPagerPausedByMenu = true;
              _ui.autoPager.pause();
              _coordinator.toggleMenu();
            },
            onOpenChapterList: () {
              _ui.toggleAutoReadPanel(false);
              ReaderDialogHelpers.showChapterList(
                context: context,
                coordinator: _coordinator,
              );
            },
            onStop: () {
              _ui.autoPager.stop();
              _ui.toggleAutoReadPanel(false);
            },
            onPause: () => _ui.autoPager.pause(),
            onResume: () => _ui.autoPager.resume(),
          ),
        );
      },
    );
  }

  // ── 朗读控制栏 ──

  Widget _buildReadAloudBar() {
    return ListenableBuilder(
      listenable: _coordinator.readAloudController,
      builder: (context, _) {
        final snapshot = _coordinator.readAloudController.snapshot;
        if (!snapshot.isRunning) return const SizedBox.shrink();

        final theme = _settings.themeResolver;
        return Positioned(
          top: 0, left: 0, right: 0,
          child: ReaderReadAloudBar(
            snapshot: snapshot,
            speechRate: _coordinator.readAloudController.speechRate,
            bgColor: theme.panelBg,
            fgColor: theme.textStrong,
            accentColor: theme.accent,
            onPreviousParagraph: () =>
                unawaited(_coordinator.readAloudController.previousParagraph()),
            onTogglePauseResume: () =>
                unawaited(_coordinator.readAloudController.togglePauseResume()),
            onNextParagraph: () =>
                unawaited(_coordinator.readAloudController.nextParagraph()),
            onStop: () =>
                unawaited(_coordinator.readAloudController.stop()),
            onSetTimer: () {
              // 朗读定时器选择对话框待迁移。
            },
            onOpenChapterList: () {
              ReaderDialogHelpers.showChapterList(
                context: context,
                coordinator: _coordinator,
              );
            },
            onSpeechRateChanged: (rate) {
              unawaited(_coordinator.readAloudController.updateSpeechRate(rate));
            },
            onPreviousChapter: _chapter.currentIndex > 0
                ? _coordinator.previousChapter
                : null,
            onNextChapter: _chapter.currentIndex < _chapter.maxIndex
                ? _coordinator.nextChapter
                : null,
          ),
        );
      },
    );
  }
}
