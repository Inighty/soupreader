import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/reading_settings.dart';
import 'reader_style_asset_picker.dart';
import 'reader_style_edit_dialogs.dart';

/// 阅读样式编辑面板（对标 legado BgTextConfigDialog）。
class ReaderStyleEditSheet extends StatefulWidget {
  final ReadStyleConfig config;
  final bool canDelete;
  final ValueChanged<ReadStyleConfig> onChanged;
  final VoidCallback? onDelete;

  const ReaderStyleEditSheet({
    super.key,
    required this.config,
    required this.canDelete,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<ReaderStyleEditSheet> createState() => _ReaderStyleEditSheetState();
}

class _ReaderStyleEditSheetState extends State<ReaderStyleEditSheet> {
  late ReadStyleConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.config.sanitize();
  }

  void _update(ReadStyleConfig next) {
    final sanitized = next.sanitize();
    setState(() => _draft = sanitized);
    widget.onChanged(sanitized);
  }

  bool get _isDark =>
      CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent =>
      _isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    final sheetBg = isDark
        ? CupertinoColors.systemGroupedBackground.resolveFrom(context).darkColor
        : CupertinoColors.systemGroupedBackground.resolveFrom(context).color;
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final mutedColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      child: Container(
        color: sheetBg,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGrabber(separatorColor),
              _buildHeader(labelColor, isDark),
              _buildDivider(separatorColor),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildNameRow(labelColor, mutedColor, separatorColor),
                      _buildDivider(separatorColor),
                      _buildColorRow(
                        label: '文字颜色',
                        colorValue: _draft.textColor,
                        labelColor: labelColor,
                        separatorColor: separatorColor,
                        onTap: _pickTextColor,
                      ),
                      _buildDivider(separatorColor),
                      _buildColorRow(
                        label: '背景颜色',
                        colorValue: _draft.backgroundColor,
                        labelColor: labelColor,
                        separatorColor: separatorColor,
                        onTap: _draft.bgType == ReadStyleConfig.bgTypeColor
                            ? _pickBgColor
                            : null,
                      ),
                      _buildDivider(separatorColor),
                      _buildBgTypeRow(labelColor, mutedColor, isDark),
                      if (_draft.bgType == ReadStyleConfig.bgTypeAsset) ...[
                        _buildDivider(separatorColor),
                        _buildAssetPicker(separatorColor),
                      ],
                      if (_draft.bgType == ReadStyleConfig.bgTypeFile) ...[
                        _buildDivider(separatorColor),
                        _buildFilePickerRow(labelColor, mutedColor),
                      ],
                      _buildDivider(separatorColor),
                      _buildAlphaRow(labelColor, mutedColor),
                      _buildDivider(separatorColor),
                      _buildPresetRow(labelColor, isDark),
                      if (widget.canDelete) ...[
                        _buildDivider(separatorColor),
                        _buildDeleteRow(),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrabber(Color color) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(Color labelColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '编辑样式',
              style: TextStyle(
                color: labelColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          CupertinoButton(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            minimumSize: Size.zero,
            onPressed: () => Navigator.pop(context),
            child: Text(
              '完成',
              style: TextStyle(
                color: _accent,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(height: 0.5, color: color);
  }

  Widget _buildNameRow(
    Color labelColor,
    Color mutedColor,
    Color separatorColor,
  ) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: Size.zero,
      onPressed: _editName,
      child: Row(
        children: [
          Text(
            '样式名称',
            style: TextStyle(color: labelColor, fontSize: 15),
          ),
          const Spacer(),
          Text(
            _draft.name.isEmpty ? '未命名' : _draft.name,
            style: TextStyle(color: mutedColor, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_right,
            color: mutedColor,
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow({
    required String label,
    required int colorValue,
    required Color labelColor,
    required Color separatorColor,
    VoidCallback? onTap,
  }) {
    final color = Color(colorValue);
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(color: labelColor, fontSize: 15),
            ),
            const Spacer(),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: separatorColor, width: 0.8),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '#${readerStyleHexRgb(colorValue)}',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 13,
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBgTypeRow(Color labelColor, Color mutedColor, bool isDark) {
    final types = [
      (ReadStyleConfig.bgTypeColor, '纯色'),
      (ReadStyleConfig.bgTypeAsset, '内置图片'),
      (ReadStyleConfig.bgTypeFile, '自定义图片'),
    ];
    final chipBg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            '背景类型',
            style: TextStyle(color: labelColor, fontSize: 15),
          ),
          const Spacer(),
          for (final (type, name) in types)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => _setBgType(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _draft.bgType == type
                        ? _accent.withValues(alpha: isDark ? 0.18 : 0.12)
                        : chipBg,
                    borderRadius: BorderRadius.circular(8),
                    border: _draft.bgType == type
                        ? Border.all(
                            color: _accent.withValues(alpha: 0.5),
                            width: 1.5)
                        : null,
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: _draft.bgType == type ? _accent : mutedColor,
                      fontSize: 13,
                      fontWeight: _draft.bgType == type
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssetPicker(Color separatorColor) {
    return ReaderStyleAssetPicker(
      draft: _draft,
      accent: _accent,
      separatorColor: separatorColor,
      onSelected: _update,
    );
  }

  Widget _buildAlphaRow(Color labelColor, Color mutedColor) =>
      ReaderStyleAlphaRow(
        draft: _draft,
        labelColor: labelColor,
        mutedColor: mutedColor,
        accent: _accent,
        onUpdate: _update,
      );

  Widget _buildPresetRow(Color labelColor, bool isDark) => ReaderStylePresetRow(
        labelColor: labelColor,
        onTap: _showPresetPicker,
      );

  Widget _buildDeleteRow() => ReaderStyleDeleteRow(onTap: _confirmDelete);

  Future<void> _editName() => showReaderStyleNameDialog(
        context: context,
        draft: _draft,
        onUpdate: _update,
      );

  Future<void> _pickTextColor() => showReaderStyleTextColorPicker(
        context: context,
        draft: _draft,
        onUpdate: _update,
      );

  Future<void> _pickBgColor() => showReaderStyleBgColorPicker(
        context: context,
        draft: _draft,
        onUpdate: _update,
      );

  void _setBgType(int type) {
    if (type == _draft.bgType) return;
    if (type == ReadStyleConfig.bgTypeColor) {
      _update(_draft.copyWith(
        bgType: ReadStyleConfig.bgTypeColor,
        bgStr: '#${readerStyleHexRgb(_draft.backgroundColor)}',
        bgAlpha: 100,
      ));
    } else if (type == ReadStyleConfig.bgTypeFile) {
      // 对齐 legado：直接触发文件选择，不产生 bgStr 为空的中间状态
      _pickBgFile();
    } else {
      final defaultAsset =
          kBundledBgAssets.isNotEmpty ? kBundledBgAssets.first : '';
      _update(_draft.copyWith(
        bgType: type,
        bgStr: defaultAsset,
        bgAlpha: _draft.bgAlpha == 100 ? 80 : _draft.bgAlpha,
      ));
    }
  }

  Future<void> _pickBgFile() => pickReaderStyleBgFile(
        draft: _draft,
        onUpdate: _update,
        isMounted: () => mounted,
      );

  Widget _buildFilePickerRow(Color labelColor, Color mutedColor) {
    final hasFile = !kIsWeb &&
        _draft.bgStr.isNotEmpty &&
        File(_draft.bgStr).existsSync();
    final fileName = hasFile
        ? _draft.bgStr.split('/').last
        : '未选择图片';
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: _pickBgFile,
      child: Row(
        children: [
          Text(
            '选择图片',
            style: TextStyle(color: labelColor, fontSize: 15),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: mutedColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: mutedColor,
          ),
        ],
      ),
    );
  }

  void _showPresetPicker() => showReaderStylePresetPicker(
        context: context,
        draft: _draft,
        onUpdate: _update,
      );

  void _confirmDelete() => confirmReaderStyleDelete(
        context: context,
        draft: _draft,
        onDelete: widget.onDelete,
      );
}
