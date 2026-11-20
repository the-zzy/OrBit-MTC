# 14bit 装载 · 专章

> 主入口 ⇒ [SKILL.md](./SKILL.md)；验收总表 ⇒ [workflow_accept.md](./workflow_accept.md)。

用于 option 太大、平台取串超时 / 截断，或图位本就是 TH 3D 原生骨架的看板。
返回的不是明文 option，而是一段**自解码 IIFE**：平台 `eval` 它，它自己还原出 option。

---

## 1. 硬前提

| 项 | 要求 |
|---|---|
| 底本 | 必须拿到**该环境自己的**前端骨架正文（master 提供），逐字节内联 |
| 环境 | 另一环境的过程不能顶替。基板正式与总装正式不同源 |
| 改法 | 只把**数据段**挖成占位，其余字符一个不动 |
| 文件头 | 写 `-- 底本：基板正式库` 或 `-- 底本：总装正式库`，验收脚本据此判取数地址 |

没有底本 ⇒ 退回明文形态，不许自己编骨架。

## 1.1 唯一标准（库内定义，不是本地文件）

**标准 = 该环境库里的 `dbo.WebAPI_THKanbanFlash`。** 本地 `deliverables/` 下的交付件只是某次的历史副本，
会过期，⛔ 不作准。用目标环境的 `<mcp>-query` / `<mcp>-procedure` 拉定义：

```sql
SELECT LEN(m.definition) AS def_len,
       CONVERT(varchar(23), o.modify_date, 121) AS modify_date,
       CASE WHEN m.definition LIKE '%var B=19968%' THEN 1 ELSE 0 END AS has_pack,
       CASE WHEN m.definition LIKE '%atob%' THEN 1 ELSE 0 END AS has_atob
FROM sys.objects o JOIN sys.sql_modules m ON m.object_id = o.object_id
WHERE o.name = 'WebAPI_THKanbanFlash';
```

实测（2026-11-09 核对）：基板正式与总装正式两侧同源，`def_len = 58040`、`has_pack = 1`、`has_atob = 0`。
换环境或改过标准版就重新核对，数值不是长期常量。

本地交付件的定位：

| 文件 | 形态 | 用途 |
|---|---|---|
| `JBPROD_102_WebAPI_THKanbanFlash.sql` / `TVPROD_102_WebAPI_THKanbanFlash.sql` | 14bit，与库内定义一致 | 可作模板参考 |
| `JBPROD_98_WebAPI_THKanbanFlash345.sql` / `TVPROD_98_WebAPI_THKanbanFlash345.sql` | 旧 `atob` + base64 内联 | `check_proc.py` 报 `legacy(base64)`，⛔ 不作底本 |

---

## 2. 装载原理（验收时按这个对）

```
骨架正文（UTF-8 字节）
  → LZ 编码（自写格式，非 zlib）
  → 头部 24 位压缩流长度 + 每字节 8 位，整体按 14 位一段切
  → 每段 + 19968（U+4E00）写成汉字
  → 每 3,900 汉字一段，首段包进 CAST(N'…' AS NVARCHAR(MAX))，后续用 + N'…' 拼
```

装载块实测（标准版，15,345 汉字 / 4 段）：

```sql
DECLARE @b64 NVARCHAR(MAX) =
    CAST(N'<seg1，3900 字>' AS NVARCHAR(MAX))
    + N'<seg2，3900 字>'
    + N'<seg3，3900 字>'
    + N'<seg4，3645 字>'
```

- 分段是为了单行不超长，**不是协议要求**；段长只要不触发 T-SQL 字符串字面量上限即可。
- 段内不许有 `'`、`\`、`"`、换行 —— 汉字装载天然满足。
- `verify_pack.py` 会把 DECLARE 之后所有 `N'…'` 全部拼回再解包，段数不影响判定。

LZ 格式（照库内解码器抄，别按 zlib 猜）：

| 首字节 | 含义 |
|---|---|
| `l < 128` | 字面量，长度 `l+1`，其后紧跟原文字节 |
| `l == 255` | 长匹配，`l = 低16位 + 4`，再 2 字节距离 |
| `128 ≤ l < 255` | 匹配，`l = l-128+4`，再 2 字节距离 |

