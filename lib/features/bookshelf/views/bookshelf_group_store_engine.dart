// ignore_for_file: invalid_use_of_protected_member

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/services/exception_log_service.dart';
import '../models/bookshelf_book_group.dart';
import 'bookshelf_view.dart';

extension BookshelfGroupStoreEngine on BookshelfViewState {
  Future<void> reloadBookGroupContext({required bool showError}) async {
    try {
      final groups = await bookGroupStore.getGroups();
      if (!mounted) return;
      final normalizedGroups = normalizeGroups(groups);
      final groupMembership = readBookGroupMembershipMap();
      var nextSelectedGroupId = selectedGroupId;
      final hasSelectedGroup = nextSelectedGroupId ==
              BookshelfBookGroup.idRoot ||
          normalizedGroups.any((group) => group.groupId == nextSelectedGroupId);
      if (!hasSelectedGroup) {
        nextSelectedGroupId = BookshelfBookGroup.idRoot;
      }
      setState(() {
        bookGroups = normalizedGroups;
        bookGroupMembershipMap = groupMembership;
        selectedGroupId = nextSelectedGroupId;
      });
    } catch (error, stackTrace) {
      debugPrint('[bookshelf] 加载分组失败: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!showError || !mounted) return;
      showMessage('加载分组失败：$error');
    }
  }

  List<BookshelfBookGroup> normalizeGroups(List<BookshelfBookGroup> groups) {
    final byId = <int, BookshelfBookGroup>{
      for (final group in groups) group.groupId: group,
    };
    for (final fallback in BookshelfViewState.defaultBookGroups) {
      byId.putIfAbsent(fallback.groupId, () => fallback);
    }
    final normalized = byId.values.toList(growable: false);
    normalized.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.groupId.compareTo(b.groupId);
    });
    return normalized;
  }

  Map<String, int> readBookGroupMembershipMap() {
    final raw = database.getSetting(
      BookshelfViewState.bookGroupMembershipSettingKey,
      defaultValue: const <String, dynamic>{},
    );
    if (raw is! Map) return const <String, int>{};
    final parsed = <String, int>{};
    raw.forEach((key, value) {
      final bookId = '$key'.trim();
      if (bookId.isEmpty) return;
      parsed[bookId] = parseGroupBits(value);
    });
    return parsed;
  }

  int parseGroupBits(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  int readStyle1SelectedTabIndex() {
    final raw = database.getSetting(
      BookshelfViewState.style1SelectedTabIndexSettingKey,
      defaultValue: 0,
    );
    if (raw is int) return math.max(raw, 0);
    if (raw is num) return math.max(raw.toInt(), 0);
    if (raw is String) {
      return math.max(int.tryParse(raw.trim()) ?? 0, 0);
    }
    return 0;
  }

  Future<void> persistStyle1SelectedTabIndex(int index) async {
    final normalized = math.max(index, 0);
    try {
      await database.putSetting(
        BookshelfViewState.style1SelectedTabIndexSettingKey,
        normalized,
      );
      debugPrint('[bookshelf] style1 save tab index=$normalized');
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.style1.save_tab_index',
        message: '保存 style1 分组页签索引失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'tabIndex': normalized,
        },
      );
    }
  }

  int resolveCustomGroupMask() {
    var mask = 0;
    for (final group in bookGroups) {
      if (group.groupId > 0) {
        mask |= group.groupId;
      }
    }
    return mask;
  }
}
