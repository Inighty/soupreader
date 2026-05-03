import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/database_service.dart';
import '../../core/services/exception_log_service.dart';
import 'import_file_support.dart';
import 'import_results.dart';

class ImportDirectoryService {
  static const String _importBookPathKey = 'importBookPath';

  final DatabaseService _database;

  ImportDirectoryService({DatabaseService? database})
      : _database = database ?? DatabaseService();

  String? getSavedImportDirectory() {
    final raw = _database.getSetting(_importBookPathKey, defaultValue: null);
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return p.normalize(text);
  }

  Future<ImportDirectorySelectionResult> selectImportDirectory({
    String? initialDirectory,
  }) async {
    try {
      final selected = await FilePicker.platform.getDirectoryPath(
        initialDirectory: _resolveInitialDirectory(initialDirectory),
      );
      final normalized = (selected ?? '').trim();
      if (normalized.isEmpty) {
        return ImportDirectorySelectionResult.cancelled();
      }
      final directoryPath = p.normalize(normalized);
      final validationError = await _validateImportDirectory(directoryPath);
      if (validationError != null) {
        return ImportDirectorySelectionResult.error(validationError);
      }
      await _database.putSetting(_importBookPathKey, directoryPath);
      return ImportDirectorySelectionResult.success(
        directoryPath: directoryPath,
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.import.select_folder.failed',
        message: '选择导入文件夹失败',
        error: error,
        stackTrace: stackTrace,
      );
      return ImportDirectorySelectionResult.error(error.toString());
    }
  }

  Future<ImportDirectoryCreateResult> createImportDirectory({
    required String parentDirectoryPath,
    required String folderName,
  }) async {
    final normalizedParent = p.normalize(parentDirectoryPath.trim());
    final normalizedName = folderName.trim();
    final nameError = _validateFolderName(normalizedName);
    if (nameError != null) {
      return ImportDirectoryCreateResult.error(nameError);
    }

    try {
      final parentDirectory = Directory(normalizedParent);
      if (!await parentDirectory.exists()) {
        return ImportDirectoryCreateResult.error('父文件夹不存在');
      }
      if (!await _isAllowedImportDirectory(normalizedParent)) {
        return ImportDirectoryCreateResult.error('请选择应用目录之外的文件夹');
      }
      final normalizedTarget = p.normalize(
        p.join(normalizedParent, normalizedName),
      );
      if (normalizedTarget == normalizedParent ||
          !p.isWithin(normalizedParent, normalizedTarget)) {
        return ImportDirectoryCreateResult.error('非法文件夹名');
      }
      final targetDirectory = Directory(normalizedTarget);
      if (!await targetDirectory.exists()) {
        await targetDirectory.create(recursive: false);
      }
      if (!await targetDirectory.exists()) {
        return ImportDirectoryCreateResult.error('创建文件夹失败');
      }
      if (!await _isAllowedImportDirectory(normalizedTarget)) {
        return ImportDirectoryCreateResult.error('请选择应用目录之外的文件夹');
      }
      await _database.putSetting(_importBookPathKey, normalizedTarget);
      return ImportDirectoryCreateResult.success(
        directoryPath: normalizedTarget,
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.import.create_folder.failed',
        message: '创建导入文件夹失败',
        error: error,
        stackTrace: stackTrace,
      );
      return ImportDirectoryCreateResult.error(error.toString());
    }
  }

  Future<ImportScanResult> scanImportDirectory() async {
    final savedDirectory = getSavedImportDirectory();
    if (savedDirectory == null || savedDirectory.trim().isEmpty) {
      return ImportScanResult.error('请先选择文件夹');
    }

    final normalizedRoot = p.normalize(savedDirectory);
    final rootDirectory = Directory(normalizedRoot);
    if (!await rootDirectory.exists()) {
      return ImportScanResult.error('所选文件夹不存在');
    }

    final candidates = <ImportScanCandidate>[];
    try {
      await for (final entity
          in rootDirectory.list(recursive: true, followLinks: false)) {
        final candidate = await _scanFile(entity);
        if (candidate != null) {
          candidates.add(candidate);
        }
      }
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.import.scan_folder.failed',
        message: '智能扫描文件夹失败',
        error: error,
        stackTrace: stackTrace,
      );
      return ImportScanResult.error(error.toString());
    }

