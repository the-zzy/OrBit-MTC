# -*- coding: utf-8 -*-
"""看板 ECharts 存储过程 · 静态规则 / 运行时规则检查器

用法：
  python check_proc.py static  <proc.sql> [more.sql ...]
  python check_proc.py runtime <option.txt>

退出码：0 全 PASS / 1 存在 FAIL
"""
import re
import subprocess
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def read_text(path):
    with open(path, 'rb') as f:
        raw = f.read()
    if raw.startswith(b'\xef\xbb\xbf'):
        raw = raw[3:]
    return raw.decode('utf-8', errors='replace')


def strip_comments(s):
    """去掉 -- 行注释与 /* */ 块注释（保留字符串字面量里的内容不做特殊处理）。"""
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    out = []
    for ln in s.splitlines():
        p = ln.find('--')
        out.append(ln if p < 0 else ln[:p])
    return '\n'.join(out)


def option_block(code):
    """取出 `SET/DECLARE @变量 = N'option = {` 拼装段（到 N'};' 那行为止）。

    ⚠️ 别写死 `SET @Option =`：
       · 趋势类过程是 `SET @Option = N'option = {...' + ...`；
       · 预警信息列表是 `DECLARE @Option nvarchar(max) = N'option = {' + @G + N'}';`
         （@G 是逐行 graphic 数组，真正的外壳在 DECLARE 那行之后）。
    ⇒ 按「有 @变量 赋值 + 其后 6 行内出现 N'option = {」识别起点。
    """
    lines = code.splitlines()
    start = None
    for i, ln in enumerate(lines):
        if start is None and re.search(r'\b(?:SET|DECLARE)\s+@\w+[^=]*=', ln):
            window = '\n'.join(lines[i:i + 6])
            if "N'option = {" in window:
                start = i
        elif start is not None and "N'};'" in ln:
            return '\n'.join(lines[start:i + 1]), start + 1, i + 1
    if start is not None:
        return '\n'.join(lines[start:]), start + 1, len(lines)
    return '', 0, 0


def form_of(code):
    """判返回形态：pack = 14bit 汉字装载；plain = 明文 option 拼串。

    平台只看 value 能否 eval，两形态都合法，但静态判据不同：
      plain  首 option = {  尾 };       裸键、禁函数
      pack   首 (function     尾 })();  自带 var B=19968 拆包 + LZ 解码
    """
    if 'var B=19968' in code:
        return 'pack'
    if "N'option = {" in code:
        return 'plain'
    if 'atob' in code:
        return 'legacy'
    return 'unknown'


