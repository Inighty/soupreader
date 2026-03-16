import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../models/reader_view_models.dart';

/// Callback for loading a chapter's content by index.
typedef SearchChapterContentLoader = Future<String?> Function(
  int chapterIndex,
);

/// Callback for post-processing content (replace rules + Chinese conversion).
typedef SearchContentProcessor = Future<String> Function(String raw);

/// Callback to navigate to a search hit.
typedef SearchHitNavigator = Future<void> Function(ReaderSearchHit hit);

/// Self-contained search overlay for the reader.
///
/// Manages its own search state (query, hits, current index, progress
/// snapshot). Communicates with the parent reader through callbacks.
class ReaderSearchOverlay extends StatefulWidget {
  const ReaderSearchOverlay({
    super.key,
    required this.visible,
    required this.chapters,
    required this.currentChapterIndex,
    required this.currentChapterProgress,
    required this.isDark,
    required this.accentColor,
    required this.panelBg,
    required this.textStrong,
    required this.textNormal,
    required this.textSubtle,
    required this.borderColor,
    required this.searchHighlightColor,
    required this.searchHighlightTextColor,
    required this.fontFamily,
    required this.fontFamilyFallback,
    required this.loadChapterContent,
    required this.processContent,
    required this.navigateToHit,
    required this.onClose,
    required this.onRequestRestoreProgress,
  });

  final bool visible;
  final List<dynamic> chapters;
  final int currentChapterIndex;
  final double currentChapterProgress;
  final bool isDark;
  final Color accentColor;
  final Color panelBg;
  final Color textStrong;
  final Color textNormal;
  final Color textSubtle;
  final Color borderColor;
  final Color searchHighlightColor;
  final Color searchHighlightTextColor;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final SearchChapterContentLoader loadChapterContent;
  final SearchContentProcessor processContent;
  final SearchHitNavigator navigateToHit;
  final VoidCallback onClose;
  final Future<bool> Function() onRequestRestoreProgress;

  @override
  State<ReaderSearchOverlay> createState() => ReaderSearchOverlayState();
}

