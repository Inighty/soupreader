# R-02 TXT目录规则证据

- 入口: `我的 -> TXT目录规则`
- 步骤:
  1. 进入规则列表并检查新增、编辑、启用/禁用入口。
  2. 验证帮助、复制、粘贴等关键动作可达。
  3. 执行定向检索并记录命中行，形成可复现证据。
- 结果: `通过`
- 异常分支: 非法规则（`格式不对`）、导入异常（`_formatImportError`）与帮助加载失败分支均可观测，删除存在取消/确认双分支（见“命中摘要”）。
- 处理动作: `维持现状|通过|owner:MY-19|截止:2026-02-26|状态:已完成|R-02 无偏差`
- 验证命令: `rg -n "本地导入|网络导入|二维码导入|帮助|复制规则|粘贴规则|批量操作|是否确认删除|帮助文档加载失败|_formatImportError|格式不对" lib/features/reader/views/txt_toc_rule_manage_view.dart lib/features/reader/views/txt_toc_rule_edit_view.dart lib/features/reader/services/txt_toc_rule_store.dart`
- 命中摘要: `txt_toc_rule_manage_view.dart:170,177,182,194,229,331,383,623,650,677,690,1114,1115,1120`；`txt_toc_rule_edit_view.dart:58,65,100,110`；`txt_toc_rule_store.dart:211,289,311,332`
- 关联锚点: `#my-final-regression-r-02`
