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
  testWidgets('书源调试顶栏扫码入口触发扫描二维码动作', (WidgetTester tester) async {
    String? capturedTitle;
    var launchCount = 0;

    Future<String?> fakeScanLauncher(
      BuildContext context, {
      String title = '扫码',
    }) async {
      launchCount += 1;
      capturedTitle = title;
      return null;
    }

    await tester.pumpWidget(
      _buildTestApp(
        SourceDebugLegacyView(
          source: const BookSource(
            bookSourceUrl: 'https://example.com/source',
            bookSourceName: '测试书源',
          ),
          scanLauncher: fakeScanLauncher,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final scanAction = find.byIcon(CupertinoIcons.qrcode_viewfinder);
    expect(scanAction, findsOneWidget);

    await tester.tap(scanAction);
    await tester.pump();

    expect(launchCount, 1);
    expect(capturedTitle, '扫描二维码');
  });
}
