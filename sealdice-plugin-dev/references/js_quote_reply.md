# 引用消息（回复）匹配模式

来自真实插件「加群验证」（`sealdice-js` 仓库，依赖 ob11 网络连接）的实现：
管理员**引用**机器人发出的某条消息，回复「同意 / 拒绝 / 取消」即可执行对应操作。
该模式可泛化为「引用某条消息触发操作」的通用写法。

## 匹配正则（onNotCommandReceived 中）

```js
const match = message.match(/^\[CQ:reply,id=(-?\d+)\]\s*(?:\[CQ:at,qq=\d+\])?\s*(.+)/);
if (match && !isNaN(match[1]) && match[2].trim()) {
  const msgId = parseInt(match[1]);
  const cmd = match[2].trim();
  switch (cmd) {
    case '同意':
    case 'ap':   // 批准
      break;
    case '拒绝':
    case 'dp':   // 拒绝
      break;
    case '取消':
    case 'cc':   // 取消验证
      break;
  }
}
```

规则：

- 消息**必须以回复 CQ 码开头**：`[CQ:reply,id=<消息ID>]`（OneBot v11 的引用消息格式）。
- 中间**可选**一个 `[CQ:at,qq=xxx]`（回复时顺带 @ 骰子）。
- 末尾是指令文本，`trim()` 后**精确匹配**（支持中英文别名）。
- 守卫条件：`!isNaN(match[1])` 且指令文本非空。

## 数据流（msgId 从哪来、怎么查）

1. 机器人发出提示消息并保存返回的 `message_id`。加群验证通过 ob11 依赖发送并取回：
   ```js
   // net.callApi(epId, 'send_group_msg', { group_id, message }) -> data.message_id
   reqMap[user_id] = { flag, sub_type, msgId };      // 加群请求条目
   vrfMap[user_id] = { timer, code, msgId };         // 加群验证条目
   ```
2. 收到引用消息后，用 `match[1]` 的 msgId **反查存储表**（`req.msgId === msgId`），
   命中则执行操作并删除条目；未命中 `console.warn('未找到回复 xxx 的...')`。

## 注意

- 要求回复码在消息**最开头**；平台若把引用渲染成其他段序则不会命中。
- 匹配的是 `msg.message` 的**文本 / CQ 码字符串**，不是结构化消息段数组。
- 找不到对应条目时显式告警，不要静默。
- 无引用场景应保留普通指令参数入口（如 `.agv ap <user_id>`）作为替代。
