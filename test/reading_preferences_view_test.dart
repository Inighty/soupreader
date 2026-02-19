import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/settings/views/reading_preferences_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService().init();
  });

  testWidgets('ReadingPreferencesView 对齐样式与排版入口分组', (tester) async {
    final shadTheme = AppShadcnTheme.light();
    await tester.pumpWidget(
      ShadApp.custom(
        theme: shadTheme,
        darkTheme: shadTheme,
        appBuilder: (context) => CupertinoApp(
          home: const ReadingPreferencesView(),
          builder: (context, child) => ShadAppBuilder(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('样式'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('字体'), findsOneWidget);
    expect(find.text('字重'), findsOneWidget);
    expect(find.text('翻页模式'), findsOneWidget);
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('字距'), findsOneWidget);
    expect(find.text('行距'), findsOneWidget);
    expect(find.text('段距'), findsOneWidget);
    expect(find.text('排版与边距（高级）', skipOffstage: false), findsOneWidget);
    expect(find.text('亮度'), findsNothing);
    expect(find.text('手动亮度'), findsNothing);
    expect(find.text('恢复默认阅读设置'), findsNothing);
  });
}
