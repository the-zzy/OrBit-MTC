// JS 语法 + eval 检查：node js_syntax_check.js <串文件> [--out option_eval.json]
//
// 判据：
//   ① 整段能 eval（= 平台 eval 不报语法错）
//   ② eval 后是 object，且有 series 或 graphic.elements
//   ③ **按图形类型**判必需顶层键：
//      pie / funnel / gauge 本就不用直角坐标系 ⇒ 不要求 grid / xAxis / yAxis
//      其余（line / bar / 自绘等）才要求 grid + xAxis + yAxis
//
// 两种返回形态：
//   明文  `option = {...};`      ⇒ new Function(src + ';return option;')
//   装载  `(function(){...})();` ⇒ eval(src) 直接取 IIFE 返回值（解码器本身被验证）
//
// ⚠️ 输入只允许是自己交付件取回的串。eval 是为等同平台行为，不要拿外部文件跑。
const fs = require('fs');
const p = process.argv[2];
if (!p) { console.log('ERR 缺少参数'); process.exit(1); }
const outIdx = process.argv.indexOf('--out');
const outPath = outIdx > 0 ? process.argv[outIdx + 1] : null;
const src = fs.readFileSync(p, 'utf8').trim();

const isPack = /var B=19968/.test(src) || /^\(function/.test(src);

try {
  let opt;
  if (isPack) {
    opt = eval(src);
  } else {
    opt = new Function(src + '\n;return option;')();
  }
  if (!opt || typeof opt !== 'object') { console.log('ERR eval 结果不是对象：' + typeof opt); process.exit(1); }

  const series = [].concat(opt.series || []);
  const gElements = (opt.graphic && opt.graphic.elements) || [];
  if (!series.length && !gElements.length) { console.log('ERR 没有 series 也没有 graphic'); process.exit(1); }

  if (outPath) fs.writeFileSync(outPath, JSON.stringify(opt), 'utf8');

  const tag = isPack ? ' [装载]' : '';
  const tail = outPath ? ' → ' + outPath : '';

  // 纯 graphic 选项（楼宇剖面 / 整体概览卡等自绘，无 series）—— 不要求直角坐标系
  if (!series.length) {
    console.log('OK' + tag + ' keys=' + Object.keys(opt).join(',') +
                ' graphic=' + gElements.length + ' 个元素（纯 graphic，无 series）' + tail);
    process.exit(0);
  }

  // 不含直角坐标系的图形类型
  const NO_CARTESIAN = new Set(['pie', 'funnel', 'gauge', 'graph', 'treemap', 'sunburst']);
  const needAxis = series.some(s => !NO_CARTESIAN.has(s && s.type));
  const required = needAxis ? ['series', 'grid', 'xAxis', 'yAxis'] : ['series'];
  const missing = required.filter(k => !opt[k]);
  if (missing.length) { console.log('ERR 缺少顶层键：' + missing.join(',')); process.exit(1); }

  const kinds = [...new Set(series.map(s => s && s.type))].join('/');
  console.log('OK' + tag + ' keys=' + Object.keys(opt).join(',') +
              ' series=' + series.length + '(' + kinds + ')' +
              ' grid=' + [].concat(opt.grid).filter(Boolean).length + tail);
} catch (e) {
  console.log('ERR ' + e.name + ': ' + e.message);
  process.exit(1);
}
