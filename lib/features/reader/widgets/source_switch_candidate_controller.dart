import 'package:flutter/cupertino.dart';

import '../services/reader_source_switch_helper.dart';
import 'source_switch_candidate_dialogs.dart';
import 'source_switch_candidate_sheet.dart';

/// 候选 sheet 的状态控制器：把搜索/刷新/置顶/分组等异步操作与所有
/// 临时 busy 状态从 [SourceSwitchCandidateSheet] 中抽离出来，便于上层
/// widget 仅负责装配 UI。
class SourceSwitchCandidateController extends ChangeNotifier {
  SourceSwitchCandidateController(this._widget)
      : _checkAuthorEnabled = _widget.checkAuthorEnabled,
        _loadInfoEnabled = _widget.loadInfoEnabled,
        _loadWordCountEnabled = _widget.loadWordCountEnabled,
        _loadTocEnabled = _widget.loadTocEnabled,
        _changeSourceGroup = _widget.changeSourceGroup.trim(),
        _changeSourceDelaySeconds =
            _widget.changeSourceDelaySeconds.clamp(0, 9999).toInt(),
        _candidates = List<ReaderSourceSwitchCandidate>.from(
          _widget.candidates,
          growable: false,
        ) {
    queryController.addListener(_handleQueryChanged);
  }

  SourceSwitchCandidateSheet _widget;
  SourceSwitchCandidateSheet get widget => _widget;

  final TextEditingController queryController = TextEditingController();
  final FocusNode queryFocusNode = FocusNode();

  String _query = '';
  bool _filterExpanded = false;
  bool _openingSourceManage = false;
  bool _searchingCandidates = false;
  bool _stoppingCandidates = false;
  bool _refreshingCandidates = false;
  bool _runningToggle = false;
  bool _updatingSourceDelay = false;
  bool _updatingSourceGroup = false;
  bool _runningCandidateOp = false;
  int _candidateSearchRequestSerial = 0;
  bool _checkAuthorEnabled;
  bool _loadInfoEnabled;
  bool _loadWordCountEnabled;
  bool _loadTocEnabled;
  String _changeSourceGroup;
  int _changeSourceDelaySeconds;
  List<ReaderSourceSwitchCandidate> _candidates;
  bool _disposed = false;

  String get query => _query;
  bool get filterExpanded => _filterExpanded;
  bool get openingSourceManage => _openingSourceManage;
  bool get searchingCandidates => _searchingCandidates;
  bool get stoppingCandidates => _stoppingCandidates;
  bool get refreshingCandidates => _refreshingCandidates;
  bool get updatingSourceGroup => _updatingSourceGroup;
  bool get loadWordCountEnabled => _loadWordCountEnabled;
  String get changeSourceGroup => _changeSourceGroup;
  List<ReaderSourceSwitchCandidate> get candidates => _candidates;

  bool get anyCandidateOpBusy => _runningCandidateOp;
  bool get anyToggleBusy => _runningToggle || _updatingSourceDelay;

  List<ReaderSourceSwitchCandidate> get filteredCandidates {
    final filtered = ReaderSourceSwitchHelper.filterCandidates(
      candidates: _candidates,
      query: _query,
    );
    return ReaderSourceSwitchHelper.filterCandidatesByAuthor(
      candidates: filtered,
      authorKeyword: widget.authorKeyword,
      checkAuthorEnabled: _checkAuthorEnabled,
    );
  }

