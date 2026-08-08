# 海豹实测笔记（v1.6.0 端到端测试踩坑记录）

以下结论来自对 v1.6.0 测试实例的真实 API 验证（脚本见 `scripts/test-sealdice.ps1`）。

## 已实测通过的流程

1. JS 插件：`POST /js/upload`（multipart 字段 `file`）→ `POST /js/reload` →
   `GET /js/get_configs` 查看配置 → `POST /js/set_configs` 修改配置 →
   `POST /dice/exec` 指令测试 → `GET /dice/recentMessage` 取回复 →
   `GET /log/fetchAndClear` 抓日志 → `POST /js/delete`（body `{"filename"}`）→ 重载。
2. 自定义回复：`POST /configs/custom_reply/file_upload`（multipart `file`）→
   `GET /configs/custom_reply?filename=` 读取 → 指令测试触发 → 验证 →
   `POST /configs/custom_reply/file_delete`。
3. 牌堆：`POST /deck/upload`（multipart `file`）→ **必须 `POST /deck/reload`** 才进列表 →
   `.draw 牌组` 指令测试 → `POST /deck/delete`。
4. 自定义文案：`GET /configs/customText` → `POST /configs/customText/save`
   （body `{"category","data"}`）→ 再 GET 验证 → 恢复原值。
5. 扩展包：构建 `.sealpack`（zip：`info.toml` + `scripts/main.js`）→
   `POST /package/install-upload`（octet-stream 原样上传）→ `POST /package/enable`
   （`{"id"}`）→ `POST /package/reload` → 指令测试 → `POST /package/uninstall`
   （`{"id","mode":"full"}`）。

## 踩坑记录

1. **PowerShell `Invoke-RestMethod` 对含 `@`/`:` 的 token 报「格式无效」**：
   改用 `curl.exe` 传 `authorization`/`token` 请求头。
2. **echo 路由区分方法大小写**：`curl -X Post` 会被判为 405 Method Not Allowed，
   `-X` 必须用大写 `POST`。
3. **`$args` 是 PowerShell 自动变量**：函数内做参数数组会失效，改名为 `$curlArgs`。
4. **新装海豹自定义回复总开关默认关闭**：`customReplyConfigEnable = false`，
   需先 `POST /dice/config/set {"customReplyConfigEnable":true}`，否则回复不触发。
5. **回复文件重名上传返回 409**：先删同名文件再上传。
6. **牌堆上传后必须 `/deck/reload`**，否则 `GET /deck/list` 看不到。
7. **`/configs/customText` 的 `texts` 值就是 origin 数组** `[["文本",权重],...]`
   （对象详情在 `previewInfo`）；**保存必须整类回传**，否则该分类会被整类覆盖。
8. **中文文件名查询参数**：curl 需 `--data-urlencode "filename=xxx"`。
9. **指令测试**：`POST /dice/exec`（`{"message","messageType":"private|group"}`，
   限频约 500ms）→ `GET /dice/recentMessage`（读取即清空）。
10. **首次运行（未设密码）**：`POST /sd-api/signin {"password":""}` 直接返回 token。
11. **日志**：`GET /log/fetchAndClear` 会清空缓冲，重复调用前先保存。
12. **Edge/Chrome 无头截图**：旧 `--headless` 会静默失败，用
    `--headless=new --user-data-dir=<临时目录> --no-first-run`。
13. **set_configs 需完整字段**：配置项要带 `key/type/defaultValue/value/description`，
    最好先 GET 再改 `value` 回传。
14. **已设密码实例的 API 签入**：密码哈希由 WebUI 前端计算，核心只存哈希；脚本
    `signin` 仅对未设密码（哈希为空）的新实例可用。已设密码的实例请用浏览器自动化
    在 WebUI 表单中解锁（Chrome DevTools MCP），或把 `.env` 中的密码交给 UI 流程。
