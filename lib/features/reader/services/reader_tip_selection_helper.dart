import '../models/reading_settings.dart';

enum ReaderTipSlot {
  headerLeft,
  headerCenter,
  headerRight,
  footerLeft,
  footerCenter,
  footerRight,
}

enum _ReaderTipContentToken {
  none,
  bookName,
  chapterTitle,
  time,
  battery,
  progress,
  page,
  chapterProgress,
  pageAndTotal,
  timeBattery,
  unknown,
}

/// 对齐 legado `TipConfigDialog.clearRepeat`：
/// 选择某一内容位后，清除其它位置的同类内容（无除外）。
class ReaderTipSelectionHelper {
  static const int headerNoneValue = 2;
  static const int footerNoneValue = 4;

  static ReadingSettings applySelection({
    required ReadingSettings settings,
    required ReaderTipSlot slot,
    required int selectedValue,
  }) {
    final selectedToken = _tokenFor(slot, selectedValue);
    var next = settings;

    final shouldClearRepeats = selectedToken != _ReaderTipContentToken.none &&
        selectedToken != _ReaderTipContentToken.unknown;
    if (shouldClearRepeats) {
      for (final currentSlot in ReaderTipSlot.values) {
        if (currentSlot == slot) continue;
        final currentValue = _valueOf(next, currentSlot);
        if (_tokenFor(currentSlot, currentValue) == selectedToken) {
          next = _setValue(
            next,
            currentSlot,
            _noneValueForSlot(currentSlot),
          );
        }
      }
    }

    return _setValue(next, slot, selectedValue);
  }

  static bool _isHeaderSlot(ReaderTipSlot slot) {
    switch (slot) {
      case ReaderTipSlot.headerLeft:
      case ReaderTipSlot.headerCenter:
      case ReaderTipSlot.headerRight:
        return true;
      case ReaderTipSlot.footerLeft:
      case ReaderTipSlot.footerCenter:
      case ReaderTipSlot.footerRight:
        return false;
    }
  }

  static int _noneValueForSlot(ReaderTipSlot slot) {
    return _isHeaderSlot(slot) ? headerNoneValue : footerNoneValue;
  }

  static int _valueOf(ReadingSettings settings, ReaderTipSlot slot) {
    switch (slot) {
      case ReaderTipSlot.headerLeft:
        return settings.headerLeftContent;
      case ReaderTipSlot.headerCenter:
        return settings.headerCenterContent;
      case ReaderTipSlot.headerRight:
        return settings.headerRightContent;
      case ReaderTipSlot.footerLeft:
        return settings.footerLeftContent;
      case ReaderTipSlot.footerCenter:
        return settings.footerCenterContent;
      case ReaderTipSlot.footerRight:
        return settings.footerRightContent;
    }
  }

  static ReadingSettings _setValue(
    ReadingSettings settings,
    ReaderTipSlot slot,
    int value,
  ) {
    switch (slot) {
      case ReaderTipSlot.headerLeft:
        return settings.copyWith(headerLeftContent: value);
      case ReaderTipSlot.headerCenter:
        return settings.copyWith(headerCenterContent: value);
      case ReaderTipSlot.headerRight:
        return settings.copyWith(headerRightContent: value);
      case ReaderTipSlot.footerLeft:
        return settings.copyWith(footerLeftContent: value);
      case ReaderTipSlot.footerCenter:
        return settings.copyWith(footerCenterContent: value);
      case ReaderTipSlot.footerRight:
        return settings.copyWith(footerRightContent: value);
    }
  }

  static _ReaderTipContentToken _tokenFor(ReaderTipSlot slot, int value) {
    if (_isHeaderSlot(slot)) {
      switch (value) {
        case 0:
          return _ReaderTipContentToken.bookName;
        case 1:
          return _ReaderTipContentToken.chapterTitle;
        case 2:
          return _ReaderTipContentToken.none;
        case 3:
          return _ReaderTipContentToken.time;
        case 4:
          return _ReaderTipContentToken.battery;
        case 5:
          return _ReaderTipContentToken.progress;
        case 6:
          return _ReaderTipContentToken.page;
        case 7:
          return _ReaderTipContentToken.chapterProgress;
        case 8:
          return _ReaderTipContentToken.pageAndTotal;
        case 9:
          return _ReaderTipContentToken.timeBattery;
        default:
          return _ReaderTipContentToken.unknown;
      }
    }

    switch (value) {
      case 0:
        return _ReaderTipContentToken.progress;
      case 1:
        return _ReaderTipContentToken.page;
      case 2:
        return _ReaderTipContentToken.time;
      case 3:
        return _ReaderTipContentToken.battery;
      case 4:
        return _ReaderTipContentToken.none;
      case 5:
        return _ReaderTipContentToken.chapterTitle;
      case 6:
        return _ReaderTipContentToken.bookName;
      case 7:
        return _ReaderTipContentToken.chapterProgress;
      case 8:
        return _ReaderTipContentToken.pageAndTotal;
      case 9:
        return _ReaderTipContentToken.timeBattery;
      default:
        return _ReaderTipContentToken.unknown;
    }
  }
}