    candidates.sort((a, b) {
      final nameCompare = a.fileName.compareTo(b.fileName);
      if (nameCompare != 0) return nameCompare;
      return a.filePath.compareTo(b.filePath);
    });
    return ImportScanResult.success(
      rootDirectoryPath: normalizedRoot,
      candidates: candidates,
    );
  }

  Future<BatchDeleteResult> deleteLocalBooksByPaths(
    List<String> filePaths,
  ) async {
    final uniquePaths = _normalizeUniquePaths(filePaths);
    if (uniquePaths.isEmpty) {
      return const BatchDeleteResult(
        totalCount: 0,
        deletedCount: 0,
        failures: <BatchDeleteFailure>[],
      );
    }

    final failures = <BatchDeleteFailure>[];
    for (final filePath in uniquePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (error, stackTrace) {
        ExceptionLogService().record(
          node: 'bookshelf.import.scan_folder.delete_file.failed',
          message: '删除导入文件失败',
          error: error,
          stackTrace: stackTrace,
        );
        failures.add(
          BatchDeleteFailure(
            filePath: filePath,
            errorMessage: error.toString(),
          ),
        );
      }
    }

    return BatchDeleteResult(
      totalCount: uniquePaths.length,
      deletedCount: uniquePaths.length - failures.length,
      failures: failures,
    );
  }

  String? _resolveInitialDirectory(String? initialDirectory) {
    if (initialDirectory?.trim().isNotEmpty ?? false) {
      return p.normalize(initialDirectory!.trim());
    }
    return getSavedImportDirectory();
  }

  Future<ImportScanCandidate?> _scanFile(FileSystemEntity entity) async {
    if (entity is! File) return null;
    final extension = normalizeImportExtension(p.extension(entity.path));
    if (!kSupportedImportExtensions.contains(extension)) {
      return null;
    }
    final normalizedPath = p.normalize(entity.path);
    final stat = await _statFile(entity, normalizedPath);
    return ImportScanCandidate(
      filePath: normalizedPath,
      fileName: p.basename(normalizedPath),
      sizeInBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }

  Future<FileStat> _statFile(File file, String normalizedPath) async {
    try {
      return await file.stat();
    } catch (_) {
      return FileStat.statSync(normalizedPath);
    }
  }

  String? _validateFolderName(String normalizedName) {
    if (normalizedName.isEmpty) return '文件夹名不能为空';
    if (normalizedName == '.' || normalizedName == '..') return '非法文件夹名';
    if (normalizedName.contains(RegExp(r'[\\/]'))) {
      return '文件夹名不能包含路径分隔符';
    }
    return null;
  }

  Future<String?> _validateImportDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return '所选文件夹不存在';
    }
    if (!await _isAllowedImportDirectory(directoryPath)) {
      return '请选择应用目录之外的文件夹';
    }
    return null;
  }

  Set<String> _normalizeUniquePaths(List<String> filePaths) {
    final uniquePaths = <String>{};
    for (final rawPath in filePaths) {
      final normalizedPath = p.normalize(rawPath.trim());
      if (normalizedPath.isEmpty) continue;
      uniquePaths.add(normalizedPath);
    }
    return uniquePaths;
  }

  Future<bool> _isAllowedImportDirectory(String directoryPath) async {
    final normalized = p.normalize(directoryPath.trim());
    if (normalized.isEmpty) return false;

    final protectedDirectories = <String>{};
    await _collectProtectedPath(
      protectedDirectories,
      getApplicationSupportDirectory,
    );
    await _collectProtectedPath(
      protectedDirectories,
      getApplicationDocumentsDirectory,
    );
    await _collectProtectedPath(protectedDirectories, getTemporaryDirectory);

    for (final protectedPath in protectedDirectories) {
      if (normalized == protectedPath) return false;
      if (p.isWithin(protectedPath, normalized)) return false;
    }
    return true;
  }

  Future<void> _collectProtectedPath(
    Set<String> protectedDirectories,
    Future<Directory> Function() loader,
  ) async {
    try {
      final directory = await loader();
      final path = p.normalize(directory.path.trim());
      if (path.isNotEmpty) {
        protectedDirectories.add(path);
      }
    } catch (_) {
      // 路径查询失败时按原流程忽略，继续校验其它系统目录。
    }
  }
}