解码在返回串里自带，四处特征缺一不可：

| 特征 | 写法 |
|---|---|
| 基数 | `var B=19968`，全文恰好 1 处 |
| 拆包 | `bits+=14`、`acc += (charCodeAt(p++)-B) * Math.pow(2,bits)`、`Math.floor(acc/q)` |
| 长度头 | `n=g(24)`，随后 `n` 次 `g(8)` 取字节 |
| 收尾 | `option=(function(){…})();` |

⛔ 全文不许出现 `atob`。⛔ 装载块字符必须全在 U+4E00–U+8DFF，且不含 `'` `\` `"` 与换行
（越界字符会被 T-SQL 字符串吞掉或截断）。

---

## 3. 过程骨架

```sql
-- =============================================
-- 存储过程: WebAPI_<名称>
-- 环境: <深圳基板正式 / 深圳总装正式>
-- 返回形态: B 14bit 装载
-- 底本：<基板正式库|总装正式库>
-- 画布: <W>×<H>
-- =============================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID(N'dbo.WebAPI_<名称>', N'P') IS NULL
    EXEC (N'CREATE PROCEDURE dbo.WebAPI_<名称> AS BEGIN SET NOCOUNT ON; SELECT N'''' AS value; END');
GO
ALTER PROCEDURE dbo.WebAPI_<名称>
    @OrBitUserName NVARCHAR(100) = N'',
    @ResourceName  NVARCHAR(100) = N'',
    @UserParameter NVARCHAR(MAX) = N'',
    @UserData      NVARCHAR(MAX) = N'',
    @Chunked       BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    BEGIN TRY
        /* 1. 取数：算出各数据段字符串，放进 @变量 */
        /* 2. 拼串：骨架字面量 + 数据段替换，顺序不能错 */
        DECLARE @js NVARCHAR(MAX);

        SET @js = N'(function(){ ... var B=19968; ... Z("'
                + @b64
                + N'"); ... return eval(s) })();';

        IF ISNULL(@js, N'') = N''
        BEGIN
            SELECT N'ServerMessage: 无数据' AS value;
            RETURN -1;
        END

        IF @Chunked = 0
            SELECT @js AS value;
        ELSE
            /* 分块：M|6 位序号|200 字符|# */
            ...;

        RETURN 0;
    END TRY
    BEGIN CATCH
        SELECT N'ServerMessage: 装载失败 - ' + ERROR_MESSAGE() AS value;
        RETURN -1;
    END CATCH
END
GO
```

- `@Chunked=1` 输出 `M|序号|` 块，供 `extract_option.py` 拼回；分块那段的 SQL 见 `workflow_layout.md` §8.1。
- **TRY/CATCH 不豁免**：解码器与拼串一起包进去。缺了就是静默空白。
- 空数据必须给 `ServerMessage:` 串，不许返回空串。
- ⚠️ 库内标准版实测（2026-11-09）**没有** `BEGIN TRY`、**没有** `ServerMessage:`，违反红线 2。
  新做必须补；动那份过程时顺带补，⛔ 不因为「标准版没写」就跟着不写。

---

## 3.5 压缩工具（写完必走）

明文 option 调通后，用 `scripts/pack_option.py` 一次压成同款装载块：

```bash
py scripts/pack_option.py <option.txt> --sql <装载块.sql> [--chunk 3900]
```

脚本做四件事，任一环不一致直接报错退出、不出文件：

1. LZ 压缩 —— 严格逆推标准版解码器，**不是 zlib**（`l<128` 字面量 / `l==255` 长匹配 +4 / 其余 `l-128+4`）
2. 24 位压缩流长度 + 每字节 8 位，按 14 位一段，每段 `+19968` 落汉字
3. 拆包回字节，与 LZ 流比对
4. LZ 解码，与原文字节比对

实测（23,039 字节的 option 样本）：

| 阶段 | 结果 |
|---|---|
| LZ 流 | 10,378 字节（45.0%） |
| 装载串 | 5,932 汉字 / 2 段 |
| SQL 片段 | 6,001 字符（26.0%） |
| 自检 | 拆包 + LZ 解码 逐字节一致 |
| 耗时 | 0.55 s |

