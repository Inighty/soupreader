import 'package:flutter/cupertino.dart';

import '../models/reading_settings.dart';

/// "背景图片"横向选择器：内置 `kBundledBgAssets` 列表 + 选中态。
class ReaderStyleAssetPicker extends StatelessWidget {
  final ReadStyleConfig draft;
  final Color accent;
  final Color separatorColor;
  final ValueChanged<ReadStyleConfig> onSelected;

  const ReaderStyleAssetPicker({
    super.key,
    required this.draft,
    required this.accent,
    required this.separatorColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: kBundledBgAssets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final fileName = kBundledBgAssets[i];
          final assetPath = 'assets/bg/$fileName';
          final selected = draft.bgStr == fileName ||
              draft.bgStr == assetPath ||
              draft.bgStr == 'assets/bg/$fileName';
          return GestureDetector(
            onTap: () => onSelected(draft.copyWith(
              bgType: ReadStyleConfig.bgTypeAsset,
              bgStr: fileName,
            )),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? accent : separatorColor,
                  width: selected ? 2.0 : 0.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color:
                          CupertinoColors.systemGrey5.resolveFrom(context),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    left: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0x88000000),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        fileName.replaceAll('.jpg', ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark,
                          color: CupertinoColors.white,
                          size: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
