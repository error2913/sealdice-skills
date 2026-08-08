---
name: sealdice-sealpack
description: 海豹（SealDice）扩展包 .sealpack 手动打包与发布助手（v1.6.0+）。覆盖包格式与 info.toml 清单（package/dependencies/permissions/contents/store/config）、归档布局规则（zip、顶层目录白名单、路径约束）、sealpack CLI 的 init/login/token/refresh/validate/size/pack/version/publish 命令、不依赖模板 CI 的纯手动打包流程，以及 WebUI 安装/启用/重载/卸载。当用户要求创建/打包/校验/发布海豹 .sealpack 扩展包、编写 info.toml、手动打包扩展包（俗称豹包）、发布到海豹商店（SealRepo）时使用。
---

# SealDice 扩展包（.sealpack）手动打包与发布

## 0. 核心事实（v1.6.0 源码验证：dice/sealpack/*.go + 手册 config/package.md）

- `.sealpack` 是一个 **zip 压缩包**，可同时携带 JS 脚本、牌堆、自定义回复、帮助文档、规则模板。
- 术语：「扩展包」是正式名称，「豹包」是俗称，两者指同一个东西。
- 归档顶层只允许：`info.toml`、`README.md`、`assets/`、`decks/`、`helpdoc/`、`reply/`、`scripts/`、`templates/`。
- `info.toml` 必须在压缩包根目录；不支持 `src/` 布局、绝对路径、`..`、空路径段、重复条目、反斜杠。
- `[contents]` 里的路径必须落在对应类型目录下（如 scripts 只能引用 `scripts/` 下的文件）。

## 1. info.toml 结构

完整注释模板见 `assets/info.toml`。要点：

```toml
format_version = "1.0.0"

[package]
id = "your-name/your-plugin"   # 必填，author/package，两段各 ≤64 字符，仅限字母（含中文）/数字/下划线/连字符
name = "你的插件名"             # 必填
version = "1.0.0"              # 必填，语义化版本
authors = ["你的名字"]
license = "MIT"
description = "..."
homepage = "https://..."
repository = "https://..."
keywords = ["sealdice"]

[package.seal]
min_version = "1.6.0"          # 最低/最高海豹版本（可省略）
max_version = ""

[dependencies]                 # 依赖包 ID = semver 约束
# "author/dep" = ">=1.0.0"

[permissions]
network = false
network_hosts = []             # 允许访问的域名白名单
file_read = []                 # 可读取的路径模式
file_write = []                # 可写入的路径模式（未声明时默认仅包自身 _userdata）
dangerous = false              # 危险操作（执行外部程序）
http_server = false            # 监听 HTTP 服务
ipc = []                       # 允许通信的包 ID 列表

[contents]                     # 内容清单，路径必须在对应目录下
scripts = ["scripts/*.js"]
decks = []
reply = []
helpdoc = []
templates = []

[store]
readme = "README.md"
icon = "assets/icon.png"
banner = ""
screenshots = []
category = "tool"

[config]                       # 可选：包配置项（类 JSON Schema）
[config.api_key]
type = "string"
title = "API Key"
description = "..."
default = ""
secret = true
```

`[config]` 的 type 支持：`string` / `integer` / `number` / `boolean` / `array` / `object`，
可选 `title` / `description` / `default` / `secret` / `min` / `max` / `enum` / `items` / `properties`。

## 2. 手动打包流程（不依赖模板 CI）

### 2.1 安装 CLI

```bash
npm install -g sealpack
```

### 2.2 建目录（二选一）

用模板初始化（推荐）：

```bash
sealpack init my-package --id your-name/my-package --template full
# --template: minimal(仅 info.toml+README) | script(+scripts/main.js) | full(全部内容类型)
# 也可用 --contents scripts,decks,reply 指定类别
# --category 商店分类：tool/entertainment/game/storybook/trpg-system/campaign/
#   documentation/operations/ruleset/example/official
```

或纯手动创建目录：

```text
my-package/
├── info.toml
├── README.md
├── scripts/     # JS 插件
├── decks/       # 牌堆 json/yaml/toml
├── reply/       # 自定义回复 yaml
├── helpdoc/     # 帮助文档
├── templates/   # 规则模板
└── assets/      # 商店图标/横幅/截图
```

### 2.3 校验、打包、发布

```bash
cd my-package
sealpack refresh                  # 扫描子目录，自动更新 [contents]
sealpack validate                 # 校验格式
sealpack size                     # 统计体积（默认估算图片压缩后大小）
sealpack version set 1.1.0        # 或 version major/minor/patch/release
sealpack pack --out ../my-package-1.1.0.sealpack
sealpack publish --create         # 发布；--create = 远程仓库不存在时自动创建
```

`sealpack size` / `pack` / `publish` 会估算并压缩包内图片（只作用于包内副本，
不修改原始资源）；不需要时加 `--no-compress-images`。

登录认证（二选一）：

```bash
sealpack login --server https://repo.sealdice.com/   # 邮箱+密码，生成 CLI token
sealpack token set <token>                           # 直接写网站后台复制的 token
```

发布前可用 `sealpack publish --dry-run` 只做校验打包不上传。
常用管理：`sealpack whoami`、`logout`、`config-path`。

## 3. 从 JS 工程模板打包（快速路径）

见 sealdice-plugin-dev 技能 §3：`npm run package:check`（build+同步版本+校验）、
`npm run pack:sealpack`（在 `dist/` 生成 `.sealpack`）、
`npm run pack:release`（本体 JS + 带版本扩展包）。
其 `scripts/prepare-sealpack.js` 会把 `dist/<文件名>` 复制为 `sealpack/scripts/main.js`
并同步 `info.toml` 的 version。

## 4. 安装与验证（WebUI，v1.6.0）

- 入口：「扩展功能 - 扩展包」，支持上传 `.sealpack`、URL 安装、商店/清单安装。
- 状态：已安装（未启用）/ 已启用 / 已禁用 / 错误；「安装」和「启用」是两步。
- 启用/禁用后按类型重载：脚本 / 牌堆 / 自定义回复 / 帮助文档 / 规则模板；
  重载期间不要连续点击或重启核心。
- 卸载：`full`（删包+配置+用户数据，不可撤销）或 `keep_data`（保留用户配置与数据）。
- 数据位置：源包 `data/packages/`，运行缓存 `cache/packages/`，
  用户数据 `data/extensions/<作者>/<包名>/_userdata/`（含 config.json）。

## 5. 注意事项

- 权限声明只是限制边界，不是完整安全防护：`dangerous`、广泛文件权限、不受限网络
  的包应在隔离环境验证后再安装。
- 商店展示与权限声明不能代替代码审查；不安装来历不明的 `.sealpack`。
- 发布同名包必须递增 `version`；`sealpack refresh` 后记得重新 `validate`。

## 6. 参考文件

| 文件 | 内容 |
|---|---|
| `references/package.md` | 手册「扩展包与商店」（状态/安装/权限/卸载） |
| `assets/info.toml` | 带完整注释的 info.toml 模板 |
| `scripts/test-sealpack.ps1` | 扩展包端到端测试（构建/安装/启用/重载/指令测试/卸载） |
| `../sealdice-plugin-dev/references/dicescript.md` | 豹语（DiceScript）语法（共用） |
| `../sealdice-plugin-dev/references/test-notes.md` | 实测坑记录（共用） |

共用资源说明：豹语指导、测试脚本与实测坑统一存放在 `sealdice-plugin-dev`，
本技能通过相对路径引用，建议整套安装。