def static(path):
    raw = read_text(path)
    code = strip_comments(raw)
    form = form_of(code)
    block, b0, b1 = option_block(code)
    rows = []

    def add(rule, ok, detail):
        rows.append((rule, 'PASS' if ok else 'FAIL', detail))

    # R1 列名 value
    n_alias = len(re.findall(r'\bAS\s+value\b', code, re.I))
    add('R1 列名=value', n_alias >= 1, f'AS value ×{n_alias}')

    if form == 'plain':
        # ---- 明文形态专用 ----
        # R2/R3 前缀与结尾
        has_prefix = "N'option = {'" in block or 'N\'option = {\'' in block
        add('R2 前缀 option = {', has_prefix, '拼装段首行' if has_prefix else '未找到 N\'option = {\'')
        has_tail = "N'};'" in block
        add('R3 结尾 };', has_tail, "N'};'" if has_tail else "未找到 N'};'")

        # R4 裸键：拼装段里出现 "标识符": 即违规
        bad_keys = []
        for ln in block.splitlines():
            for m in re.finditer(r'"([A-Za-z_][A-Za-z0-9_]*)"\s*:', ln):
                bad_keys.append(m.group(1))
        add('R4 裸键（无引号）', not bad_keys,
            '0 处' if not bad_keys else f'{len(bad_keys)} 处，例：{", ".join(bad_keys[:6])}')

        # R5 禁 media
        media = re.findall(r'["\']?media["\']?\s*:', block)
        add('R5 无 media', not media, '0 处' if not media else f'{len(media)} 处（v4 会整块不渲染）')

        # R6 graphic 百分比
        g = re.findall(r"graphic", block) and re.findall(r"'100%'|\"100%\"", block)
        add('R6 无 graphic 百分比', not g, '0 处' if not g else 'graphic + 100% 组合（v4 不支持）')

        # R7 函数（装载形态整体就是 IIFE，不判此条）
        fn = re.findall(r'\bfunction\b|=>', block)
        add('R7 无函数', not fn, '0 处' if not fn else f'{len(fn)} 处')
    elif form == 'pack':
        # ---- 装载形态专用 ----
        p1 = bool(re.search(r'SELECT\s+@\w+\s+AS\s+value', code, re.I))
        add('P1 返回 @js AS value', p1, '有' if p1 else '未找到 SELECT @js AS value')

        n_b = code.count('var B=19968')
        dec_ok = n_b == 1 and 'bits+=14' in code and 'Math.floor' in code
        add('P2 解码器', dec_ok, f'var B=19968 ×{n_b}；bits+=14={"bits+=14" in code}；Math.floor={"Math.floor" in code}')

        add('P3 无 atob', 'atob' not in raw, '全文 0 处 atob' if 'atob' not in raw else '存在 atob（旧 base64 形态）')

        runs = re.findall(r'[\u4e00-\u8dff]{20,}', raw)
        big = max(runs, key=len) if runs else ''
        add('P4 装载字面量', len(big) >= 200, f'最长汉字段 {len(big)} 字符')

        p5 = '})();' in code
        add('P5 收尾 })();', p5, '有' if p5 else '未找到 })();')

        p6 = bool(re.search(r"DECLARE\s+@\w+\s+NVARCHAR\(MAX\)\s*=\s*CAST\(\s*N'", code, re.I))
        add('P6 首段 CAST', p6, 'DECLARE … = CAST(N\'…\'' if p6 else '装载串未以 CAST(N\'…\' 开头')
    elif form == 'legacy':
        add('形态 legacy(base64)', False,
            '旧的 atob + base64 内联形态，重做为 14bit 装载（var B=19968、无 atob）')
    else:
        add('形态', False, "未识别：既无 N'option = {' 也无 var B=19968")


    # R8 显式事务
    tx = re.findall(r'\b(BEGIN\s+TRAN|COMMIT\s+TRAN|ROLLBACK\s+TRAN|COMMIT\b|ROLLBACK\b)', code, re.I)
    add('R8 无显式事务', not tx, '0 处' if not tx else f'{len(tx)} 处：{sorted(set(x.upper() for x in tx))}')

    # R9 TRY/CATCH + RETURN
    try_ok = bool(re.search(r'BEGIN\s+TRY', code)) and bool(re.search(r'END\s+CATCH', code))
    ret0 = bool(re.search(r'RETURN\s+0\b', code))
    retm = bool(re.search(r'RETURN\s+-1\b', code))
    add('R9 TRY/CATCH+RETURN', try_ok and ret0 and retm,
        f'TRY={try_ok} CATCH={try_ok} RETURN0={ret0} RETURN-1={retm}')

    # R10 ServerMessage
    sm = len(re.findall(r'ServerMessage:', code))
    add('R10 ServerMessage:', sm >= 2, f'{sm} 处')

    # R11 series 索引不越界（启发式）
    Q = r'["\']?'
    y_cnt = len(re.findall(Q + r'type' + Q + r'\s*:\s*' + Q + r'value' + Q, block))
    x_cnt = len(re.findall(Q + r'type' + Q + r'\s*:\s*' + Q + r'category' + Q, block))
    y_idx = [int(v) for v in re.findall(Q + r'yAxisIndex' + Q + r'\s*:\s*(\d+)', block)]
    x_idx = [int(v) for v in re.findall(Q + r'xAxisIndex' + Q + r'\s*:\s*(\d+)', block)]
    ok11 = (not y_idx or max(y_idx) < max(y_cnt, 1)) and (not x_idx or max(x_idx) < max(x_cnt, 1))
    add('R11 轴索引不越界', ok11,
        f'yAxis {y_cnt} 条 / 用到 {sorted(set(y_idx)) or "-"}；xAxis {x_cnt} 条 / 用到 {sorted(set(x_idx)) or "-"}')

    # R12 可重复执行：两种写法都合法
    #   ① IF OBJECT_ID(...) IS NOT NULL → DROP PROCEDURE ; CREATE
    #   ② IF OBJECT_ID(...) IS NULL     → EXEC(N'CREATE ... 空壳') ; ALTER PROCEDURE
    guard_drop = bool(re.search(
        r"IF\s+OBJECT_ID\([^)]*\)\s+IS\s+NOT\s+NULL[\s\S]{0,160}?DROP\s+PROCEDURE", code, re.I))
    guard_shell = bool(re.search(
        r"IF\s+OBJECT_ID\([^)]*\)\s+IS\s+NULL[\s\S]{0,240}?CREATE\s+PROCEDURE", code, re.I))
    add('R12 可重复执行(守卫)',
        guard_drop or guard_shell,
        '空壳+ALTER' if guard_shell else ('DROP+CREATE' if guard_drop else '缺 IF OBJECT_ID 守卫（重复部署报 2714）'))
    # 本库过程规范禁用 DROP+CREATE（丢权限与依赖，stored-procedure-rules §6）
    add('R12b 禁 DROP+CREATE', not guard_drop,
        '0 处' if not guard_drop else '存在 DROP+CREATE ⇒ 改「IF OBJECT_ID IS NULL 空壳 + ALTER」')

    # R13 哨兵值：温度 / 湿度**各自**都要排除 -999
    #   ⚠️⚠️ 2026-10-19 正式库实测踩过：只给 temperature 加了 `T > -900`、湿度那支没加
    #      ⇒ 列表里蹦出一条「湿度 -999%」红条（TH40W-EX 停报，末条温湿度都是 -999）。
    #   同表同哨兵、两个指标必须成对写，所以拆成 R13a / R13b 两条判。
    #   写法两种都算：`T > -900`（区间判断）与 `TRY_CONVERT(..., temperature) <> -999`（精确剔除）
    #   ⇒ 标识符与运算符之间只允许右括号/空格，避免跨到别的指标上造成假 PASS
    #   ⚠️ 2026-10-19 补两处漏判：
    #      ① 哨兵值写在**右操作数**侧也算（`-999 = s.T`）；
    #      ② `TRY_CONVERT(..., 'temperature') <> -999` 中间夹着字符串收尾 `'` + `))`，
    #         首版只允许右括号 ⇒ THPointMatrix 的精确剔除写法被误判成「没过滤」。
    #         右括号与引号现在**任意交错**都吃。
    PT = r"\bT\b|\btemperature\b(?:[\'\"])?(?:\)*)"
    PH = r"\bH(?:u|umidity)?\b|\bhumidity\b(?:[\'\"])?(?:\)*)"
    OP = r'\s*(?:<=|<|>=|>|<>|!=)\s*'
    reads_temp = bool(re.search(r'\btemperature\b', code, re.I))
    reads_humi = bool(re.search(r'\bhumidity\b', code, re.I))
    guard_t = re.search(PT + OP + r'-\s*(?:900|999)', code, re.I) \
        or re.search(r'-\s*(?:900|999)' + OP + PT, code, re.I)
    guard_h = re.search(PH + OP + r'-\s*(?:900|999)', code, re.I) \
        or re.search(r'-\s*(?:900|999)' + OP + PH, code, re.I)
    add('R13a 温度哨兵', (not reads_temp) or bool(guard_t),
        ('不读温度' if not reads_temp else
         ('有' if guard_t else '读了 temperature 但没排除 -999（无读数哨兵会拉垮 y 轴）')))
    add('R13b 湿度哨兵', (not reads_humi) or bool(guard_h),
        ('不读湿度' if not reads_humi else
         ('有' if guard_h else '读了 humidity 但没排除 -999 —— 温度有过滤不算，湿度要单独写（如 Hu > -900）')))

    return dict(path=path, rows=rows, block_lines=(b0, b1))