**兼容性另验一次**（脚本自检只证明自家互逆，不证明前端能解）：
把装载串喂给标准版解码器（`function Z(a){var B=19968,…}`）跑 `node`，
还原结果与原文逐字节相同才算过。这条已验证：
23,039 字节样本 → 20,489 字符，还原逐字节一致。

⛔ 解码器与 IIFE 外壳**不复制、不修改** —— 它们属于标准版 `dbo.WebAPI_THKanbanFlash`，
改一次就可能与前端不兼容。本脚本只生产 `DECLARE @b64 …` 那一段。

---

## 4. 数据段回填（真正的坑都在这）

- 骨架里的每个数据段先定位边界，**只替换值，不动引号与分隔符**。
- 拼串时字符串值必须转义：`REPLACE(REPLACE(REPLACE(REPLACE(@v, N'\', N'\\'), N'"', N'\"'), NCHAR(13), N''), NCHAR(10), N'')`。
- 一个数据段要吃几个值，由骨架里的解包代码决定，**不能按「一串一个值」猜**。
  ⚠️ 这是**实例值，不是通用规则**：TH 温湿度看板的 `r:[e("…"),e("…")]` 每串解出 8 个值
  `[日, 均温, 最低温, 最高温, 均湿, 最低湿, 最高湿, 状态码]`，少一个 ⇒ `p[1].toFixed` of undefined。
  换一个看板，值个数与顺序按那份骨架自己的解包代码定。
- 数组顺序必须与骨架设计一致，**不按库里的拼音 / 笔画排序**。顺序错 = 标签全错位。
- 切层数由 `__vfloor` 出现次数体现，回填后次数必须不变（`verify_pack.py` 会数）。

---

## 5. 验收

```bash
py scripts/verify_pack.py <候选.sql> [底本.sql]
```

第二个参数是**同一环境、装载前的过程正文**（用目标环境的 `<mcp>-procedure` 从库内 `sys.sql_modules` 取回，
不是另一环境的文件）。不加它只查形态，加了才做 LZ 字节逐字对拍与 `__vfloor` 切层计数。

| 项 | 判据 |
|---|---|
| 解压器 | `var B=19968` 恰好 1 处，步长 14，`Math.floor` 拆包 |
| 无 atob | 全文 0 处 |
| 首段 CAST | `DECLARE @b64` 第一段是 `CAST(N'…' AS NVARCHAR(MAX))` |
| 字面量 | 全在 U+4E00–U+8DFF，无 `'` `\` `"` 与换行 |
| 可拆包 | 能按 14bit 解出合法字节流 |
| 过程壳 | 有 `SET ANSI_NULLS ON` / `SET QUOTED_IDENTIFIER ON`，0 处显式事务 |
| 返回 | 有 `SELECT @js AS value`，表达式以 `})();` 结尾 |
| 取数地址 | 按文件头底本判；表以 `scripts/verify_pack.py` 的 `ENV_IP` 为准：基板正式 → `[172.16.8.31]`（总装正式），总装正式 → `[172.16.9.111]`（基板正式） |
| 对拍 | 附底本时，LZ 字节逐字节相同 |
| 切层 | 对拍通过后 `__vfloor` 次数 > 0 且与底本一致 |

退出码 0 才算过。任一项 FAIL 就停，不出「可以上库」的结论。

`verify_pack.py` **只读本地文件**：不连库、不 `EXEC`、不跑 `sqlcmd`、不跑 `*apply*.sh`。
需要真跑时把脚本交给受控通道或人工执行。

过了 `verify_pack.py` 还要过 [workflow_accept.md](./workflow_accept.md) 的第 4~6 关：
取串 → `js_syntax_check.js`（装载形态走 `eval(src)`）→ v4 渲染截图。**对拍只证明装载没坏，不证明图画对了。**

---

## 6. 不做

- 不执行存储过程，不授予、不借用执行权限。
- 不把验证脚本改成 `EXEC dbo.WebAPI_*`。
- 不部署、不改白名单、不改过程；写操作只走当批授权的受控通道。
- 不另造「短键名 + 映射表」的压缩串 —— 需前端解码，前端不改就崩。
- 不以本地 `deliverables/` 副本为准；形态与长度一律回库查 `sys.sql_modules`。