class ReaderSearchOverlayState extends State<ReaderSearchOverlay>
    with SingleTickerProviderStateMixin {
  String _query = '';
  List<ReaderSearchHit> _hits = const [];
  int _currentHitIndex = -1;
  bool _isSearching = false;
  bool _useReplace = false;
  ReaderSearchProgressSnapshot? _progressSnapshot;
  int _taskToken = 0;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  /// The active search query for highlighting in the reader, or null.
  String? get activeHighlightQuery {
    if (_query.isEmpty || _hits.isEmpty) return null;
    return _query;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
  }

  @override
  void didUpdateWidget(covariant ReaderSearchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _animController.forward();
    } else if (!widget.visible && oldWidget.visible) {
      _animController.reverse();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Public API for parent ──

  /// Start a search with the given text.
  void searchText(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    _showSearchDialog(initialQuery: normalized);
  }

  /// Handle back navigation. Returns true if consumed.
  Future<bool> handleBack() async {
    if (_progressSnapshot != null) {
      final restore = await widget.onRequestRestoreProgress();
      if (restore) {
        _clear(clearSnapshot: true);
        widget.onClose();
        return true;
      }
    }
    _clear(clearSnapshot: true);
    widget.onClose();
    return true;
  }

  // ── Search logic ──

  void _showSearchDialog({String initialQuery = ''}) {
    final controller = TextEditingController(
      text: initialQuery.isNotEmpty ? initialQuery : _query,
    );
    showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('搜索内容'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '输入搜索关键词',
            autofocus: true,
            onSubmitted: (value) {
              Navigator.pop(ctx, value.trim());
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('搜索'),
          ),
        ],
      ),
    ).then((query) {
      controller.dispose();
      if (query != null && query.isNotEmpty) {
        _applySearch(query);
      }
    });
  }

  Future<void> _applySearch(String query) async {
    _captureProgressIfNeeded();
    _taskToken++;
    final token = _taskToken;

    setState(() {
      _query = query;
      _hits = const [];
      _currentHitIndex = -1;
      _isSearching = true;
    });

    final results = <ReaderSearchHit>[];
    final chapterCount = widget.chapters.length;

    for (int i = 0; i < chapterCount; i++) {
      if (_taskToken != token) return;
      final raw = await widget.loadChapterContent(i);
      if (_taskToken != token || !mounted) return;
      if (raw == null || raw.isEmpty) continue;

      final content = _useReplace
          ? await widget.processContent(raw)
          : raw;
      if (_taskToken != token || !mounted) return;

      final chapter = widget.chapters[i];
      final title = (chapter is dynamic && chapter.title != null)
          ? chapter.title as String
          : '第${i + 1}章';

      results.addAll(_collectHits(
        chapterIndex: i,
        chapterTitle: title,
        content: content,
        query: query,
      ));
    }

    if (_taskToken != token || !mounted) return;
    setState(() {
      _hits = results;
      _currentHitIndex = results.isEmpty ? -1 : 0;
      _isSearching = false;
    });

    if (results.isNotEmpty) {
      await widget.navigateToHit(results.first);
    }
  }

  List<ReaderSearchHit> _collectHits({
    required int chapterIndex,
    required String chapterTitle,
    required String content,
    required String query,
  }) {
    final lower = content.toLowerCase();
    final queryLower = query.toLowerCase();
    final hits = <ReaderSearchHit>[];
    var cursor = 0;
    var occurrence = 0;

    while (cursor < lower.length) {
      final idx = lower.indexOf(queryLower, cursor);
      if (idx < 0) break;

      const previewLen = 20;
      final beforeStart = (idx - previewLen).clamp(0, content.length);
      final afterEnd =
          (idx + query.length + previewLen).clamp(0, content.length);

      hits.add(ReaderSearchHit(
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        chapterContentLength: content.length,
        start: idx,
        end: idx + query.length,
        query: query,
        occurrenceIndex: occurrence,
        previewBefore: content.substring(beforeStart, idx),
        previewMatch: content.substring(idx, idx + query.length),
        previewAfter: content.substring(idx + query.length, afterEnd),
        pageIndex: null,
      ));
      occurrence++;
      cursor = idx + 1;
    }
    return hits;
  }

  void _navigate(int delta) {
    if (_hits.isEmpty) return;
    final next = (_currentHitIndex + delta).clamp(0, _hits.length - 1);
    if (next == _currentHitIndex) return;
    setState(() => _currentHitIndex = next);
    unawaited(widget.navigateToHit(_hits[_currentHitIndex]));
  }

  void _captureProgressIfNeeded() {
    _progressSnapshot ??= ReaderSearchProgressSnapshot(
      chapterIndex: widget.currentChapterIndex,
      chapterProgress: widget.currentChapterProgress,
    );
  }

  void _clear({bool clearSnapshot = true}) {
    _taskToken++;
    setState(() {
      _query = '';
      _hits = const [];
      _currentHitIndex = -1;
      _isSearching = false;
      if (clearSnapshot) _progressSnapshot = null;
    });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    if (!widget.visible && _animController.isDismissed) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _buildOverlay(),
      ),
    );
  }

  Widget _buildOverlay() {
    final accent = widget.accentColor;
    final hit = (_currentHitIndex >= 0 && _currentHitIndex < _hits.length)
        ? _hits[_currentHitIndex]
        : null;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: widget.panelBg,
          border: Border(
            top: BorderSide(color: widget.borderColor, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: query + result count + options
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showSearchDialog(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? CupertinoColors.white.withValues(alpha: 0.08)
                                : CupertinoColors.black
                                    .withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _query.isEmpty ? '搜索内容...' : _query,
                            style: TextStyle(
                              color: _query.isEmpty
                                  ? widget.textSubtle
                                  : widget.textStrong,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isSearching)
                      const CupertinoActivityIndicator()
                    else
                      Text(
                        _hits.isEmpty
                            ? '无结果'
                            : '${_currentHitIndex + 1}/${_hits.length}',
                        style: TextStyle(
                          color: widget.textNormal,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Preview text
                if (hit != null)
                  _buildPreview(hit, accent),
                const SizedBox(height: 8),
                // Navigation row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavButton(
                      icon: CupertinoIcons.chevron_up,
                      onTap: _currentHitIndex > 0
                          ? () => _navigate(-1)
                          : null,
                      label: '上一个',
                    ),
                    _buildNavButton(
                      icon: CupertinoIcons.chevron_down,
                      onTap: _currentHitIndex < _hits.length - 1
                          ? () => _navigate(1)
                          : null,
                      label: '下一个',
                    ),
                    _buildNavButton(
                      icon: CupertinoIcons.xmark,
                      onTap: () {
                        _clear();
                        widget.onClose();
                      },
                      label: '关闭',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ReaderSearchHit hit, Color accent) {
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          color: widget.textNormal,
          fontSize: 13,
          fontFamily: widget.fontFamily,
          fontFamilyFallback: widget.fontFamilyFallback,
        ),
        children: [
          TextSpan(text: hit.previewBefore),
          TextSpan(
            text: hit.previewMatch,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: hit.previewAfter),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onTap,
    required String label,
  }) {
    final enabled = onTap != null;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: enabled ? widget.accentColor : widget.textSubtle,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: enabled ? widget.textNormal : widget.textSubtle,
            ),
          ),
        ],
      ),
    );
  }
}
