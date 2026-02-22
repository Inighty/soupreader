import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/views/source_list_view.dart';

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
  required bool enabled,
  required int customOrder,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    enabled: enabled,
    customOrder: customOrder,
    enabledExplore: true,
    weight: 0,
    respondTime: 0,
    lastUpdateTime: 0,
  );
}

Future<void> _seedSources(List<BookSource> sources) async {
  final sourceRepo = SourceRepository(DatabaseService());
  await sourceRepo.addSources(sources);
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

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'source_manage_help_shown_v1': true,
    });

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_source_sort_menu_',
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

  testWidgets('书源管理顶栏排序入口会打开排序菜单', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CupertinoActionSheet, '排序'), findsOneWidget);
  });

  testWidgets('书源管理顶栏分组入口会打开分组菜单', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final groupAction = find.byIcon(CupertinoIcons.square_grid_2x2);
    expect(groupAction, findsOneWidget);

    await tester.tap(groupAction);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CupertinoActionSheet, '分组'), findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '分组管理'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '已启用'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '已禁用'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '需要登录'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '未分组'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '已启用发现'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '已禁用发现'),
      findsOneWidget,
    );
  });

  testWidgets('书源管理更多菜单帮助入口会打开帮助弹层', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final moreAction = find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byIcon(CupertinoIcons.ellipsis_circle),
    );
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final helpAction = find.widgetWithText(CupertinoActionSheetAction, '帮助');
    expect(helpAction, findsOneWidget);

    await tester.tap(helpAction);
    await tester.pumpAndSettle();

    expect(find.text('帮助'), findsOneWidget);
    expect(find.textContaining('书源管理界面帮助'), findsOneWidget);
  });

  testWidgets('书源管理更多菜单新建书源入口会打开书源编辑页', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final moreAction = find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byIcon(CupertinoIcons.ellipsis_circle),
    );
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final addSourceAction = find.text('新建书源');
    expect(addSourceAction, findsOneWidget);

    await tester.tap(addSourceAction);
    await tester.pumpAndSettle();

    expect(find.text('书源编辑'), findsOneWidget);
    expect(find.text('书源地址'), findsOneWidget);
    expect(find.text('书源名称'), findsOneWidget);
    expect(find.text('自动保存Cookie'), findsOneWidget);

    final cookieRow = find.ancestor(
      of: find.text('自动保存Cookie'),
      matching: find.byType(Row),
    );
    final cookieSwitch = find.descendant(
      of: cookieRow.first,
      matching: find.byType(CupertinoSwitch),
    );
    expect(cookieSwitch, findsOneWidget);
    expect(tester.widget<CupertinoSwitch>(cookieSwitch).value, isTrue);
  });

  testWidgets('书源管理更多菜单本地导入入口文案与 legado 一致', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final moreAction = find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byIcon(CupertinoIcons.ellipsis_circle),
    );
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CupertinoActionSheetAction, '本地导入'),
        findsOneWidget);
    expect(
        find.widgetWithText(CupertinoActionSheetAction, '从文件导入'), findsNothing);
  });

  testWidgets('书源管理更多菜单网络导入入口文案与 legado 一致', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final moreAction = find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byIcon(CupertinoIcons.ellipsis_circle),
    );
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final onlineImportAction = find.widgetWithText(
      CupertinoActionSheetAction,
      '网络导入',
    );
    expect(onlineImportAction, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '从网络导入'),
      findsNothing,
    );

    await tester.tap(onlineImportAction);
    await tester.pumpAndSettle();

    expect(find.text('网络导入'), findsOneWidget);
  });

  testWidgets('书源管理更多菜单二维码导入入口文案与 legado 一致', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final moreAction = find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byIcon(CupertinoIcons.ellipsis_circle),
    );
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(CupertinoActionSheetAction, '二维码导入'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '扫码导入'),
      findsNothing,
    );
  });

  testWidgets('书源管理更多菜单按域名分组显示为勾选态切换语义', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://zeta.com/source-z',
          name: 'Zeta源',
          enabled: true,
          customOrder: 1,
        ).copyWith(lastUpdateTime: 10),
        _buildSource(
          url: 'https://alpha.com/source-a',
          name: 'Alpha旧',
          enabled: true,
          customOrder: 2,
        ).copyWith(lastUpdateTime: 1),
        _buildSource(
          url: 'https://alpha.com/source-b',
          name: 'Alpha新',
          enabled: true,
          customOrder: 3,
        ).copyWith(lastUpdateTime: 9),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final sourceNames = <String>['Zeta源', 'Alpha旧', 'Alpha新'];
    expect(
      _orderedByVerticalPosition(tester, sourceNames),
      orderedEquals(<String>['Zeta源', 'Alpha旧', 'Alpha新']),
    );

    final moreAction = find.descendant(
      of: find.byType(CupertinoNavigationBar),
      matching: find.byIcon(CupertinoIcons.ellipsis_circle),
    );
    expect(moreAction, findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final groupByDomainAction = find.widgetWithText(
      CupertinoActionSheetAction,
      '按域名分组显示',
    );
    expect(groupByDomainAction, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '关闭按域名分组'),
      findsNothing,
    );

    await tester.tap(groupByDomainAction);
    await tester.pumpAndSettle();

    expect(
      _orderedByVerticalPosition(tester, sourceNames),
      orderedEquals(<String>['Alpha新', 'Alpha旧', 'Zeta源']),
    );
    expect(find.text('alpha.com'), findsOneWidget);
    expect(find.text('zeta.com'), findsOneWidget);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 按域名分组显示'),
      findsOneWidget,
    );
  });

  testWidgets('书源管理分组菜单已启用项写入已启用查询并即时筛选', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://example.com/enabled-source',
          name: '已启用源',
          enabled: true,
          customOrder: 1,
        ),
        _buildSource(
          url: 'https://example.com/disabled-source',
          name: '已禁用源',
          enabled: false,
          customOrder: 2,
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.square_grid_2x2));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '已启用'),
    );
    await tester.pumpAndSettle();

    expect(find.text('已启用源'), findsOneWidget);
    expect(find.text('已禁用源'), findsNothing);
  });

  testWidgets('书源管理分组菜单已禁用项写入已禁用查询并即时筛选', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://example.com/enabled-source-b',
          name: '启用源B',
          enabled: true,
          customOrder: 1,
        ),
        _buildSource(
          url: 'https://example.com/disabled-source-b',
          name: '禁用源B',
          enabled: false,
          customOrder: 2,
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.square_grid_2x2));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '已禁用'),
    );
    await tester.pumpAndSettle();

    expect(find.text('启用源B'), findsNothing);
    expect(find.text('禁用源B'), findsOneWidget);
  });

  testWidgets('书源管理分组菜单需要登录项写入需要登录查询并即时筛选', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://example.com/login-required',
          name: '登录源',
          enabled: true,
          customOrder: 1,
        ).copyWith(loginUrl: 'https://example.com/login'),
        _buildSource(
          url: 'https://example.com/no-login',
          name: '免登录源',
          enabled: true,
          customOrder: 2,
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.square_grid_2x2));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '需要登录'),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录源'), findsOneWidget);
    expect(find.text('免登录源'), findsNothing);
  });

  testWidgets('书源管理分组菜单未分组项写入未分组查询并即时筛选', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://example.com/no-group-empty',
          name: '空分组源',
          enabled: true,
          customOrder: 1,
        ),
        _buildSource(
          url: 'https://example.com/no-group-word',
          name: '未分组词源',
          enabled: true,
          customOrder: 2,
        ).copyWith(bookSourceGroup: '都市,未分组来源'),
        _buildSource(
          url: 'https://example.com/grouped',
          name: '普通分组源',
          enabled: true,
          customOrder: 3,
        ).copyWith(bookSourceGroup: '武侠'),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.square_grid_2x2));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '未分组'),
    );
    await tester.pumpAndSettle();

    expect(find.text('空分组源'), findsOneWidget);
    expect(find.text('未分组词源 (都市,未分组来源)'), findsOneWidget);
    expect(find.text('普通分组源 (武侠)'), findsNothing);
  });

  testWidgets('书源管理分组菜单已启用发现项写入已启用发现查询并即时筛选', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://example.com/explore-enabled',
          name: '发现已启用源',
          enabled: true,
          customOrder: 1,
        ).copyWith(enabledExplore: true),
        _buildSource(
          url: 'https://example.com/explore-disabled',
          name: '发现已禁用源',
          enabled: true,
          customOrder: 2,
        ).copyWith(enabledExplore: false),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.square_grid_2x2));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '已启用发现'),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现已启用源'), findsOneWidget);
    expect(find.text('发现已禁用源'), findsNothing);
  });

  testWidgets('书源管理分组菜单已禁用发现项写入已禁用发现查询并即时筛选', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://example.com/explore-enabled-2',
          name: '发现启用源2',
          enabled: true,
          customOrder: 1,
        ).copyWith(enabledExplore: true),
        _buildSource(
          url: 'https://example.com/explore-disabled-2',
          name: '发现禁用源2',
          enabled: true,
          customOrder: 2,
        ).copyWith(enabledExplore: false),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.square_grid_2x2));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '已禁用发现'),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现启用源2'), findsNothing);
    expect(find.text('发现禁用源2'), findsOneWidget);
  });

  testWidgets('书源管理分组菜单分组管理项可打开分组管理弹层', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final groupAction = find.byIcon(CupertinoIcons.square_grid_2x2);
    expect(groupAction, findsOneWidget);

    await tester.tap(groupAction);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '分组管理'),
    );
    await tester.pumpAndSettle();

    expect(find.text('分组管理'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.add_circled), findsOneWidget);
  });

  testWidgets('书源管理分组管理新增按钮会打开输入弹窗', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.square_grid_2x2));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '分组管理'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.add_circled));
    await tester.pumpAndSettle();
    final addDialog = find.byType(CupertinoAlertDialog).last;
    final addDialogInput = find.descendant(
      of: addDialog,
      matching: find.byType(CupertinoTextField),
    );
    expect(addDialogInput, findsOneWidget);
    expect(find.text('添加分组'), findsOneWidget);
    final addConfirmAction = find.descendant(
      of: addDialog,
      matching: find.widgetWithText(CupertinoDialogAction, '确定'),
    );
    expect(addConfirmAction, findsOneWidget);
  });

  testWidgets('书源管理分组管理列表展示编辑与删除操作入口', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://example.com/old-group',
          name: '旧分组源',
          enabled: true,
          customOrder: 1,
        ).copyWith(bookSourceGroup: '旧组'),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.square_grid_2x2));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '分组管理'),
    );
    await tester.pumpAndSettle();

    final oldGroupText = find.descendant(
      of: find.byType(CupertinoPopupSurface).last,
      matching: find.text('旧组'),
    );
    expect(oldGroupText, findsOneWidget);

    final oldGroupRow = find.ancestor(
      of: oldGroupText.first,
      matching: find.byType(Row),
    );
    final editAction = find.descendant(
      of: oldGroupRow.first,
      matching: find.widgetWithText(CupertinoButton, '编辑'),
    );
    final deleteAction = find.descendant(
      of: oldGroupRow.first,
      matching: find.widgetWithText(CupertinoButton, '删除'),
    );
    expect(editAction, findsOneWidget);
    expect(deleteAction, findsOneWidget);
  });

  testWidgets('书源管理分组菜单动态分组项写入 group: 查询并即时筛选', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://example.com/wuxia',
          name: '甲源',
          enabled: true,
          customOrder: 1,
        ).copyWith(bookSourceGroup: '武侠'),
        _buildSource(
          url: 'https://example.com/scifi',
          name: '乙源',
          enabled: true,
          customOrder: 2,
        ).copyWith(bookSourceGroup: '科幻'),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final groupAction = find.byIcon(CupertinoIcons.square_grid_2x2);
    expect(groupAction, findsOneWidget);

    await tester.tap(groupAction);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(CupertinoActionSheetAction, '武侠'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '科幻'),
      findsOneWidget,
    );

    final wuxiaAction =
        find.widgetWithText(CupertinoActionSheetAction, '武侠').first;
    await tester.ensureVisible(wuxiaAction);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(wuxiaAction);
    await tester.pumpAndSettle();

    expect(find.text('甲源 (武侠)'), findsOneWidget);
    expect(find.text('乙源 (科幻)'), findsNothing);
  });

  testWidgets('书源管理反序菜单项为勾选态切换语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    final reverseUnchecked = find.widgetWithText(
      CupertinoActionSheetAction,
      '反序',
    );
    expect(reverseUnchecked, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 反序'),
      findsNothing,
    );

    await tester.tap(reverseUnchecked);
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 反序'),
      findsOneWidget,
    );
  });

  testWidgets('书源管理智能排序菜单项保持单选勾选语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    final autoSortUnchecked = find.widgetWithText(
      CupertinoActionSheetAction,
      '智能排序',
    );
    expect(autoSortUnchecked, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 智能排序'),
      findsNothing,
    );

    await tester.tap(autoSortUnchecked);
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 智能排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsNothing,
    );
  });

  testWidgets('书源管理名称排序菜单项保持单选勾选语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    final nameSortUnchecked = find.widgetWithText(
      CupertinoActionSheetAction,
      '名称排序',
    );
    expect(nameSortUnchecked, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 名称排序'),
      findsNothing,
    );

    await tester.tap(nameSortUnchecked);
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 名称排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsNothing,
    );
  });

  testWidgets('书源管理地址排序菜单项保持单选勾选语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    final urlSortUnchecked = find.widgetWithText(
      CupertinoActionSheetAction,
      '地址排序',
    );
    expect(urlSortUnchecked, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 地址排序'),
      findsNothing,
    );

    await tester.tap(urlSortUnchecked);
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 地址排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsNothing,
    );
  });

  testWidgets('书源管理更新时间排序菜单项保持单选勾选语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    final updateSortUnchecked = find.widgetWithText(
      CupertinoActionSheetAction,
      '更新时间排序',
    );
    expect(updateSortUnchecked, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 更新时间排序'),
      findsNothing,
    );

    await tester.tap(updateSortUnchecked);
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 更新时间排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsNothing,
    );
  });

  testWidgets('书源管理响应时间排序菜单项保持单选勾选语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    final respondSortUnchecked = find.widgetWithText(
      CupertinoActionSheetAction,
      '响应时间排序',
    );
    expect(respondSortUnchecked, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 响应时间排序'),
      findsNothing,
    );

    await tester.tap(respondSortUnchecked);
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 响应时间排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsNothing,
    );
  });

  testWidgets('书源管理是否启用菜单项保持单选勾选语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    final enableSortUnchecked = find
        .widgetWithText(
          CupertinoActionSheetAction,
          '是否启用',
        )
        .first;
    await tester.ensureVisible(enableSortUnchecked);
    await tester.pump(const Duration(milliseconds: 200));
    expect(enableSortUnchecked, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 是否启用'),
      findsNothing,
    );

    await tester.tap(enableSortUnchecked);
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 是否启用'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsNothing,
    );
  });

  testWidgets('书源管理是否启用反序时同启用状态内名称保持正序', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await _seedSources(<BookSource>[
        _buildSource(
          url: 'https://example.com/disabled-a',
          name: 'A-disabled',
          enabled: false,
          customOrder: 1,
        ),
        _buildSource(
          url: 'https://example.com/enabled-b',
          name: 'B-enabled',
          enabled: true,
          customOrder: 2,
        ),
        _buildSource(
          url: 'https://example.com/disabled-b',
          name: 'B-disabled',
          enabled: false,
          customOrder: 3,
        ),
        _buildSource(
          url: 'https://example.com/enabled-a',
          name: 'A-enabled',
          enabled: true,
          customOrder: 4,
        ),
      ]);
    });

    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    final allNames = <String>[
      'A-enabled',
      'B-enabled',
      'A-disabled',
      'B-disabled',
    ];

    await tester.tap(sortAction);
    await tester.pump(const Duration(milliseconds: 400));
    final enableSortAction = find
        .widgetWithText(
          CupertinoActionSheetAction,
          '是否启用',
        )
        .first;
    await tester.ensureVisible(enableSortAction);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(enableSortAction);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      _orderedByVerticalPosition(tester, allNames),
      orderedEquals(<String>[
        'A-enabled',
        'B-enabled',
        'A-disabled',
        'B-disabled',
      ]),
    );

    await tester.tap(sortAction);
    await tester.pump(const Duration(milliseconds: 400));
    final reverseAction = find
        .widgetWithText(
          CupertinoActionSheetAction,
          '反序',
        )
        .first;
    await tester.ensureVisible(reverseAction);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(reverseAction);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      _orderedByVerticalPosition(tester, allNames),
      orderedEquals(<String>[
        'A-disabled',
        'B-disabled',
        'A-enabled',
        'B-enabled',
      ]),
    );
  });

  testWidgets('书源管理更新时间排序与反序保持联动勾选语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '更新时间排序'),
    );
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, '反序'));
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 更新时间排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 反序'),
      findsOneWidget,
    );
  });

  testWidgets('书源管理手动排序菜单项保持单选勾选语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '智能排序'),
    );
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 智能排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsNothing,
    );

    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '手动排序'),
    );
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 智能排序'),
      findsNothing,
    );
  });
}
