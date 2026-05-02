import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/app_sheet_header.dart';
import '../../../app/widgets/app_sheet_panel.dart';
import '../models/reading_settings.dart';
import 'reader_quick_sheet_slider_row.dart';
import 'reader_style_config_list_sheet.dart';
import 'reader_style_edit_sheet.dart';
import 'reader_style_theme_picker_row.dart';

/// 阅读界面快速调整面板，对应底部菜单「界面」按钮。
///
/// 参考 legado ReadStyleDialog，用 iOS 方式重新设计：
/// chip 行（粗细/字体/缩进/简繁/边距/信息栏）+ 字号步进 + 字距/行距/段距滑杆 + 翻页模式 + 背景主题。
class ReaderStyleQuickSheet extends StatefulWidget {
  final ReadingSettings settings;
  final List<ReadingThemeColors> themes;
  final List<ReadStyleConfig> styleConfigs;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback? onOpenTipSettings;
  final VoidCallback? onOpenPaddingSettings;
  final VoidCallback? onImportStyle;
  final VoidCallback? onExportStyle;

  const ReaderStyleQuickSheet({
    super.key,
    required this.settings,
    required this.themes,
    required this.styleConfigs,
    required this.onSettingsChanged,
    this.onOpenTipSettings,
    this.onOpenPaddingSettings,
    this.onImportStyle,
    this.onExportStyle,
  });

  @override
  State<ReaderStyleQuickSheet> createState() =>
      _ReaderStyleQuickSheetState();
}

