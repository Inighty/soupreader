import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../models/rss_source.dart';
import '../services/rss_source_import_export_service.dart';
import '../services/rss_source_manage_helper.dart';

/// 把所选源 URL 在仓库中映射成最新对象（自动跳过已不存在的项）。
List<RssSource> _resolveCurrentSources(
  RssSourceRepository repo,
  Iterable<String> selectedUrls,
) {
  final result = <RssSource>[];
  for (final sourceUrl in selectedUrls) {
    final current = repo.getByKey(sourceUrl);
    if (current != null) result.add(current);
  }
  return result;
}

/// 提取 selected 中所有非空 sourceUrl。
Set<String> _selectedUrlsOf(Iterable<RssSource> selected) {
  return selected
      .map((source) => source.sourceUrl.trim())
      .where((url) => url.isNotEmpty)
      .toSet();
}

Future<void> _runSelectionUpdate({
  required RssSourceRepository repo,
  required List<RssSource> selected,
  required RssSource Function(RssSource current) transform,
  required String logNode,
  required String logMessage,
  Map<String, dynamic> extraContext = const <String, dynamic>{},
}) async {
  if (selected.isEmpty) return;
  final selectedUrls = _selectedUrlsOf(selected);
  if (selectedUrls.isEmpty) return;
  final currents = _resolveCurrentSources(repo, selectedUrls);
  final updates = currents.map(transform).toList(growable: false);
  if (updates.isEmpty) return;
  try {
    await repo.updateSources(updates);
  } catch (error, stackTrace) {
    ExceptionLogService().record(
      node: logNode,
      message: logMessage,
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'selectedCount': selected.length,
        'updateCount': updates.length,
        'sourceUrls':
            updates.map((source) => source.sourceUrl).toList(growable: false),
        ...extraContext,
      },
    );
  }
}

Future<void> enableRssSelection({
  required RssSourceRepository repo,
  required List<RssSource> selected,
}) =>
    _runSelectionUpdate(
      repo: repo,
      selected: selected,
      transform: (current) => current.copyWith(enabled: true),
      logNode: 'rss_source_sel.menu_enable_selection',
      logMessage: 'RSS 源管理启用所选失败',
    );

Future<void> disableRssSelection({
  required RssSourceRepository repo,
  required List<RssSource> selected,
}) =>
    _runSelectionUpdate(
      repo: repo,
      selected: selected,
      transform: (current) => current.copyWith(enabled: false),
      logNode: 'rss_source_sel.menu_disable_selection',
      logMessage: 'RSS 源管理禁用所选失败',
    );

Future<void> addGroupToRssSelection({
  required RssSourceRepository repo,
  required List<RssSource> selected,
  required String groupInput,
}) =>
    _runSelectionUpdate(
      repo: repo,
      selected: selected,
      transform: (current) => current.addGroup(groupInput),
      logNode: 'rss_source_sel.menu_add_group',
      logMessage: 'RSS 源管理添加分组失败',
      extraContext: {'groupInput': groupInput},
    );

Future<void> removeGroupFromRssSelection({
  required RssSourceRepository repo,
  required List<RssSource> selected,
  required String groupInput,
}) =>
    _runSelectionUpdate(
      repo: repo,
      selected: selected,
      transform: (current) => current.removeGroup(groupInput),
      logNode: 'rss_source_sel.menu_remove_group',
      logMessage: 'RSS 源管理移除分组失败',
      extraContext: {'groupInput': groupInput},
    );

Future<void> moveRssSelectionToTop({
  required RssSourceRepository repo,
  required List<RssSource> selected,
}) async {
  if (selected.isEmpty) return;
  final selectedUrls = _selectedUrlsOf(selected);
  if (selectedUrls.isEmpty) return;
  final currents = _resolveCurrentSources(repo, selectedUrls);
  if (currents.isEmpty) return;
  final sorted = currents.toList(growable: false)
    ..sort((a, b) => a.customOrder.compareTo(b.customOrder));
  final minOrder = repo.minOrder - 1;
  final updates = sorted
      .asMap()
      .entries
      .map((entry) =>
          entry.value.copyWith(customOrder: minOrder - entry.key))
      .toList(growable: false);
  try {
    await repo.updateSources(updates);
  } catch (error, stackTrace) {
    ExceptionLogService().record(
      node: 'rss_source_sel.menu_top_sel',
      message: 'RSS 源管理置顶所选失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'selectedCount': selected.length,
        'updateCount': updates.length,
        'minOrderBase': minOrder,
        'sourceUrls':
            updates.map((source) => source.sourceUrl).toList(growable: false),
      },
    );
  }
}

Future<void> moveRssSelectionToBottom({
  required RssSourceRepository repo,
  required List<RssSource> selected,
}) async {
  if (selected.isEmpty) return;
  final selectedUrls = _selectedUrlsOf(selected);
  if (selectedUrls.isEmpty) return;
  final currents = _resolveCurrentSources(repo, selectedUrls);
  if (currents.isEmpty) return;
  final sorted = currents.toList(growable: false)
    ..sort((a, b) => a.customOrder.compareTo(b.customOrder));
  final maxOrder = repo.maxOrder + 1;
  final updates = sorted
      .asMap()
      .entries
      .map((entry) =>
          entry.value.copyWith(customOrder: maxOrder + entry.key))
      .toList(growable: false);
  try {
    await repo.updateSources(updates);
  } catch (error, stackTrace) {
    ExceptionLogService().record(
      node: 'rss_source_sel.menu_bottom_sel',
      message: 'RSS 源管理置底所选失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'selectedCount': selected.length,
        'updateCount': updates.length,
        'maxOrderBase': maxOrder,
        'sourceUrls':
            updates.map((source) => source.sourceUrl).toList(growable: false),
      },
    );
  }
}

