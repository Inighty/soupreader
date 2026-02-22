import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/drift/source_drift_service.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/core/services/source_variable_store.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/views/source_debug_legacy_view.dart';
import 'package:soupreader/features/source/views/source_login_form_view.dart';
import 'package:soupreader/features/source/views/source_list_view.dart';
import 'package:soupreader/features/search/views/search_view.dart';

Widget _buildTestApp(Widget home) {
  final shadTheme = AppShadcnTheme.light();
  return ShadApp.custom(
    theme: shadTheme,
    darkTheme: shadTheme,
    appBuilder: (context) {
      final shad = ShadTheme.of(context);
      final cupertinoTheme = CupertinoTheme.of(context).copyWith(
        barBackgroundColor: shad.colorScheme.background.withValues(alpha: 0.92),
      );
      return CupertinoApp(
        theme: cupertinoTheme,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[
          Locale('zh'),
          Locale('en'),
        ],
        home: home,
        builder: (context, child) => ShadAppBuilder(child: child!),
      );
    },
  );
}

BookSource _buildSource({
  required String url,
  required String name,
  required int customOrder,
  bool enabledExplore = true,
  String? exploreUrl,
  String? loginUrl,
  String? loginUi,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    enabled: true,
    customOrder: customOrder,
    enabledExplore: enabledExplore,
    weight: 0,
    respondTime: 0,
    lastUpdateTime: 0,
    exploreUrl: exploreUrl,
    loginUrl: loginUrl,
    loginUi: loginUi,
  );
}

Future<void> _seedSources(List<BookSource> sources) async {
  final sourceRepo = SourceRepository(DatabaseService());
  await sourceRepo.addSources(sources);
}

Future<bool?> _queryEnabledExplore(String sourceUrl) async {
  final driftDb = SourceDriftService().db;
  final row = await (driftDb.select(driftDb.sourceRecords)
        ..where((tbl) => tbl.bookSourceUrl.equals(sourceUrl)))
      .getSingleOrNull();
  return row?.enabledExplore;
}

Future<bool> _sourceExists(String sourceUrl) async {
  final driftDb = SourceDriftService().db;
  final row = await (driftDb.select(driftDb.sourceRecords)
        ..where((tbl) => tbl.bookSourceUrl.equals(sourceUrl)))
      .getSingleOrNull();
  return row != null;
}

List<String> _orderedByVerticalPosition(
  WidgetTester tester,
  List<String> names,
) {
  final ordered = <MapEntry<String, double>>[];
  for (final name in names) {
    final finder = find.text(name);
    expect(finder, findsOneWidget);
    ordered.add(MapEntry<String, double>(name, tester.getTopLeft(finder).dy));
  }
  ordered.sort((a, b) => a.value.compareTo(b.value));
  return ordered.map((entry) => entry.key).toList(growable: false);
}

Future<void> _openItemMoreMenu(
  WidgetTester tester, {
  required String sourceUrl,
}) async {
  final moreAction = find.byKey(
    ValueKey<String>('source-item-more-$sourceUrl'),
  );
  expect(moreAction, findsOneWidget);
  await tester.tap(moreAction);
  await tester.pumpAndSettle();
  expect(find.byType(CupertinoActionSheet), findsOneWidget);
  expect(find.text(sourceUrl), findsOneWidget);
}

Future<void> _tapSheetAction(
  WidgetTester tester, {
  required String label,
}) async {
  final sheet = find.byType(CupertinoActionSheet);
  expect(sheet, findsOneWidget);
  final action = find.descendant(
    of: sheet,
    matching: find.widgetWithText(CupertinoActionSheetAction, label),
  );
  expect(action, findsOneWidget);
  final actionWidget = tester.widget<CupertinoActionSheetAction>(action);
  actionWidget.onPressed?.call();
  await tester.pumpAndSettle();
}

