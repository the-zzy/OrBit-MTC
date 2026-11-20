# -*- coding: utf-8 -*-
"""把明文 option 压成群内标准版同款装载块（14bit 汉字装载）。

用法：
  py scripts/pack_option.py <option.txt> [--sql out.sql] [--chunk 3900] [--verify-only]

做三件事：
  1. LZ 压缩（严格逆推库内解码器，非 zlib）
  2. 24 位长度头 + 每字节 8 位 → 按 14 位一段 → +19968 写成汉字
  3. 自检：拆包 → LZ 解码 → 与原文字节逐字节比对，不一致直接报错退出

输出 `DECLARE @b64 NVARCHAR(MAX) = CAST(N'…' AS NVARCHAR(MAX)) + N'…'` 片段，
替换进标准版过程（`dbo.WebAPI_THKanbanFlash`）的装载占位处。解码器与外壳不在本脚本里 ——
它们属于标准版，改一次就可能与前端不兼容。

⚠️ 只压，不校验业务。压完仍要过 workflow_accept.md 的第 4~6 关。
"""
import sys

BASE = 19968
MAXDIST = 65536
MIN_MATCH = 4
MAX_MATCH = 0xFFFF + 4


def lz_encode(data):
    """逆推解码器：l<128 字面量(l+1) / 128<=l<255 匹配(l-128+4) / l==255 长匹配(+4)。"""
    n = len(data)
    out = bytearray()
    lit = bytearray()
    table = {}

    def flush():
        i = 0
        while i < len(lit):
            chunk = lit[i:i + 128]
            out.append(len(chunk) - 1)
            out.extend(chunk)
            i += 128
        del lit[:]

    i = 0
    while i < n:
        best_len = 0
        best_dist = 0
        if i + MIN_MATCH <= n:
            key = bytes(data[i:i + 3])
            cands = table.get(key)
            if cands:
                for p in reversed(cands[-48:]):
                    dist = i - p
                    if dist > MAXDIST:
                        break
                    maxl = min(n - i, MAX_MATCH)
                    l = 0
                    while l < maxl and data[p + l] == data[i + l]:
                        l += 1
                    if l > best_len:
                        best_len, best_dist = l, dist
                        if l >= 128:
                            break
        if best_len >= MIN_MATCH:
            flush()
            t = best_dist - 1
            if best_len <= 130:
                out.append(128 + best_len - 4)
            else:
                out.append(255)
                v = best_len - 4
                out.append(v & 0xFF)
                out.append((v >> 8) & 0xFF)
            out.append(t & 0xFF)
            out.append((t >> 8) & 0xFF)
            end = min(i + best_len, n - 2)
            for k in range(i + 1, end):
                table.setdefault(bytes(data[k:k + 3]), []).append(k)
            i += best_len
        else:
            if i + 3 <= n:
                table.setdefault(bytes(data[i:i + 3]), []).append(i)
            lit.append(data[i])
            if len(lit) == 128:
                flush()
            i += 1
    flush()
    return bytes(out)


def pack_bits(payload):
    """24 位长度 + 每字节 8 位，小端位序，每 14 位 +19968 落一个汉字。"""
    bits = []

    def push(v, width):
        for k in range(width):
            bits.append((v >> k) & 1)

    push(len(payload), 24)
    for b in payload:
        push(b, 8)

    chars = []
    for i in range(0, len(bits), 14):
        val = 0
        for k, bit in enumerate(bits[i:i + 14]):
            val |= bit << k
        chars.append(chr(BASE + val))
    return ''.join(chars)


def unpack_bits(s):
    acc = bits = p = 0
    state = [0, 0, 0]

    def g(k):
        while state[1] < k:
            state[0] += (ord(s[state[2]]) - BASE) << state[1]
            state[1] += 14
            state[2] += 1
        q = 1 << k
        b = state[0] % q
        state[0] //= q
        state[1] -= k
        return b

    n = g(24)
    return bytes(g(8) for _ in range(n))


def lz_decode(data):
    out = bytearray()
    i, n = 0, len(data)
    while i < n:
        l = data[i]
        i += 1
        if l < 128:
            l += 1
            out.extend(data[i:i + l])
            i += l
        else:
            if l == 255:
                l = (data[i] | (data[i + 1] << 8)) + 4
                i += 2
            else:
                l = l - 128 + 4
            t = data[i] | (data[i + 1] << 8)
            i += 2
            m = len(out) - t - 1
            for k in range(l):
                out.append(out[m + k])
    return bytes(out)


def sql_block(chars, chunk=3900):
    segs = [chars[i:i + chunk] for i in range(0, len(chars), chunk)] or ['']
    lines = ["DECLARE @b64 NVARCHAR(MAX) =",
             "    CAST(N'%s' AS NVARCHAR(MAX))" % segs[0]]
    for s in segs[1:]:
        lines.append("    + N'%s'" % s)
    return '\n'.join(lines), segs


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src_path = sys.argv[1]
    out_path = chunk = None
    for i, a in enumerate(sys.argv):
        if a == '--sql' and i + 1 < len(sys.argv):
            out_path = sys.argv[i + 1]
        if a == '--chunk' and i + 1 < len(sys.argv):
            chunk = int(sys.argv[i + 1])

    raw = open(src_path, 'rb').read()
    comp = lz_encode(raw)
    chars = pack_bits(comp)

    back = unpack_bits(chars)
    if back != comp:
        raise SystemExit('自检失败：拆包字节与 LZ 流不一致，不要使用')
    restored = lz_decode(back)
    if restored != raw:
        raise SystemExit('自检失败：LZ 解码结果与原文不一致，不要使用')

    sql, segs = sql_block(chars, chunk or 3900)
    ratio = 100.0 * len(sql) / len(raw) if raw else 0

    print('原文       %d 字节' % len(raw))
    print('LZ 流      %d 字节（%.1f%%）' % (len(comp), 100.0 * len(comp) / len(raw)))
    print('装载串     %d 汉字 / %d 段' % (len(chars), len(segs)))
    print('SQL 片段   %d 字符（占原文 %.1f%%）' % (len(sql), ratio))
    print('自检       拆包 + LZ 解码 逐字节一致')

    if out_path:
        with open(out_path, 'w', encoding='utf-8-sig', newline='\r\n') as f:
            f.write(sql + '\n')
        print('已写入     %s' % out_path)
    else:
        print('\n前 60 字：' + chars[:60])
        print('（加 --sql <路径> 输出完整片段）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
