---
name: mes-db
description: >-
  按工厂、MES/WMS、测试/正式选定唯一数据库，只调用该库的工具。用户提到基板、总装、通信、光元、数码、MES、WMS、测试、正式、查表、存储过程时先读。
---

# 数据库

跟用户说明用中文。真正执行的 MCP 名和工具名用英文，方便下命令。一个 MCP 只连一个库，不能在参数里换库。

没写系统时也是 MES。只有仓储写成 WMS。

| 环境 | 库 | 能做的事 |
|---|---|---|
| 基板 MES 测试 | `192.168.0.21` / `JIBAN` | 查表、看存储过程、执行存储过程 |
| 基板 MES 正式 | `172.16.9.111` / `OrBitXIZC` | 查表、看存储过程、执行存储过程 |
| 总装 MES 测试 | `172.16.9.112` / `TV` | 查表、看存储过程、执行存储过程 |
| 总装 MES 正式 | `172.16.8.31` / `OrBitXIZC` | 查表、看存储过程 |
| 通信 MES 正式 | `192.168.0.246` / `OrBitXICH` | 查表 |
| 光元 MES 正式 | `172.16.8.244` / `OrBitXIZC` | 查表 |
| 光元 WMS 正式 | `172.16.9.244` / `OrBitXIZC` | 查表、看存储过程、执行存储过程 |
| 数码 MES 正式 | `172.16.8.111` / `OrBitXIZC` | 查表 |

## 执行名

查表是 `query`，看存储过程是 `procedure`，执行存储过程是 `execute`。工具全名是 MCP 名加这个动作。表里没有的事，就没有这个工具。

| 环境 | MCP | 工具 |
|---|---|---|
| 基板 MES 测试 | `jiban-mes-test` | `jiban-mes-test-query` `jiban-mes-test-procedure` `jiban-mes-test-execute` |
| 基板 MES 正式 | `jiban-mes-prod` | `jiban-mes-prod-query` `jiban-mes-prod-procedure` `jiban-mes-prod-execute` |
| 总装 MES 测试 | `zongzhuang-mes-test` | `zongzhuang-mes-test-query` `zongzhuang-mes-test-procedure` `zongzhuang-mes-test-execute` |
| 总装 MES 正式 | `zongzhuang-mes-prod` | `zongzhuang-mes-prod-query` `zongzhuang-mes-prod-procedure` |
| 通信 MES 正式 | `tongxin-mes-prod` | `tongxin-mes-prod-query` |
| 光元 MES 正式 | `guangyuan-mes-prod` | `guangyuan-mes-prod-query` |
| 光元 WMS 正式 | `guangyuan-wms-prod` | `guangyuan-wms-prod-query` `guangyuan-wms-prod-procedure` `guangyuan-wms-prod-execute` |
| 数码 MES 正式 | `shuma-mes-prod` | `shuma-mes-prod-query` |

## 调用

1. 先确定工厂、系统、测试还是正式，只选上面的一套。
   - 用户没写测试/正式时**默认测试**；这套库没有测试环境（表里只有正式）才用正式。
   - 工具描述里写明了库名、地址和阶段，调用前核对一眼，别只看工具名后缀。
   - `execute` 会写数据：执行前先说明目标是哪套库，写正式库前必须确认。
2. 只调用这一套的英文工具名。
3. 要查另一套库，换 MCP，不在参数里改地址或库名。
4. 别用其他对话里的库。这个对话查哪套，就只调哪套。
5. 默认账号是 `AIAssistant`；数码 MES 正式使用 `zhuozy`。凭据在 `secrets/{MCP名}.env`，不读进对话。

架构表（`SysPlugIn`、`SysMetadata`、`MESTxnObject`、`MobileObject` 等）字段固定，快速查询用 `mes-meta-query` 技能和只读脚本 `scripts/query_meta.ps1`，不经过 MCP。

执行任何业务表 SQL（`SELECT` / `INSERT` / `UPDATE` / `DELETE`）前，先读 `sql-query-safety` 技能：查表规模、分级处置、红线，以及禁止直接写入的表。

## 改过程 / DDL

- 首选项目虚拟环境：`.venv/Scripts/python.exe -I scripts/proc_tool.py get|put --source <MCP名> ...`。
- 系统 `python` 在这台机器上是 WindowsApps 的别名桩：任何调用都**退出码 49、无输出**；系统环境也没装 `pymssql`。看到这种结果先怀疑解释器，不要怀疑库或凭据。
- 没有 venv、或要一次执行多条批处理时用 `scripts/proc_sql.ps1 -Env <MCP名> -Action get|put -File <路径> [-DryRun]`。整个脚本在一个事务里执行，`-DryRun` 校验后回滚。
- 改正式库的顺序：`get` 把当前定义备份到 `tasks/{库}/{类别}/{功能}/<过程名>.rollback.sql` → 改脚本 → `put -DryRun` → `put` → 查 `OBJECT_DEFINITION` 确认已生效。
