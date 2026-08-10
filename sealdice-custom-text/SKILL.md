---
name: sealdice-custom-text
description: 海豹（SealDice）自定义文案修改与调试助手。覆盖 WebUI「自定义文案」的分类/条目/筛选/导入导出/重置，文案模板（豹语变量、嵌套调用、图片与 CQ 码、DRAW 牌堆引用），以及通过 WebUI 后端 API（/sd-api/configs/customText）实际读取、修改、验证与恢复文案。当用户要求修改海豹固定回复词、调整骰子人设文案、编辑自定义文案、通过 WebUI/API 改文案或排查文案不生效时使用。
---

# SealDice 自定义文案

## 0. 参考

| 意图 | 参考文件 |
|---|---|
| WebUI 操作（分类/筛选/导入导出/重置） | `references/config_custom_text.md` |
| 复杂文案与嵌套规则 | `references/edit_complex_custom_text.md` |
| 豹语变量与语法（$t/$m/$g、执行块） | `references/script.md`、`../sealdice-plugin-dev/references/dicescript.md`（共用） |
| 修改并验证（API 方式，实测可用） | `scripts/edit-custom-text.ps1` |
| 文案回归测试 / 实测注意事项 | `../sealdice-plugin-dev/scripts/test-sealdice.ps1`（-Only text）、`../sealdice-plugin-dev/references/test-notes.md`（共用） |

> 共用资源说明：豹语指导、端到端测试脚本与实测注意事项统一存放在 `sealdice-plugin-dev`，
> 本技能通过相对路径引用，建议整套安装。

## 1. 概念

- 自定义文案是海豹大部分固定回复（检定、制卡、暗骰、进群问候等）的文本模板，
  按大类组织：CoC / DND / 其它 / 功能 / 日志 / 核心。
- 每条文案是 `string[]`（多条随机抽取），可含权重（`%50%回复A`）与豹语表达式。
- 文案模板可嵌套调用其他文案：`{核心:骰子名字}`、`{$t判定结果}`。
- 支持变量插值 `{$t玩家}`、掷骰 `{d100}`、图片 `[图:data/images/x.png]`、
  CQ 码与牌堆引用 `#{DRAW-牌组名}`。
- 禁止递归嵌套文案。

## 2. WebUI 修改（打开后台实际操作）

1. WebUI「自定义文案」→ 左侧选大类（CoC/DND/其它/功能/日志/核心）。
2. 右侧「文案列表」用筛选定位条目（搜索/修改过/旧版文案等）。
3. 点条目左侧「加号」增加一行、点「删除」移除一行（至少保留一行）。
4. **及时保存，保存前不要切换左侧分类**（未保存修改会丢失）。
5. 右上角「刷子」可重置为初始设置；「导入/导出」可复制粘贴分享。
6. 验证：在指令测试中触发对应指令，或直接看回复。

## 3. API 修改（脚本方式，可被任意 agent 执行）

实测可用的接口（v1.6.0）：

- 读取：`GET /sd-api/configs/customText`，返回 `{texts, helpInfo, previewInfo}`。
  `texts` 结构：分类 → 条目 → origin 数组 `[["文本",权重], ...]`
  （对象详情在 `previewInfo`，注意区分）。
- 保存：`POST /sd-api/configs/customText/save`，body
  `{"category":"COC","data":{"判定_大失败":[["大失败！",1]]}}`。
  **保存会整类覆盖**，必须回传整类所有条目。
- 预览刷新：`POST /sd-api/configs/customText/preview-refresh`（body `{"category"}`）。

直接运行 [scripts/edit-custom-text.ps1](scripts/edit-custom-text.ps1) 即可
读取→修改→验证→恢复：

```powershell
.\scripts\edit-custom-text.ps1 -BaseUrl http://127.0.0.1:3211 -Category COC -Key 判定_大失败 -NewText "新的文案内容"
```

## 4. 常见问题

- 修改不生效：检查是否保存；`preview-refresh` 或重载 JS。
- 文案显示为空/0：变量未赋值默认 0；检查 `{变量名}` 拼写与豹语语法。
- 导入旧版文案可能缺条目：不要跨大版本导入。
- 想按逻辑分支输出：用豹语执行块 `{% if ... %}`（见 script.md）。

## 5. 参考文件

| 文件 | 内容 |
|---|---|
| `references/config_custom_text.md` | WebUI 完整操作手册 |
| `references/edit_complex_custom_text.md` | 复杂文案进阶 |
| `references/script.md` | 豹语变量与脚本语法 |
| `scripts/edit-custom-text.ps1` | 读取/修改/验证/恢复文案的脚本 |
| `../sealdice-plugin-dev/references/dicescript.md` | 豹语（DiceScript）语法（共用） |
| `../sealdice-plugin-dev/references/test-notes.md` | 实测注意事项（共用） |
