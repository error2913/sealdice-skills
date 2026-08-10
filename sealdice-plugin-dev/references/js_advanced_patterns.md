# JS 插件实战进阶模式（真实项目验证）

以下模式来自三个真实运行项目：`triangle-score-plugin`（单文件 JS）、
`sealdice-plugin-ob11-net-connection`（TS 工程模板 + esbuild）、
`sealdice-js`（单文件插件合集，作者「错误&白鱼」）。均已在海豹环境实际运行，
代码片段可作参考直接改写。

## 1. 热重载安全

海豹「重载 JS」会重新执行所有插件脚本，直接 `seal.ext.new` + `register` 会造成重复注册。
三件套保命：

1. **先 find 后 new**（见 SKILL.md §2）：
   ```js
   let ext = seal.ext.find('ext_name');
   if (!ext) {
     ext = seal.ext.new('ext_name', '作者', '1.0.0');
     seal.ext.register(ext);
   }
   ```
2. **常驻循环用全局标记**，防止热重载后 setInterval 叠加：
   ```js
   if (!globalThis.__myPluginLoopStarted) {
     globalThis.__myPluginLoopStarted = true;
     setInterval(tickLoop, 500);
     console.log('[' + ext.name + '] 0.5s 常驻循环已启动');
   }
   ```
3. **状态全部放 ext.storage**（只收字符串，复杂结构 JSON 序列化），常驻循环每次从
   存储读取：插件重载后循环继续跑、任务不丢；`onLoad` 打印恢复日志便于确认。
   ```js
   function loadJson(key, fallback) {
     try {
       const raw = ext.storageGet(key);
       if (!raw) return fallback;
       const o = JSON.parse(raw);
       return o && typeof o === 'object' ? o : fallback;
     } catch (e) { return fallback; }
   }
   ```
4. **配置项变更后清理旧键**：旧版本注册过、新版已删除的配置项会残留在 WebUI，
   用 `seal.ext.unregisterConfig` 清理（老版本没有该 API，需 try/catch 包住）：
   ```js
   try {
     seal.ext.unregisterConfig(ext, 'oldKey1', 'oldKey2');
   } catch (e) { /* 接口不支持或已清理时忽略 */ }
   ```

## 2. 主动发消息（无原始 ctx）

定时任务、事件回调里没有现成的 `ctx` 时，用临时端点 + 临时 ctx 主动群发：

```js
function sendGroup(gid, text) {
  const eps = seal.getEndPoints();
  if (!eps || eps.length === 0) return false;
  const ep = eps[0];                       // 多账号时按 platform/userId 挑选
  const m = seal.newMessage();
  m.messageType = 'group';
  m.platform = ep.platform;
  m.groupId = gid;
  m.sender.userId = ep.userId;             // 模拟机器人自己发消息
  const tempCtx = seal.createTempCtx(ep, m);
  seal.replyGroup(tempCtx, m, text);
  return true;
}
```

要点：`newMessage()` 返回海豹内部消息对象，需填 `messageType/platform/groupId`，
`sender.userId` 填端点账号；权限、冷却等逻辑与普通指令 ctx 一致。

## 3. fetch 超时（goja 没有 AbortController）

goja 环境的 `fetch` 不支持 `AbortController`，用 `Promise.race` + 定时器实现超时：

```js
function withTimeout(promise, ms) {
  return new Promise(function (resolve, reject) {
    const timer = setTimeout(function () {
      reject(new Error('请求超时（' + ms + 'ms）'));
    }, ms);
    promise.then(function (v) { clearTimeout(timer); resolve(v); },
                 function (e) { clearTimeout(timer); reject(e); });
  });
}
```

已知边界：超时只是提前让调用方收到错误，**底层请求无法真正中断**，会继续占用连接
直到服务端响应；对外部 API 长耗时请求（如 AI 识别）超时要设大（实战用 420000ms），
并提前告知用户「模型响应慢请等待」。

## 4. 插件内调用 MCP（Streamable HTTP）

插件直接当 MCP 客户端调用本机/远程 MCP Server（如 web-read 截图工具）的完整流程：

