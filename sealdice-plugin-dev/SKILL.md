---
name: sealdice-plugin-dev
description: 海豹（SealDice）JS 插件/扩展开发与测试助手。覆盖两种开发方式：单文件 JS 插件编写，以及基于 sealdice-js-ext-template 的 TypeScript 工程模板编写；并覆盖测试环境搭建：从 GitHub releases 下载并运行海豹核心、WebUI 辅助工具-指令测试、连接指定 WebUI（含面板自动化）、QQ 环境测试（qqmcp）。当用户要求编写/开发/修改/测试海豹 JS 插件或 .ext 扩展、使用 seal.d.ts/goja/海豹 API、搭建海豹测试环境、进行指令测试、连接海豹 WebUI 或使用 qqmcp 做 QQ 群验证时使用。
---

# SealDice 插件开发与测试

## 0. 决策：用户想做什么？

| 用户意图 | 进入 | 参考文件 |
|---|---|---|
| 快速写一个最小 JS 插件 | §2 单文件 | `assets/plugin-template.js`、`references/js_start.md` |
| 大型插件 / TypeScript 工程化 | §3 工程模板 | `references/js_project.md` |
| 查某个 `seal.*` API | §5 API 速查 | `references/seal.d.ts`（最权威）、`references/js_api_list.md` |
| 参考实战写法（HTTP、图片、长流程等） | §5 | `references/js_example.md` |
| 引用消息（回复）匹配与操作 | §5 | `references/js_quote_reply.md` |
| 自定义规则模板（GameSystem） | §5 | `references/js_gamesystem.md` |
| 搭建测试环境 / 指令测试 / 连接 WebUI / QQ 验证 | §4 | `references/test-environment.md` |
| 安装 QQ-MCP / Chrome DevTools MCP（Chrome/Edge） | §4 | `references/mcp-setup.md` |
| 端到端测试脚本（安装/重载/日志/配置/删除/指令测试） | §4 | `scripts/test-sealdice.ps1`、`scripts/screenshot.ps1` |
| WebUI 中如何管理 JS 插件 | §4 | `references/config_jsscript.md` |
| 编写自定义回复（关键词自动回复） | 其他技能 | `sealdice-custom-reply` |
| 编写牌堆 / 抽牌内容 | 其他技能 | `sealdice-deck` |
| 手动打包 / 发布扩展包（.sealpack） | 其他技能 | `sealdice-sealpack` |
| 修改自定义文案（WebUI/API） | 其他技能 | `sealdice-custom-text` |
| 跨插件暴露 / 调用 API | §2.11 | 本节（globalThis 模式） |

不确定时：先读 `references/introduce.md` + `references/js_start.md`。

## 1. 运行环境（先告诉用户的事实）

