import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/widgets/reader_color_picker_dialog.dart';

void main() {
  testWidgets(
      'ReaderColorPickerDialog supports palette selection and recent list',
      (tester) async {
    int? pickedColor;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) {
            return CupertinoButton(
              onPressed: () async {
                pickedColor = await showReaderColorPickerDialog(
                  context: context,
                  title: '选择颜色',
                  initialColor: 0xFF333333,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('最近使用'), findsNothing);
    final boardFinder = find.byKey(const Key('reader_color_sv_board'));
    expect(boardFinder, findsOneWidget);

    final boardRect = tester.getRect(boardFinder);
    await tester.tapAt(Offset(boardRect.right - 8, boardRect.top + 8));
    await tester.pumpAndSettle();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(pickedColor, isNotNull);
    expect(pickedColor! & 0x00FFFFFF, isNot(equals(0x333333)));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('最近使用'), findsOneWidget);
    final recentHex = (pickedColor! & 0x00FFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    expect(find.byKey(Key('reader_recent_color_$recentHex')), findsOneWidget);
  });

  testWidgets('ReaderColorPickerDialog validates and accepts hex input',
      (tester) async {
    int? pickedColor;

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) {
            return CupertinoButton(
              onPressed: () async {
                pickedColor = await showReaderColorPickerDialog(
                  context: context,
                  title: '选择颜色',
                  initialColor: 0xFF123456,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final inputFinder = find.byKey(const Key('reader_color_hex_input'));
    expect(inputFinder, findsOneWidget);

    await tester.enterText(inputFinder, 'XYZ');
    await tester.pumpAndSettle();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('请输入 6 位十六进制颜色（如 FF6600）'), findsOneWidget);

    await tester.enterText(inputFinder, 'FF6600');
    await tester.pumpAndSettle();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(pickedColor, equals(0xFFFF6600));
  });
}
