import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/settings/views/reading_tip_settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService().init();
  });

  testWidgets('ReadingTipSettingsView renders title spacing controls',
      (tester) async {
    final shadTheme = AppShadcnTheme.light();
    await tester.pumpWidget(
      ShadApp.custom(
        theme: shadTheme,
        darkTheme: shadTheme,
        appBuilder: (context) => CupertinoApp(
          home: const ReadingTipSettingsView(),
          builder: (context, child) => ShadAppBuilder(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('标题字号偏移'), findsOneWidget);
    expect(find.text('标题上边距'), findsOneWidget);
    expect(find.text('标题下边距'), findsOneWidget);
    expect(find.text('显示模式'), findsOneWidget);
  });
}
