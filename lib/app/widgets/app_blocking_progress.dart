import 'package:flutter/cupertino.dart';

/// 阻塞操作进行中的内容展示（菊花 + 文字）。
class AppBlockingProgress extends StatelessWidget {
  final String text;

  const AppBlockingProgress({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 10),
          Text(text),
        ],
      ),
    );
  }
}
