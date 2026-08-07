---
name: sealdice-deck
description: 海豹（SealDice）牌堆编写与管理助手。覆盖三种牌堆格式（TOML/JSON/YAML）的结构与元信息字段、抽取语法（放回/不放回、嵌套、权重、掷骰表达式、海豹语、CQ 码与图片）、隐藏与导出控制、TOML 复杂牌组与云端内容、带图牌堆 .deck 打包、更新链接配置，以及 WebUI 上传管理和 .draw 命令。当用户要求编写/修改/制作海豹牌堆、deck 文件、抽牌内容、云牌堆、带图牌堆或配置牌堆更新时使用。
---

# SealDice 牌堆

## 0. 格式选择

| 格式 | 特点 |
|---|---|
| TOML | 功能最全（复杂牌组、隐藏/导出、云端内容），新版本推荐 |
| JSON / JSONC | 通用；v1.4.4+ 支持注释与尾逗号，v1.4.5+ 支持 `.jsonc` 后缀 |
| YAML | 简洁，但功能最少（无隐藏键；抽取语义与 TOML/JSON 相反） |

所有牌堆文件**必须 UTF-8 编码**，使用半角符号。详细语法见 `references/edit_deck.md`。

## 1. 最小牌堆（三格式等价示例见 `assets/`）

```toml
[meta]
title = "野兽牌堆"
author = "田所浩二"
version = "1.0"
desc = "示例"

[decks]
"快端上来罢" = ["哼哼哼啊啊啊啊啊", "你是一个一个一个牌堆结果"]
```

```json
{
  "_title": ["野兽牌堆"],
  "_author": ["田所浩二"],
  "_version": ["1.0"],
  "快端上来罢": ["哼哼哼啊啊啊啊啊", "你是一个一个一个牌堆结果"]
}
```

```yaml
name: 野兽牌堆
author: 田所浩二
version: 1
快端上来罢:
  - 哼哼哼啊啊啊啊啊
  - 你是一个一个一个牌堆结果
```

## 2. 元信息字段（v1.6.0 源码验证：dice/ext_deck.go）

| 含义 | JSON | YAML | TOML（[meta]） |
|---|---|---|---|
| 标题 | `_title` | `name` | `title` |
| 作者 | `_author` | `author` | `author` / `authors` |
| 版本 | `_version` | `version`（整数） | `version` |
| 简介 | `_brief` | `desc` | `desc` |
| 协议 | `_license` | `license` | `license` |
| 日期 | `_date` / `_updateDate` | - | `date` / `update_date` |
| 更新链接 | `_updateUrls` | `update_urls` | `update_urls`（**snake_case**，手册旧示例写 `updateUrls` 已过时） |
| 导出控制 | `_export` / `_exports` | `command` + `default` | 复杂牌组 `export` |
| 显示列表 | `_keys` | - | 复杂牌组 `visible` |

## 3. 条目语法

- 抽取其他牌组（嵌套）：`{key}` 不放回、`{%key}` 放回（TOML/JSON）；
  **YAML 相反**：`{key}` 放回、`{%key}` 不放回。
  - 不放回的尺度是一次抽牌指令（`draw 3# 牌组` 视为一次）。
- 掷骰表达式：`[d100]` 先执行再拼接进结果。
- 权重：条目最前 `::9::` 表示权重 9（默认 1）；权重项在不放回时只影响抽出顺序，
  不视为多个副本。
- 图片/CQ 码：可直接插入 `[图:data/images/x.png]` 或 CQ 码。
- 海豹语：与文案不同，牌堆里用 `[...]` 包裹，如 `[$m金币=$m金币+114]`。
- 在自定义回复/文案中引用牌堆：`#{DRAW-牌组名}`。

## 4. TOML 复杂牌组与云端内容

```toml
["数字论证"]
export = true
visible = true
aliases = ["恶臭论证"]
options = ["114514", "1919810"]
cloud_extra = true        # 每次抽取时请求 API 合并云端数据
options_urls = ["https://example.com/xxx"]  # 返回 JSON 字符串数组
distinct = true            # 云端与本地去重（注意字段名是 distinct）
```

注意：选项名必须完全一致（`aliases`/`options` 不能少 s）。云端内容仅 TOML 支持。

## 5. 隐藏与导出

- TOML：`_` 前缀 = 不在 `.draw keys` 显示但可抽取；`__` 前缀 = 不导出（不可抽取）。
- JSON：`_keys` 指定显示列表；`_export`/`_exports` 指定导出列表。
- YAML：`command` + `default` 组成唯一导出牌组，其余全部不导出。
- WebUI 牌堆列表里灰色 = 隐藏（可抽但列表不显示）。

## 6. 带图牌堆（.deck）

`.deck` 本质是 zip：牌堆文件 + 图片资源，相对路径引用 `./assets/...`：

```text
.
├─assets
│  └─1.jpg
└─ test.json   # 内容形如 {"test":["[图:./assets/1.jpg]"]}
```

选中牌堆文件和 assets 目录压缩为 ZIP，改后缀为 `.deck`，WebUI 可直接上传。
不要回退到上级目录再压缩（会带多余外层文件夹）。

## 7. 管理命令与 WebUI

- `.draw <牌组> [n#]` 抽牌；`.draw list` 列表；`.draw keys [牌堆]` 可抽牌组；
  `.draw search <词>` 模糊搜索；`.draw desc <牌组>` 详情；`.draw reload` 重载（Master）。
- 牌组名不存在时会模糊搜索并提示相似项。
- WebUI「扩展功能 - 牌堆管理」：上传牌堆（json/yaml/toml/zip deck）、删除、
  更新、重载牌堆；带更新链接的牌堆可一键更新对比。
- 扩展包：牌堆文件放进 `.sealpack` 的 `decks/` 目录（见 sealdice-sealpack 技能）。

## 8. 参考文件

| 文件 | 内容 |
|---|---|
| `references/edit_deck.md` | 完整编写文档（语法入门、抽取、权重、隐藏、云端、打包） |
| `references/config_deck.md` | WebUI 管理与 .draw 使用 |
| `references/deck_and_reply.md` | .draw/.reply 命令手册 |
| `assets/example-deck.toml` / `.json` / `.yaml` | 三格式最小示例 |
