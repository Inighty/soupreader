import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_explore_kinds_service.dart';
import 'package:soupreader/features/source/views/source_debug_legacy_view.dart';

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
        home: home,
        builder: (context, child) => ShadAppBuilder(child: child!),
      );
    },
  );
}

void main() {
  testWidgets('书源调试更多菜单刷新发现会清缓存并重建发现帮助区', (WidgetTester tester) async {
    final forceRefreshCalls = <bool>[];
    var clearCacheCallCount = 0;

    Future<List<SourceExploreKind>> fakeExploreKindsLoader(
      BookSource source, {
      bool forceRefresh = false,
    }) async {
      forceRefreshCalls.add(forceRefresh);
      if (forceRefreshCalls.length == 1) {
        throw StateError('首次加载失败');
      }
      return const <SourceExploreKind>[
        SourceExploreKind(
          title: '推荐',
          url: 'https://example.com/explore',
        ),
      ];
    }

    Future<void> fakeClearExploreKindsCache(BookSource source) async {
      clearCacheCallCount += 1;
    }

    await tester.pumpWidget(
      _buildTestApp(
        SourceDebugLegacyView(
          source: const BookSource(
            bookSourceUrl: 'https://example.com/source',
            bookSourceName: '测试书源',
          ),
          exploreKindsLoader: fakeExploreKindsLoader,
          clearExploreKindsCache: fakeClearExploreKindsCache,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('获取发现出错 JSON 数据错误'), findsOneWidget);
    expect(find.text('调试搜索 >> 输入关键字，如：'), findsNothing);

    final moreAction = find.byIcon(CupertinoIcons.ellipsis);
    expect(moreAction, findsOneWidget);
    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final refreshExploreAction = find.text('刷新发现');
    expect(refreshExploreAction, findsOneWidget);
    await tester.tap(refreshExploreAction);
    await tester.pumpAndSettle();

    expect(clearCacheCallCount, 1);
    expect(forceRefreshCalls, <bool>[false, true]);
    expect(find.text('调试搜索 >> 输入关键字，如：'), findsOneWidget);
    expect(find.text('提交 key 后开始调试'), findsOneWidget);
    expect(find.text('推荐::https://example.com/explore'), findsOneWidget);
  });
}
