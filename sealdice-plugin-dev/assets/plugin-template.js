// ==UserScript==
// @name 插件名（必填）
// @author 作者名（必填）
// @version 1.0.0
// @description 插件功能描述
// @timestamp 2026-06-05
// @license MIT
// @homepageURL https://github.com/yourname/your-plugin
// @sealVersion 1.4.5
// @depends OtherAuthor:OtherPlugin:>=1.0.0
// ==/UserScript==

// seal.d.ts 位于本技能 references/ 目录；把本文件复制到你的项目后，
// 若把 seal.d.ts 放在同一目录，可将下面这行改为 ./seal.d.ts
/// <reference path="../references/seal.d.ts" />

// ============= 1. 创建 / 复用扩展 =============
// 用 find 拿到已注册的同名扩展（热重载场景），否则新建
let ext = seal.ext.find('your_ext_name');
if (!ext) {
  ext = seal.ext.new('your_ext_name', '作者名', '1.0.0');
  seal.ext.register(ext);
}

// ============= 2. 注册配置项（可选） =============
// 这些会出现在 WebUI 该扩展的「配置」面板里
seal.ext.registerStringConfig(ext, 'tip', '今日运势仅供娱乐', '尾部提示语');
seal.ext.registerIntConfig(ext, 'cooldown', 60, '冷却秒数');
seal.ext.registerBoolConfig(ext, 'enableLog', true, '是否记录日志');
seal.ext.registerOptionConfig(ext, 'mode', 'normal', ['normal', 'hard', 'easy'], '难度');
seal.ext.registerTemplateConfig(ext, 'replies', ['你好', '在', '怎么了'], '随机回复列表');

// ============= 3. 创建指令 =============
const cmdFortune = seal.ext.newCmdItemInfo();
cmdFortune.name = 'fortune';
cmdFortune.help = `.fortune          抽今日运势
.fortune help     显示帮助`;
cmdFortune.allowDelegate = true;       // 允许 .fortune @某人 代骰
cmdFortune.disabledInPrivate = false;  // 私聊也可用

cmdFortune.solve = (ctx, msg, cmdArgs) => {
  // 子指令分发
  const sub = cmdArgs.getArgN(1);
  if (sub === 'help') {
    const ret = seal.ext.newCmdExecuteResult(true);
    ret.showHelp = true;            // 让海豹自动展示 cmd.help
    return ret;
  }

  // 代骰：把上下文换到被 @ 的人
  const targetCtx = seal.getCtxProxyFirst(ctx, cmdArgs);

  const luck = ['大吉','吉','小吉','末吉','凶','大凶'][Math.floor(Math.random() * 6)];
  const tip  = seal.ext.getStringConfig(ext, 'tip');

  seal.replyToSender(ctx, msg, `${targetCtx.player.name} 今日运势：${luck}\n${tip}`);
  return seal.ext.newCmdExecuteResult(true);
};

ext.cmdMap['fortune'] = cmdFortune;
ext.cmdMap['运势']    = cmdFortune;   // 中英别名指向同一个对象

// ============= 4. 事件钩子 =============
ext.onLoad = () => {
  console.log(`[${ext.name}] loaded v${ext.version}`);
};

ext.onMessageReceived = (ctx, msg) => {
  // 收到任意消息（包括非指令）。注意性能！
};

ext.onNotCommandReceived = (ctx, msg) => {
  // 非指令消息触发，做关键词回复神器
  if (msg.message.includes('在吗')) {
    seal.replyToSender(ctx, msg, '在的');
  }
};

// ============= 5. 持久化（扩展级 KV） =============
// ext.storageSet('lastDraw_' + ctx.player.userId, String(Date.now()));
// const t = ext.storageGet('lastDraw_' + ctx.player.userId);

// ============= 6. 定时任务 =============
seal.ext.registerTask(ext, 'daily', '08:30', () => {
  console.log('每日 8:30 触发');
}, 'morning_greet', '每日问候');

// 或 cron（5 位）
seal.ext.registerTask(ext, 'cron', '*/30 * * * *', () => {
  console.log('每 30 分钟一次');
}, 'half_hour_tick');