1. initialize（`POST {base}/mcp`），**必须带** `Accept: application/json, text/event-stream`；
   需要鉴权时加请求头（实战是 `X-Token`）：
   ```js
   const headers = {
     'Content-Type': 'application/json',
     'Accept': 'application/json, text/event-stream',
   };
   if (token) headers['X-Token'] = token;
   ```
2. **会话 ID 在响应头 `mcp-session-id`，不在 body 里**：
   ```js
   const initResp = await withTimeout(fetch(base + '/mcp', {
     method: 'POST', headers: headers,
     body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize',
       params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'seal-plugin', version: '1.0.0' } } }),
   }), 20000);
   const sid = initResp.headers.get('mcp-session-id') || '';
   await initResp.text();                 // 必须消费 body，否则后续请求可能挂起
   if (!sid) return null;
   ```
3. 后续请求带 `Mcp-Session-Id` 头：先发 `notifications/initialized`（无 id），再发
   `tools/call`（jsonrpc 2.0 + id）：
   ```js
   const h2 = Object.assign({}, headers, { 'Mcp-Session-Id': sid });
   await fetch(base + '/mcp', { method: 'POST', headers: h2,
     body: JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} }) });
   const callResp = await withTimeout(fetch(base + '/mcp', { method: 'POST', headers: h2,
     body: JSON.stringify({ jsonrpc: '2.0', id: 2, method: 'tools/call',
       params: { name: '工具名', arguments: { /* 工具参数 */ } } }) }), 90000);
   ```
4. 响应可能是**纯 JSON 或 SSE**（`event: message` + `data: {...}`），要两种都解析：
   ```js
   function parseMcpResult(text) {
     const t = String(text || '').trim();
     let obj = null;
     if (t.startsWith('{')) {
       try { obj = JSON.parse(t); } catch (e) { obj = null; }
     } else {
       for (const line of t.split('\n')) {
         if (line.indexOf('data:') === 0) {
           try {
             const parsed = JSON.parse(line.slice(5).trim());
             if (parsed && parsed.result) obj = parsed;
           } catch (e) { /* 忽略非 JSON 行 */ }
         }
       }
     }
     if (!obj || !obj.result) return null;
     const res = obj.result;
     if (res && res.content && Array.isArray(res.content)) {
       return res.content.map(function (c) { return c.text || ''; }).join('\n');
     }
     return JSON.stringify(res);
   }
   ```
5. 工具返回 base64（如截图）时用「纯 base64 字符 + 足够长」判定，避免把错误文本当图片：
   ```js
   if (resultText && /^[A-Za-z0-9+/=]+$/.test(resultText) && resultText.length > 100) {
     seal.replyToSender(ctx, msg, '[CQ:image,file=base64://' + resultText + ']');
   }
   ```

## 5. 跨插件 API（globalThis + @depends）

所有 JS 插件共享同一个 goja 全局环境，跨插件通信用 `globalThis`：

- 提供方：幂等暴露接口（热重载不重复覆盖），建议带 `name/version` 便于状态展示：
  ```js
  if (!globalThis.myPluginApi) {
    globalThis.myPluginApi = {
      name: 'my-plugin',
      version: '1.0.0',
      recognize(url) { /* ... */ },
    };
  }
  ```
- 使用方：**必须在元数据头声明依赖**，保证提供方先注册、缺失/版本不符时拒载：
  ```text
  // @depends 作者:提供方插件名:>=1.0.0
  ```
  注意作者名可含 `&` 等字符（实战有 `错误&白鱼:ob11网络连接依赖:>=2.1.0`），
  作者、插件名、版本之间始终用英文冒号分隔。
- 调用时仍要判空防御（依赖声明缺失、加载顺序异常、提供方被卸载时直接提示）：
  ```js
  const api = globalThis.imageRecognizerAPI;
  if (!api || typeof api.recognize !== 'function') {
    seal.replyToSender(ctx, msg, '未找到 xxx 接口（globalThis.xxx），请确认已加载提供方插件');
    return;
  }
  ```
- 命名空间要唯一，避免与第三方插件撞名；提供方热重载后 `globalThis` 引用会更新，
  使用方每次调用时**重新读取**，不要缓存旧引用。

## 6. 调用 ob11 网络连接依赖

QQ 环境的 OneBot 操作统一走 ob11 网络连接依赖插件暴露的 `globalThis.net`：

