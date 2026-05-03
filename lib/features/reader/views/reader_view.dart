import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/services/keep_screen_on_service.dart';
import '../../../core/services/screen_brightness_service.dart';
import '../../../core/services/settings_service.dart';
import '../../bookshelf/models/book.dart';
import '../controllers/reader_bookmark_controller.dart';
import '../controllers/reader_coordinator.dart';
import '../controllers/reader_read_aloud_controller.dart';
import '../controllers/reader_settings_controller.dart';
import '../controllers/reader_state.dart';
import '../services/read_aloud_service.dart' show ReadAloudChapterDirection;
import 'reader_content.dart';
import 'reader_dialog_helpers.dart';
import 'reader_menu_overlay.dart';
import 'reader_overlays.dart';

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

    _chapter = ChapterState();
    _ui = UiState();
    _settings = SettingsState();
    _scroll = ScrollModeState();
    _paged = PagedModeState();
    _image = ImageCacheState();

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

    _ui.addListener(_syncMenuAnimation);
    _ui.pendingToast.addListener(_onPendingToast);
    _chapter.addListener(_onChapterStateChanged);

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

  @override
  Widget build(BuildContext context) {
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
          Positioned.fill(child: _buildBackground()),
          Positioned.fill(
            child: ReaderContent(
              coordinator: _coordinator,
              chapter: _chapter,
              settings: _settings,
              scroll: _scroll,
              paged: _paged,
              ui: _ui,
              bookTitle: widget.bookTitle,
              pagedContentKey: _pagedContentKey,
            ),
          ),
          ReaderStatusBars(
            ui: _ui,
            settings: _settings,
            scroll: _scroll,
          ),
          _buildMenuScrim(),
          ReaderMenuOverlay(
            coordinator: _coordinator,
            chapter: _chapter,
            ui: _ui,
            settings: _settings,
            paged: _paged,
            image: _image,
            bookTitle: widget.bookTitle,
            menuFadeAnimation: _menuFadeAnim,
            topMenuSlideAnimation: _topMenuSlideAnim,
            bottomMenuSlideAnimation: _bottomMenuSlideAnim,
          ),
          ReaderSearchOverlayHost(
            coordinator: _coordinator,
            ui: _ui,
            chapter: _chapter,
            settings: _settings,
          ),
          ReaderAutoReadPanelHost(
            coordinator: _coordinator,
            ui: _ui,
          ),
          ReaderReadAloudBarHost(
            coordinator: _coordinator,
            chapter: _chapter,
            settings: _settings,
          ),
          if (_chapter.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CupertinoActivityIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final theme = _settings.themeResolver;
        return ColoredBox(color: theme.backgroundColor);
      },
    );
  }

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
}
