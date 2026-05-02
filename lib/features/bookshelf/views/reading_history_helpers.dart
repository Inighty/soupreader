import '../../search/models/search_scope_group_helper.dart';
import '../models/book.dart';

/// 阅读记录顶部菜单动作。
enum ReadingHistoryTopMenuAction {
  sort,
  toggleRecord,
}

/// 阅读记录排序方式（对齐 legado `readRecordSort`）。
class ReadingHistorySort {
  const ReadingHistorySort._();

  static const int byName = 0;
  static const int byReadLong = 1;
  static const int byReadTime = 2;
}

/// 把毫秒数格式化为「Xd Xh Xm Xs」中文文本。空值显示「0秒」。
String formatReadingDuration(int milliseconds) {
  final safeMs = milliseconds < 0 ? 0 : milliseconds;
  final days = safeMs ~/ (1000 * 60 * 60 * 24);
  final hours = (safeMs % (1000 * 60 * 60 * 24)) ~/ (1000 * 60 * 60);
  final minutes = (safeMs % (1000 * 60 * 60)) ~/ (1000 * 60);
  final seconds = (safeMs % (1000 * 60)) ~/ 1000;
  final dayText = days > 0 ? '${days}天' : '';
  final hourText = hours > 0 ? '${hours}小时' : '';
  final minuteText = minutes > 0 ? '${minutes}分钟' : '';
  final secondText = seconds > 0 ? '${seconds}秒' : '';
  final text = '$dayText$hourText$minuteText$secondText';
  if (text.trim().isEmpty) {
    return '0秒';
  }
  return text;
}

/// 把日期格式化为「YYYY-MM-DD」，null 显示为「—」。
String formatReadingHistoryDate(DateTime? date) {
  if (date == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

/// 按当前排序方式对阅读记录列表原地排序。
void sortReadingHistory({
  required List<Book> books,
  required int sortMode,
  required Map<String, int> readRecordDurationByBookId,
}) {
  if (sortMode == ReadingHistorySort.byReadLong) {
    books.sort((left, right) {
      final leftDuration = readRecordDurationByBookId[left.id] ?? 0;
      final rightDuration = readRecordDurationByBookId[right.id] ?? 0;
      final byDuration = rightDuration.compareTo(leftDuration);
      if (byDuration != 0) return byDuration;
      return _compareByReadTimeDescThenTitle(left, right);
    });
    return;
  }
  if (sortMode == ReadingHistorySort.byReadTime) {
    books.sort(_compareByReadTimeDescThenTitle);
    return;
  }
  books.sort(_compareByNameLikeLegado);
}

int _compareByReadTimeDescThenTitle(Book left, Book right) {
  final leftTime = left.lastReadTime ?? DateTime.fromMillisecondsSinceEpoch(0);
  final rightTime =
      right.lastReadTime ?? DateTime.fromMillisecondsSinceEpoch(0);
  final byReadTime = rightTime.compareTo(leftTime);
  if (byReadTime != 0) return byReadTime;
  return _compareByNameLikeLegado(left, right);
}

int _compareByNameLikeLegado(Book left, Book right) {
  return SearchScopeGroupHelper.cnCompareLikeLegado(left.title, right.title);
}
