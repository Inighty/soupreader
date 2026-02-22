import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/views/source_debug_legacy_view.dart';
import 'package:soupreader/features/source/views/source_debug_text_view.dart';

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
  testWidgets('书源调试正文源码入口在源码为空时也直接打开源码承载页', (WidgetTester tester) async {
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

    final contentSrcAction = find.text('正文源码');
    expect(contentSrcAction, findsOneWidget);
    await tester.tap(contentSrcAction);
    await tester.pumpAndSettle();

    expect(find.byType(SourceDebugTextView), findsOneWidget);
    expect(find.text('html'), findsOneWidget);
    expect(find.text('暂无正文源码'), findsNothing);
  });
}