def runtime(path):
    s = read_text(path).strip()
    rows = []

    def add(rule, ok, detail):
        rows.append((rule, 'PASS' if ok else 'FAIL', detail))

    add('V1 首', s.startswith('option = {') or s.startswith('(function'),
        repr(s[:14]))
    tail_ok = s.rstrip().endswith('};') or s.rstrip().endswith('})();')
    add('V1 尾', tail_ok, repr(s[-8:]))
    if s.startswith('(function'):
        add('V2/V3 裸键+media', True, '装载形态：由 eval 后判，见 js_syntax_check')
    else:
        quoted = re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)"\s*:', s)
        add('V2 裸键 0 处带引号', not quoted, '0 处' if not quoted else f'{len(quoted)} 处')
        add('V3 无 media', 'media' not in s, '无' if 'media' not in s else '含 media')

    js = os.path.join(HERE, 'js_syntax_check.js')
    if os.path.exists(js):
        r = subprocess.run(['node', js, path], capture_output=True, text=True, encoding='utf-8', errors='replace')
        out = (r.stdout or '').strip()
        add('V4 JS 语法', out.startswith('OK'), out.splitlines()[0] if out else (r.stderr or 'node 无输出'))
    else:
        add('V4 JS 语法', False, '找不到 js_syntax_check.js')

    add('V5 长度', len(s) > 200, f'{len(s)} 字符')
    return dict(path=path, rows=rows)


def print_table(res):
    print(f'\n=== {os.path.basename(res["path"])} ===' + (
        f'  拼装段 行 {res["block_lines"][0]}~{res["block_lines"][1]}' if 'block_lines' in res else ''))
    w = max(len(r[0]) for r in res['rows'])
    bad = 0
    for rule, st, detail in res['rows']:
        if st != 'PASS':
            bad += 1
        print(f'  {st:4}  {rule.ljust(w)}  {detail}')
    print(f'  ---- {"全部通过" if bad == 0 else str(bad) + " 项不通过"}')
    return bad


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    mode, files = sys.argv[1], sys.argv[2:]
    total_fail = 0
    for p in files:
        if not os.path.exists(p):
            print(f'文件不存在：{p}')
            total_fail += 1
            continue
        res = static(p) if mode == 'static' else runtime(p)
        total_fail += print_table(res)
    return 1 if total_fail else 0


if __name__ == '__main__':
    sys.exit(main())
