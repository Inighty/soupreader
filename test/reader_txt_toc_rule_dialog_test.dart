import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/import/txt_parser.dart';
import 'package:soupreader/features/reader/widgets/reader_txt_toc_rule_dialog.dart';
import 'dart:async';

void main() {
  Future<Completer<String?>> _openDialog(
    WidgetTester tester, {
    required String currentRegex,
  }) async {
    final completer = Completer<String?>();
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (context) => Center(
              child: CupertinoButton(
                onPressed: () async {
                  final selected = await ReaderTxtTocRuleDialog.show(
                    context: context,
                    currentRegex: currentRegex,
                  );
                  if (!completer.isCompleted) {
                    completer.complete(selected);
                  }
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    return completer;
  }

  testWidgets('TXT 目录规则弹窗取消后不返回选择结果', (tester) async {
    final selectedCompleter = await _openDialog(
      tester,
      currentRegex: TxtParser.defaultTocRuleOptions.first.rule,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('reader_txt_toc_rule_option_2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reader_txt_toc_rule_cancel')));
    await tester.pumpAndSettle();

    expect(await selectedCompleter.future, isNull);
  });

  testWidgets('TXT 目录规则弹窗确认后返回当前选中规则', (tester) async {
    final expectedRule = TxtParser.defaultTocRuleOptions.first.rule;
    final selectedCompleter = await _openDialog(
      tester,
      currentRegex: '',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('reader_txt_toc_rule_option_1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reader_txt_toc_rule_confirm')));
    await tester.pumpAndSettle();

    expect(await selectedCompleter.future, expectedRule);
  });

  testWidgets('TXT 目录规则弹窗保留当前自定义规则并可确认', (tester) async {
    const customRule = r'^\s*@@\s*.+$';
    final selectedCompleter = await _openDialog(
      tester,
      currentRegex: customRule,
    );
    expect(find.text('当前规则（自定义）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader_txt_toc_rule_confirm')));
    await tester.pumpAndSettle();

    expect(await selectedCompleter.future, customRule);
  });
}
