# goja 引擎兼容性（v1.6.0 实测）

海豹 JS 插件运行在 [goja](https://github.com/dop251/goja) 上，而不是 Node 或浏览器。
本文给出 v1.6.0 锁定的引擎版本、支持与不支持的语法/API 清单，以及海豹宿主额外注入的
能力。结论来自源码核对与 v1.6.0 实机探测（脚本与原始结果见文末）。

## 1. 版本锁定（v1.6.0）

海豹核心 v1.6.0（core commit `b06a2d92a7af0b8b33be33390206297edf29c7bd`）在
`go.mod` 中锁定的依赖：

| 组件 | 版本 | 用途 |
|---|---|---|
| github.com/dop251/goja | `v0.0.0-20260216154549-8b74ce4618c5`（2026-02-16） | JS 引擎本体 |
| goja_nodejs | `f7acab6894b0`，replace 为 `github.com/PaienNate/goja_nodejs bac2e5ba5231` | console / require / eventloop |
| github.com/fy0/gojax | `4140cf8509bd` | fetch 实现 |

goja README 的官方能力声明：ES5.1 完整；已实现特性通过
[tc39/test262](https://github.com/tc39/test262) 测试（测试快照 commit
`cb4a6c8074671c00df8cbc17a620c0f9462b312a`）；`setTimeout`/`setInterval` 等由宿主提供，
引擎本身不实现。

注意：海豹后续版本可能升级 goja，本文清单只对 v1.6.0 成立；升级后应重跑
`scripts/run-goja-probe.ps1` 重新核对，不要凭印象沿用。

## 2. 支持的语法与内置对象（实测）

### 语法

- ES5.1 完整。
- ES6+ 大部分可用：箭头函数、模板字符串、let/const、解构、展开运算符
  （数组与对象）、默认/rest 参数、class（含 public/private/static 字段与
  static block）、可选链、空值合并、逻辑赋值、指数运算符、数字分隔符、
  生成器、async/await、无绑定 catch、对象简写与计算键、tagged template、
  `for...of`。

### 内置对象与方法

- 数值：`BigInt`（含字面量与 `BigInt.asIntN/asUintN`）、`Number` 全套 ES6+ 方法
  （`isNaN/isFinite/isInteger/isSafeInteger/EPSILON/MAX_SAFE_INTEGER` 等）。
- 集合：`Map`、`Set`、`WeakMap`、`WeakSet` 基础功能；`Symbol` 常用 well-known
  symbols（`iterator/hasInstance/toPrimitive/toStringTag/species/matchAll` 等，
  `asyncIterator` 除外）。
- 反射：`Proxy`（含 `Proxy.revocable`）、`Reflect` 全套。
- 异步：`Promise` 全套（`all/allSettled/any/race`、`prototype.finally`）、
  `AggregateError`、`Error.cause`。
- 二进制：`ArrayBuffer`、`DataView`、全部 11 种 TypedArray（含
  `BigInt64Array`/`BigUint64Array`）。
- 字符串：`at/replaceAll/matchAll/padStart/padEnd/trimStart/trimEnd/
  startsWith/endsWith/includes/repeat/codePointAt/normalize`、
  `String.fromCodePoint/String.raw`。
- 数组：`from/of/at/findLast/findLastIndex/flat/flatMap/includes/find/
  findIndex/keys/values/entries/copyWithin/fill/toSorted/toReversed/toSpliced/with`
  及 `[Symbol.iterator]`。
- 对象：`assign/entries/values/fromEntries/getOwnPropertyDescriptors/
  getOwnPropertySymbols/hasOwn/getPrototypeOf/setPrototypeOf`。
- 数学：`cbrt/clz32/imul/log10/log2/sign/trunc/hypot/expm1/log1p/fround/
  acosh/asinh/atanh/cosh/sinh/tanh`。
- 正则：`RegExp` 的 dotAll（`s`）、lookbehind（`(?<=...)`）、sticky（`y`）、
  unicode（`u`）标志，`RegExp.prototype.matchAll`。

## 3. 不支持的语法与内置对象（实测）

| 类别 | 具体内容 |
|---|---|
| 正则 | 命名组 `(?<name>...)`：语法可解析，但结果没有 `groups`，不可用；`d`（indices）标志不支持 |
| 异步迭代 | `for await...of`、`Symbol.asyncIterator` |
| Set 新方法 | `union/intersection/difference/symmetricDifference/isSubsetOf/isSupersetOf/isDisjointFrom` |
| 内存/弱引用 | `WeakRef`、`FinalizationRegistry` |
| 并发 | `SharedArrayBuffer`、`Atomics` |
| 任务调度 | `queueMicrotask`、`structuredClone` |
| 国际化 | `Intl`（`Intl.NumberFormat` 等全部不可用） |
| URL | `URL`、`URLSearchParams` |
| 编码 | `TextEncoder`、`TextDecoder` |
| 中止控制 | `AbortController`、`AbortSignal`（fetch 无法真正中断，见 §6） |
| 其他 | `WebAssembly` |

## 4. 宿主注入的全局（非 goja 自带）

以下全局由海豹或 goja_nodejs / gojax 注入，不是引擎原生能力，换环境（如 Node）不会自动存在：

- `seal`：海豹 API 总入口（`vars/ban/ext/coc/deck/replyGroup/replyPerson/
  replyToSender/format/formatTmpl/createTempCtx/gameSystem/getVersion/
  getEndPoints/setPlayerGroupCard` 等，见 `seal.d.ts`）。
- `console`：goja_nodejs console，输出转发到海豹日志与 WebUI 控制台。
- `setTimeout/clearTimeout/setInterval/clearInterval`：goja_nodejs eventloop 提供。
- `fetch`：fy0/gojax 实现，走海豹内置代理。
- `WebSocket`：海豹 `utils/plugin/websocket` 提供。
- `atob/btoa`：海豹自实现（标准 base64）。`atob` 会先剥除
  `data:text/plain;base64,` 前缀与空格再解码，非法输入返回错误。
- `require`：goja_nodejs require registry（见 §5）。

## 5. require 与 Node 模块（实测仅 console/util 可用）

- 插件文件通过 require 机制加载，包装为
  `(function(exports, require, module, __filename, __dirname){ ... })`，
  因此插件文件内 `require/exports/module/__filename/__dirname` 是可用参数；
  `globalThis.require` 也存在。
- 实测可加载的模块：仅 `console`、`util`。`buffer/process/url/events/path/fs/
  http/https/crypto/os/net/querystring/zlib/timers` 等其余 Node 内置模块均报
  `Invalid module`。
- 原因：海豹只向 registry 注册了 `console`；`util` 是 console 包的依赖被带入。
  goja_nodejs 其余核心模块未随海豹编译进二进制，注册表里没有它们。
- WebUI 控制台执行（`/sd-api/js/execute`）时，代码被包装为
  `(function(exports, require, module) { ... })()` 且不传参数，局部
  `require/exports/module` 是 `undefined`（遮蔽同名全局）；此时要用
  `globalThis.require` 才能调 `require('console')`。
- 建议：插件不要依赖 `require` 加载模块；需要 Node 能力时，在宿主工具链
  （Node/TypeScript 工程）中处理后把结果注入插件，或通过 fetch/MCP 调用外部服务。

## 6. 已知坑

1. **WeakMap 内存不释放**（goja README 明确）：只要 key 存活，value 就不会被回收，
   即使 WeakMap 本身已被丢弃。因此 goja 无法实现 WeakRef/FinalizationRegistry。
   缓存类场景慎用 WeakMap，或定期清理 key。
2. **fetch 无法真正中断**：没有 `AbortController`，`Promise.race` 只是让调用方提前
   收到错误，底层请求仍占用连接直到响应。长耗时接口要设足够大的超时（实战建议
   420000ms）并提示用户等待，写法见 `js_advanced_patterns.md` §3。
3. **整数语义**（纠正旧手册说法）：goja 内部整型为 int64，JS Number 是 IEEE-754
   double，安全整数到 2^53-1。实测 `Number.MAX_SAFE_INTEGER` 正常、`2147483647 + 1`
   不溢出、`seal.vars.intSet/intGet` 可完整存取 `9007199254740991` 与
   `Date.now()` 时间戳（dicescript 的整数类型为 Go int，64 位平台即 int64）。
   早期手册「整型 32 位、时间戳不要存入 intSet」的说法基于旧版引擎，对 v1.6.0 不成立。
4. **浮点与数组长度**：数值运算遵循 double 精度（如 `0.1 + 0.2`）；数组长度上限
   `2^32 - 1` 是 JS 规范行为，超出部分不作为数组索引。
5. **`RegExp` 命名组陷阱**：`/(?<w>\w+)/` 不报语法错误，但 `.groups` 不存在，
   按命名组写的代码会在运行期静默取到 `undefined`，应改用普通捕获组。

## 7. 验证方法

- `scripts/goja-probe.js`：逐项探测语法/内置对象/宿主全局的探测代码。
- `scripts/run-goja-probe.ps1`：自动读取 `.env`（或 `-BaseUrl/-Password`）、按
  v1.6+ PBKDF2 流程登录，通过 `/sd-api/js/execute` 执行探测并输出结果；
  `-ProbeFile` 可指定其他探测脚本。
- `references/goja-probe-result.json`：v1.6.0+20260726（versionCode 1006000）
  实机完整结果快照，可作为本文结论的原始证据。
- 升级海豹后重跑上述脚本，把新结果与快照对比，再决定本文是否过时。
