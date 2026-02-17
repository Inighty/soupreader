import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/widgets/scroll_runtime_helper.dart';

void main() {
  test('splitParagraphs strips empty paragraphs and keeps effective content',
      () {
    const raw = ' 第一段  \n\n\n第二段\n   \n第三段   ';
    final paragraphs = ScrollRuntimeHelper.splitParagraphs(raw);
    expect(paragraphs, <String>[' 第一段', '第二段', '第三段']);
  });

  test('splitParagraphs returns empty list for blank content', () {
    expect(ScrollRuntimeHelper.splitParagraphs('   \n \n\t'), isEmpty);
  });

  test('shouldRun obeys minimal interval', () {
    final now = DateTime(2026, 2, 17, 10, 0, 0, 500);
    final last = DateTime(2026, 2, 17, 10, 0, 0, 420);
    expect(
      ScrollRuntimeHelper.shouldRun(
        now: now,
        lastRunAt: last,
        minIntervalMs: 120,
      ),
      isFalse,
    );
    expect(
      ScrollRuntimeHelper.shouldRun(
        now: now,
        lastRunAt: DateTime(2026, 2, 17, 10, 0, 0, 300),
        minIntervalMs: 120,
      ),
      isTrue,
    );
  });

  test('shouldRun always true when interval is non-positive', () {
    final now = DateTime(2026, 2, 17);
    expect(
      ScrollRuntimeHelper.shouldRun(
        now: now,
        lastRunAt: now,
        minIntervalMs: 0,
      ),
      isTrue,
    );
  });
}
