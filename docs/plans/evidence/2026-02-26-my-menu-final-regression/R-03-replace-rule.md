# R-03 替换净化证据

- 入口: `我的 -> 替换净化`
- 步骤:
  1. 进入替换规则列表并检查新增、编辑、启用/禁用入口。
  2. 验证帮助、复制、粘贴动作可触发。
  3. 执行定向检索并记录命中行，形成可复现证据。
- 结果: `通过`
- 异常分支: 非法规则（`格式不对` / `ImportError:*`）、帮助加载失败与删除取消/确认分支均可观测，分组筛选链路可达（见“命中摘要”）。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-03 无偏差`
- 验证命令: `rg -n "本地导入|网络导入|二维码导入|帮助|复制规则|粘贴规则|批量操作|是否确认删除|帮助文档加载失败|_formatImportError|ImportError|格式不对|分组" lib/features/replace/views/replace_rule_list_view.dart lib/features/replace/views/replace_rule_edit_view.dart lib/core/database/repositories/replace_rule_repository.dart`
- 命中摘要: `replace_rule_list_view.dart:387,394,797,804,811,818,890,923,999,1218,1246,1274,1289,1664,2024`；`replace_rule_edit_view.dart:182,189,229,257,320`；`replace_rule_list_view.dart:35,447,459,520,571,2149`
- 关联锚点: `#my-final-regression-r-03`