class _ReaderStyleQuickSheetState
    extends State<ReaderStyleQuickSheet> {
  late ReadingSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.settings;
  }

  void _apply(ReadingSettings next) {
    setState(() => _draft = next);
    widget.onSettingsChanged(next);
  }

  bool get _isDark =>
      CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get _labelColor => _isDark
      ? CupertinoColors.white
      : CupertinoColors.label.resolveFrom(context);

  Color get _metaColor => _isDark
      ? CupertinoColors.white.withValues(alpha: 0.5)
      : CupertinoColors.secondaryLabel.resolveFrom(context);

  @override
  Widget build(BuildContext context) {
    return AppSheetPanel(
      contentPadding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSheetHeader(title: '界面'),
            _buildChipRow(),
            _buildDivider(),
            _buildThemeRow(),
            _buildDivider(),
            _buildFontSizeRow(),
            _buildLetterSpacingRow(),
            _buildLineHeightRow(),
            _buildParagraphSpacingRow(),
            _buildDivider(),
            _buildPageTurnRow(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
  }

  Widget _buildChipRow() {
    final isDark = _isDark;
    // 粗细
    const boldLabels = {0: '正常', 1: '粗体', 2: '细体'};
    final boldLabel = boldLabels[_draft.textBold] ?? '正常';
    final nextBold = (_draft.textBold + 1) % 3;
    // 字体
    final fontName = ReadingFontFamily.getFontName(_draft.fontFamilyIndex);
    // 缩进
    final indentOptions = ['', '　', '　　', '　　　'];
    final indentLabels = ['无缩进', '缩进1', '缩进2', '缩进3'];
    final indentIndex = indentOptions.indexOf(_draft.paragraphIndent)
        .clamp(0, indentOptions.length - 1);
    final nextIndent = (indentIndex + 1) % indentOptions.length;
    final indentLabel = indentLabels[indentIndex];
    // 简繁
    final converterLabels = {0: '简繁', 1: '繁→简', 2: '简→繁'};
    final converterLabel = converterLabels[_draft.chineseConverterType] ?? '简繁';
    final nextConverter = (_draft.chineseConverterType + 1) % 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildChip(label: boldLabel, onTap: () => _apply(_draft.copyWith(textBold: nextBold)), isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildChip(label: fontName, onTap: () { final next = (_draft.fontFamilyIndex + 1) % ReadingFontFamily.presets.length; _apply(_draft.copyWith(fontFamilyIndex: next)); }, isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildChip(label: indentLabel, onTap: () => _apply(_draft.copyWith(paragraphIndent: indentOptions[nextIndent])), isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildChip(label: converterLabel, onTap: () => _apply(_draft.copyWith(chineseConverterType: nextConverter)), isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildChip(label: '边距', onTap: () { Navigator.pop(context); widget.onOpenPaddingSettings?.call(); }, isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildChip(label: '信息栏', onTap: () { Navigator.pop(context); widget.onOpenTipSettings?.call(); }, isDark: isDark)),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final bg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final textColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.85)
        : CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeRow() {
    final isDark = _isDark;
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final mutedColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    const double minSize = 8, maxSize = 50, step = 1;
    final sv = _draft.fontSize.isFinite
        ? _draft.fontSize.clamp(minSize, maxSize)
        : 18.0;
    final canDec = sv > minSize;
    final canInc = sv < maxSize;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Text('字号',
                style: TextStyle(
                    color: labelColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400)),
            const Spacer(),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size.zero,
              onPressed: canDec
                  ? () => _apply(
                        _draft.copyWith(
                            fontSize: (sv - step).clamp(minSize, maxSize)),
                      )
                  : null,
              child: Text('A',
                  style: TextStyle(
                      color: canDec ? _accent : mutedColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
            SizedBox(
              width: 36,
              child: Text(sv.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: labelColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
            ),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size.zero,
              onPressed: canInc
                  ? () => _apply(
                        _draft.copyWith(
                            fontSize: (sv + step).clamp(minSize, maxSize)),
                      )
                  : null,
              child: Text('A',
                  style: TextStyle(
                      color: canInc ? _accent : mutedColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineHeightRow() {
    final sv = _draft.lineHeight.isFinite
        ? _draft.lineHeight.clamp(1.0, 3.0)
        : 1.8;
    return ReaderQuickSheetSliderRow(
      label: '行距',
      value: sv.toDouble(),
      min: 1.0,
      max: 3.0,
      labelColor: _labelColor,
      metaColor: _metaColor,
      accent: _accent,
      onChanged: (v) => _apply(_draft.copyWith(lineHeight: v)),
      formatValue: (v) => v.toStringAsFixed(1),
    );
  }

  Widget _buildLetterSpacingRow() {
    final sv = _draft.letterSpacing.isFinite
        ? _draft.letterSpacing.clamp(-2.0, 5.0)
        : 0.0;
    return ReaderQuickSheetSliderRow(
      label: '字距',
      value: sv.toDouble(),
      min: -2.0,
      max: 5.0,
      valueWidth: 40,
      labelColor: _labelColor,
      metaColor: _metaColor,
      accent: _accent,
      onChanged: (v) => _apply(_draft.copyWith(letterSpacing: v)),
      formatValue: (v) => v.toStringAsFixed(1),
    );
  }

  Widget _buildParagraphSpacingRow() {
    final sv = _draft.paragraphSpacing.isFinite
        ? _draft.paragraphSpacing.clamp(0.0, 50.0)
        : 0.0;
    return ReaderQuickSheetSliderRow(
      label: '段距',
      value: sv.toDouble(),
      min: 0.0,
      max: 50.0,
      valueWidth: 40,
      labelColor: _labelColor,
      metaColor: _metaColor,
      accent: _accent,
      onChanged: (v) => _apply(_draft.copyWith(paragraphSpacing: v)),
      formatValue: (v) => v.toStringAsFixed(0),
    );
  }

  Widget _buildPageTurnRow() {
    final isDark = _isDark;
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final modes = [
      PageTurnMode.cover,
      PageTurnMode.slide,
      PageTurnMode.simulation,
      PageTurnMode.scroll,
      PageTurnMode.none,
    ];
    final bg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final textNormal = isDark
        ? CupertinoColors.white.withValues(alpha: 0.7)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('翻页',
              style: TextStyle(
                  color: labelColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w400)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: modes.map((mode) {
                final selected = _draft.pageTurnMode == mode;
                final chipBg = selected
                    ? _accent.withValues(alpha: isDark ? 0.18 : 0.12)
                    : bg;
                final chipText = selected ? _accent : textNormal;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () =>
                        _apply(_draft.copyWith(pageTurnMode: mode)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(
                            AppDesignTokens.radiusControl),
                        border: selected
                            ? Border.all(
                                color: _accent.withValues(alpha: 0.5),
                                width: 1.5)
                            : null,
                      ),
                      child: Text(
                        mode.name,
                        style: TextStyle(
                          color: chipText,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildThemeRow() => ReaderStyleThemePickerRow(
        draft: _draft,
        fallbackStyleConfigs: widget.styleConfigs,
        accent: _accent,
        isDark: _isDark,
        onApply: _apply,
        onAddNew: _addNewStyle,
        onOpenList: _openStyleListSheet,
        onOpenEdit: _openEditSheet,
      );

  void _openStyleListSheet(
    List<ReadStyleConfig> configs,
    int selectedIndex,
  ) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => ReaderStyleConfigListSheet(
        configs: configs,
        selectedIndex: selectedIndex,
        onConfigsChanged: (newConfigs) {
          _apply(_draft.copyWith(readStyleConfigs: newConfigs));
        },
        onSelectIndex: (i) {
          _apply(_draft.copyWith(themeIndex: i));
        },
        onImport: widget.onImportStyle,
        onExport: widget.onExportStyle,
      ),
    );
  }

  void _addNewStyle() {
    final configs = _draft.readStyleConfigs.isNotEmpty
        ? _draft.readStyleConfigs
        : widget.styleConfigs;
    final newConfig = const ReadStyleConfig(
      name: '新样式',
      backgroundColor: 0xFFFFFFFF,
      textColor: 0xFF333333,
      bgType: ReadStyleConfig.bgTypeColor,
      bgStr: '#FFFFFF',
      bgAlpha: 100,
    );
    final newIndex = configs.length;
    final newConfigs = List<ReadStyleConfig>.from(configs)..add(newConfig);
    _apply(_draft.copyWith(
      readStyleConfigs: newConfigs,
      themeIndex: newIndex,
    ));
    // 打开编辑面板
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openEditSheet(newIndex, newConfig, newConfigs);
    });
  }

  void _openEditSheet(
    int index,
    ReadStyleConfig config,
    List<ReadStyleConfig> configs,
  ) {
    final canDelete = configs.length > ReadStyleConfig.minEditableCount;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => ReaderStyleEditSheet(
        config: config,
        canDelete: canDelete,
        onChanged: (updated) {
          final newConfigs = List<ReadStyleConfig>.from(configs);
          if (index < newConfigs.length) {
            newConfigs[index] = updated;
          }
          _apply(_draft.copyWith(readStyleConfigs: newConfigs));
        },
        onDelete: () {
          final newConfigs = List<ReadStyleConfig>.from(configs);
          if (index < newConfigs.length) {
            newConfigs.removeAt(index);
          }
          final newIndex = _draft.themeIndex >= newConfigs.length
              ? newConfigs.length - 1
              : _draft.themeIndex;
          _apply(_draft.copyWith(
            readStyleConfigs: newConfigs,
            themeIndex: newIndex.clamp(0, newConfigs.length - 1),
          ));
        },
      ),
    );
  }
}