```js
const net = globalThis.net || globalThis.http;   // 兼容旧 HTTP 依赖
if (!net || typeof net.callApi !== 'function') {
  seal.replyToSender(ctx, msg, '未找到 ob11 网络连接依赖');
  return;
}
const data = await withTimeout(net.callApi(epId, 'send_group_msg',
  { group_id: gid, message: text }), 15000);
```

- `epId` 是端点 ID，格式 `<平台>:<账号>`（如 `QQ:12345`），从 `ctx.endPoint.userId`
  或 `seal.getEndPoints()` 取；多账号时用 `get_login_info` 返回的 user_id 与
  `seal.getEndPoints()` 匹配。
- **方法名兼容 query string 旧写法**：老插件写 `'get_group_list?no_cache=true'`，
  新实现要解析 query 合并进 data，两种调用方式都要支持：
  ```js
  net.callApi(epId, 'get_group_list?no_cache=true');
  net.callApi(epId, 'send_group_sign', { group_id: gid });
  ```
- 常用方法：`get_login_info` / `get_group_list` / `send_group_msg` /
  `send_group_sign` / `get_msg`（按 message_id 反查消息，返回消息段数组，image 段取
  `url` 优先、非 http 时再 `get_image`）/ `send_forward_msg`（合并转发，先构造
  `messages` 段数组 + `summary`/`preview`）。
- 权限判断用 `ctx.privilegeLevel`（≥50 群管理、≥100 群主/机器人管理员），无权限回
  `seal.formatTmpl(ctx, '核心:提示_无权限')`。

## 7. 真实 bug 教训（都是线上修复过的）

1. **空数组随机索引**：`arr[Math.floor(Math.random() * arr.length)]` 在 `arr.length === 0`
   时得到 `undefined` 并往下崩。随机取值前先判空：
   ```js
   if (!arr || arr.length === 0) return fallbackCode;  // 题库为空时回退自动生成
   ```
2. **失败/成功返回类型不一致**：`getQQLevel()` 失败 `return 0`、成功
   `return {qqLevel, nickname}`，调用方解构时直接崩。失败分支要返回同构对象：
   ```js
   return { qqLevel: 0, nickname: '未知' };
   ```
3. **日志对象不一定存在**：某些环境 `logger` 未定义，`logger.error(...)` 直接抛错；
   兜底用 `console.error`。
4. **删除调试残留**：上线前清理 `console.log(JSON.stringify(...))` 之类的调试输出。
5. **截图失败要显示 HTTP 状态码与响应内容预览**：只提示「截图失败」没法排查后端
   问题；返回非 200 时把状态码 + 前 120 字符响应体带出来。
6. **不要校验图片拍摄时间**：QQ 会清空图片 EXIF 时间，基于 EXIF 的上传校验上线后被
   revert；需要时间信息时应以消息时间或服务端记录为准。
7. **长耗时请求要提示用户**：AI 识别类接口响应可能长达数分钟，超时设大并回复
   「模型响应慢，请等待」，避免用户以为机器人挂了。

## 8. 无海豹环境 mock 测试

单文件插件可在 Node 里 mock `seal` / `fetch` / `globalThis.net` 跑核心逻辑，
提前发现加载期 ReferenceError/TypeError：

```js
// mock-test.js（Node 运行，不装海豹）
globalThis.seal = {
  ext: {
    find: () => null,
    new: () => ({ cmdMap: {}, onLoad() {} }),
    register() {},
    newCmdExecuteResult: (ok) => ({ ok }),
  },
  replyToSender(ctx, msg, text) { console.log('[回复]', text); },
  getEndPoints: () => [{ platform: 'QQ', userId: '12345' }],
  newMessage: () => ({ sender: {} }),
  createTempCtx: (ep, m) => ({ endPoint: ep }),
  replyGroup(ctx, m, text) { console.log('[群发]', m.groupId, text); },
};
globalThis.net = {
  async callApi(epId, method, data) { return { ok: true }; },
};
globalThis.fetch = async (url, opts) => new Response('{}', { status: 200 });
// 然后 require/执行被测插件，触发指令 solve 断言输出
```

工程模板自带 smoke 检查（用 seal 桩在 Node 加载 dist 产物），意义相同，见
`js_project.md`。
