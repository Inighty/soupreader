import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/features/settings/views/global_reading_settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GlobalReadingSettingsView 保持界面与行为入口顺序', (tester) async {
    final shadTheme = AppShadcnTheme.light();
    await tester.pumpWidget(
      ShadApp.custom(
        theme: shadTheme,
        darkTheme: shadTheme,
        appBuilder: (context) => CupertinoApp(
          home: const GlobalReadingSettingsView(),
          builder: (context, child) => ShadAppBuilder(child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final interfaceFinder = find.text('界面（样式）');
    final behaviorFinder = find.text('设置（行为）');

    expect(interfaceFinder, findsOneWidget);
    expect(behaviorFinder, findsOneWidget);
    expect(find.text('恢复默认阅读设置'), findsNothing);

    final interfaceDy = tester.getTopLeft(interfaceFinder).dy;
    final behaviorDy = tester.getTopLeft(behaviorFinder).dy;
    expect(interfaceDy, lessThan(behaviorDy));
  });
}
