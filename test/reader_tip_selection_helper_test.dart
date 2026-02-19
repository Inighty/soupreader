import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/models/reading_settings.dart';
import 'package:soupreader/features/reader/services/reader_tip_selection_helper.dart';

void main() {
  test('non-none selection clears duplicate content across header and footer',
      () {
    const settings = ReadingSettings(
      headerLeftContent: 0, // 书名
      footerRightContent: 6, // 书名
      footerLeftContent: 0, // 进度
    );

    final next = ReaderTipSelectionHelper.applySelection(
      settings: settings,
      slot: ReaderTipSlot.footerLeft,
      selectedValue: 6, // 书名
    );

    expect(next.footerLeftContent, 6);
    expect(next.headerLeftContent, ReaderTipSelectionHelper.headerNoneValue);
    expect(next.footerRightContent, ReaderTipSelectionHelper.footerNoneValue);
  });

  test('selecting none does not clear other slots', () {
    const settings = ReadingSettings(
      headerLeftContent: 3, // 时间
      footerCenterContent: 2, // 时间
      headerRightContent: 4, // 电量
    );

    final next = ReaderTipSelectionHelper.applySelection(
      settings: settings,
      slot: ReaderTipSlot.headerRight,
      selectedValue: 2, // 无
    );

    expect(next.headerRightContent, 2);
    expect(next.headerLeftContent, 3);
    expect(next.footerCenterContent, 2);
  });

  test('header selection clears same semantic value in footer', () {
    const settings = ReadingSettings(
      headerRightContent: 4, // 电量
      footerLeftContent: 3, // 电量
    );

    final next = ReaderTipSelectionHelper.applySelection(
      settings: settings,
      slot: ReaderTipSlot.headerLeft,
      selectedValue: 4, // 电量
    );

    expect(next.headerLeftContent, 4);
    expect(next.headerRightContent, ReaderTipSelectionHelper.headerNoneValue);
    expect(next.footerLeftContent, ReaderTipSelectionHelper.footerNoneValue);
  });
}
