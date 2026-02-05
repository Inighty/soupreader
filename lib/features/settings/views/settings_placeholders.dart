import 'package:flutter/cupertino.dart';

class SettingsPlaceholders {
  static void showNotImplemented(BuildContext context, {String? title}) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n${title ?? '该功能暂未实现'}'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

