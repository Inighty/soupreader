import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/features/source/models/book_source.dart';
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
  testWidgets('书源调试更多菜单帮助入口会打开debugHelp文档弹层', (WidgetTester tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        const SourceDebugLegacyView(
          source: BookSource(
            bookSourceUrl: 'https://example.com/source',
            bookSourceName: '测试书源',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final moreAction = find.byIcon(CupertinoIcons.ellipsis);
    expect(moreAction, findsOneWidget);
    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final helpAction = find.text('帮助');
    expect(helpAction, findsOneWidget);
    await tester.tap(helpAction);
    await tester.pumpAndSettle();

    expect(find.text('帮助'), findsOneWidget);
    expect(find.textContaining('# 书源调试'), findsOneWidget);
    expect(find.textContaining('调试搜索>>输入关键字，如：'), findsOneWidget);
    expect(find.textContaining('调试输入规则：'), findsNothing);
  });
}
