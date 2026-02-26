import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/exception_log_service.dart';

class AboutSettingsView extends StatefulWidget {
  const AboutSettingsView({super.key});

  @override
  State<AboutSettingsView> createState() => _AboutSettingsViewState();
}

class _AboutSettingsViewState extends State<AboutSettingsView> {
  static const String _fallbackAppName = 'SoupReader';
  static const String _appShareDescription =
      'SoupReader 下载链接：\nhttps://github.com/Inighty/soupreader/releases';

  String _version = '—';
  String _appName = _fallbackAppName;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final appName = info.appName.trim();
      if (!mounted) return;
      setState(() {
        _appName = appName.isEmpty ? _fallbackAppName : appName;
        _version = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appName = _fallbackAppName;
        _version = '—';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '关于与诊断',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(30, 30),
        onPressed: _handleShare,
        child: const Icon(CupertinoIcons.share),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('应用'),
            children: [
              CupertinoListTile.notched(
                title: const Text('应用名称'),
                additionalInfo: const Text('SoupReader'),
              ),
              CupertinoListTile.notched(
                title: const Text('版本'),
                additionalInfo: Text(_version),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('更新'),
            children: [
              CupertinoListTile.notched(
                title: const Text('检查更新'),
                trailing: const CupertinoListTileChevron(),
                onTap: _checkUpdate,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('说明'),
            children: const [
              CupertinoListTile(
                title: Text('如遇到书源解析问题，建议在“书源”中导出相关书源 JSON 便于排查。'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _handleShare() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _appShareDescription,
          subject: _appName,
        ),
      );
    } catch (_) {
      // 对齐 legado Context.share(text, title)：分享失败静默吞掉。
    }
  }

  Future<void> _checkUpdate() async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://github-action-cf.mcshr.workers.dev/latest',
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final updateInfo = _parseUpdateInfo(response.data);
        if (updateInfo == null) {
          _showMessage('检查失败');
          return;
        }
        if (updateInfo.downloadUrl.isEmpty) {
          _showMessage('未找到安装包');
          return;
        }
        if (updateInfo.updateBody.trim().isEmpty) {
          _showMessage('没有数据');
          return;
        }
        _showUpdateInfo(updateInfo);
        return;
      }

      _showMessage('检查失败');
    } catch (e, stackTrace) {
      ExceptionLogService().record(
        node: 'app_update.check_update',
        message: '检查更新失败',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        Navigator.pop(context);
        if (e is DioException && e.response?.statusCode == 404) {
          _showMessage('暂无更新');
        } else {
          _showMessage('检查失败');
        }
      }
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  _AppUpdateInfo? _parseUpdateInfo(dynamic rawData) {
    Map<String, dynamic>? map;
    if (rawData is Map) {
      map = rawData.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } else if (rawData is String) {
      final rawText = rawData.trim();
      if (rawText.isEmpty) return null;
      try {
        final decoded = jsonDecode(rawText);
        if (decoded is Map) {
          map = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } catch (_) {
        return null;
      }
    }
    if (map == null) return null;

    final tagName = _firstNonEmptyString([
          _readString(map, 'tag'),
          _readString(map, 'tagName'),
          _readString(map, 'version'),
        ]) ??
        'nightly';
    final name = _readString(map, 'name') ?? 'Nightly Build';
    final publishedAtText = _formatPublishedAt(_readString(map, 'publishedAt'));
    final updateBody = _firstNonEmptyString([
          _readString(map, 'updateLog'),
          _readString(map, 'body'),
          _readString(map, 'note'),
          _readString(map, 'description'),
          _readString(map, 'info'),
        ]) ??
        [
          name,
          if (publishedAtText != null && publishedAtText.isNotEmpty)
            publishedAtText,
        ].join('\n');
    final downloadUrl = _firstNonEmptyString([
          _readString(map, 'downloadUrl'),
          _readString(map, 'apkUrl'),
          _readString(map, 'url'),
          _readString(map, 'browser_download_url'),
        ]) ??
        '';
    final fileName = _firstNonEmptyString([
          _readString(map, 'fileName'),
          _readString(map, 'name'),
        ]) ??
        _fallbackApkName(tagName);
    return _AppUpdateInfo(
      tagName: tagName,
      updateBody: updateBody,
      downloadUrl: downloadUrl,
      fileName: fileName,
    );
  }

  String? _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _firstNonEmptyString(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String? _formatPublishedAt(String? publishedAt) {
    final text = publishedAt?.trim() ?? '';
    if (text.isEmpty) return null;
    try {
      final date = DateTime.parse(text).toLocal();
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return text;
    }
  }

  String _fallbackApkName(String tagName) {
    final normalized = tagName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return 'soupreader_$normalized.apk';
  }

  void _showUpdateInfo(_AppUpdateInfo updateInfo) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AppUpdateDialog(
        updateInfo: updateInfo,
        onDownload: () => _handleDownloadAction(updateInfo),
      ),
    );
  }

  Future<void> _handleDownloadAction(_AppUpdateInfo updateInfo) async {
    final downloadUrl = updateInfo.downloadUrl.trim();
    final fileName = updateInfo.fileName.trim();
    if (downloadUrl.isEmpty || fileName.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) {
      ExceptionLogService().record(
        node: 'app_update.menu_download',
        message: '更新下载链接无效',
        context: {
          'downloadUrl': downloadUrl,
          'fileName': fileName,
        },
      );
      _showMessage('下载启动失败');
      return;
    }

    try {
      final started = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!started) {
        ExceptionLogService().record(
          node: 'app_update.menu_download',
          message: '更新下载未能启动',
          context: {
            'downloadUrl': downloadUrl,
            'fileName': fileName,
          },
        );
        _showMessage('下载启动失败');
        return;
      }
      if (!mounted) return;
      _showMessage('开始下载');
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'app_update.menu_download',
        message: '更新下载触发失败',
        error: error,
        stackTrace: stackTrace,
        context: {
          'downloadUrl': downloadUrl,
          'fileName': fileName,
        },
      );
      if (!mounted) return;
      _showMessage('下载启动失败');
    }
  }
}

class _AppUpdateInfo {
  final String tagName;
  final String updateBody;
  final String downloadUrl;
  final String fileName;

  const _AppUpdateInfo({
    required this.tagName,
    required this.updateBody,
    required this.downloadUrl,
    required this.fileName,
  });
}

class _AppUpdateDialog extends StatelessWidget {
  final _AppUpdateInfo updateInfo;
  final Future<void> Function() onDownload;

  const _AppUpdateDialog({
    required this.updateInfo,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * 0.92, 680.0);
    final height = math.min(screenSize.height * 0.82, 760.0);
    final separator = CupertinoColors.separator.resolveFrom(context);
    final bodyColor = CupertinoColors.label.resolveFrom(context);

    return Center(
      child: CupertinoPopupSurface(
        child: SizedBox(
          width: width,
          height: height,
          child: CupertinoPageScaffold(
            backgroundColor:
                CupertinoColors.systemBackground.resolveFrom(context),
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
                          minSize: 30,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Icon(CupertinoIcons.xmark),
                        ),
                        Expanded(
                          child: Text(
                            updateInfo.tagName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minSize: 30,
                          onPressed: () async {
                            await onDownload();
                          },
                          child: const Text('下载'),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 0.5, color: separator),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                      child: SelectableText(
                        updateInfo.updateBody,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.48,
                          color: bodyColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