- 引擎是 [goja](https://github.com/dop251/goja)，不是 Node、不是浏览器；支持 ES6 几乎全部特性（async/await、Promise、generator）。
- 整型 32 位，注意溢出：`Date.now()` 等大数不要塞进 `seal.vars.intSet`，改用字符串。
- 海豹注入的全局：`seal`（全部海豹 API）、`console`、`setTimeout/setInterval`、`fetch`、`atob/btoa`。
- 不支持 Node 模块、`require`、`process`、`fs`、DOM。
- 工程化方式（TypeScript 编译为 ES6 单文件）与单文件 JS 功能无差异，仅工程便利度不同。

术语约定（本套技能统一）：WebUI 页面名「JS 扩展」与「JS 插件」同义；「扩展包」是
`.sealpack` 的正式名称，「豹包」是俗称；牌堆=文件，牌组=可抽取项，牌堆项=其中一条内容。

通用性：本套技能面向任意 AI 编码代理（Codex / Claude / Cursor 等），脚本与 API 用法
不绑定特定代理；MCP 注册章节以 Codex 配置为例，其他客户端的配置见 `references/mcp-setup.md`。

## 2. 方式一：单文件 JS 插件

直接复制 `assets/plugin-template.js` 作为骨架，然后：

1. 改元数据头（`// ==UserScript==`）：`@name`、`@author`、`@version` 必填；可选
   `@description`、`@timestamp`（unix 秒或 YYYY-MM-DD）、`@license`、`@homepageURL`、
   `@depends`（`作者:插件名[:版本约束]`，可多行）、`@sealVersion`（目标海豹版本）、
   `@updateUrl`（更新链接，可多行）、`@etag`。注意：`@depends`/`@updateUrl` 示例
   不要原样保留，`@depends` 指向不存在的插件会导致拒载。
2. 扩展注册三件套（热重载安全，务必先 find 后 new）：
   ```js
   let ext = seal.ext.find('ext_name');
   if (!ext) {
     ext = seal.ext.new('ext_name', '作者', '1.0.0');
     seal.ext.register(ext);
   }
   ```
3. 写指令：`ext.cmdMap['xxx'] = cmd`；`cmd.solve` 必须返回 `seal.ext.newCmdExecuteResult(true)`；`cmd.help` 多行用 `\n`；别名（中英）指向**同一个对象引用**，不要复制。
4. 子指令：用 `cmdArgs.getArgN(1)`（**1-based**）做 switch 分发；参数 `-xx=yy` 用 `getKwarg('xx')`。
5. 代骰：`const targetCtx = seal.getCtxProxyFirst(ctx, cmdArgs)`，后续业务一律用 `targetCtx`。
6. 回复：`seal.replyToSender(ctx, msg, text)`（最常用）、`replyGroup`、`replyPerson`；模板 `seal.format(ctx, text)`。
7. 事件钩子：`onLoad` / `onMessageReceived` / `onNotCommandReceived`（常用于关键词回复）/ `onMessageSend` / `onCommandReceived`。
8. 配置项：`seal.ext.registerStringConfig/IntConfig/FloatConfig/BoolConfig/TemplateConfig/OptionConfig`，读取对应 `getXxxConfig(ext, key)`；全部出现在 WebUI「插件设置」。
9. 持久化：`ext.storageSet(key, string)` / `storageGet(key)`，**只接受字符串**，复杂结构用 `JSON.stringify/parse`。
10. 定时任务：`seal.ext.registerTask(ext, 'daily', '08:30', fn, 'key', '描述')` 或 `cron`（5 位表达式）。

11. 跨插件暴露 API：所有 JS 插件共享同一个 goja 全局环境，用 `globalThis` 暴露接口，
    供其他插件调用（幂等，热重载不重复覆盖）：
    ```js
    // 提供方：暴露
    if (!globalThis.myPluginApi) {
      globalThis.myPluginApi = {
        name: 'my-plugin',
        version: '1.0.0',
        hello(name) { return `你好，${name}`; },
      };
    }
    // 使用方：在插件元数据头声明依赖（保证提供方先加载，缺失/版本不符时拒载本插件）
    // // @depends 作者:提供方插件名:>=1.0.0
    const api = globalThis.myPluginApi;
    if (!api) return;   // 防御性判空（例如依赖声明缺失或版本不符时）
    const text = api.hello('世界');
    ```
    注意：命名空间要唯一（避免通用名冲突）；使用方必须在 header 里声明
    `// @depends 作者:插件名[:版本约束]`（可多行，AND），海豹会保证提供方先注册、
    缺失或版本不符时拒绝加载本插件；调用时仍建议判空做防御；提供方热重载后
    `globalThis` 上的引用会更新，使用方每次调用时重新读取。

12. 更新链接（放在 git 仓库时）：在元数据头写 `// @updateUrl <URL>`（可多行，海豹
    会从上到下逐一检查更新）。git 仓库用 **raw 文件直链**，保证 URL 直接返回 JS 文件
    内容，例如：
    ```text
    // @updateUrl https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>/plugin.js
    ```
    WebUI 插件卡片的「更新」按钮会拉取最新内容并展示差异（对应 API：
    `POST /js/check_update` + `POST /js/update`），确认后替换并重载；可选 `@etag`
    用于 HTTP 304 缓存协商。

常见陷阱：热重载重复注册（永远先 find）；`getArgN` 1-based；storage 只收字符串；别名复制对象导致回调丢失；私聊/群 ctx 不同，跨群发消息用 `seal.createTempCtx`；fetch 是异步的，结果用 `replyToSender` 后续推送；goja 无 DOM，npm 包先验证。

## 3. 方式二：TypeScript 工程模板

1. `git clone https://github.com/sealdice/sealdice-js-ext-template`（或用 Use this template 建仓库）。
2. 必改信息：`tools/build-config.js` 开头的 `filename`（决定产物名）、`package.json` 的 `version`（版本唯一来源）、`header.txt` 元数据头、`sealpack/info.toml`（扩展包/豹包元数据）。
3. `npm install` → 代码写在 `src/index.ts` → `npm run build`，产物在 `dist/<filename>.js`（默认 `sealdice-js-ext.js`）。
4. 开发检查：`npm run check` = lint + typecheck（`tsc --noEmit --strict`）+ build + smoke（用 seal 桩在 Node 加载产物，提前发现加载期 ReferenceError/TypeError）。
5. 可引用 npm 包（模板自带 lodash-es），优先 ESM；强 native 依赖的包可能不兼容 goja。
6. `types/seal.d.ts` 有更新时去模板仓库拉最新替换；缺 API 可在本地补声明。
7. 发布（可选）：`npm run package:check` → `npm run pack:sealpack` / `pack:release`；推 tag `v<版本>` 自动触发 CI 发布到海豹商店。

详细流程见 `references/js_project.md`。

## 4. 搭建测试环境（下载海豹 / WebUI / 指定 WebUI / QQ）

### 4.0 测试前确认（已配置则直接使用，不重复询问）

动手前先检查是否已有可用配置：

1. 用**全新海豹实例**测试，还是连接**现有 WebUI**？若已有 `SEALDICE_PANEL_URL` /
   `SEALDICE_PANEL_PASSWORD` 环境变量，或 `sealdice-plugin-dev/.env`
   （模板 `.env.example`，含 WebUI 地址/密码、ws 地址/token），或本会话已提供
   地址/密码，直接使用现有 WebUI。
2. 现有 WebUI：地址（如 `http://host:3211`）与解锁密码**未配置时**才向用户索取。
3. QQ 环境（qqmcp）：若 `QQ-MCP-Server` 已注册（MCP 工具可用），或 qqmcp `.env`
   / `sealdice-plugin-dev/.env` 已有 `NAPCAT_BASE_URL` / `NAPCAT_ACCESS_TOKEN`，
   直接使用；**未配置时**才向用户索取 NapCat WebSocket 地址与访问 token。

完整流程与命令见 `references/test-environment.md`。要点：

### 4.1 下载并运行海豹核心

- GitHub Releases：https://github.com/sealdice/sealdice-build/releases
  - 正式版（推荐）：如 `v1.6.0`，Windows 资产 `sealdice-core_1.6.0_windows_amd64.zip`（按平台选择）。
  - 尝鲜版：`Latest Dev Build+日期`，可能有 Bug。
- 解压到合适目录（勿直接运行压缩包内程序、勿放 Program Files），双击 `sealdice-core.exe`。
- WebUI 默认 `http://127.0.0.1:3211`，需设置/输入解锁密码。

### 4.2 WebUI 测试

- `扩展功能 → JS 扩展`（路由 `#/mod/js`）：控制台（直接执行代码片段，无需上传插件）、插件列表（上传/启用/删除/更新）、「重载 JS」使改动生效。
- **重载 JS 影响所有 JS 插件**，属写操作：两次重载间隔必须 ≥ 1 分钟。
- `辅助工具 → 指令测试`（`#/tool/test`）：模拟消息走完整链路，无需真实 IM。
  - 私聊模式：用户 ID `UI:1001`。
  - 群聊模式（v1.4.6+）：群 `UI-Group:2001`、用户 `UI:1002`（群主权限）。
  - 指令测试中产生的角色卡等数据保留；消息记录随刷新丢失。
- 日志：`console.log` 进调试控制台 + 日志；fetch/setTimeout 异步结果只保证出现在日志文件。

### 4.3 连接指定的 WebUI 测试

- 手工：浏览器打开 `http://<host>:3211` → 解锁 → `#/mod/js` 上传/重载 → 指令测试或真实平台验证。
- 接口：`POST /sd-api/signin` 拿 token，后续请求带 `authorization` 与 `token` 两个头；日志 `GET /sd-api/log/fetchAndClear`（会清空缓冲）。
- 自动化（可选）：安装 Chrome DevTools MCP（支持 Chrome / Edge）后，可直接驱动浏览器
  完成解锁、上传、重载、截图与日志读取；详细安装与配置见 `references/mcp-setup.md`。

### 4.4 QQ 环境测试（qqmcp）

- 架构：Codex(MCP 客户端) → QQ-MCP-Server(`:8888/mcp`) → NapCatQQ OneBot → QQ。
- 工具：`qq_send_group_message` 发指令（支持 CQ 码）、`qq_get_group_messages` 轮询回复、`qq_get_group_members` 确认机器人、`qq_get_bot_status` 预检。
- 流程：预检 → 发送并记录时间 → 每 2~3 秒轮询（最长 45 秒）→ 按 `user_id`+时间过滤机器人回复 → 关键字子串断言。
- 纪律：相邻指令 ≥ 3 秒、每 5 条暂停 10 秒、群里少发（以验证连通为主）、破坏性操作先获用户确认。
- 详细安装（源码、.env、注册 Codex、验证）见 `references/mcp-setup.md`。

### 4.5 一键端到端测试

`scripts/test-sealdice.ps1` 可对本地/远程实例跑完整回归：
JS 插件（安装/重载/配置查看修改/指令测试/日志/删除）、自定义回复、牌堆、自定义文案、
扩展包安装。用法：

```powershell
.\scripts\test-sealdice.ps1 -BaseUrl http://127.0.0.1:3211 -Only all
```

截图用 `scripts/screenshot.ps1`（Edge/Chrome 无头模式）。实测结论与踩坑见
`references/test-notes.md`。

共用资源说明：本技能的 `references/dicescript.md`（豹语）、`references/test-notes.md`
（实测坑）、`scripts/test-sealdice.ps1` / `screenshot.ps1`（测试脚本）被
`sealdice-custom-reply` / `sealdice-deck` / `sealdice-sealpack` / `sealdice-custom-text`
共用（相对路径引用），修改时需保持兼容。

## 5. API 速查

权威来源：`references/seal.d.ts`（全文 grep）；平铺列表 `references/js_api_list.md`；实战例子 `references/js_example.md`。

- 消息/回复：`seal.replyToSender(ctx, msg, text)`、`replyGroup`、`replyPerson`、`seal.format(ctx, text)`、`seal.formatTmpl(ctx, 'COC:检定_失败')`
- 指令参数：`cmdArgs.getArgN(1)`（1-based）、`getKwarg('xx')`、`cmdArgs.at`、`seal.getCtxProxyFirst(ctx, cmdArgs)`、`seal.getCtxProxyAtPos(ctx, cmdArgs, 0)`
- 玩家变量（豹语 `$XXX` 双向打通）：`seal.vars.intGet/intSet/strGet/strSet`，返回 `[value, ok]`
- 扩展持久化：`ext.storageSet/Get`（仅字符串）
- 配置项：6 种 `registerXxxConfig` / `getXxxConfig` 一一对应
- 定时任务：`seal.ext.registerTask(ext, 'daily'|'cron', ...)`
- 黑白名单：`seal.ban.addBan/addTrust/remove/getList/getUser`（rank：-30 禁 / -10 警告 / 0 正常 / 30 信任）
- 群名片：`seal.applyPlayerGroupCardByTemplate` / `setPlayerGroupCard`
- 牌堆：`seal.deck.draw(ctx, '堆名', true)`、`seal.deck.reload()`
- 主动发消息：`seal.getEndPoints()[0]` + `seal.newMessage()` + `seal.createTempCtx(ep, msg)` + `seal.replyGroup`
- 其他：`seal.getVersion()`、`seal.base64ToImage(b64)`、`fetch`、`setTimeout`

## 6. 调试与排错

1. 加载失败/指令没注册：读日志；确认 `seal.ext.register(ext)` 已调用、元数据头完整、`@sealVersion` 与当前海豹兼容。
2. 热重载后指令重复注册：改用 `seal.ext.find` 复用。
3. 变量类型不匹配：`intGet` 拿到字符串时 `ok=false`。
4. 异步不回复：fetch 回调里用 `replyToSender` 推送；以日志文件为准排查。
5. 依赖其他扩展：`@depends` 格式 `作者:插件名[:>=1.0.0]`，目标必须先注册。

## 7. 参考文件索引

| 文件 | 内容 |
|---|---|
| `references/test-environment.md` | 测试环境完整流程（下载海豹 / WebUI / 指定 WebUI / qqmcp） |
| `references/mcp-setup.md` | QQ-MCP 与 Chrome DevTools MCP（Chrome/Edge）详细安装与配置 |
| `references/dicescript.md` | 豹语（DiceScript）语法与四类内容编写指导 |
| `references/test-notes.md` | 端到端实测结论与踩坑记录 |
| `references/js_start.md` | 单文件 JS 入门（元数据、最小示例、依赖与版本） |
| `references/js_project.md` | TypeScript 工程模板 |
| `references/js_example.md` | 1300+ 行实战示例（HTTP、图片、跨群联动、长流程） |
| `references/js_api_list.md` | 平铺式 API 列表 |
| `references/seal.d.ts` | 类型定义（最权威 API 索引） |
| `references/js_quote_reply.md` | 引用消息（`[CQ:reply,id=...]`）匹配模式实战 |
| `references/js_gamesystem.md` | 自定义规则模板 |
| `references/config_jsscript.md` | WebUI JS 插件管理 |
| `references/introduce.md` | 官方进阶章节总览 |
| `assets/plugin-template.js` | 立即可用的单文件插件骨架 |

范围说明：自定义文案/帮助文档/敏感词等 WebUI 内容资产不在本技能范围，需要时查官方手册
config 章节；自定义回复、牌堆、扩展包打包分别使用 `sealdice-custom-reply`、
`sealdice-deck`、`sealdice-sealpack` 技能。
