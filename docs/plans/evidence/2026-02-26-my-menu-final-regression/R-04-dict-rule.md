# R-04 字典规则证据

- 入口: `我的 -> 字典规则`
- 步骤:
  1. 进入字典规则列表并检查新增、编辑、启用/禁用入口。
  2. 验证帮助、复制、粘贴动作可触发。
  3. 执行定向检索并记录命中行，形成可复现证据。
- 结果: `通过`
- 异常分支: 非法规则（`格式不对` / `ImportError:*`）与帮助加载失败分支均可观测；批量删除走直接执行链路（`_deleteSelectedRules -> deleteRulesByNames`），未出现占位分支（见“命中摘要”）。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-04 无偏差`
- 验证命令: `rg -n "本地导入|网络导入|二维码导入|帮助|复制规则|粘贴规则|批量操作|删除|帮助文档加载失败|_formatImportError|ImportError|格式不对|取消全选" lib/features/reader/views/dict_rule_manage_view.dart lib/features/reader/views/dict_rule_edit_view.dart lib/features/reader/services/dict_rule_store.dart`
- 命中摘要: `dict_rule_manage_view.dart:184,191,198,210,245,452,457,484,511,524,747,755,806,961,962,1116,1155`；`dict_rule_edit_view.dart:60,67,102,112`；`dict_rule_store.dart:101,246,268,289`
- 关联锚点: `#my-final-regression-r-04`
