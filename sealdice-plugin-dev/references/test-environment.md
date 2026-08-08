# 测试环境搭建与验证（SealDice）

> 目标：在不需要真实 IM 平台的情况下快速验证插件；需要平台级验证时再连真实 WebUI / QQ。

## 0. 测试前确认（已配置则直接使用，不重复询问）

动手前先检查是否已有配置，**已配置不再询问**，未配置才向用户索取：

1. 全新实例 vs 现有 WebUI：若已有 `SEALDICE_PANEL_URL` / `SEALDICE_PANEL_PASSWORD`
   环境变量，或技能目录 `sealdice-plugin-dev/.env`（模板见 `.env.example`）、或本会话
   已提供地址/密码，直接使用现有 WebUI；否则询问用户。
2. 现有 WebUI：向用户索取地址（如 `http://host:3211`）与解锁密码，
   对应脚本参数 `-BaseUrl <地址> -Password <密码>`。
3. qqmcp：若 `~/.codex/config.toml` 已注册 `QQ-MCP-Server`（MCP 工具可用），或
   qqmcp 项目 `.env` / `sealdice-plugin-dev/.env` 已有 `NAPCAT_BASE_URL` /
   `NAPCAT_ACCESS_TOKEN`，直接使用；否则向用户索取 NapCat WebSocket 地址与访问
   token，写入 `.env`。

`.env` 字段：`SEALDICE_PANEL_URL`（WebUI 地址含端口）、`SEALDICE_PANEL_PASSWORD`
（解锁密码）、`NAPCAT_BASE_URL`（ws 地址）、`NAPCAT_ACCESS_TOKEN`（token）；
复制 `sealdice-plugin-dev/.env.example` 为 `.env` 填写即可，`.env` 不提交。
`test-sealdice.ps1` / `edit-custom-text.ps1` 会自动读取前两项。

## 1. 下载并运行海豹核心

渠道（二选一，正式版优先）：

- GitHub Releases：<https://github.com/sealdice/sealdice-build/releases>
  - 正式版：以 `版本号+日期` 命名，如 `v1.6.0`，Windows 资产为
    `sealdice-core_1.6.0_windows_amd64.zip`（另有 linux/macOS/Android 资产）。
  - 尝鲜版：`Latest Dev Build+日期`，可能有 Bug，仅用于验证新 API。
- 官网下载页：<https://dice.weizaima.com/download>

启动要点：

1. 解压到合适的目录（不要直接运行压缩包内的程序，不要放在 Program Files 等
   高权限目录）。
2. Windows 双击 `sealdice-core.exe`，数秒后托盘出现海豹图标，点击打开后台。
3. WebUI 默认地址：`http://127.0.0.1:3211`。
4. 首次进入按提示设置解锁密码；之后进入需输入密码。

## 2. WebUI 基本操作（与插件开发相关）

### JS 扩展页（`扩展功能 → JS 扩展`，路由 `#/mod/js`）

- 页签：`控制台` / `插件列表` / `插件设置`。
- 插件列表：每张插件卡片可单独启用/停用；「上传插件」选择 JS 文件；
  「重载 JS」使上传/修改生效（**影响所有 JS 插件**，是写操作）。
- 控制台：写代码片段点「执行代码」即可运行，适合快速验证 API 调用，无需上传插件。
- 插件设置：`seal.ext.registerXxxConfig` 注册的配置项显示在这里，改后需保存。

修改插件的标准流程：

1. 上传插件文件（或在控制台执行代码）；
2. 点击「重载 JS」；
3. 等待数秒；
4. 在主页日志或「指令测试」中验证行为；异常时读日志定位。

### 日志

- `console.log/info/warn/error` 同时写入 WebUI 调试控制台和日志文件。
- `fetch` / `setTimeout` 等异步内容可能不出现在控制台面板，但会出现在日志中
  （主页内嵌日志）。
- 日志接口：解锁后 `GET /sd-api/log/fetchAndClear`（带 `authorization` 与 `token`
  请求头，值相同）；该接口会清空服务端缓冲，避免在页面之外反复调用。

## 3. 辅助工具 → 指令测试（最常用的本地测试方式）

入口：`WebUI → 辅助工具 → 指令测试`（路由 `#/tool/test`；v1.4.6 起与资源管理
同属辅助工具）。

原理：直接模拟海豹核心收到一条消息，走完整指令/事件链路，无需连接任何 IM 平台。

用法：

- 右上角切换「私聊」或「群」模式（v1.4.6+；旧版只能模拟私聊）。
- 私聊模式：你的用户 ID 固定为 `UI:1001`。
- 群聊模式：虚拟群 ID 为 `UI-Group:2001`，你的用户 ID 为 `UI:1002`，
  且在该群拥有群主权限。
- 输入消息（如 `.fortune` 或 `.seal 阿伟`），点发送，观察回复与日志。

注意事项：

- 指令测试中产生的角色卡等数据会被保留；消息记录会随页面刷新丢失。
- 适合验证：指令分发、子指令、代骰、@解析、回复、配置项读取、事件钩子。
- 不适合验证：定时任务、跨群主动消息、真实平台特有行为（QQ @ 渲染、CQ 码等）。

## 4. 连接指定的 WebUI 测试

场景：已有部署好的海豹（本地/远程/Docker/测试服），或需要在现有海豹实例上验证。

### 手工方式

1. 访问 `http://<host>:3211`，输入密码解锁。
2. `#/mod/js` 上传插件 → 重载 JS → 等数秒 → 查看日志。
3. 用「辅助工具 → 指令测试」验证，或直接在真实平台发消息验证。

### 接口 / 自动化方式

- 鉴权：`POST /sd-api/signin` 换取 token；后续所有 `/sd-api/*` 请求带
  `authorization` 与 `token` 两个请求头（值相同）。
