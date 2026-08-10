// goja / 海豹 v1.6.0 JS 运行时特性探测脚本
// 通过 WebUI 控制台接口（/sd-api/js/execute）在真实运行环境中执行。
// 注意：/sd-api/js/execute 的源码包装为函数体，必须用顶层 return 输出结果。
  var R = {};
  function chk(name, fn) {
    try { R[name] = !!fn(); } catch (e) { R[name] = false; }
  }
  function present(name) {
    try { return typeof globalThis[name] !== 'undefined'; } catch (e) { return false; }
  }
  function syntax(name, code) {
    try { eval(code); R[name] = true; } catch (e) { R[name] = false; }
  }

  // ---- 全局对象 ----
  var globals = [
    'globalThis', 'BigInt', 'Symbol', 'Proxy', 'Reflect', 'Map', 'Set',
    'WeakMap', 'WeakSet', 'WeakRef', 'FinalizationRegistry', 'Promise',
    'Intl', 'URL', 'URLSearchParams', 'TextEncoder', 'TextDecoder',
    'structuredClone', 'queueMicrotask', 'AbortController', 'AbortSignal',
    'fetch', 'WebSocket', 'setTimeout', 'setInterval', 'clearTimeout',
    'clearInterval', 'console', 'atob', 'btoa', 'seal', 'require', 'exports',
    'module', 'ArrayBuffer', 'DataView', 'SharedArrayBuffer', 'Atomics',
    'WebAssembly', 'JSON', 'Date', 'Math', 'RegExp'
  ];
  var G = {};
  globals.forEach(function (n) { G[n] = present(n); });
  R.globals = G;

  // ---- ES 语法（逐条 eval，解析失败即不支持）----
  syntax('arrow', 'var f = (x) => x + 1; f(1) === 2;');
  syntax('templateLiteral', 'var t = `a${1 + 1}b`; t === "a2b";');
  syntax('letConst', 'let a = 1; const b = 2; a + b === 3;');
  syntax('destructuring', 'var {a, b: c} = {a: 1, b: 2}; var [d, e] = [3, 4]; a + c + d + e === 10;');
  syntax('spreadArray', 'var a = [1, 2]; var b = [...a, 3]; b.length === 3;');
  syntax('spreadObject', 'var o = {a: 1}; var p = {...o, b: 2}; p.a === 1 && p.b === 2;');
  syntax('defaultParams', 'var f = (a = 1) => a; f() === 1;');
  syntax('restParams', 'var f = (a, ...rest) => rest.length; f(1, 2, 3) === 2;');
  syntax('class', 'class A { constructor(x) { this.x = x; } } new A(1).x === 1;');
  syntax('classPublicFields', 'class A { x = 1; } new A().x === 1;');
  syntax('classStaticFields', 'class A { static x = 1; } A.x === 1;');
  syntax('classPrivateFields', 'class A { #x = 1; get() { return this.#x; } } new A().get() === 1;');
  syntax('classStaticBlock', 'class A { static { this.x = 1; } } A.x === 1;');
  syntax('optionalChaining', 'var o = {a: {b: 1}}; o?.a?.b === 1 && o?.c?.d === undefined;');
  syntax('nullishCoalescing', 'var a = null; (a ?? 1) === 1 && (0 ?? 2) === 0;');
  syntax('logicalAssignment', 'var a = 0; a ||= 5; var b = null; b ??= 6; var c = 1; c &&= 2; a === 5 && b === 6 && c === 2;');
  syntax('exponentiation', '2 ** 10 === 1024;');
  syntax('numericSeparators', 'var n = 1_000_000; n === 1000000;');
  syntax('generators', 'function* g() { yield 1; yield 2; } var it = g(); it.next().value === 1 && it.next().value === 2;');
  syntax('asyncAwait', 'async function f() { return await Promise.resolve(1); } typeof f === "function";');
  syntax('asyncIterators', 'async function f() { for await (const x of [1]) { return x; } } typeof f === "function";');
  syntax('catchWithoutBinding', 'try { throw 1; } catch { } true;');
  syntax('objectShorthand', 'var x = 1; var o = {x}; o.x === 1;');
  syntax('computedKeys', 'var k = "a"; var o = {[k]: 1}; o.a === 1;');
  syntax('taggedTemplates', 'function tag(s, ...v) { return s[0] + v[0]; } tag`a${1}b` === "a1";');
  syntax('regexpLookbehind', '/(?<=a)b/.test("ab");');
  syntax('regexpNamedGroups', '/(?<word>\\w+)/.exec("hi").groups.word === "hi";');
  syntax('regexpDotAll', '/a.b/s.test("a\\nb");');
  syntax('regexpSticky', 'var re = /a/y; re.lastIndex = 0; re.test("ba") === false;');
  syntax('regexpUnicode', '/\\u{1F600}/u.test("\\u{1F600}");');
  chk('RegExp indices (d flag)', function () {
    var re = new RegExp('a', 'd');
    var m = re.exec('a');
    return m.indices && m.indices[0][0] === 0;
  });

  // ---- 内建方法与对象 ----
  var B = {};
  chk('String.prototype.at', function () { return 'abc'.at(1) === 'b'; });
  chk('String.prototype.replaceAll', function () { return 'a-b-c'.replaceAll('-', '+') === 'a+b+c'; });
  chk('String.prototype.matchAll', function () { return 'a1b2'.matchAll(/[0-9]/g).length !== undefined || Array.from('a1b2'.matchAll(/[0-9]/g)).length === 2; });
  chk('String.prototype.padStart', function () { return '1'.padStart(3, '0') === '001'; });
  chk('String.prototype.padEnd', function () { return '1'.padEnd(3, '0') === '100'; });
  chk('String.prototype.trimStart', function () { return ' a '.trimStart() === 'a '; });
  chk('String.prototype.trimEnd', function () { return ' a '.trimEnd() === ' a'; });
  chk('String.prototype.startsWith', function () { return 'abc'.startsWith('ab'); });
  chk('String.prototype.endsWith', function () { return 'abc'.endsWith('bc'); });
  chk('String.prototype.includes', function () { return 'abc'.includes('b'); });
  chk('String.prototype.repeat', function () { return 'a'.repeat(3) === 'aaa'; });
  chk('String.prototype.codePointAt', function () { return '𠮷'.codePointAt(0) > 0xFFFF; });
  chk('String.fromCodePoint', function () { return String.fromCodePoint(0x1F600).length === 2; });
  chk('String.prototype.normalize', function () { return 'e\u0301'.normalize('NFC').length === 1; });
  chk('String.raw', function () { return String.raw`a\nb` === 'a\\nb'; });

  chk('Array.from', function () { return Array.from('ab').length === 2; });
  chk('Array.of', function () { return Array.of(1, 2).length === 2; });
  chk('Array.prototype.at', function () { return [1, 2, 3].at(-1) === 3; });
  chk('Array.prototype.findLast', function () { return [1, 2, 3].findLast(function (x) { return x % 2 === 1; }) === 3; });
  chk('Array.prototype.findLastIndex', function () { return [1, 2, 3].findLastIndex(function (x) { return x % 2 === 1; }) === 2; });
  chk('Array.prototype.flat', function () { return [1, [2, [3]]].flat(2).length === 3; });
  chk('Array.prototype.flatMap', function () { return [1, 2].flatMap(function (x) { return [x, x]; }).length === 4; });
  chk('Array.prototype.includes', function () { return [1, NaN].includes(NaN); });
  chk('Array.prototype.find', function () { return [1, 2].find(function (x) { return x > 1; }) === 2; });
  chk('Array.prototype.findIndex', function () { return [1, 2].findIndex(function (x) { return x > 1; }) === 1; });
  chk('Array.prototype.keys', function () { return Array.from([1, 2].keys()).join() === '0,1'; });
  chk('Array.prototype.values', function () { return Array.from([1, 2].values()).join() === '1,2'; });
  chk('Array.prototype.entries', function () { return Array.from([9].entries())[0][1] === 9; });
  chk('Array.prototype.copyWithin', function () { return [1, 2, 3, 4].copyWithin(0, 2).join() === '3,4,3,4'; });
  chk('Array.prototype.fill', function () { return [1, 2].fill(0).join() === '0,0'; });
  chk('Array.prototype.toSorted', function () { return [3, 1, 2].toSorted().join() === '1,2,3'; });
  chk('Array.prototype.toReversed', function () { return [1, 2, 3].toReversed().join() === '3,2,1'; });
  chk('Array.prototype.toSpliced', function () { return [1, 2, 3].toSpliced(1, 1).join() === '1,3'; });
  chk('Array.prototype.with', function () { return [1, 2].with(0, 9).join() === '9,2'; });
  chk('Array.prototype[Symbol.iterator]', function () { return typeof [][Symbol.iterator] === 'function'; });

  chk('Object.assign', function () { return Object.assign({}, {a: 1}).a === 1; });
  chk('Object.entries', function () { return Object.entries({a: 1}).length === 1; });
  chk('Object.values', function () { return Object.values({a: 1})[0] === 1; });
  chk('Object.fromEntries', function () { return Object.fromEntries([['a', 1]]).a === 1; });
  chk('Object.getOwnPropertyDescriptors', function () { return typeof Object.getOwnPropertyDescriptors({}).a === 'undefined'; });
  chk('Object.hasOwn', function () { return Object.hasOwn({a: 1}, 'a'); });
  chk('Object.getOwnPropertySymbols', function () { return Object.getOwnPropertySymbols({[Symbol('x')]: 1}).length === 1; });

  chk('Number.isNaN', function () { return Number.isNaN(NaN) && !Number.isNaN('NaN'); });
  chk('Number.isFinite', function () { return Number.isFinite(1) && !Number.isFinite('1'); });
  chk('Number.isInteger', function () { return Number.isInteger(1) && !Number.isInteger(1.5); });
  chk('Number.isSafeInteger', function () { return Number.isSafeInteger(Number.MAX_SAFE_INTEGER); });
  chk('Number.EPSILON', function () { return Number.EPSILON > 0; });
  chk('Number.MAX_SAFE_INTEGER', function () { return Number.MAX_SAFE_INTEGER === 9007199254740991; });
  chk('Number.MIN_SAFE_INTEGER', function () { return Number.MIN_SAFE_INTEGER === -9007199254740991; });

  chk('Math.cbrt', function () { return Math.cbrt(8) === 2; });
  chk('Math.clz32', function () { return Math.clz32(1) === 31; });
  chk('Math.imul', function () { return Math.imul(2, 3) === 6; });
  chk('Math.log10', function () { return Math.log10(100) === 2; });
  chk('Math.log2', function () { return Math.log2(8) === 3; });
  chk('Math.sign', function () { return Math.sign(-5) === -1; });
  chk('Math.trunc', function () { return Math.trunc(1.9) === 1; });
  chk('Math.hypot', function () { return Math.hypot(3, 4) === 5; });
  chk('Math.expm1', function () { return Math.expm1(0) === 0; });
  chk('Math.log1p', function () { return Math.log1p(0) === 0; });
  chk('Math.fround', function () { return Math.fround(1.337) === 1.3370000123977661; });
  chk('Math.acosh', function () { return Math.acosh(1) === 0; });
  chk('Math.asinh', function () { return Math.asinh(0) === 0; });
  chk('Math.atanh', function () { return Math.atanh(0) === 0; });
  chk('Math.cosh', function () { return Math.cosh(0) === 1; });
  chk('Math.sinh', function () { return Math.sinh(0) === 0; });
  chk('Math.tanh', function () { return Math.tanh(0) === 0; });

  chk('RegExp named groups', function () { return /(?<w>\w+)/.exec('hi').groups.w === 'hi'; });
  chk('RegExp lookbehind', function () { return /(?<=a)b/.exec('ab')[0] === 'b'; });
  chk('RegExp dotAll', function () { return /a.b/s.test('a\nb'); });
  chk('RegExp sticky', function () { var re = /a/y; return re.exec('a').index === 0; });
  chk('RegExp unicode', function () { return /\u{1F600}/u.test('\u{1F600}'); });
  chk('RegExp.prototype.matchAll', function () { return Array.from('a1a2'.matchAll(/a[0-9]/g)).length === 2; });
  chk('RegExp indices (d)', function () {
    var re = new RegExp('a', 'd');
    return re.exec('a').indices[0][0] === 0;
  });

  chk('Promise.all', function () { return Promise.all([1]).then === Promise.prototype.then; });
  chk('Promise.allSettled', function () { return typeof Promise.allSettled === 'function'; });
  chk('Promise.any', function () { return typeof Promise.any === 'function'; });
  chk('Promise.race', function () { return typeof Promise.race === 'function'; });
  chk('Promise.prototype.finally', function () { return typeof Promise.prototype.finally === 'function'; });
  chk('AggregateError', function () { return typeof AggregateError !== 'undefined'; });
  chk('Error.cause', function () { return new Error('x', {cause: 1}).cause === 1; });

  chk('TypedArray Int8', function () { return new Int8Array(2).length === 2; });
  chk('TypedArray Uint8', function () { return new Uint8Array(2).length === 2; });
  chk('TypedArray Uint8Clamped', function () { return new Uint8ClampedArray(2).length === 2; });
  chk('TypedArray Int16', function () { return new Int16Array(2).length === 2; });
  chk('TypedArray Uint16', function () { return new Uint16Array(2).length === 2; });
  chk('TypedArray Int32', function () { return new Int32Array(2).length === 2; });
  chk('TypedArray Uint32', function () { return new Uint32Array(2).length === 2; });
  chk('TypedArray Float32', function () { return new Float32Array(2).length === 2; });
  chk('TypedArray Float64', function () { return new Float64Array(2).length === 2; });
  chk('TypedArray BigInt64', function () { return typeof BigInt64Array !== 'undefined' && new BigInt64Array(2).length === 2; });
  chk('TypedArray BigUint64', function () { return typeof BigUint64Array !== 'undefined' && new BigUint64Array(2).length === 2; });
  chk('ArrayBuffer', function () { return new ArrayBuffer(8).byteLength === 8; });
  chk('DataView', function () { var dv = new DataView(new ArrayBuffer(4)); dv.setUint32(0, 1); return dv.getUint32(0) === 1; });
  chk('SharedArrayBuffer', function () { return typeof SharedArrayBuffer !== 'undefined'; });

  chk('BigInt literal', function () { return 10n + 1n === 11n; });
  chk('BigInt.asIntN', function () { return BigInt.asIntN(8, 300n) === 44n; });
  chk('BigInt.asUintN', function () { return BigInt.asUintN(8, 300n) === 44n; });
  chk('Symbol.iterator', function () { return typeof Symbol.iterator === 'symbol'; });
  chk('Symbol.asyncIterator', function () { return typeof Symbol.asyncIterator === 'symbol'; });
  chk('Symbol.matchAll', function () { return typeof Symbol.matchAll === 'symbol'; });
  chk('Symbol.hasInstance', function () { return typeof Symbol.hasInstance === 'symbol'; });
  chk('Symbol.toPrimitive', function () { return typeof Symbol.toPrimitive === 'symbol'; });
  chk('Symbol.toStringTag', function () { return typeof Symbol.toStringTag === 'symbol'; });
  chk('Symbol.species', function () { return typeof Symbol.species === 'symbol'; });

  chk('Proxy basic', function () { var p = new Proxy({a: 1}, {get: function (t, k) { return k === 'a' ? 42 : t[k]; }}); return p.a === 42; });
  chk('Proxy revocable', function () { var r = Proxy.revocable({}, {}); r.revoke(); try { r.proxy.a; return false; } catch (e) { return true; } });
  chk('Reflect.get', function () { return Reflect.get({a: 1}, 'a') === 1; });
  chk('Reflect.set', function () { var o = {}; return Reflect.set(o, 'a', 1) && o.a === 1; });
  chk('Reflect.has', function () { return Reflect.has({a: 1}, 'a'); });
  chk('Reflect.ownKeys', function () { return Reflect.ownKeys({a: 1}).length === 1; });
  chk('Reflect.defineProperty', function () { var o = {}; return Reflect.defineProperty(o, 'a', {value: 1}) && o.a === 1; });
  chk('Reflect.deleteProperty', function () { var o = {a: 1}; return Reflect.deleteProperty(o, 'a') && !('a' in o); });
  chk('Reflect.getPrototypeOf', function () { return Reflect.getPrototypeOf({}) === Object.prototype; });

  chk('Map basic', function () { var m = new Map([[1, 'a']]); return m.size === 1 && m.get(1) === 'a'; });
  chk('Set basic', function () { var s = new Set([1, 1, 2]); return s.size === 2 && s.has(1); });
  chk('WeakMap basic', function () { var k = {}; var wm = new WeakMap(); wm.set(k, 1); return wm.get(k) === 1 && wm.has(k); });
  chk('WeakSet basic', function () { var k = {}; var ws = new WeakSet(); ws.add(k); return ws.has(k); });
  chk('WeakRef', function () { return typeof WeakRef !== 'undefined'; });
  chk('FinalizationRegistry', function () { return typeof FinalizationRegistry !== 'undefined'; });
  chk('Set.union', function () { return typeof Set.prototype.union === 'function'; });
  chk('Set.intersection', function () { return typeof Set.prototype.intersection === 'function'; });
  chk('Set.difference', function () { return typeof Set.prototype.difference === 'function'; });
  chk('Set.symmetricDifference', function () { return typeof Set.prototype.symmetricDifference === 'function'; });
  chk('Set.isSubsetOf', function () { return typeof Set.prototype.isSubsetOf === 'function'; });
  chk('Set.isSupersetOf', function () { return typeof Set.prototype.isSupersetOf === 'function'; });
  chk('Set.isDisjointFrom', function () { return typeof Set.prototype.isDisjointFrom === 'function'; });

  chk('Object.getPrototypeOf', function () { return Object.getPrototypeOf([]) === Array.prototype; });
  chk('Object.setPrototypeOf', function () { var o = {}; Object.setPrototypeOf(o, {p: 1}); return o.p === 1; });
  chk('JSON.stringify BigInt throws', function () { try { JSON.stringify(1n); return false; } catch (e) { return true; } });
  chk('for-of over string', function () { var n = 0; for (var ch of 'ab') { n++; } return n === 2; });
  chk('WeakMap caveat check', function () {
    // goja 已知坑：key 存活期间 value 无法回收；这里只验证行为可用的最小用例
    var k = {}; var wm = new WeakMap(); wm.set(k, {x: 1}); return wm.get(k).x === 1;
  });

  // ---- 数值精度与 intSet 大整数 ----
  var I = {};
  I.maxSafe = Number.MAX_SAFE_INTEGER === 9007199254740991;
  I.intNoOverflow = 2147483647 + 1 === 2147483648;
  I.twoPow40 = Math.pow(2, 40) === 1099511627776;
  I.intSetBig = false;
  I.intSetTimestamp = false;
  try {
    var eps = seal.getEndPoints();
    if (eps && eps.length > 0) {
      var ep0 = eps[0];
      var m0 = seal.newMessage();
      m0.messageType = 'group';
      m0.groupId = 'goja-probe';
      var ctx0 = seal.createTempCtx(ep0, m0);
      seal.vars.intSet(ctx0, '$t_test_goja_big', 9007199254740991);
      var got = seal.vars.intGet(ctx0, '$t_test_goja_big');
      I.intSetBig = got[0] === 9007199254740991;
      var ts = Date.now();
      seal.vars.intSet(ctx0, '$t_test_goja_ts', ts);
      var g2 = seal.vars.intGet(ctx0, '$t_test_goja_ts');
      I.intSetTimestamp = g2[0] === ts && ts > 1e12;
    }
  } catch (e) { /* 无端点等环境差异时跳过 */ }
  R.int = I;

  R.builtins = B;
  R.version = seal && seal.getVersion ? seal.getVersion() : null;
  return R;
