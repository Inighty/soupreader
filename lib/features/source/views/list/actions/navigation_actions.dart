import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:soupreader/app/widgets/app_toast.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/core/utils/legado_json.dart';
import 'package:soupreader/features/search/models/search_scope.dart';
import 'package:soupreader/features/search/views/search_view.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_login/url_resolver.dart';
import 'package:soupreader/features/source/services/source_login/ui_helper.dart';
import 'package:soupreader/features/source/views/edit/source_edit_view.dart';
import 'package:soupreader/features/source/views/login/login_form_view.dart';
import 'package:soupreader/features/source/views/login/login_webview_view.dart';

class SourceListNavigationActions {
  const SourceListNavigationActions({
    required this.context,
    required this.sourceRepo,
    required this.settingsService,
  });

  final BuildContext context;
  final SourceRepository sourceRepo;
  final SettingsService settingsService;

  Future<void> createNewSource() async {
    final template = {
      'bookSourceUrl': '',
      'bookSourceName': '',
      'bookSourceGroup': null,
      'bookSourceType': 0,
      'customOrder': 0,
      'enabled': true,
      'enabledExplore': true,
      'enabledCookieJar': true,
      'respondTime': 180000,
      'weight': 0,
      'searchUrl': null,
      'exploreUrl': null,
      'ruleSearch': null,
      'ruleBookInfo': null,
      'ruleToc': null,
      'ruleContent': null,
    };
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceEditView(
          initialRawJson: LegadoJson.encode(template),
          originalUrl: null,
        ),
      ),
    );
  }

  Future<void> openEditor(
    String bookSourceUrl, {
    int? initialTab,
    String? initialDebugKey,
  }) async {
    final source = sourceRepo.getSourceByUrl(bookSourceUrl);
    if (source == null) {
      unawaited(showAppToast(context, message: '书源不存在或已被删除'));
      return;
    }
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceEditView.fromSource(
          source,
          rawJson: sourceRepo.getRawJsonByUrl(source.bookSourceUrl),
          initialTab: initialTab,
          initialDebugKey: initialDebugKey,
        ),
      ),
    );
  }

  Future<void> openSourceLogin(String bookSourceUrl) async {
    final source = sourceRepo.getSourceByUrl(bookSourceUrl);
    if (source == null) {
      unawaited(showAppToast(context, message: '未找到书源'));
      return;
    }
    if (SourceLoginUiHelper.hasLoginUi(source.loginUi)) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => SourceLoginFormView(source: source),
        ),
      );
      return;
    }

    final resolvedUrl = SourceLoginUrlResolver.resolve(
      baseUrl: source.bookSourceUrl,
      loginUrl: source.loginUrl ?? '',
    );
    if (resolvedUrl.isEmpty) {
      unawaited(showAppToast(context, message: '当前书源未配置登录地址'));
      return;
    }
    final uri = Uri.tryParse(resolvedUrl);
    final scheme = uri?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      unawaited(showAppToast(context, message: '登录地址不是有效网页地址'));
      return;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceLoginWebViewView(
          source: source,
          initialUrl: resolvedUrl,
        ),
      ),
    );
  }

  Future<void> toggleSourceExplore(BookSource source) async {
    final currentSource = sourceRepo.getSourceByUrl(source.bookSourceUrl);
    if (currentSource == null) return;
    final nextEnabledExplore = !source.enabledExplore;
    if (currentSource.enabledExplore == nextEnabledExplore) return;
    await sourceRepo.updateSource(
      currentSource.copyWith(enabledExplore: nextEnabledExplore),
    );
  }

  Future<void> openSourceDebug(BookSource source) {
    return openEditor(source.bookSourceUrl, initialTab: 3);
  }

  Future<void> openSourceScopedSearch(BookSource source) async {
    final nextScope = SearchScope.fromSource(source);
    final currentSettings = settingsService.appSettings;
    if (currentSettings.searchScope != nextScope) {
      unawaited(
        settingsService.saveAppSettings(
          currentSettings.copyWith(searchScope: nextScope),
        ),
      );
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const SearchView()),
    );
  }
}
