# -*- coding: utf-8 -*-
"""只读核对看板过程 SQL 文件。不连接数据库，不执行存储过程。"""
import base64
import re
import sys

BASE = 0x4E00
MASK = (1 << 14) - 1
Z_MARKS = ("var B=19968", "bits+=14", "Math.floor(acc/q)")

# 部署环境 → 该环境过程里**允许出现**的跨实例取数地址。换项目改这张表即可；
# 文件头写「底本：<键>」决定判哪边，键名必须与「底本：」后第一个词一致。
#   基板正式（本机 172.16.9.111）跨实例读总装正式 → 172.16.8.31
#   总装正式（本机 172.16.8.31）跨实例读基板正式 → 172.16.9.111
# 只读本库、没有跨实例地址的过程同样合法。
ENV_IP = {
    "基板正式库": "[172.16.8.31].OrBitXIZC.dbo.",
    "总装正式库": "[172.16.9.111].OrBitXIZC.dbo.",
}


def read(path):
    return open(path, encoding="utf-8-sig").read()


def packed_block(text):
    m = re.search(r"DECLARE @b64 NVARCHAR\(MAX\) =\s*(.*?);\s*\n", text, re.S)
    if not m:
        return None
    parts = re.findall(r"N'((?:[^']|'')*)'", m.group(1))
    return "".join(p.replace("''", "'") for p in parts), m.group(1)


def b64_of(text):
    block = packed_block(text)
    if not block:
        return None
    body = block[1]
    if "CAST(" not in body.split("AS NVARCHAR(MAX))", 1)[0]:
        return None
    parts = re.findall(r"N'((?:[^']|'')*)'", body)
    raw = "".join(p.replace("''", "'") for p in parts)
    try:
        return base64.b64decode(raw, validate=True)
    except Exception:
        return None


def unpack(s):
    acc = 0
    bits = 0
    p = 0

    def g(k):
        nonlocal acc, bits, p
        while bits < k:
            acc += (ord(s[p]) - BASE) << bits
            bits += 14
            p += 1
        q = 1 << k
        b = acc % q
        acc //= q
        bits -= k
        return b

    n = g(24)
    return bytes(g(8) for _ in range(n))


def lz_decode(data):
    out = bytearray()
    i = 0
    n = len(data)
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
    return out.decode("utf-8")


def add(rows, name, ok, detail):
    rows.append((name, "PASS" if ok else "FAIL", detail))


def main():
    if len(sys.argv) < 2:
        print("usage: verify_pack.py <candidate.sql> [baseline.sql]")
        return 2
    text = read(sys.argv[1])
    rows = []

    add(rows, "解压器",
        all(x in text for x in Z_MARKS) and text.count("var B=19968") == 1,
        "B=19968 / 14bit / floor")
    add(rows, "无atob", "atob" not in text, "全文 0 处 atob")

    block = packed_block(text)
    if not block:
        add(rows, "装载块", False, "找不到 DECLARE @b64")
        chars = ""
        body = ""
    else:
        chars, body = block
        add(rows, "首段CAST",
            body.lstrip().startswith("CAST(N'"),
            "第一段 CAST AS NVARCHAR(MAX)")
        bad = [c for c in chars if c in "'\\\"\r\n" or not (BASE <= ord(c) <= BASE + MASK)]
        add(rows, "字面量", not bad, "越界 %d 字符" % len(bad) if bad else "%d 字符" % len(chars))
        try:
            raw = unpack(chars)
            add(rows, "可拆包", True, "%d 字节" % len(raw))
        except Exception as e:
            raw = None
            add(rows, "可拆包", False, str(e))

    add(rows, "ANSI_NULLS", "SET ANSI_NULLS ON" in text, "脚本头")
    add(rows, "QUOTED_IDENTIFIER", "SET QUOTED_IDENTIFIER ON" in text, "脚本头")
    add(rows, "无显式事务",
        not re.search(r"\bBEGIN\s+TRAN\b|\bCOMMIT\b|\bROLLBACK\b", text, re.I),
        "0 处")
    add(rows, "返回列", "SELECT @js AS value" in text, "value")
    add(rows, "表达式收尾", "})();" in text, "分号在 IIFE 后")

    env = None
    m = re.search(r"底本[：:]\s*(\S+)", text)
    if m:
        env = m.group(1)
    if env in ENV_IP:
        allowed = ENV_IP[env]
        found = [v for v in ENV_IP.values() if v in text]
        bad = [v for v in found if v != allowed]
        add(rows, "取数地址", not bad,
            ("%s：无跨实例地址（只读本库）" % env) if not found else
            ("%s：仅 %s" % (env, allowed) if not bad else
             "%s 串到了不允许的地址：%s" % (env, ", ".join(bad))))
    else:
        ips = sorted(set(re.findall(r"\[\d+\.\d+\.\d+\.\d+\]", text)))
        add(rows, "取数地址", False,
            "文件头无「底本：」或未在 ENV_IP 登记，地址 %s" % (ips or "无"))

    if len(sys.argv) >= 3 and raw is not None:
        base = b64_of(read(sys.argv[2]))
        if base is None:
            add(rows, "对拍", False, "底本不是 base64 装载")
        else:
            same = raw == base
            add(rows, "对拍", same, "LZ 字节 %s" % ("相同" if same else "不同"))
            if same:
                skel = lz_decode(raw)
                n = skel.count("__vfloor")
                add(rows, "切层", n > 0, "__vfloor %d 处" % n)

    width = max(len(r[0]) for r in rows)
    failed = 0
    for name, status, detail in rows:
        if status != "PASS":
            failed += 1
        print("%s  %-*s  %s" % (status, width, name, detail))
    print("FAIL %d" % failed if failed else "ALL PASS")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
