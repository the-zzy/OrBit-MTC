# -*- coding: utf-8 -*-
"""把返回的 option 原文生成 ECharts 渲染验证页（默认 v4.9.0 本地文件）。

用法：
  python gen_render_page.py <option.txt> <out.html> [--echarts echarts4.min.js] [--title 标题]

页面内容：顶部状态栏（✅/❌ + 原因）、键数统计、多尺寸渲染、返回原文、报错堆栈。
无头验证：chrome --headless=new --disable-gpu --window-size=1500,1150 \
          --virtual-time-budget=5000 --screenshot=<绝对路径>.png file:///<绝对路径>.html
"""
import json
import os
import sys

TPL = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>__TITLE__</title>
<style>
  *{box-sizing:border-box}
  body{margin:0;padding:0 0 40px;background:#0a1220;color:#e8eefc;
       font-family:"Microsoft YaHei","PingFang SC",Arial,sans-serif}
  #status{position:sticky;top:0;z-index:9;padding:12px 16px;font-size:15px;font-weight:bold;
          background:#12351f;color:#7ef2a8;border-bottom:1px solid #1e4b32}
  #status.bad{background:#3a1414;color:#ff9d9d;border-bottom-color:#5e2020}
  .wrap{display:flex;flex-wrap:wrap;gap:16px;padding:16px;align-items:flex-start}
  .card{background:#0f1b2e;border:1px solid #1d2b42;border-radius:8px;padding:10px}
  .cap{font-size:12px;color:#7d8ba1;padding:2px 4px 8px}
  .chart{background:#111c30;border-radius:6px}
  .meta{padding:8px 16px 0;font-size:13px;color:#9fb0c8;line-height:2}
  .meta b{color:#fff}
  .meta code{background:#16233b;padding:1px 6px;border-radius:4px;color:#22d3ee}
  pre{margin:12px 16px;padding:12px;background:#08101d;border:1px solid #1d2b42;border-radius:8px;
      color:#9fb0c8;font-size:12px;line-height:1.8;white-space:pre-wrap;word-break:break-all;
      max-height:300px;overflow:auto}
  h3{font-size:14px;color:#9fb0c8;margin:22px 16px 0;font-weight:normal}
  #dbg:empty{display:none}
</style>
</head>
<body>
<div id="status">检测中……</div>
<div class="meta" id="meta"></div>
<pre id="dbg" style="color:#ffd479"></pre>
<div class="wrap" id="wrap"></div>
<h3>过程实际返回的原文（未加工，直接 eval）</h3>
<pre id="raw"></pre>
<script src="__ECHARTS__"></script>
<script>
var RAW = __RAW__;
var statusEl=document.getElementById('status'),metaEl=document.getElementById('meta'),dbgEl=document.getElementById('dbg');
document.getElementById('raw').textContent=RAW;
function fail(m,x){statusEl.className='bad';statusEl.textContent='❌ '+m;dbgEl.textContent+=(x||'')+'\n';console.error('[FAIL]',m,x||'');}
window.onerror=function(m,s,l,c){fail(m,'位置 '+s+':'+l+':'+c);};
(function(){
  if(typeof echarts==='undefined'){fail('echarts 未加载');return;}
  var option;
  try{ option=eval(RAW); }catch(e){ fail('eval 失败：'+e.name+': '+e.message, e.stack||''); return; }
  if(!option||typeof option!=='object'){fail('eval 结果不是对象：'+typeof option);return;}
  var keys=Object.keys(option);
  metaEl.innerHTML='ECharts <b>'+echarts.version+'</b>　|　返回串 <b>'+RAW.length+'</b> 字符　|　首 <code>'+
    RAW.slice(0,12)+'</code>　尾 <code>'+RAW.slice(-4)+'</code><br>顶层键 <code>'+keys.join(', ')+'</code>　|　'+
    'series <b>'+[].concat(option.series||[]).length+'</b>　grid <b>'+[].concat(option.grid||[]).length+'</b>';
  var SIZES = __SIZES__;
  var wrap = document.getElementById('wrap'), ids = [];
  SIZES.forEach(function(sz, i){
    var id = 'c' + i;
    ids.push(id);
    var card = document.createElement('div'); card.className = 'card';
    var cap = document.createElement('div'); cap.className = 'cap';
    cap.textContent = sz[0] + ' × ' + sz[1] + (sz[2] ? '  ' + sz[2] : '');
    var box = document.createElement('div'); box.className = 'chart'; box.id = id;
    box.style.width = sz[0] + 'px'; box.style.height = sz[1] + 'px';
    card.appendChild(cap); card.appendChild(box); wrap.appendChild(card);
  });
  var ok=0;
  ids.forEach(function(id){
    var dom=document.getElementById(id);
    try{
      var ch=echarts.init(dom,null,{renderer:'canvas'});
      ch.setOption(option);
      if(!dom.querySelector('canvas')){fail(id+' 未生成 canvas（静默失败）');return;}
      ok++;
    }catch(e){ fail('渲染 '+id+' 失败：'+e.name+': '+e.message, e.stack||''); }
  });
  if(ok===ids.length){statusEl.className='';statusEl.textContent='✅ 通过 —— eval 无异常，ECharts '+echarts.version+' 下 '+ids.length+' 个尺寸全部出图';}
  else{fail('仅 '+ok+'/'+ids.length+' 个尺寸渲染成功');}
})();
</script>
</body>
</html>
'''


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    opt_path, out_html = sys.argv[1], sys.argv[2]
    echarts, title = 'echarts4.min.js', '看板 option 渲染验证'
    sizes = [[320, 159, '图位真实尺寸'], [320, 330, ''], [420, 430, ''], [640, 430, '']]
    args = sys.argv[3:]
    for i in range(0, len(args) - 1, 2):
        if args[i] == '--echarts':
            echarts = args[i + 1]
        elif args[i] == '--title':
            title = args[i + 1]
        elif args[i] == '--sizes':
            sizes = [[int(x.split('x')[0]), int(x.split('x')[1]), ''] for x in args[i + 1].split(',')]
    # echarts 引用按 HTML 所在目录算相对路径
    rel = os.path.relpath(
        os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(opt_path))), 'preview', echarts),
        os.path.dirname(os.path.abspath(out_html))) if os.path.basename(echarts) == echarts else echarts
    opt = open(opt_path, encoding='utf-8').read()
    html = (TPL.replace('__TITLE__', title)
               .replace('__ECHARTS__', rel.replace('\\', '/'))
               .replace('__RAW__', json.dumps(opt, ensure_ascii=False))
               .replace('__SIZES__', json.dumps(sizes, ensure_ascii=False)))
    open(out_html, 'w', encoding='utf-8', newline='\n').write(html)
    print(f'已生成 {out_html}（{os.path.getsize(out_html)} bytes），引用 echarts：{rel}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