  void updateWidget(SourceSwitchCandidateSheet next) {
    final prev = _widget;
    _widget = next;
    var changed = false;
    void apply(bool cond, void Function() set) {
      if (!cond) return;
      set();
      changed = true;
    }
    apply(prev.checkAuthorEnabled != next.checkAuthorEnabled,
        () => _checkAuthorEnabled = next.checkAuthorEnabled);
    apply(prev.loadInfoEnabled != next.loadInfoEnabled,
        () => _loadInfoEnabled = next.loadInfoEnabled);
    apply(prev.loadWordCountEnabled != next.loadWordCountEnabled,
        () => _loadWordCountEnabled = next.loadWordCountEnabled);
    apply(prev.loadTocEnabled != next.loadTocEnabled,
        () => _loadTocEnabled = next.loadTocEnabled);
    apply(prev.changeSourceGroup != next.changeSourceGroup,
        () => _changeSourceGroup = next.changeSourceGroup.trim());
    apply(
        prev.changeSourceDelaySeconds != next.changeSourceDelaySeconds,
        () => _changeSourceDelaySeconds =
            next.changeSourceDelaySeconds.clamp(0, 9999).toInt());
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    queryFocusNode.dispose();
    queryController
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _set(VoidCallback fn) {
    if (_disposed) return;
    fn();
    notifyListeners();
  }

  void _handleQueryChanged() {
    final value = queryController.text;
    if (value == _query) return;
    _set(() => _query = value);
  }

  void openFilter() {
    if (_filterExpanded) {
      queryFocusNode.requestFocus();
      return;
    }
    _set(() => _filterExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) queryFocusNode.requestFocus();
    });
  }

  void collapseFilter() {
    queryFocusNode.unfocus();
    queryController.clear();
    if (!_filterExpanded) return;
    _set(() => _filterExpanded = false);
  }

  Future<void> handleOpenSourceManage() async {
    final cb = widget.onOpenSourceManage;
    if (cb == null || _openingSourceManage || _refreshingCandidates) return;
    _set(() => _openingSourceManage = true);
    try {
      await cb();
    } finally {
      _set(() => _openingSourceManage = false);
    }
  }

  Future<void> handleStartCandidatesSearch() async {
    final cb = widget.onStartCandidatesSearch;
    if (cb == null ||
        _searchingCandidates ||
        _refreshingCandidates ||
        _openingSourceManage) {
      return;
    }
    _set(() {
      _searchingCandidates = true;
      _stoppingCandidates = false;
    });
    final requestSerial = ++_candidateSearchRequestSerial;
    final current = List<ReaderSourceSwitchCandidate>.from(_candidates);
    try {
      final searched = await cb(current);
      if (_disposed || requestSerial != _candidateSearchRequestSerial) return;
      _set(() => _candidates = List<ReaderSourceSwitchCandidate>.from(
            searched,
            growable: false,
          ));
    } catch (_) {
      // 与 legado 一致：停止/失败时保持当前列表，不追加扩展提示。
    } finally {
      if (!_disposed && requestSerial == _candidateSearchRequestSerial) {
        _set(() {
          _searchingCandidates = false;
          _stoppingCandidates = false;
        });
      }
    }
  }

  Future<void> handleStopCandidatesSearch() async {
    final cb = widget.onStopCandidatesSearch;
    if (cb == null || !_searchingCandidates || _stoppingCandidates) return;
    _set(() => _stoppingCandidates = true);
    try {
      await cb();
    } catch (_) {
      // 与 legado 一致：停止失败不追加提示。
    }
  }

  Future<void> handleRefreshCandidates() async {
    final cb = widget.onRefreshCandidates;
    if (cb == null ||
        _refreshingCandidates ||
        _searchingCandidates ||
        _openingSourceManage) {
      return;
    }
    _set(() => _refreshingCandidates = true);
    final current = List<ReaderSourceSwitchCandidate>.from(filteredCandidates);
    try {
      final refreshed = await cb(current);
      if (_disposed) return;
      _set(() => _candidates = List<ReaderSourceSwitchCandidate>.from(
            refreshed,
            growable: false,
          ));
    } catch (_) {
      // 与 legado 一致：刷新失败保持当前列表且不弹额外提示。
    } finally {
      _set(() => _refreshingCandidates = false);
    }
  }

  Future<void> _runCandidateOp({
    required SourceSwitchCandidatesUpdater? callback,
    required ReaderSourceSwitchCandidate candidate,
  }) async {
    if (callback == null ||
        anyCandidateOpBusy ||
        _openingSourceManage ||
        _refreshingCandidates ||
        _searchingCandidates ||
        _stoppingCandidates) {
      return;
    }
    _set(() => _runningCandidateOp = true);
    final current = List<ReaderSourceSwitchCandidate>.from(_candidates);
    try {
      final updated = await callback(candidate, current);
      if (_disposed) return;
      _set(() => _candidates = List<ReaderSourceSwitchCandidate>.from(
            updated,
            growable: false,
          ));
    } catch (_) {
      // 与 legado 一致：失败保持静默并维持当前候选列表。
    } finally {
      _set(() => _runningCandidateOp = false);
    }
  }

  Future<void> showCandidateActions(
    BuildContext context,
    ReaderSourceSwitchCandidate candidate,
  ) async {
    final hasCandidateActions = widget.onTopSourceCandidate != null ||
        widget.onEditSourceCandidate != null ||
        widget.onBottomSourceCandidate != null ||
        widget.onDisableSourceCandidate != null ||
        widget.onDeleteSourceCandidate != null;
    if (!hasCandidateActions ||
        anyCandidateOpBusy ||
        _openingSourceManage ||
        _refreshingCandidates ||
        _searchingCandidates ||
        _stoppingCandidates ||
        _updatingSourceGroup ||
        anyToggleBusy) {
      return;
    }
    final action = await showSourceSwitchCandidateActions(
      context: context,
      showTop: widget.onTopSourceCandidate != null,
      showBottom: widget.onBottomSourceCandidate != null,
      showEdit: widget.onEditSourceCandidate != null,
      showDisable: widget.onDisableSourceCandidate != null,
      showDelete: widget.onDeleteSourceCandidate != null,
    );
    if (action == null || _disposed) return;
    final cb = switch (action) {
      SourceSwitchCandidateAction.topSource => widget.onTopSourceCandidate,
      SourceSwitchCandidateAction.editSource => widget.onEditSourceCandidate,
      SourceSwitchCandidateAction.bottomSource =>
        widget.onBottomSourceCandidate,
      SourceSwitchCandidateAction.disableSource =>
        widget.onDisableSourceCandidate,
      SourceSwitchCandidateAction.deleteSource =>
        widget.onDeleteSourceCandidate,
    };
    if (action == SourceSwitchCandidateAction.deleteSource &&
        widget.confirmDeleteSourceCandidate) {
      if (!context.mounted) return;
      final confirmed = await confirmSourceSwitchDelete(
        context: context,
        candidate: candidate,
      );
      if (!confirmed) return;
    }
    await _runCandidateOp(callback: cb, candidate: candidate);
  }

  Future<void> _toggleFlag({
    required bool currentValue,
    required void Function(bool value) applyOptimistic,
    required Future<void> Function(bool value)? saver,
    Future<void> Function()? afterSave,
  }) async {
    if (saver == null) return;
    final next = !currentValue;
    _set(() {
      applyOptimistic(next);
      _runningToggle = true;
    });
    try {
      await saver(next);
      if (afterSave != null) await afterSave();
    } finally {
      _set(() => _runningToggle = false);
    }
  }

  Future<void> runToggle(
    BuildContext context,
    SourceSwitchMenuAction action,
  ) async {
    switch (action) {
      case SourceSwitchMenuAction.checkAuthor:
        await _toggleFlag(
          currentValue: _checkAuthorEnabled,
          applyOptimistic: (v) => _checkAuthorEnabled = v,
          saver: widget.onCheckAuthorChanged,
        );
      case SourceSwitchMenuAction.loadWordCount:
        await _toggleFlag(
          currentValue: _loadWordCountEnabled,
          applyOptimistic: (v) => _loadWordCountEnabled = v,
          saver: widget.onLoadWordCountChanged,
          afterSave: () async {
            if (_loadWordCountEnabled &&
                !_disposed &&
                widget.onRefreshCandidates != null &&
                !_refreshingCandidates &&
                !_searchingCandidates &&
                !_openingSourceManage) {
              await handleRefreshCandidates();
            }
          },
        );
      case SourceSwitchMenuAction.loadInfo:
        await _toggleFlag(
          currentValue: _loadInfoEnabled,
          applyOptimistic: (v) => _loadInfoEnabled = v,
          saver: widget.onLoadInfoChanged,
        );
      case SourceSwitchMenuAction.loadToc:
        await _toggleFlag(
          currentValue: _loadTocEnabled,
          applyOptimistic: (v) => _loadTocEnabled = v,
          saver: widget.onLoadTocChanged,
        );
      case SourceSwitchMenuAction.changeSourceDelay:
        await handleChangeSourceDelay(context);
    }
  }

  Future<void> handleChangeSourceGroup(
    BuildContext context,
    String nextGroup,
  ) async {
    final normalized = nextGroup.trim();
    if (_updatingSourceGroup || normalized == _changeSourceGroup) return;
    final cb = widget.onChangeSourceGroupChanged;
    _set(() {
      _changeSourceGroup = normalized;
      _updatingSourceGroup = true;
    });
    try {
      if (cb != null) await cb(normalized);
      if (widget.onStopCandidatesSearch != null) {
        await widget.onStopCandidatesSearch!();
        if (!_disposed && _searchingCandidates) {
          _set(() {
            _searchingCandidates = false;
            _stoppingCandidates = false;
          });
        }
      }
      if (widget.onStartCandidatesSearch != null) {
        await handleStartCandidatesSearch();
      }
      if (!_disposed &&
          _changeSourceGroup.isNotEmpty &&
          _candidates.isEmpty &&
          cb != null &&
          widget.onStartCandidatesSearch != null) {
        if (!context.mounted) return;
        final fallback = await confirmSourceSwitchGroupToAll(
          context: context,
          group: _changeSourceGroup,
        );
        if (_disposed || !fallback) return;
        _changeSourceGroup = '';
        await cb('');
        if (widget.onStopCandidatesSearch != null) {
          await widget.onStopCandidatesSearch!();
        }
        await handleStartCandidatesSearch();
      }
    } finally {
      _set(() => _updatingSourceGroup = false);
    }
  }

  Future<void> showGroupActions(BuildContext context) async {
    if (_updatingSourceGroup ||
        _openingSourceManage ||
        _refreshingCandidates ||
        anyToggleBusy) {
      return;
    }
    final groups = <String>{
      for (final raw in widget.sourceGroups)
        if (raw.trim().isNotEmpty) raw.trim(),
    }.toList(growable: false);
    final selected = await showSourceSwitchGroupActions(
      context: context,
      groups: groups,
      selectedGroup: _changeSourceGroup.trim(),
    );
    if (selected == null) return;
    if (!context.mounted) return;
    await handleChangeSourceGroup(context, selected);
  }

  Future<void> showMoreActions(BuildContext context) async {
    if (_openingSourceManage ||
        _refreshingCandidates ||
        _updatingSourceGroup ||
        anyToggleBusy) {
      return;
    }
    final action = await showSourceSwitchMoreActions(
      context: context,
      showCheckAuthor: widget.onCheckAuthorChanged != null,
      showLoadWordCount: widget.onLoadWordCountChanged != null,
      showLoadInfo: widget.onLoadInfoChanged != null,
      showLoadToc: widget.onLoadTocChanged != null,
      showChangeSourceDelay: widget.onChangeSourceDelayChanged != null,
      checkAuthorEnabled: _checkAuthorEnabled,
      loadWordCountEnabled: _loadWordCountEnabled,
      loadInfoEnabled: _loadInfoEnabled,
      loadTocEnabled: _loadTocEnabled,
      changeSourceDelaySeconds: _changeSourceDelaySeconds,
    );
    if (action == null) return;
    if (!context.mounted) return;
    await runToggle(context, action);
  }

  Future<void> handleChangeSourceDelay(BuildContext context) async {
    final cb = widget.onChangeSourceDelayChanged;
    if (cb == null || _updatingSourceDelay) return;
    final picked = await showSourceSwitchDelayPicker(
      context: context,
      initialSeconds: _changeSourceDelaySeconds,
    );
    if (_disposed || picked == null) return;
    final next = picked.clamp(0, 9999).toInt();
    if (next == _changeSourceDelaySeconds) return;
    _set(() {
      _changeSourceDelaySeconds = next;
      _updatingSourceDelay = true;
    });
    try {
      await cb(next);
    } finally {
      _set(() => _updatingSourceDelay = false);
    }
  }
}