Future<void> _tapDialogAction(
  WidgetTester tester, {
  required String label,
}) async {
  final dialog = find.byType(CupertinoAlertDialog);
  expect(dialog, findsOneWidget);
  final action = find.descendant(
    of: dialog,
    matching: find.widgetWithText(CupertinoDialogAction, label),
  );
  expect(action, findsOneWidget);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'source_manage_help_shown_v1': true,
    });

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_source_item_top_action_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return tempDir.path;
    });

    await DatabaseService().init();
    await SettingsService().init();
  });

  tearDownAll(() async {
    try {
      await DatabaseService().close();
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await DatabaseService().clearAll();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'source_manage_help_shown_v1': true,
    });
    await SettingsService().init();
  });

  testWidgets('书源条目菜单置顶入口仅在手动排序显示', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://source.example.com/manual-only',
          name: '单源',
          customOrder: 1,
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await _openItemMoreMenu(
      tester,
      sourceUrl: 'https://source.example.com/manual-only',
    );
    expect(
        find.widgetWithText(CupertinoActionSheetAction, '置顶'), findsOneWidget);
    expect(
        find.widgetWithText(CupertinoActionSheetAction, '置底'), findsOneWidget);

    await _tapSheetAction(tester, label: '取消');

    await tester.tap(find.byIcon(CupertinoIcons.arrow_up_arrow_down));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '名称排序'),
    );
    await tester.pumpAndSettle();

    await _openItemMoreMenu(
      tester,
      sourceUrl: 'https://source.example.com/manual-only',
    );
    expect(find.widgetWithText(CupertinoActionSheetAction, '置顶'), findsNothing);
    expect(find.widgetWithText(CupertinoActionSheetAction, '置底'), findsNothing);
  });

  testWidgets('书源条目菜单 loginUrl 为空时不显示登录入口', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://source.example.com/login-hidden',
          name: '登录隐藏源',
          customOrder: 1,
          loginUrl: '',
          loginUi: '[{"name":"账号","type":"text"}]',
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await _openItemMoreMenu(
      tester,
      sourceUrl: 'https://source.example.com/login-hidden',
    );

    expect(
      find.widgetWithText(CupertinoActionSheetAction, '登录'),
      findsNothing,
    );
  });

  testWidgets('书源条目菜单 loginUrl 非空且存在 loginUi 时点击登录进入表单页',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://source.example.com/login-ui',
          name: '登录表单源',
          customOrder: 1,
          loginUrl: '/login',
          loginUi: '[{"name":"账号","type":"text"}]',
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await _openItemMoreMenu(
      tester,
      sourceUrl: 'https://source.example.com/login-ui',
    );
    await _tapSheetAction(tester, label: '登录');

    expect(find.byType(SourceLoginFormView), findsOneWidget);
  });

  testWidgets('书源条目菜单搜索按条目快照写入 legacy scope 并打开搜索页',
      (WidgetTester tester) async {
    const sourceUrl = 'https://source.example.com/deleted-before-search';
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: sourceUrl,
          name: '删:除源',
          customOrder: 1,
        ),
      ]);
      final settingsService = SettingsService();
      await settingsService.saveAppSettings(
        settingsService.appSettings.copyWith(searchScope: '旧分组'),
      );
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await _openItemMoreMenu(
      tester,
      sourceUrl: sourceUrl,
    );

    await tester.runAsync(() async {
      final sourceRepo = SourceRepository(DatabaseService());
      await sourceRepo.deleteSource(sourceUrl);
    });
    await tester.pump();

    await _tapSheetAction(tester, label: '搜索');

    expect(find.byType(SearchView), findsOneWidget);
    expect(
      SettingsService().appSettings.searchScope,
      '删除源::$sourceUrl',
    );
  });

  testWidgets('书源条目菜单调试按条目快照打开调试页', (WidgetTester tester) async {
    const sourceUrl = 'https://source.example.com/deleted-before-debug';
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: sourceUrl,
          name: '调试源',
          customOrder: 1,
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await _openItemMoreMenu(
      tester,
      sourceUrl: sourceUrl,
    );

    await tester.runAsync(() async {
      final sourceRepo = SourceRepository(DatabaseService());
      await sourceRepo.deleteSource(sourceUrl);
    });
    await tester.pump();

    await _tapSheetAction(tester, label: '调试');

    expect(find.byType(SourceDebugLegacyView), findsOneWidget);
  });

  testWidgets('书源条目菜单启用发现入口显隐与切换文案对齐 legado', (WidgetTester tester) async {
    const noExploreUrl = 'https://source.example.com/no-explore';
    const enabledExploreUrl = 'https://source.example.com/explore-enabled';

    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: noExploreUrl,
          name: '无发现源',
          customOrder: 1,
          enabledExplore: true,
          exploreUrl: null,
        ),
        _buildSource(
          url: enabledExploreUrl,
          name: '发现已启用源',
          customOrder: 2,
          enabledExplore: true,
          exploreUrl: '/explore',
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await _openItemMoreMenu(
      tester,
      sourceUrl: noExploreUrl,
    );
    expect(
        find.widgetWithText(CupertinoActionSheetAction, '启用发现'), findsNothing);
    expect(
        find.widgetWithText(CupertinoActionSheetAction, '禁用发现'), findsNothing);
    await _tapSheetAction(tester, label: '取消');

    await _openItemMoreMenu(
      tester,
      sourceUrl: enabledExploreUrl,
    );
    expect(find.widgetWithText(CupertinoActionSheetAction, '禁用发现'),
        findsOneWidget);
    expect(
        find.widgetWithText(CupertinoActionSheetAction, '启用发现'), findsNothing);
    await _tapSheetAction(tester, label: '禁用发现');

    await tester.runAsync(() async {
      expect(await _queryEnabledExplore(enabledExploreUrl), isFalse);
    });
  });

  testWidgets('书源条目菜单启用发现在弹层期间删除书源不会重建记录', (WidgetTester tester) async {
    const sourceUrl = 'https://source.example.com/explore-toggle-deleted';

    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: sourceUrl,
          name: '删除后切换发现源',
          customOrder: 1,
          enabledExplore: true,
          exploreUrl: '/explore',
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await _openItemMoreMenu(
      tester,
      sourceUrl: sourceUrl,
    );

    await tester.runAsync(() async {
      final repo = SourceRepository(DatabaseService());
      await repo.deleteSource(sourceUrl);
    });
    await tester.pump();

    await _tapSheetAction(tester, label: '禁用发现');

    await tester.runAsync(() async {
      expect(await _sourceExists(sourceUrl), isFalse);
    });
  });

  testWidgets('书源条目菜单删除会先移除选中态，取消后保留条目', (WidgetTester tester) async {
    const sourceUrl = 'https://source.example.com/delete-cancel';
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: sourceUrl,
          name: '删除取消源',
          customOrder: 1,
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final selectButton = find.byIcon(CupertinoIcons.circle);
    expect(selectButton, findsOneWidget);
    await tester.tap(selectButton);
    await tester.pumpAndSettle();
    expect(
      find.byIcon(CupertinoIcons.check_mark_circled_solid),
      findsOneWidget,
    );

    await _openItemMoreMenu(
      tester,
      sourceUrl: sourceUrl,
    );
    await _tapSheetAction(tester, label: '删除');

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('提醒'), findsOneWidget);
    expect(find.textContaining('是否确认删除？'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.textContaining('删除取消源'),
      ),
      findsOneWidget,
    );
    expect(
      find.byIcon(CupertinoIcons.check_mark_circled_solid),
      findsNothing,
    );

    await _tapDialogAction(tester, label: '取消');

    expect(find.text('删除取消源'), findsOneWidget);
  });

  testWidgets('书源条目菜单确认删除后会删除条目', (WidgetTester tester) async {
    const sourceUrl = 'https://source.example.com/delete-confirm';
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: sourceUrl,
          name: '删除确认源',
          customOrder: 1,
        ),
      ]);
      await SourceVariableStore.putVariable(sourceUrl, 'legacy-variable');
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await _openItemMoreMenu(
      tester,
      sourceUrl: sourceUrl,
    );
    await _tapSheetAction(tester, label: '删除');

    await _tapDialogAction(tester, label: '确定');
    await tester.runAsync(() async {
      final driftDb = SourceDriftService().db;
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (DateTime.now().isBefore(deadline)) {
        final source = await (driftDb.select(driftDb.sourceRecords)
              ..where((tbl) => tbl.bookSourceUrl.equals(sourceUrl)))
            .getSingleOrNull();
        if (source == null) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final source = await (driftDb.select(driftDb.sourceRecords)
            ..where((tbl) => tbl.bookSourceUrl.equals(sourceUrl)))
          .getSingleOrNull();
      expect(source, isNull);
    });
  });

  testWidgets('书源条目菜单置顶在升序时写入最小 customOrder 并置于顶部',
      (WidgetTester tester) async {
    List<BookSource>? movedSources;
    bool? movedToTop;

    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://source.example.com/a',
          name: '甲源',
          customOrder: 10,
        ),
        _buildSource(
          url: 'https://source.example.com/b',
          name: '乙源',
          customOrder: 20,
        ),
      ]);
    });

    await tester.pumpWidget(
      _buildTestApp(
        SourceListView(
          moveSourcesHandler: (sources, {required toTop}) async {
            movedSources = List<BookSource>.from(sources);
            movedToTop = toTop;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      _orderedByVerticalPosition(tester, const <String>['甲源', '乙源']),
      orderedEquals(const <String>['甲源', '乙源']),
    );

    await _openItemMoreMenu(
      tester,
      sourceUrl: 'https://source.example.com/b',
    );
    await _tapSheetAction(tester, label: '置顶');
    expect(movedToTop, isTrue);
    expect(movedSources, isNotNull);
    expect(movedSources!.length, 1);
    expect(
      movedSources!.first.bookSourceUrl,
      'https://source.example.com/b',
    );
  });

  testWidgets('书源条目菜单置顶在反序时走 legacy 同义链路', (WidgetTester tester) async {
    List<BookSource>? movedSources;
    bool? movedToTop;

    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://source.example.com/desc-a',
          name: '反序甲源',
          customOrder: 1,
        ),
        _buildSource(
          url: 'https://source.example.com/desc-b',
          name: '反序乙源',
          customOrder: 2,
        ),
      ]);
    });

    await tester.pumpWidget(
      _buildTestApp(
        SourceListView(
          moveSourcesHandler: (sources, {required toTop}) async {
            movedSources = List<BookSource>.from(sources);
            movedToTop = toTop;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.arrow_up_arrow_down));
    await tester.pumpAndSettle();
    await _tapSheetAction(tester, label: '反序');

    expect(
      _orderedByVerticalPosition(tester, const <String>['反序甲源', '反序乙源']),
      orderedEquals(const <String>['反序乙源', '反序甲源']),
    );

    await _openItemMoreMenu(
      tester,
      sourceUrl: 'https://source.example.com/desc-a',
    );
    await _tapSheetAction(tester, label: '置顶');
    expect(movedToTop, isFalse);
    expect(movedSources, isNotNull);
    expect(movedSources!.length, 1);
    expect(
      movedSources!.first.bookSourceUrl,
      'https://source.example.com/desc-a',
    );
  });

  testWidgets('书源条目菜单置底在升序时走 legacy 同义链路', (WidgetTester tester) async {
    List<BookSource>? movedSources;
    bool? movedToTop;

    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://source.example.com/bottom-a',
          name: '置底甲源',
          customOrder: 10,
        ),
        _buildSource(
          url: 'https://source.example.com/bottom-b',
          name: '置底乙源',
          customOrder: 20,
        ),
      ]);
    });

    await tester.pumpWidget(
      _buildTestApp(
        SourceListView(
          moveSourcesHandler: (sources, {required toTop}) async {
            movedSources = List<BookSource>.from(sources);
            movedToTop = toTop;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await _openItemMoreMenu(
      tester,
      sourceUrl: 'https://source.example.com/bottom-a',
    );
    await _tapSheetAction(tester, label: '置底');
    expect(movedToTop, isFalse);
    expect(movedSources, isNotNull);
    expect(movedSources!.length, 1);
    expect(
      movedSources!.first.bookSourceUrl,
      'https://source.example.com/bottom-a',
    );
  });

  testWidgets('书源条目菜单置底在反序时走 legacy 同义链路', (WidgetTester tester) async {
    List<BookSource>? movedSources;
    bool? movedToTop;

    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://source.example.com/bottom-desc-a',
          name: '反序置底甲源',
          customOrder: 1,
        ),
        _buildSource(
          url: 'https://source.example.com/bottom-desc-b',
          name: '反序置底乙源',
          customOrder: 2,
        ),
      ]);
    });

    await tester.pumpWidget(
      _buildTestApp(
        SourceListView(
          moveSourcesHandler: (sources, {required toTop}) async {
            movedSources = List<BookSource>.from(sources);
            movedToTop = toTop;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.arrow_up_arrow_down));
    await tester.pumpAndSettle();
    await _tapSheetAction(tester, label: '反序');

    expect(
      _orderedByVerticalPosition(tester, const <String>['反序置底甲源', '反序置底乙源']),
      orderedEquals(const <String>['反序置底乙源', '反序置底甲源']),
    );

    await _openItemMoreMenu(
      tester,
      sourceUrl: 'https://source.example.com/bottom-desc-a',
    );
    await _tapSheetAction(tester, label: '置底');
    expect(movedToTop, isTrue);
    expect(movedSources, isNotNull);
    expect(movedSources!.length, 1);
    expect(
      movedSources!.first.bookSourceUrl,
      'https://source.example.com/bottom-desc-a',
    );
  });
}
