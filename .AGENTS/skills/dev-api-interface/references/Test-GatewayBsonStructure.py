#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
网关 BP/WG bson 结构完整性断言

平台 Loader 反序列化要求字段「键全、空值也显式存在」。实测 2026-10-15：
  步骤1 内部 REST  P_ActionUrlConfig（数组元素） = 109 字段
  步骤2 API 列表   P_ActionUrlConfig（对象）     = 109 字段
  paramsDocs 每个节点                          = 16 字段信封
少一个空字段，平台打开编排就抛异常，且不指明缺哪个 —— 上一版 BP 56 / WG 62 就是这么炸的。

用法（生成脚本写盘后必须调用）：
    python Test-GatewayBsonStructure.py BP_xxx.bson WG_xxx.bson
    python Test-GatewayBsonStructure.py --kind bp BP_xxx.bson

退出码：0 = 通过；1 = 断言失败（脚本里的 throw）。
"""
import argparse
import json
import sys

EXPECT_ACTIONURL_FIELDS = 109
EXPECT_PARAMSDOC_FIELDS = 16

# paramsDocs 节点信封的 16 个键（实测自平台导出件 ref_API列表_契约锁_含Object入参_16091445.bson，
# 462 节点中 391 个 16 键、60 个带 children 变 17 键，键集与顺序固定，空值也显式存在）
PARAMSDOC_KEYS = [
    "id", "fieldName", "fieldId", "fieldType", "hidden", "breakFlag",
    "required", "sampleValue", "enCode", "order", "in", "errorCode",
    "maxLength", "minLength", "deprecated", "sortNum",
]
# Object / Array 型节点会多一个 children 键
PARAMSDOC_OPTIONAL_KEYS = ["children"]


def load(path):
    with open(path, "r", encoding="utf-8-sig") as f:
        return json.load(f)


def walk(node, path="$"):
    """深度遍历，产出 (路径, 容器)"""
    yield path, node
    if isinstance(node, dict):
        for k, v in node.items():
            yield from walk(v, "%s.%s" % (path, k))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk(v, "%s[%d]" % (path, i))


def check_action_url_config(tree):
    """P_ActionUrlConfig 字段数：对象形态数本身，数组形态数每个元素"""
    errors, checked = [], 0
    for path, node in walk(tree):
        if not isinstance(node, dict) or "P_ActionUrlConfig" not in node:
            continue
        cfg = node["P_ActionUrlConfig"]
        if isinstance(cfg, list):
            if not cfg:
                errors.append("%s.P_ActionUrlConfig 是空数组" % path)
                continue
            for i, elem in enumerate(cfg):
                checked += 1
                if not isinstance(elem, dict):
                    errors.append("%s.P_ActionUrlConfig[%d] 不是对象" % (path, i))
                elif len(elem) != EXPECT_ACTIONURL_FIELDS:
                    errors.append(
                        "%s.P_ActionUrlConfig[%d] = %d 字段，期望 %d" %
                        (path, i, len(elem), EXPECT_ACTIONURL_FIELDS))
        elif isinstance(cfg, dict):
            checked += 1
            if len(cfg) != EXPECT_ACTIONURL_FIELDS:
                errors.append("%s.P_ActionUrlConfig = %d 字段，期望 %d" %
                              (path, len(cfg), EXPECT_ACTIONURL_FIELDS))
        else:
            errors.append("%s.P_ActionUrlConfig 类型异常：%s" % (path, type(cfg).__name__))
    if checked == 0:
        errors.append("P_ActionUrlConfig 不存在（模板用错，可能拿了定时任务模板）")
    return errors, checked


def check_params_docs(tree):
    """paramsDocs 每个节点必须是 16 键信封"""
    errors, nodes = [], 0

    def walk_params(node, path=""):
        nonlocal nodes
        if isinstance(node, dict):
            if "nodeId" in node or "fieldId" in node:
                nodes += 1
                missing = [k for k in PARAMSDOC_KEYS if k not in node]
                extra = [k for k in node if k not in PARAMSDOC_KEYS and k not in PARAMSDOC_OPTIONAL_KEYS]
                name = node.get("fieldName") or node.get("nodeId") or "?"
                p = "%s/%s" % (path, name)
                if missing:
                    errors.append("paramsDocs%s 缺键：%s（空值也必须显式存在）" % (p, ", ".join(missing)))
                if extra:
                    errors.append("paramsDocs%s 多余键：%s" % (p, ", ".join(extra)))
            for k, v in node.items():
                walk_params(v, "%s/%s" % (path, k))
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk_params(v, "%s[%d]" % (path, i))

    for _path, node in walk(tree):
        if isinstance(node, dict) and "paramsDocs" in node:
            walk_params(node["paramsDocs"], ".")
    return errors, nodes


def check_map_url(tree, kind, label):
    """地址口径：BP 走 /system_mes/，WG 走 /thirdparty/mes/ 且不带 /api 前缀"""
    errors = []
    urls = []
    for _path, node in walk(tree):
        if isinstance(node, dict):
            for key in ("mapUrl", "backendUrl"):
                v = node.get(key)
                if isinstance(v, str) and v.startswith("/"):
                    urls.append((key, v))

    if not urls:
        errors.append("%s 找不到任何 mapUrl / backendUrl" % label)
        return errors

    if kind == "bp":
        if not any("/system_mes/" in v for _k, v in urls):
            errors.append("%s 缺 /system_mes/ 的地址（步骤1 内部 REST 不对）" % label)
    elif kind == "wg":
        if not any("/thirdparty/mes/" in v for _k, v in urls):
            errors.append("%s 缺 /thirdparty/mes/ 的地址（步骤2 对外地址不对）" % label)
        if any(v.startswith("/api/") for _k, v in urls):
            errors.append("%s 的 mapUrl 带了 /api 前缀（网关统一挂 /api，bson 里不写）" % label)
    return errors


def check_placeholders(tree, label):
    """残留占位符 / 样例标识"""
    errors = []
    raw = json.dumps(tree, ensure_ascii=False)
    for bad in ("REPLACE_", "000000000000000000000000", "亚马逊AUTOTEST",
                "YMXUploadFileSetObaTested", "TEST_YMX_OBA_001", "TESTLOT00002"):
        if bad in raw:
            errors.append("%s 残留占位/样例标识：%s" % (label, bad))
    return errors


def check_pair(bp_tree, wg_tree):
    """BP / WG 的 configName 必须一致，否则平台关联不上"""
    def names(tree):
        out = set()
        for _p, node in walk(tree):
            if isinstance(node, dict):
                v = node.get("configName")
                if isinstance(v, str) and v:
                    out.add(v)
        return out

    bp_names, wg_names = names(bp_tree), names(wg_tree)
    if not bp_names & wg_names:
        return ["configName 不一致：BP=%s / WG=%s（步骤1 与步骤2 必须同名）" %
                (sorted(bp_names), sorted(wg_names))]
    return []


def main():
    ap = argparse.ArgumentParser(description="网关 bson 结构完整性断言")
    ap.add_argument("files", nargs="+", help="要校验的 bson（1~2 个）")
    ap.add_argument("--kind", choices=["bp", "wg", "auto"], default="auto",
                    help="文件类型；两个文件时自动按文件名前缀判定")
    args = ap.parse_args()

    trees, kinds = [], []
    for f in args.files:
        name = f.replace("\\", "/").rsplit("/", 1)[-1]
        kind = args.kind if args.kind != "auto" else ("bp" if name.startswith("BP_") else "wg" if name.startswith("WG_") else None)
        if kind is None:
            print("[FAIL] 无法判定类型（文件名须以 BP_ / WG_ 开头）：%s" % name)
            return 1
        try:
            trees.append(load(f))
        except Exception as e:
            print("[FAIL] %s 解析失败：%s" % (name, e))
            return 1
        kinds.append(kind)

    all_errors = []
    for f, kind, tree in zip(args.files, kinds, trees):
        label = f.replace("\\", "/").rsplit("/", 1)[-1]
        e1, n1 = check_action_url_config(tree)
        e2, n2 = check_params_docs(tree)
        e3 = check_map_url(tree, kind, label)
        e4 = check_placeholders(tree, label)
        errs = ["%s : %s" % (label, x.replace(label + " ", "")) for x in (e1 + e2 + e3 + e4)]
        all_errors += errs
        if not errs:
            print("[OK] %s (%s) : P_ActionUrlConfig x%d 均 %d 字段；paramsDocs 节点 %d 个均 %d 键" %
                  (label, kind.upper(), n1, EXPECT_ACTIONURL_FIELDS, n2, EXPECT_PARAMSDOC_FIELDS))

    if len(trees) == 2:
        pair_err = check_pair(trees[0], trees[1])
        all_errors += pair_err
        if not pair_err:
            print("[OK] configName 一致")

    if all_errors:
        print("\n[FAIL] 结构断言失败 %d 项：" % len(all_errors))
        for e in all_errors:
            print("  - " + e)
        return 1

    print("\n[PASS] 全部结构断言通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
