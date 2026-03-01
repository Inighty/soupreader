import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<QueryExecutor> openSourceDriftConnection() async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final file = File(
    p.join(documentsDirectory.path, 'soupreader_sources.sqlite'),
  );
  // NOTE: iOS Release 下 `createInBackground` 若后台 isolate 启动失败，
  // 可能导致主 isolate 永久等待连接而“卡在启动白屏”。
  // 这里改为前台打开：若 SQLite 初始化失败，会显式抛错并被启动流程捕获。
  return NativeDatabase(
    file,
    logStatements: kDebugMode,
  );
}
