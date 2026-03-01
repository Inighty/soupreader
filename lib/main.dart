import 'package:flutter/cupertino.dart';

/// 绝对最小测试：不引用任何项目代码，只用 Flutter 核心。
/// 如果这个也白屏 → pubspec.yaml 中某依赖导致 AOT 编译失败。
/// 如果这个正常 → reui 新增的 Dart 文件有编译问题。
void main() {
  runApp(
    const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CupertinoPageScaffold(
        child: Center(
          child: Text(
            'SoupReader Boot Test OK',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    ),
  );
}
