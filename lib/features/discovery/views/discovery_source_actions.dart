import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/book_source.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../search/models/search_scope.dart';
import '../../search/views/search_view.dart';
import '../../source/services/source/explore_kinds_service.dart';
import '../../source/services/source_login/url_resolver.dart';
import '../../source/views/edit/source_edit_view.dart';
import '../../source/views/login/login_form_view.dart';
import '../../source/views/login/login_webview_view.dart';

/// 把书源置顶（自定义排序设为最小值 - 1）。
Future<void> moveDiscoverySourceToTop({
  required SourceRepository sourceRepo,
  required String sourceUrl,
}) async {
  final key = sourceUrl.trim();
  if (key.isEmpty) return;

  final currentSource = sourceRepo.getSourceByUrl(key);
  if (currentSource == null) return;

  final all = sourceRepo.getAllSources();
  final minOrder = all.isEmpty
      ? currentSource.customOrder
      : all.map((item) => item.customOrder).reduce(math.min);

  await sourceRepo.updateSource(
    currentSource.copyWith(customOrder: minOrder - 1),
  );
}

/// 跳转到书源编辑页（按 sourceUrl 取出当前书源；不存在时打开空模板）。
Future<void> openDiscoverySourceEditor({
  required BuildContext context,
  required SourceRepository sourceRepo,
  required String sourceUrl,
}) async {
  final key = sourceUrl.trim();
  if (key.isEmpty || !context.mounted) return;
  final current = sourceRepo.getSourceByUrl(key);
  if (current == null) {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const SourceEditView(initialRawJson: '{}'),
      ),
    );
    return;
  }

  await Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => SourceEditView.fromSource(
        current,
        rawJson: sourceRepo.getRawJsonByUrl(current.bookSourceUrl),
      ),
    ),
  );
}

/// 打开书源登录入口（loginUi 优先，回退到 WebView）。
Future<void> openDiscoverySourceLogin({
  required BuildContext context,
  required SourceRepository sourceRepo,
  required BookSource source,
  required void Function(String message) showMessage,
}) async {
  final currentSource = sourceRepo.getSourceByUrl(source.bookSourceUrl);
  if (currentSource == null) {
    showMessage('未找到书源');
    return;
  }

  final hasLoginUi = (currentSource.loginUi ?? '').trim().isNotEmpty;
  if (hasLoginUi) {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceLoginFormView(source: currentSource),
      ),
    );
    return;
  }

  final resolvedUrl = SourceLoginUrlResolver.resolve(
    baseUrl: currentSource.bookSourceUrl,
    loginUrl: currentSource.loginUrl ?? '',
  );
  if (resolvedUrl.isEmpty) {
    showMessage('当前书源未配置登录地址');
    return;
  }
  final uri = Uri.tryParse(resolvedUrl);
  final scheme = uri?.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    showMessage('登录地址不是有效网页地址');
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => SourceLoginWebViewView(
        source: currentSource,
        initialUrl: resolvedUrl,
      ),
    ),
  );
}

/// 跳转到搜索页，并把当前书源设为搜索范围。
Future<void> searchInDiscoverySource({
  required BuildContext context,
  required SettingsService settingsService,
  required BookSource source,
}) async {
  final nextScope = SearchScope.fromSource(source);
  final currentSettings = settingsService.appSettings;
  if (currentSettings.searchScope != nextScope) {
    await settingsService.saveAppSettings(
      currentSettings.copyWith(searchScope: nextScope),
    );
  }
  if (!context.mounted) return;

  await Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => const SearchView(),
    ),
  );
}

/// 弹出「确认删除」对话框，确认后真正删除书源。
Future<bool> confirmDeleteDiscoverySource({
  required BuildContext context,
  required SourceRepository sourceRepo,
  required BookSource source,
}) async {
  final ok = await showCupertinoBottomSheetDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('提醒'),
          content: Text('是否确认删除？\n${source.bookSourceName}'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定'),
            ),
          ],
        ),
      ) ??
      false;

  if (!ok) return false;
  await deleteDiscoverySource(sourceRepo: sourceRepo, source: source);
  return true;
}

Future<void> deleteDiscoverySource({
  required SourceRepository sourceRepo,
  required BookSource source,
}) async {
  final sourceUrl = source.bookSourceUrl.trim();
  if (sourceUrl.isEmpty) return;

  try {
    await sourceRepo.deleteSource(sourceUrl);
    await SourceVariableStore.removeVariable(sourceUrl);
  } catch (error, stackTrace) {
    ExceptionLogService().record(
      node: 'explore_item.menu_del',
      message: '删除书源失败',
      error: error,
      stackTrace: stackTrace,
      context: <String, dynamic>{
        'sourceKey': sourceUrl,
        'sourceName': source.bookSourceName,
      },
    );
  }
}

/// 清除发现入口缓存并返回是否成功；失败时调用 [showMessage] 通知。
Future<bool> clearDiscoverySourceKindsCache({
  required SourceExploreKindsService exploreKindsService,
  required BookSource source,
  required void Function(String message) showMessage,
}) async {
  try {
    await exploreKindsService.clearExploreKindsCache(source);
    return true;
  } catch (e, st) {
    ExceptionLogService().record(
      node: 'discovery.refresh_kinds',
      message: '刷新发现入口缓存失败',
      error: e,
      stackTrace: st,
      context: <String, dynamic>{
        'sourceUrl': source.bookSourceUrl,
        'sourceName': source.bookSourceName,
      },
    );
    showMessage('刷新发现入口失败，请稍后重试');
    return false;
  }
}
