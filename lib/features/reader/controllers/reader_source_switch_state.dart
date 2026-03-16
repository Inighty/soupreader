import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Holds all mutable state for the source-switching feature.
///
/// Extracted from `_SimpleReaderViewState` so that the 15+ source-related
/// fields live in one cohesive object. The View creates one instance and
/// passes it into source-switch helper methods.
class ReaderSourceSwitchState extends ChangeNotifier {
  String bookAuthor = '';
  String? bookCoverUrl;
  String? currentSourceUrl;
  String? currentSourceName;

  final Map<String, bool> chapterVipByUrl = {};
  final Map<String, bool> chapterPayByUrl = {};

  bool changeSourceCheckAuthor = false;
  bool changeSourceLoadInfo = false;
  bool changeSourceLoadWordCount = false;
  bool changeSourceLoadToc = false;
  String changeSourceGroup = '';
  int changeSourceDelaySeconds = 0;

  CancelToken? sourceSwitchCandidateSearchCancelToken;
  bool isAutoChangingSource = false;
  bool offlineCacheRunning = false;

  /// Update book info after a successful source switch.
  void updateBookInfo({
    required String author,
    String? coverUrl,
    String? sourceUrl,
    String? sourceName,
  }) {
    bookAuthor = author;
    bookCoverUrl = coverUrl;
    currentSourceUrl = sourceUrl;
    currentSourceName = sourceName;
    notifyListeners();
  }

  /// Cancel any in-flight source-switch candidate search.
  void stopCandidateSearch() {
    sourceSwitchCandidateSearchCancelToken?.cancel('stopped');
    sourceSwitchCandidateSearchCancelToken = null;
  }

  @override
  void dispose() {
    stopCandidateSearch();
    super.dispose();
  }
}
