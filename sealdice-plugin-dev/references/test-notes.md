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
14. **新版（1.6+）signin 不认明文密码**（最坑）：`POST /sd-api/signin {"password":"明文"}`
    直接 400。正确流程：`GET /sd-api/signin/salt` 取盐 →
    PBKDF2-SHA512(password, salt, 1000, 32) →
    提交 `base64("v01" + salt(utf8) + [0x00,0x03,0xE8] + derived)` 作为 password。
    实现见 `test-sealdice.ps1` 的 `Get-SealPasswordHash`；旧明文 signin 脚本
    在 1.6+ 会 400。
    新装未设密码实例仍可用 `{"password":""}` 直签；或 `.env` 配
    `SEALDICE_PANEL_TOKEN` 跳过 signin。

以下来自真实项目（triangle-score-plugin / sealdice-plugin-ob11-net-connection /
sealdice-js）线上开发与修复的经验，详见 `js_advanced_patterns.md`：

15. **长耗时请求超时要设大**：AI 识别类接口可能数分钟才返回，`Promise.race` 超时
    实战用 420000ms，并回复「模型响应慢请等待」；超时只是让调用方提前报错，
    底层 fetch 无法真正中断（goja 无 AbortController）。
16. **`@depends` 作者名可含 `&`**：实测 `错误&白鱼:ob11网络连接依赖:>=2.1.0` 合法，
    作者、插件名、版本之间始终用英文冒号分隔。
17. **ob11 方法名兼容 query 旧写法**：`net.callApi(epId, 'get_group_list?no_cache=true')`
    这类带 query string 的调用要解析合并进 data，`send_group_msg` 等对象参数写法
    也要同时支持。
18. **无海豹环境可 mock 测试**：Node 里 mock `seal` / `fetch` / `globalThis.net`
    可跑通插件核心逻辑，提前发现加载期 ReferenceError/TypeError。
19. **截图失败要带 HTTP 状态码与响应预览**：只提示「截图失败」无法排查后端，
    非 200 时把状态码 + 前 120 字符响应体拼进提示。
20. **不要基于 EXIF 校验图片拍摄时间**：QQ 会清空图片 EXIF 时间，基于 EXIF 的上传
    校验上线后被 revert。
21. **空数组随机索引崩溃**：`arr[Math.floor(Math.random() * arr.length)]` 在空数组时
    取到 `undefined`；随机取值前先判空（验证码题库为空时回退自动生成）。
22. **失败/成功返回类型必须一致**：失败 `return 0`、成功 `return {qqLevel, nickname}`
    会导致调用方解构崩；失败分支返回同构对象 `{ qqLevel: 0, nickname: '未知' }`。
23. **`logger` 不一定存在**：用 `logger.error` 前确认定义，兜底 `console.error`。
24. **上线前删除调试残留**：清掉 `console.log(JSON.stringify(...))` 等调试输出。