/// 导出所选到本地文件，结果通过回调暴露：返回 outputPath（成功）或错误消息（失败）。
Future<({String? outputPath, String? error, bool cancelled})>
    exportRssSelection({
  required RssSourceImportExportService importExportService,
  required List<RssSource> selected,
}) async {
  final result = await importExportService.exportToFile(
    selected,
    defaultFileName: 'exportRssSource.json',
  );
  if (result.cancelled) return (outputPath: null, error: null, cancelled: true);
  if (!result.success) {
    return (
      outputPath: null,
      error: result.errorMessage ?? '导出失败',
      cancelled: false,
    );
  }
  return (
    outputPath: (result.outputPath ?? '').trim(),
    error: null,
    cancelled: false,
  );
}

Future<void> shareRssSelection({
  required RssSourceImportExportService importExportService,
  required List<RssSource> selected,
}) async {
  try {
    final file = await importExportService.exportToShareFile(selected);
    if (file == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'text/*')]),
    );
  } catch (_) {
    // 对齐 legado Context.share(file)：分享异常不追加提示。
  }
}

/// 把可视范围内介于已选的最小 / 最大下标的所有源全部加入选择。
void checkSelectedInterval({
  required List<RssSource> visibleSources,
  required Set<String> selectedSourceUrls,
}) {
  if (selectedSourceUrls.isEmpty || visibleSources.isEmpty) return;
  int? minIndex;
  int? maxIndex;
  for (var index = 0; index < visibleSources.length; index++) {
    final sourceUrl = visibleSources[index].sourceUrl.trim();
    if (sourceUrl.isEmpty || !selectedSourceUrls.contains(sourceUrl)) continue;
    minIndex = minIndex == null || index < minIndex ? index : minIndex;
    maxIndex = maxIndex == null || index > maxIndex ? index : maxIndex;
  }
  if (minIndex == null || maxIndex == null) return;
  for (var index = minIndex; index <= maxIndex; index++) {
    final sourceUrl = visibleSources[index].sourceUrl.trim();
    if (sourceUrl.isEmpty) continue;
    selectedSourceUrls.add(sourceUrl);
  }
}

Future<void> moveRssSourceToTop({
  required RssSourceRepository repo,
  required RssSource source,
}) async {
  final sourceUrl = source.sourceUrl.trim();
  if (sourceUrl.isEmpty) return;
  final current = repo.getByKey(sourceUrl);
  if (current == null) return;
  final updated = RssSourceManageHelper.moveToTop(
    source: current,
    minOrder: repo.minOrder,
  );
  try {
    await repo.updateSource(updated);
  } catch (error, stackTrace) {
    ExceptionLogService().record(
      node: 'rss_source_item.menu_top',
      message: 'RSS 源管理置顶失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'sourceUrl': sourceUrl,
        'sourceName': current.sourceName,
        'fromOrder': current.customOrder,
        'toOrder': updated.customOrder,
      },
    );
  }
}

Future<void> moveRssSourceToBottom({
  required RssSourceRepository repo,
  required RssSource source,
}) async {
  final sourceUrl = source.sourceUrl.trim();
  if (sourceUrl.isEmpty) return;
  final current = repo.getByKey(sourceUrl);
  if (current == null) return;
  final updated = RssSourceManageHelper.moveToBottom(
    source: current,
    maxOrder: repo.maxOrder,
  );
  try {
    await repo.updateSource(updated);
  } catch (error, stackTrace) {
    ExceptionLogService().record(
      node: 'rss_source_item.menu_bottom',
      message: 'RSS 源管理置底失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'sourceUrl': sourceUrl,
        'sourceName': current.sourceName,
        'fromOrder': current.customOrder,
        'toOrder': updated.customOrder,
      },
    );
  }
}

Future<void> deleteRssSource({
  required RssSourceRepository repo,
  required RssSource source,
}) async {
  final sourceUrl = source.sourceUrl.trim();
  if (sourceUrl.isEmpty) return;
  final current = repo.getByKey(sourceUrl);
  if (current == null) return;
  try {
    await repo.deleteSourceWithArticles(sourceUrl);
    await SourceVariableStore.removeVariable(sourceUrl);
  } catch (error, stackTrace) {
    ExceptionLogService().record(
      node: 'rss_source_item.menu_del',
      message: 'RSS 源管理删除订阅源失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'sourceUrl': sourceUrl,
        'sourceName': current.sourceName,
      },
    );
  }
}

/// 在 [BuildContext] 弹出导出成功 toast（无 outputPath 时）。
void showRssExportToast(BuildContext context) {
  unawaited(showAppToast(context, message: '导出成功'));
}
