# -*- coding: utf-8 -*-
"""把 sqlcmd 分块输出拼回一段完整返回串。

唯一分块协议：`M|000001|<200 字符块>#`，块内容是 base64。
过程侧靠 `@Chunked = 1` 输出（见 workflow_pack.md §3、workflow_layout.md §8.1）。

用法：python extract_option.py <raw_out.txt> <option_out.txt>

兼容：找不到 `M|` 块时，退回旧的 `序号|明文块` 格式并提示。
"""
import base64
import binascii
import re
import sys

M_RE = re.compile(r'^M\|(\d{6})\|(.*?)#\s*$')
OLD_RE = re.compile(r'^(\d+)\|(.*)$')


def extract(raw_path, out_path):
    lines = open(raw_path, encoding='utf-8', errors='replace').read().split('\n')

    chunks, mode = {}, None
    for ln in lines:
        m = M_RE.match(ln)
        if m:
            mode = 'M'
            chunks[int(m.group(1))] = m.group(2)
            continue
        if mode is None:
            m = OLD_RE.match(ln)
            if m:
                mode = 'old'
                chunks[int(m.group(1))] = m.group(2)

    if not chunks:
        raise SystemExit('没有解析到任何分块，确认 raw_out.txt 里有 M|序号| 段')

    seq = sorted(chunks)
    gaps = [i for i in range(1, seq[-1] + 1) if i not in chunks]
    if gaps:
        raise SystemExit(f'缺块 {gaps}，不要拼，重取一次')

    joined = ''.join(chunks[i] for i in seq)

    if mode == 'M':
        try:
            data = base64.b64decode(joined, validate=True)
        except (binascii.Error, ValueError) as e:
            raise SystemExit(f'base64 解码失败：{e}；块数 {len(chunks)}，字符 {len(joined)}')
        s = data.decode('utf-8')
    else:
        s = joined
        print('⚠️ 使用旧格式（明文块），建议改用 M| 分块')

    open(out_path, 'w', encoding='utf-8', newline='\n').write(s)

    head = s[:14].replace('\n', '\\n')
    tail = s[-8:].replace('\n', '\\n')
    form = '装载' if s.lstrip().startswith('(function') or 'var B=19968' in s else '明文'
    print(f'块 {len(chunks)} 个｜拼回 {len(s)} 字符｜形态 {form}')
    print(f'首 {head!r}｜尾 {tail!r}')
    if not (s.startswith('option = {') or s.lstrip().startswith('(function')):
        print('⚠️ 首部既不是 option = { 也不是 (function，确认取串是否取错')
    if len(s) < 200:
        print('⚠️ 长度 < 200，大概率拿到的是提示串')
    return s


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    extract(sys.argv[1], sys.argv[2])
