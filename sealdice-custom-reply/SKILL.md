---
name: sealdice-custom-reply
description: 海豹（SealDice）自定义回复编写与调试助手。覆盖 WebUI 中创建/管理回复文件（YAML）、触发条件（文本匹配/文本长度/表达式为真）、回复结果（私聊/群内/延迟/随机多条）、公共条件、豹语脚本（执行块、变量、正则捕获组、DRAW 牌堆调用）、回复调试与文件分发。当用户要求编写/修改/调试海豹自定义回复、关键词自动回复、回复 YAML 文件、用 .text 测试回复、实现按条件自动回复或为海豹骰子配置自动应答时使用。
---

# SealDice 自定义回复

## 0. 先读哪份参考？

| 意图 | 参考文件 |
|---|---|
| WebUI 基本操作（开关/文件管理/添加回复项） | `references/config_reply.md` |
| 进阶编写（正则、豹语、复杂逻辑、限次、随机图） | `references/edit_reply.md` |
| 豹语语法（变量、执行块、if/三元、时间变量） | `references/script.md`、`../sealdice-plugin-dev/references/dicescript.md`（共用） |
| 立即可用的完整示例 | `assets/example-reply.yaml`（打卡示例） |
| 端到端测试 / 实测注意事项 | `scripts/test-reply.ps1`、`../sealdice-plugin-dev/references/test-notes.md`（共用） |

> 共用资源说明：豹语指导（dicescript.md）、端到端测试脚本（test-sealdice.ps1）与
> 实测注意事项（test-notes.md）统一存放在 `sealdice-plugin-dev`，本技能通过相对路径引用，
> 建议整套安装；修改共用资源时保持四类内容技能兼容。

## 1. 快速开始

1. WebUI「扩展功能 - 自定义回复」→ 打开页面左上角功能开关 → 同意许可协议。
2. 默认有一个 `reply.yaml` 回复文件，可直接编写；也可「新建」或「上传」 `.yaml` 文件。
3. 「添加一项」创建回复项：**条件**（什么时候触发）+ **结果**（怎么回复）。
4. 随时保存；编写时可勾选「开启回复调试日志」查看命中过程。
5. 用 `.text <文本>` 无触发词地测试输出（等价于免触发的自定义回复）。
6. 文件级「删除」不可找回，优先用「已启用」开关禁用代替删除。

## 2. YAML 文件结构（v1.6.0 源码验证：dice/ext_reply.go、ext_reply_logic.go）

```yaml
enable: true
interval: 0              # 文件级回复间隔（秒，小于 2 按 2 处理）
conditions: []           # 公共条件（v1.4.6+）：全部满足才检查本文件回复项
items:
  - enable: true
    conditions:          # 一个回复项可有多个条件，必须同时满足（AND）
      - condType: textMatch
        matchType: matchExact
        value: 打卡
    results:             # 多个结果从上到下依次执行（=发多条消息）
      - resultType: replyToSender
        delay: 0         # 延迟秒数，可小数
        message:
          - - |-         # 候选回复文本，随机抽一条
              {% if $m打卡!=$tDate {$t标记=1} else {$t标记=0} %}
              {$t输出}
            - 1          # 权重
name: 打卡.yaml
author:
  - 无名海豹
version: ""
desc: ""
```

## 3. 触发条件

- `textMatch`（condType=textMatch），matchType 取值（源码验证）：
  - `matchExact` 精准匹配；`matchMulti` 任意相符（`aa|bb` 任意命中）
  - `matchContains` 包含；`matchNotContains` 不含
  - `matchFuzzy` 模糊匹配（Jaro/Hamming 均值 > 0.7，不推荐依赖）
  - `matchRegex` 正则匹配（RE2 规范）；`matchPrefix` 前缀；`matchSuffix` 后缀
- `textLenLimit`（condType=textLenLimit）：`matchOp: ge|le` + `value` 字数；
  **汉字按 2 个字符计**。
- `exprTrue`（condType=exprTrue）：直接写 `$m变量 == 需要的值`，不需要 `{}`。
- 多个条件 = AND；文件级「公共条件」先行判断（v1.4.6+）。
- 触发词前缀避免使用 `.` `。` `/` `!`（会被识别为指令）。

## 4. 回复结果

- resultType 取值（v1.6.0 源码验证，dice/ext_reply_logic.go）：
  - `replyToSender` 直接回复发送者（最常用）
  - `replyPrivate` 私聊回复（强制私聊）
  - `replyGroup` 回群（强制群内回复）
  - `runText` 执行豹语表达式，等同 `.text` 但不发送消息
- 一个结果多条候选文本：随机抽取一条；`message` 第二项为该条权重。
- 多个 results 依次执行，几个结果就发几条消息。
- 文本支持：变量 `{$t玩家}`、掷骰 `{d100}`、执行块 `{% %}`、CQ 码、
  `#{DRAW-牌组名}` 调用牌堆。

## 5. 进阶要点

- 正则捕获组存进 `$t1` `$t2`…，完整匹配进 `$t0`，命名组 `(?P<A>cc)` 存 `$tA`；
  匹配 CQ 码记得转义：`^\[CQ:xxx,xx=xxx\]`。
- 豹语没有 `else if`：`if` 与 `else` 一对一配对；条件里的 `||` `&&` 从左到右，
  需要优先级就加括号。
- 三元写法：`判断 ? `值1`, 判断2 ? `值2`, 1 ? `兜底``。
- 限定每人/每群每天一次：用 `$tDate` 与 `$m变量`/`$g变量` 标记。
- 多行输出：把 `\n` 写进变量内部、回复中连写 `{$t输出0}{$t输出1}...`，避免空变量造成空行。
- 调试：`.text` 指令 + 「开启回复调试日志」；自动化验证用
  `scripts/test-reply.ps1`（内部调用共用的 test-sealdice.ps1）或
  sealdice-plugin-dev 的测试环境。

## 6. 分发与扩展包

- 分享：在回复文件下拉框「下载」该 `.yaml`，其他人「上传」导入。
- 社区：https://github.com/sealdice/reply
- 扩展包：把回复文件放进 `.sealpack` 的 `reply/` 目录（见 sealdice-sealpack 技能）。
- 指令：`.reply on|off` 开关本群自定义回复（等价 `.ext reply on|off`）。
