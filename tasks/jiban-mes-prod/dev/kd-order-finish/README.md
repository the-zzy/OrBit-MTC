# KDYN 订单完成状态与配载拉取

基板正式库 `jiban-mes-prod` / `OrBitXIZC`，插件 `KDYN`「国外CKD订单」（`Plugin Standard.dll`，元对象 `MTD1000000LI`）。

## 2026-11-20 修复：柜号为空时配载被丢弃

**现象**：`JB2026111319-1` 点「手动同步数据」后，配载数仍为 0。

**原因**：`KDOrderLoadedPull` 远端条件 `ISNULL(c.ContainerSN,'') <> ''` 只取已生成正式柜号的配载。该单货柜 `CIFD00000PUV` 只有预柜号 `40HQCNTR26111900001`、柜号 `40HQCNTR261119/1`，`ContainerSN` 为空串，整单 126 条配载被过滤。

**改动**（`KDOrderLoadedPull_FixEmptyContainerSN.sql`）：

- 去掉 `ContainerSN` 非空过滤，草稿柜/未挂柜号的配载也计入已装柜数量。
- `Container` 字段依次取 `ContainerSN` → `ContainerNumber` → `ContainerPreSN`。
- 增量拉取、`CIT`/`JDB` 前缀清理、`MERGE` 口径不变。

**部署**：已通过 `scripts/proc_sql.ps1` 在正式库执行 `ALTER PROCEDURE`。

**回滚**：`KDOrderLoadedPull.rollback.sql`（部署前定义）。

## 验证

新口径下该单可拉取：

| 项目 | 值 |
|---|---:|
| 配载明细 | 126 行 |
| RealQty 合计 | 28,395,233 |
| 包装数（`KDMOItem.IssuedQty`） | 28,395,233 |

同步后按「包装数 = 配载数 > 0」自动置 `IsManualFinish=1`。同柜订单 `JB2026110914-1`、`JB2026102609-1` 也会一起满足完成条件；其余未完成订单数量仍不等，不受影响。

## 部署工具

```text
.venv/Scripts/python.exe -I scripts/proc_tool.py get|put --source jiban-mes-prod ...
scripts/proc_sql.ps1 -Env jiban-mes-prod -Action get|put -File <路径> [-DryRun]
```

系统 `python` 是 WindowsApps 别名桩（退出码 49），不要用。
