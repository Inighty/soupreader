import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/widgets/reader_color_picker_dialog.dart';

void main() {
  testWidgets(
      'ReaderColorPickerDialog supports swatch selection and recent list',
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
    expect(find.byKey(const Key('reader_color_015A86')), findsWidgets);

    await tester.tap(find.byKey(const Key('reader_color_015A86')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(pickedColor, equals(0xFF015A86));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('最近使用'), findsOneWidget);
  });
}
