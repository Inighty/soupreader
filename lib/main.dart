import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/soup_reader_app.dart';
import 'app/widgets/app_error_widget.dart';
import 'core/services/exception_log_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Release 模式下默认 ErrorWidget 常退化为灰色方块，
  // 在无 Xcode 日志时难以诊断构建期故障。
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return AppErrorWidget(
      message: details.exceptionAsString(),
      stackTrace: details.stack?.toString(),
    );
  };

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

  runZonedGuarded(() async {
    debugPrint('[boot] bootstrap start');

    BootFailure? bootFailure;
    try {
      // 超时保护：如果 bootstrap 某步 hang 住（如 platform channel 死锁），
      // 30 秒后强制跳过并展示启动失败页面，避免永远卡在白色闪屏上。
      bootFailure = await bootstrapApp().timeout(const Duration(seconds: 30),
          onTimeout: () {
        debugPrint('[boot] bootstrapApp TIMEOUT after 30s');
        return BootFailure(
          stepName: 'timeout',
          error: 'Bootstrap 超时（30 秒），可能某步初始化 hang 住了。',
          stack: StackTrace.current,
        );
      });
    } catch (e, st) {
      debugPrint('[boot] bootstrapApp threw: $e');
      debugPrintStack(stackTrace: st);
      bootFailure = BootFailure(
        stepName: 'bootstrapApp',
        error: e,
        stack: st,
      );
    }

    debugPrint('[boot] bootstrap done, failure=$bootFailure');
    debugPrint('[boot] runApp start');
    runApp(SoupReaderApp(initialBootFailure: bootFailure));
    debugPrint('[boot] runApp done');
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
