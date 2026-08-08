# MCP 环境搭建：QQ-MCP 与 Chrome DevTools MCP（Chrome / Edge）

海豹插件的两类常用 MCP 服务：

1. **QQ-MCP-Server**：让 Codex 能收发 QQ 群消息，用于 QQ 环境测试（@ 解析、CQ 码、
   群权限、平台侧渲染）。
2. **Chrome DevTools MCP**：让 Codex 控制 Chrome / Edge 浏览器，用于 WebUI 面板
   自动化（解锁、上传插件、重载、截图、读取控制台与日志）。

两个服务都通过 MCP 客户端配置注册，改完**重启客户端**生效。示例以 Codex
（`~/.codex/config.toml` 的 `[mcp_servers]`）为准；其他客户端对应：
Claude Desktop（`claude_desktop_config.json` 的 `mcpServers`）、
Cursor（`.cursor/mcp.json`）、Cline（`mcp_settings.json`），字段结构相同。

## 1. QQ-MCP-Server（qqmcp）

### 1.1 架构与前置条件

```text
Codex(MCP 客户端) -> QQ-MCP-Server (:8888/mcp) -> NapCatQQ OneBot (HTTP/WS) -> QQ
```

- Python 3.10+、Git。
- NapCatQQ 已登录，并启用 OneBot Server（HTTP 或 WebSocket，消息格式建议 Array）。
- 目标机器能访问 NapCat 的地址与端口。

使用 qqmcp 前先检查是否已配置：`~/.codex/config.toml` 已注册 `QQ-MCP-Server`
（MCP 工具可用），或 qqmcp 项目 `.env` 已有 `NAPCAT_BASE_URL` /
`NAPCAT_ACCESS_TOKEN` 时**直接使用，不再询问**；未配置才向用户索取这两个值。

### 1.2 获取源码

```powershell
git clone https://github.com/print-yuhuan/QQ-MCP-Server.git
```

若官方仓库不可访问（私有 / 404），改用本机已有的接口兼容实现（包含
`qq_mcp_server` 包与 `pyproject.toml`，提供读/写工具、消息监听与 WebSocket 客户端），
并向用户说明这不是官方源码。

### 1.3 安装

```powershell
cd QQ-MCP-Server
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e .
```

依赖会自动安装（mcp、httpx、uvicorn、websockets、python-dotenv）。

### 1.4 配置 .env

```powershell
python scripts\init_env.py <项目目录>
```

或手动创建 `.env`（全部使用占位符，禁止写入真实凭据）：

```dotenv
QQ_MCP_ACCESS_TOKEN=<MCP_ACCESS_TOKEN>
NAPCAT_BASE_URL=ws://<NAPCAT_HOST>:<NAPCAT_PORT>
NAPCAT_ACCESS_TOKEN=<NAPCAT_ACCESS_TOKEN>
QQ_MCP_LISTEN_GROUPS=<GROUP_ID>      # 可选，逗号分隔多个群
```

必填项只有 `QQ_MCP_ACCESS_TOKEN` 与 `NAPCAT_BASE_URL`；协议按 URL 前缀自动识别
（`ws://` 走 WebSocket，`http://` 走 HTTP）。

### 1.5 启动与健康检查

```powershell
.\.venv\Scripts\python.exe -m qq_mcp_server
```

- MCP 端点：`http://<HOST>:8888/mcp`
- 健康检查：`http://<HOST>:8888/health`，预期返回 `{"ok": true, ...}`

### 1.6 注册到 MCP 客户端

在 `~/.codex/config.toml` 添加（token 用真实值替换）：

```toml
[mcp_servers.QQ-MCP-Server]
type = "http"
url = "http://127.0.0.1:8888/mcp"
http_headers = { Authorization = "Bearer <MCP_ACCESS_TOKEN>" }
```

改完重启 MCP 客户端（Codex / Claude / Cursor / Cline 等）。

### 1.7 验证

```powershell
python scripts\verify.py http://127.0.0.1:8888 <MCP_ACCESS_TOKEN>
```

预期 initialize 返回 HTTP 200、/health 返回 ok。返回 401 检查 token；
工具调用报 `NAPCAT_REQUEST_FAILED` 检查 NapCat 连通性。

### 1.8 工具清单

| 工具 | 用途 |
|---|---|
| `qq_get_bot_status` | 控制器机器人在线状态（预检） |
| `qq_list_groups` | 机器人所在群列表（找测试群） |
| `qq_list_friends` | 好友列表 |
| `qq_get_group_members` | 群成员（确认待测机器人身份） |
| `qq_get_group_messages` | 拉群历史（验证回复） |
| `qq_get_private_messages` | 私聊记录 |
| `qq_get_incoming_messages` | 监听器最近收到的消息（备用验证） |
| `qq_send_group_message` | 发群消息（支持 CQ 码，如 `[CQ:at,qq=xxx]`） |
| `qq_send_private_message` | 私聊 |
| `qq_set_group_ban` / `qq_set_group_whole_ban` | 禁言（高风险，非必要不用） |

### 1.9 消息监听（可选）

服务启动时自动建立第二条 WebSocket 连接实时接收群聊/私聊消息：

