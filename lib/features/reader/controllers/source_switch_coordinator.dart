import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/book.dart';
import '../../../core/models/book_source.dart';
import '../../../core/services/settings_service.dart';
import '../../source/services/rule_parser/rule_parser_engine.dart';
import '../services/reader_source_switch_helper.dart';
import 'reader_state.dart';

/// 换源纯逻辑委托。
///
/// 所有需要 BuildContext 的对话框操作在 `source_switch_dialogs.dart` 中。
/// 此类只处理数据——搜索候选源、执行切换、维护换源状态。
class SourceSwitchCoordinator {
  SourceSwitchCoordinator({
    required this.bookId,
    required this.chapter,
    required this.image,
    required this.sourceRepo,
    required this.ruleEngine,
    required this.settingsService,
    required this.onSourceSwitched,
  });

  final String bookId;
  final ChapterState chapter;
  final ImageCacheState image;
  final SourceRepository sourceRepo;
  final RuleParserEngine ruleEngine;
  final SettingsService settingsService;

  /// 换源成功后回调，传入新的源 URL。
  final Future<void> Function(String newSourceUrl) onSourceSwitched;

  // ── 换源设置 ──
  bool checkAuthor = false;
  bool loadInfo = false;
  bool loadWordCount = false;
  bool loadToc = false;
  String group = '';
  int delaySeconds = 0;
  CancelToken? _searchCancelToken;
  bool isAutoChanging = false;

  // ═══════════════════════════════════════════════════════════════════
  // 源解析
  // ═══════════════════════════════════════════════════════════════════

  /// 获取当前活跃的书源。
  BookSource? resolveCurrentSource() {
    final url = (image.sourceUrl ?? '').trim();
    if (url.isEmpty) return null;
    return sourceRepo.getSourceByUrl(url);
  }

  /// 构建换源时使用的 Book 对象。
  Book buildCurrentBookForSwitch() {
    return Book(
      id: bookId,
      title: chapter.chapters.isNotEmpty
          ? chapter.chapters.first.bookId
          : bookId,
      author: image.bookAuthor,
      sourceUrl: image.sourceUrl,
      coverUrl: image.bookCoverUrl,
    );
  }

  /// 获取当前章节标题（用于换源搜索）。
  String resolveCurrentChapterTitle() {
    if (chapter.chapters.isEmpty) return '';
    final idx = chapter.currentIndex.clamp(0, chapter.maxIndex);
    return chapter.chapters[idx].title;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 候选源搜索
  // ═══════════════════════════════════════════════════════════════════

  /// 搜索换源候选。
  Future<List<ReaderSourceSwitchCandidate>> searchCandidates({
    required String keyword,
    String? authorKeyword,
  }) async {
    stopCandidateSearch();
    _searchCancelToken = CancelToken();

    try {
      final sources = sourceRepo.getAllSources();
      final candidates = <ReaderSourceSwitchCandidate>[];

      for (final source in sources) {
        if (_searchCancelToken?.isCancelled ?? true) break;
        try {
          final results = await ruleEngine.search(
            source,
            keyword,
          );
          for (final result in results) {
            if (authorKeyword != null &&
                checkAuthor &&
                !result.author.contains(authorKeyword)) {
              continue;
            }
            candidates.add(ReaderSourceSwitchCandidate(
              source: source,
              book: result,
            ));
          }
        } catch (_) {
          // Skip failed sources
        }
      }

      return candidates;
    } catch (e) {
      debugPrint('[source-switch] search error: $e');
      return [];
    }
  }

  void stopCandidateSearch() {
    _searchCancelToken?.cancel('stopped');
    _searchCancelToken = null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 执行换源
  // ═══════════════════════════════════════════════════════════════════

  /// 切换到指定候选源。
  Future<bool> switchToCandidate(ReaderSourceSwitchCandidate candidate) async {
    final newSourceUrl = candidate.source.bookSourceUrl;
    try {
      image.sourceUrl = newSourceUrl;
      image.sourceName = candidate.source.bookSourceName;

      await onSourceSwitched(newSourceUrl);
      return true;
    } catch (e) {
      debugPrint('[source-switch] switch error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 设置变更
  // ═══════════════════════════════════════════════════════════════════

  void updateCheckAuthor(bool value) {
    checkAuthor = value;
    unawaited(settingsService.saveChangeSourceCheckAuthor(value));
  }

  void updateLoadInfo(bool value) {
    loadInfo = value;
    unawaited(settingsService.saveChangeSourceLoadInfo(value));
  }

  void updateLoadWordCount(bool value) {
    loadWordCount = value;
    unawaited(settingsService.saveChangeSourceLoadWordCount(value));
  }

  void updateLoadToc(bool value) {
    loadToc = value;
    unawaited(settingsService.saveChangeSourceLoadToc(value));
  }

  void updateGroup(String value) {
    group = value.trim();
    unawaited(settingsService.saveChangeSourceGroup(group));
  }

  void updateDelay(int seconds) {
    delaySeconds = seconds.clamp(0, 9999);
    unawaited(settingsService.saveBatchChangeSourceDelay(delaySeconds));
  }

  // ═══════════════════════════════════════════════════════════════════
  // 工具
  // ═══════════════════════════════════════════════════════════════════

  /// 构建源分组列表。
  List<String> buildSourceGroups() {
    final sources = sourceRepo.getAllSources();
    final groups = <String>{};
    for (final source in sources) {
      final g = (source.bookSourceGroup ?? '').trim();
      if (g.isNotEmpty) groups.add(g);
    }
    return groups.toList()..sort();
  }

  void dispose() {
    stopCandidateSearch();
  }
}

// ReaderSourceSwitchCandidate 定义在
// reader_source_switch_helper.dart 中。
