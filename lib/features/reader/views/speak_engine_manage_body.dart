import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../models/http_tts_rule.dart';

/// 朗读引擎管理页的主体布局。
///
/// 渲染「系统引擎」 + 「HTTP 朗读引擎」两个分组，依据 [loading] /
/// [rules] / [selectedRuleId] 自动切换加载态、空态、列表态。
class SpeakEngineManageBody extends StatelessWidget {
  const SpeakEngineManageBody({
    super.key,
    required this.loading,
    required this.rules,
    required this.selectedRuleId,
    required this.onSelectRule,
    required this.onEditRule,
    required this.onDeleteRule,
  });

  final bool loading;
  final List<HttpTtsRule> rules;
  final int? selectedRuleId;
  final ValueChanged<int?> onSelectRule;
  final ValueChanged<HttpTtsRule> onEditRule;
  final ValueChanged<HttpTtsRule> onDeleteRule;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final tokens = AppUiTokens.resolve(context);
    return AppListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        _buildSectionHeader(tokens, '系统引擎'),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppListTile(
            title: const Text('系统默认'),
            subtitle: const Text('跟随设备 TTS 设置'),
            showChevron: false,
            onTap: () => onSelectRule(null),
            additionalInfo: selectedRuleId == null
                ? Icon(
                    CupertinoIcons.checkmark_alt,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                    size: 18,
                  )
                : null,
          ),
        ),
        if (rules.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: AppEmptyState(
              illustration: AppEmptyPlanetIllustration(size: 86),
              title: '暂无规则',
              message: '点击右上角添加，或从更多菜单导入默认规则。',
            ),
          )
        else
          _buildRuleSection(context, tokens),
      ],
    );
  }

  Widget _buildRuleSection(BuildContext context, AppUiTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _buildSectionHeader(tokens, 'HTTP 朗读引擎'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rules.length; i++) ...[
                _buildRuleTile(context, rules[i]),
                if (i < rules.length - 1) _buildDivider(tokens),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuleTile(BuildContext context, HttpTtsRule rule) {
    final fallbackTitle = rule.url.trim().isEmpty ? '未命名引擎' : rule.url.trim();
    final title = rule.name.trim().isEmpty ? fallbackTitle : rule.name.trim();
    final subtitle = rule.url.trim().isEmpty ? '未配置 URL' : rule.url.trim();
    final isSelected = selectedRuleId == rule.id;
    return AppListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      additionalInfo: isSelected
          ? Icon(
              CupertinoIcons.checkmark_alt,
              color: CupertinoColors.activeBlue.resolveFrom(context),
              size: 18,
            )
          : rule.isDefaultRule
              ? const Text('默认')
              : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(36, 36),
            onPressed: () => onEditRule(rule),
            child: Icon(
              CupertinoIcons.pencil,
              size: 18,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(left: 2, right: 2),
            minimumSize: const Size(36, 36),
            onPressed: () => onDeleteRule(rule),
            child: Icon(
              CupertinoIcons.delete,
              size: 18,
              color: CupertinoColors.destructiveRed.resolveFrom(context),
            ),
          ),
        ],
      ),
      showChevron: false,
      onTap: () => onSelectRule(rule.id),
    );
  }

  Widget _buildSectionHeader(AppUiTokens tokens, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: tokens.colors.secondaryLabel,
        ),
      ),
    );
  }

  Widget _buildDivider(AppUiTokens tokens) {
    return Container(
      height: tokens.sizes.dividerThickness,
      color: tokens.colors.separator.withValues(alpha: 0.72),
    );
  }
}