- `QQ_MCP_MESSAGE_LOG_FILE`：消息日志文件（默认 `messages.log`，UTF-8 JSON 行）。
- `QQ_MCP_LISTEN_GROUPS`：只监听指定群（逗号分隔），空则监听所有群。
- `qq_get_incoming_messages` 拉取内存缓冲（最近约 200 条）。

注意：监听只“收”不“回”，自动回复需在 `listener.py` 的 `_should_capture` 处扩展。

### 1.10 敏感信息

- 所有示例使用占位符；不要把 `.env`、`messages.log`、运行日志提交或外发。
- `QQ_MCP_LOG_MESSAGE_CONTENT` 保持 `false`。

## 2. Chrome DevTools MCP（Chrome / Edge）

### 2.1 简介

`chrome-devtools-mcp` 是 npm 发布的 MCP 服务器，让 Codex 控制并检查一个真实的
浏览器实例：导航、截图、DOM 操作、控制台与网络、性能分析。

- 官方支持 Google Chrome 与 Chrome for Testing；Edge 基于 Chromium，可通过
  `--executablePath` 指定使用（实测可用）。
- 通过 puppeteer 自动化，自动等待操作结果。
- 默认收集使用统计，可加 `--no-usage-statistics` 关闭；遥测亦可关。

### 2.2 前置条件

- Node.js LTS + npm。
- 已安装 Google Chrome 或 Microsoft Edge。

### 2.3 安装（无需全局安装）

直接验证能否运行（Windows 用 `npx.cmd`）：

```powershell
npx.cmd -y chrome-devtools-mcp@latest --help
```

也可以全局安装：`npm install -g chrome-devtools-mcp`。

### 2.4 注册到 MCP 客户端

在 `~/.codex/config.toml` 添加：

#### 默认 Chrome（npx 方式）

```toml
[mcp_servers.chrome-devtools]
type = "stdio"
command = "npx.cmd"                      # Windows 必须带 .cmd
args = ["-y", "chrome-devtools-mcp@latest"]
```

#### 指定 Edge（本机实测配置）

```toml
[mcp_servers.chrome-devtools]
type = "stdio"
command = "npx.cmd"
args = [
  "-y",
  "chrome-devtools-mcp@latest",
  "--executablePath=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
  "--isolated",
  "--no-usage-statistics",
  "--no-performance-crux",
]
```

#### Windows 上更稳定的绝对路径方式

先安装到固定目录（如 `C:\Users\<你>\chrome-devtools-mcp`），再直接指向
Node 与服务器脚本，避免 npx 每次解析：

```toml
[mcp_servers.chrome-devtools]
type = "stdio"
command = "C:\\Users\\<你>\\.codex\\tools\\node-v22.23.2-win-x64\\node.exe"
args = [
  "C:\\Users\\<你>\\chrome-devtools-mcp\\node_modules\\chrome-devtools-mcp\\build\\src\\bin\\chrome-devtools-mcp.js",
  "--executablePath=C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
  "--isolated",
  "--no-usage-statistics",
  "--no-performance-crux",
]
```

### 2.5 常用参数

| 参数 | 作用 |
|---|---|
| `--executablePath=<路径>` | 指定浏览器可执行文件（Chrome 或 Edge） |
| `--headless` | 无头模式（配合 `--slim` 做轻量自动化） |
| `--slim` | 只提供基础浏览器操作工具 |
| `--isolated` | 使用独立临时用户数据目录，避免与日常浏览器会话冲突（推荐） |
| `--channel=chrome` 等 | 自动发现指定渠道的 Chrome |
| `--no-usage-statistics` | 关闭使用统计上报 |
| `--no-performance-crux` | 关闭性能数据上传到 CrUX |

### 2.6 验证

重启 MCP 客户端后，调用浏览器工具做一次冒烟测试：打开海豹 WebUI
（如 `http://127.0.0.1:3211/#/home`）并截图。

常见问题：

- 工具报找不到命令：Windows 把 `command` 写成 `npx.cmd`，或改用绝对路径方式。
- 报找不到浏览器：确认 `--executablePath` 指向真实存在的 chrome.exe / msedge.exe。
- 与日常浏览器冲突：加 `--isolated`。

## 3. 典型场景：用 Chrome DevTools MCP 操作海豹 WebUI

1. 导航：`navigate` 到 `http://<host>:3211/#/home`。
2. 解锁：在密码输入框 `evaluate` 填入密码并点击确认（解锁后 token 存于
   `localStorage["t"]`）。
3. 上传 / 重载：进入 `#/mod/js`，操作文件输入框与「重载 JS」按钮，等待完成。
4. 验证：`screenshot` 留证；用页面内嵌日志或 `GET /sd-api/log/fetchAndClear`
   （带 `authorization` 与 `token` 请求头）读取日志。

纪律：重载 JS 影响该实例上所有 JS 扩展，两次重载间隔必须 ≥ 1 分钟；
面板凭据只放环境变量或本地 `.env`，不要写入代码、文档或日志。

## 4. 故障排查

| 现象 | 处理 |
|---|---|
| `MCP_AUTH_FAILED` | 检查 `~/.codex/config.toml` 中对应服务的 token |
| `NAPCAT_REQUEST_FAILED` | NapCat 掉线或 WS 未连接 |
| 客户端里看不到 MCP 工具 | 重启客户端；检查配置语法与 `type`（http/stdio） |
| 浏览器工具报错 | 检查 `--executablePath`、`--headless`、`--isolated` 组合 |
