import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'app/bootstrap/boot_host_app.dart';
import 'core/services/exception_log_service.dart';

const MethodChannel _bootOverlayChannel = MethodChannel('soupreader/boot_overlay');

void _hideNativeBootOverlayAfterFirstFrame() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await _bootOverlayChannel.invokeMethod<void>('hide');
    } catch (e) {
      debugPrint('[boot-overlay] hide failed: $e');
    }
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 全局错误处理 ──
  // 注意：不设置 ErrorWidget.builder。
  // 在 Release 模式下，默认 ErrorWidget 显示为灰色方块，虽然不好看但不会引发
  // 递归 Stack Overflow。自定义 ErrorWidget（如 CupertinoPageScaffold 等）在缺少
  // CupertinoTheme 上下文时自身也会 crash，导致无限递归白屏。

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[flutter-error] ${details.exceptionAsString()}');
    ExceptionLogService().record(
      node: 'global.flutter_error',
      message: details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
      context: <String, dynamic>{
        if (details.library != null) 'library': details.library!,
      },
    );
    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[platform-error] $error');
    ExceptionLogService().record(
      node: 'global.platform_error',
      message: 'PlatformDispatcher.onError',
      error: error,
      stackTrace: stack,
    );
    debugPrintStack(stackTrace: stack);
    return true;
  };

  runZonedGuarded(() {
    runApp(const BootHostApp());
    _hideNativeBootOverlayAfterFirstFrame();
  }, (Object error, StackTrace stack) {
    debugPrint('[zone-error] $error');
    ExceptionLogService().record(
      node: 'global.zone_error',
      message: 'runZonedGuarded 捕获未处理异常',
      error: error,
      stackTrace: stack,
    );
    debugPrintStack(stackTrace: stack);
  });
}
