# -*- coding: utf-8 -*-
"""看板过程 option 拼装段 · 一键修正两个致命格式问题。

做的两件事：
  1) 去掉属性名双引号：`"backgroundColor":` → `backgroundColor:`
     （只动拼装段内、且只动「标识符 + 冒号」形态；字符串值不受影响）
  2) 删掉平铺 option 上的 `media` 段（ECharts 要求 baseOption 结构，否则 v4 整块不渲染）
     同时把它前面的注释、以及上一行结尾多余逗号一并收拾干净。

用法：
  python fix_format.py <proc.sql> [--dry-run]

退出码：0 已修改 / 1 无需修改或出错
"""
import re
import sys


def read(p):
    raw = open(p, 'rb').read()
    bom = raw.startswith(b'\xef\xbb\xbf')
    s = raw.decode('utf-8-sig')
    return s, bom


def write(p, s, bom):
    data = s.encode('utf-8')
    if bom:
        data = b'\xef\xbb\xbf' + data
    open(p, 'wb').write(data)


def option_range(lines):
    start = tail = None
    for i, ln in enumerate(lines):
        if start is None and re.search(r'\bSET\s+@Option\s*=', ln):
            start = i
        elif start is not None and "N'};'" in ln:
            tail = i
            break
    return start, tail


def is_comment(ln):
    t = ln.strip()
    return t.startswith('/*') or t.startswith('*') or t.startswith('--') or t == ''


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    path = sys.argv[1]
    dry = '--dry-run' in sys.argv
    s, bom = read(path)
    lines = s.split('\n')
    start, tail = option_range(lines)
    if start is None or tail is None:
        print('✗ 找不到 SET @Option 拼装段或 N\'};\' 结尾')
        return 1

    changed = []

    # ---- 1) 去键名引号 ----
    n_key = 0
    pat = re.compile(r'"([A-Za-z_][A-Za-z0-9_]*)"(\s*):')
    for i in range(start, tail + 1):
        new, k = pat.subn(r'\1\2:', lines[i])
        if k:
            n_key += k
            lines[i] = new
    if n_key:
        changed.append(f'去键名引号 {n_key} 处')

    # ---- 2) 删 media 段 ----
    idx = None
    for i in range(start, tail + 1):
        if re.search(r'["\']?media["\']?\s*:', lines[i]):
            idx = i
            break
    if idx is not None:
        # 往上吃掉紧邻的注释行（空行也吃）
        first = idx
        j = idx - 1
        while j > start and is_comment(lines[j]):
            first = j
            j -= 1
        del lines[first:tail]
        # 上一行结尾多余的逗号（`...],' +` → `...]' +`）
        k = first - 1
        while k > start and is_comment(lines[k]):
            k -= 1
        m = re.search(r",(\s*'\s*\+\s*)$", lines[k])
        if m:
            lines[k] = lines[k][:m.start()] + m.group(1)
        changed.append('删除 media 段')

    if not changed:
        print('✓ 无需修改')
        return 1

    out = '\r\n'.join(ln.rstrip('\r') for ln in lines)
    if dry:
        print('（dry-run）将执行：' + '、'.join(changed))
        return 0
    write(path, out, bom)
    print('✓ ' + '、'.join(changed) + f' → {path}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
