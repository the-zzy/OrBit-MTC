---
name: sql-query-safety
description: >-
  MES/WMS 库执行任何 SELECT 前的安全判定：先查表规模与索引，按级别处置巨型表和 LOB 表，禁止前导通配符、裸 TOP。用户要查表、跑 SQL、导数据时先读。
---

# SQL 查询安全

跟用户说中文。先按 `mes-db` 选定唯一库和 MCP，再按本技能判定这条语句能不能跑、怎么写。

> **适用范围**：本技能是**我们用 AI 查库时的自我约束**，来自真实事故复盘。它不改变数据库权限，不替代 DBA 规范，也不对其他人员、其他工具或自动化任务生效。优先级低于数据库本身的权限与业务约定。

## 第一条：先看表有多大

元数据查询，不扫数据，毫秒级。任何业务表语句执行前先跑：

```sql
SELECT SUM(p.rows) AS row_est
FROM sys.partitions p
WHERE p.object_id = OBJECT_ID('dbo.表名') AND p.index_id IN (0,1);
```

体积（只算聚集索引/堆，不含非聚集索引，是下限）：

```sql
SELECT SUM(a.total_pages)*8/1024 AS total_mb
FROM sys.partitions p
JOIN sys.allocation_units a
     ON (a.type IN (1,3) AND a.container_id = p.hobt_id)
     OR (a.type = 2 AND a.container_id = p.partition_id)
WHERE p.object_id = OBJECT_ID('dbo.表名') AND p.index_id IN (0,1);
```

查列名（写 SELECT 前先确认字段存在，别凭习惯写）：

```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = '表名'
ORDER BY ORDINAL_POSITION;
```

索引与列类型（判断能不能 seek）：

```sql
SELECT i.name, i.type_desc,
       STUFF((SELECT ',' + c.name
              FROM sys.index_columns ic
              JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
              ORDER BY ic.key_ordinal FOR XML PATH('')),1,1,'') AS key_cols
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('dbo.表名') AND i.type > 0;
```

- 有快照的库先读 `references/`，没有快照再现场跑。
- `sys.dm_db_partition_stats` 需要 `VIEW DATABASE STATE`，普通账号（`AIAssistant`）会报 297，不要用。

## 第二条：分级处置

| 级别 | 行数 | 体积 | 处置 |
|---|---:|---:|---|
| **P0 禁止直接查** | ≥ 1 亿 | ≥ 20 GB | **AI 不得通过 MCP 执行任何 SELECT**。遇到需求先停下，说明这是 P0 表，向用户索取主键/唯一索引等值条件并取得逐条授权；没有授权就不执行 |
| **P1 高危** | ≥ 1000 万 | ≥ 5 GB | 必须有可走索引的过滤条件；禁止全表、禁止前导通配符 |
| **P2 注意** | ≥ 100 万 | ≥ 1 GB | 禁止 `%...%`；`TOP` 必须 `ORDER BY` |

P0 共 13 张，**AI 禁止直查**：`DataChainAssembly`、`DataChain`、`DataChainMove`、`Lot`、`TestResultItem`、`WriteDataTest`、`TestResultSub`、`MOItemLot`、`material_poolHistory`、`LotFirstMove`、`Interface_CallAPIServiceLog`、`T_Download_Log`、`xml_Test`。

行数和体积**任一**触发即按高级别处理。

行数会骗人：`Interface_CallAPIServiceLog` 只有 62 万行，却占 155 GB——LOB 单行几百 KB，按时间查又没索引，读 LOB 页比扫 `Lot` 还狠。体积榜必须一起看。

## 第三条：红线

1. **P0 表禁止直查**：AI 不得通过 MCP `query` 对这 13 张表执行任何 SELECT。遇到取数需求先停下，向用户说明是 P0 表，索取主键/唯一索引等值条件并取得**逐条**授权；没有明确授权不执行，也不自行换写法绕过。
2. **禁止前导通配符**：`LIKE '%...'` / `LIKE '%...%'` 不能作为唯一过滤条件。确需后缀搜索，走 `REVERSE()` 计算列 + 索引，或先用有索引的列收窄。
3. **`TOP` 必须带 `ORDER BY`**。无 `ORDER BY` 的 TOP 既是随机结果，也会触发优化器行目标，把 seek 翻成 2 亿行全扫。
4. **字面量类型/排序规则与列一致**，例如 `varchar` 列不要传 `nvarchar` 参数，防 `CONVERT_IMPLICIT` 让索引失效。
5. **P0/P1 表禁止 `SELECT *`**，LOB 列会把读取量放大几十倍。
6. **客户端超时 ≠ 服务端取消**。超时后禁止立即重试；先确认上一条已结束，再决定是否换写法。

## 第四条：跨库与 OPENQUERY

经 `OPENQUERY([链接服务器], '...')` 取数时：

1. **远端 SELECT 每一列都给唯一别名。** `z.IsCancel` 和 `ci.IsCancel` 同时出现会整条报 `Duplicate column names are not allowed in result sets obtained through OPENQUERY`，不会只丢一列。
2. **先聚合再取明细。** 先 `COUNT(*)` / `SUM(...)` 确认量级，需要看行时再拉。一次拉回几百行明细既挤占上下文，也容易触发超时。
3. **过滤写进远端 SQL。** `OPENQUERY` 不在本地优化，外层 `WHERE` 仍会把全量结果拉过来。
4. **中文别名只用于展示。** 本地 `ORDER BY` / JOIN 用英文别名或列序号，中文别名会报 `Invalid column name`。MCP 返回的中文列值有时显示成 GBK 乱码，校验类查询用英文别名、返回英文判定值（如 `OK` / `DIFF`）。
5. **连接字符串上限 8000 字符。** 订单号很多时不要拼进 `IN (...)`，按单查询或用临时表分批。

## 第五条：分环境

- **正式库**（只读账号）：先 `SET SHOWPLAN_XML ON` 看估计计划（只出计划、不执行），确认是 Index Seek 再真跑。
- 结构一致时**先去测试库验证**，正式库只跑已验证过的语句。
- 必要时加 `OPTION (MAXDOP 1)` 限流，避免并行扫描吃满 CPU。
- 长查询加 `SET LOCK_TIMEOUT 5000;`，避免无限等锁拖住业务。
- 正式库 `AIAssistant` 无 `VIEW SERVER STATE`，查不了 `sys.dm_exec_query_stats` / `sys.dm_exec_requests`，不要试图用它看实时会话。

## 第六条：已知库快照

> 本技能只管查询。写入按项目约定走 MES 存储过程，不在本技能展开。

| 库 | 快照 |
|---|---|
| 总装 MES 正式（OrBitXIZC） | `references/zongzhuang-mes-prod.md` |

其他库暂无快照，先现场跑第一条的元数据查询，查到的结果可补进 `references/`。

## 速查

```text
1. 表有多大？（sys.partitions / sys.allocation_units）
2. 过滤列有索引吗？能 seek 吗？
3. 级别？P0 停下向用户要授权、P1 加条件、P2 走常规。
4. LIKE 有没有前导 %？TOP 有没有 ORDER BY？
5. 正式库先看估计计划，再决定跑不跑。
6. OPENQUERY：列名唯一？先聚合？条件写远端？中文别名没进 ORDER BY？
```
