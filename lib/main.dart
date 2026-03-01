import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'app/bootstrap/app_bootstrap.dart';

/// 二分法测试：只引入 bootstrap 链（不引入 SoupReaderApp/MainScreen）。
/// 如果白屏 → 问题在 bootstrap 链（database/service/repository）。
/// 如果正常 → 问题在 UI 链（SoupReaderApp/MainScreen/feature views）。
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 先显示 UI
  runApp(const _TestApp(status: '正在执行 bootstrap...'));

  // 异步执行 bootstrap
  () async {
    debugPrint('[test] bootstrap start');
    final failure = await bootstrapApp();
    debugPrint('[test] bootstrap done, failure=$failure');
    runApp(_TestApp(
      status: failure == null
          ? 'Bootstrap 成功！'
          : 'Bootstrap 失败：${failure.stepName} - ${failure.error}',
    ));
  }();
}

class _TestApp extends StatelessWidget {
  final String status;
  const _TestApp({required this.status});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CupertinoPageScaffold(
        backgroundColor: const Color(0xFFFFF8E1),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              status,
              style:
                  const TextStyle(fontSize: 18, color: CupertinoColors.label),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
