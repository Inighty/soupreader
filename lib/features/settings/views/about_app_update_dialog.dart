import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_sheet_panel.dart';
import 'about_app_update.dart';

/// 更新说明全屏对话框。
class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.onDownload,
  });

  final AppUpdateInfo updateInfo;
  final Future<void> Function() onDownload;

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * 0.92, 680.0);
    final height = math.min(screenSize.height * 0.82, 760.0);
    final ui = AppUiTokens.resolve(context);
    final separator = ui.colors.separator.withValues(alpha: 0.78);

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: AppSheetPanel(
          contentPadding: EdgeInsets.zero,
          radius: ui.radii.sheet,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        onPressed: () => Navigator.of(context).pop(),
                        minimumSize: const Size(30, 30),
                        child: const Icon(CupertinoIcons.xmark),
                      ),
                      Expanded(
                        child: Text(
                          widget.updateInfo.tagName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: widget.onDownload,
                        minimumSize: const Size(30, 30),
                        child: const Text('巨魔安装'),
                      ),
                    ],
                  ),
                ),
                Container(height: ui.sizes.dividerThickness, color: separator),
                Expanded(
                  child: CupertinoScrollbar(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                      child: SelectableRegion(
                        focusNode: _focusNode,
                        selectionControls: cupertinoTextSelectionControls,
                        child: Text(
                          widget.updateInfo.updateBody,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.48,
                            color: ui.colors.label,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