- 日志：`GET /sd-api/log/fetchAndClear`（会清空缓冲）。
- 面板自动化（推荐）：安装 Chrome DevTools MCP（支持 Chrome / Edge）后，由 Codex
  直接驱动浏览器完成解锁、上传插件、点击「重载 JS」、截图与读取控制台/日志；
  详细安装见 `references/mcp-setup.md`。

安全与纪律：

- 重载 JS 影响该实例上的**所有** JS 插件，属于写操作：操作前确认，两次重载
  间隔必须 ≥ 1 分钟。
- 远程面板凭据只放环境变量或本地 `.env`（已 gitignore），不要写进代码/文档/日志。

## 5. QQ 环境测试（qqmcp）

指令测试覆盖不了真实 QQ 行为（@ 解析、CQ 码、群权限、平台侧渲染），需要
QQ 环境时使用 qqmcp。

### 架构

```text
Codex(MCP 客户端) -> QQ-MCP-Server (:8888/mcp) -> NapCatQQ OneBot (HTTP/WS) -> QQ
```

### 前置条件

- Python 3.10+、Git。
- NapCatQQ 已登录，并启用 OneBot Server（HTTP 或 WebSocket，消息格式建议 Array）。
- 目标机器能访问 NapCat 地址与端口。

### 安装（详细步骤见 `references/mcp-setup.md`）

```powershell
git clone https://github.com/print-yuhuan/QQ-MCP-Server.git   # 若 404 用本机兼容实现
cd QQ-MCP-Server
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e .
python scripts\init_env.py <项目目录>   # 或手动写 .env
```

`.env` 必填项（全部使用占位符）：

```dotenv
QQ_MCP_ACCESS_TOKEN=<MCP_ACCESS_TOKEN>
NAPCAT_BASE_URL=ws://<NAPCAT_HOST>:<NAPCAT_PORT>   # http:// 亦可，协议自动识别
NAPCAT_ACCESS_TOKEN=<NAPCAT_ACCESS_TOKEN>
QQ_MCP_LISTEN_GROUPS=<GROUP_ID>                    # 可选，逗号分隔
```

启动与验证：

```powershell
.\.venv\Scripts\python.exe -m qq_mcp_server
# 端点 http://<HOST>:8888/mcp，健康检查 http://<HOST>:8888/health
```

注册到 MCP 客户端（以 Codex 为例）：在 `~/.codex/config.toml` 添加 `type = "http"` 的
`mcp_servers.QQ-MCP-Server`（`http_headers` 带 token）；Claude Desktop / Cursor /
Cline 等客户端的字段结构相同，改完重启客户端。

### 工具清单

| 工具 | 用途 |
|---|---|
| `qq_get_bot_status` | 控制器机器人在线状态（预检） |
| `qq_list_groups` | 机器人所在群列表（找测试群） |
| `qq_get_group_members` | 群成员（确认待测机器人身份） |
| `qq_get_group_messages` | 拉群历史（验证回复） |
| `qq_get_incoming_messages` | 监听器最近收到的消息（备用验证） |
| `qq_send_group_message` | 发群消息（支持 CQ 码，如 `[CQ:at,qq=xxx]`） |
| `qq_send_private_message` | 私聊 |
| `qq_set_group_ban` / `qq_set_group_whole_ban` | 禁言（高风险，非必要不用） |

### 验证循环（发送 → 轮询 → 断言）

1. 预检：`qq_get_bot_status` → `qq_list_groups` → 向测试群发一条指令
   （如 `.ai status`）找到待测机器人。
2. 发送指令并记录本地时间。
3. 每 2~3 秒轮询 `qq_get_group_messages(group_id, count=20, reverse_order=true)`，
   最长 45 秒；过滤 `user_id == 待测机器人QQ` 且 `time >= 发送时间 - 1` 的消息。
4. 拼接 `message[]` 中 `type == "text"` 的 `data.text` 做关键字断言
   （子串匹配）：全部命中 → PASS，否则 FAIL 并记录实际文本。
5. 回复含「权限不足」→ SKIP(权限)；含「命令不存在」→ 检查插件是否加载、
   命令名是否写错。

纪律（务必遵守）：

- 群里消息以验证连通为主，**能发就够，不要刷屏**。
- 相邻指令间隔 ≥ 3 秒；每发 5 条暂停 10 秒；收到「频率过快」提示或连续 2 条
  无回复时把间隔翻倍。
- 重载 JS 两次间隔 ≥ 1 分钟；上传/重载/删除插件前先获得用户明确批准。
- 破坏性指令（清空记忆/数据、重置权限等）只测错误路径或经用户确认。
- 配置修改后必须恢复原样并重新打开页面验证。

### 故障排查

| 现象 | 处理 |
|---|---|
| `MCP_AUTH_FAILED` | 检查 `~/.codex/config.toml` 中 mcp token |
| `NAPCAT_REQUEST_FAILED` | NapCat 掉线或 WS 未连接 |
| 发指令后无回复 | 插件未重载 / 指令未注册；先读海豹日志 |
| 回复「权限不足」 | 控制器账号权限不足 |
| `listener_connected=false` | 改用 `qq_get_group_messages` 兜底 |

## 6. 推荐测试顺序（新插件）

1. 写代码 → 工程模板先 `npm run check`（lint/typecheck/build/smoke）。
2. 本地海豹 → 控制台跑最小片段（验证 API 存在性与签名）。
3. 上传插件 + 重载 → 日志确认加载无报错。
4. 辅助工具 → 指令测试（私聊 + 群两种模式）验证指令行为。
5. 需要真实平台时：连接指定 WebUI 或走 qqmcp 在 QQ 群验证。
