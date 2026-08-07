# sealdice-skills

海豹（SealDice）插件开发技能合集：面向 Codex 的可复用技能（Skills），覆盖 JS 插件开发与测试、
自定义回复、牌堆编写、`.sealpack` 扩展包手动打包。

内容依据官方手册（sealdice/sealdice-manual-next）与海豹核心 v1.6.0 源码逐项校验；
`seal.d.ts` 以 sealdice/sealdice-js-ext-template 仓库最新版为准。

## 技能列表

| 技能目录 | 用途 |
|---|---|
| `sealdice-plugin-dev` | JS 插件/扩展开发与测试：单文件 JS、TypeScript 工程模板、测试环境（下载海豹 / WebUI 指令测试 / 连接指定 WebUI / qqmcp QQ 验证） |
| `sealdice-custom-reply` | 自定义回复编写与调试：YAML 结构、触发条件、回复结果、豹语脚本 |
| `sealdice-deck` | 牌堆编写与管理：TOML/JSON/YAML、抽取语法、隐藏与导出、云端内容、`.deck` 打包 |
| `sealdice-sealpack` | `.sealpack` 扩展包手动打包与发布：info.toml、归档规则、sealpack CLI、WebUI 安装 |

## 安装到 Codex

将技能目录复制到 `~/.codex/skills`（或 `$CODEX_HOME/skills`）：

```powershell
# 安装/同步全部技能
.\scripts\sync-to-codex.ps1

# 或手动复制单个技能
Copy-Item -Recurse .\sealdice-plugin-dev $HOME\.codex\skills\
```

安装后重启 Codex 即可自动发现这些技能。

## 同步说明

本仓库是唯一事实来源。修改技能后请：

1. 提交仓库变更；
2. 重新运行 `.\scripts\sync-to-codex.ps1` 同步本机已安装副本。

## 时效性维护

- 参考文档来源：官方手册仓库 sealdice/sealdice-manual-next（main 分支）。
- 事实核对基准：海豹核心 v1.6.0 源码（sealdice/sealdice-core，对应
  sealdice-build v1.6.0 的 submodule commit `b06a2d9`）。
- `sealdice-plugin-dev/references/seal.d.ts` 应始终与
  sealdice-js-ext-template 仓库的 `types/seal.d.ts` 保持一致；该文件更新后请同步替换。

## 许可证

MIT，见 [LICENSE](LICENSE)。
