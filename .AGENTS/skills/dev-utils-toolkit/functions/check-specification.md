# 规程节点校验 (CheckSpecification)

## 功能

调用现网 `dbo.SysCheckSpecification`，判断批号**当前工作流节点（规程）**是否允许操作指定 MES 事务。不在允许节点则返回失败。

SQL Server 函数不能 `EXEC` 存储过程，因此本工具是**可直接粘贴的调用块**，不要再包一层无意义的包装过程。

---

## 前置条件

`SysCheckSpecification` 按 `MESTxnObjectName` 去查 `MESTxnObject` + `MESTxnObjectSpecification`。  
**必须先维护事务规程**，否则一律报「未维护事务规程」。

| 场景 | `@MESTxnObjectName` | 允许的规程（深圳基板正式库已核对） |
|------|---------------------|-------------------------------------|
| 点屏升级（设备口） | `ScreenUpgrade` | `SPE10000025Y` 点屏升级 |
| 线外测试 DIPTE 老化 | `DIPTESTExtra` | 老化测试 / 手压测试 / DIP_电源板_测试 |
| 老化测试事务 | `BurnAgingTest` | `SPE1000001AG` 老化测试 |

不要把点屏升级写成 `BurnAgingTest` 或 `DIPTESTExtra`：前者是老化；后者允许 3 个节点，设备会误放行老化/手压。

---

## 调用块（设备口，消息前缀 MES:）

设备 / ADC 过程没有 14 个 Orbit 参数，用业务变量映射即可。不要 `SELECT '' AS ScanSN`（那是 Orbit 界面字段）。

`SysCheckSpecification` 自己的返回消息已带 `ServerMessage:`，设备口要换成 `MES:`，不要再拼一次 `ServerMessage:`。

```sql
DECLARE @SpecCheckReturn INT = -1;
DECLARE @SpecCheckMessage NVARCHAR(MAX) = N'';

EXEC @SpecCheckReturn = dbo.SysCheckSpecification
    @I_ReturnMessage = @SpecCheckMessage OUTPUT ,
    @WorkcenterId = @WorkcenterId OUTPUT ,
    @I_OrBitUserId = @UserId ,
    @I_OrBitUserName = @UserName ,
    @I_ResourceId = @ResourceId ,
    @I_ResourceName = @ResourceName ,
    @LotId = @LotId ,
    @SpecificationId = @LotSpecificationId ,
    @MESTxnObjectName = N'ScreenUpgrade';

IF @SpecCheckReturn = -1
BEGIN
    SET @returnMessage = N'MES:' + REPLACE(ISNULL(@SpecCheckMessage, N''), N'ServerMessage:', N'');
    RETURN -1;
END;
```

| 入参 | 来源 |
|------|------|
| `@LotId` / `@LotSpecificationId` | 已解析的批号（534 转 575 之后） |
| `@MESTxnObjectName` | 本测试项对应的事务名，点屏升级固定 `ScreenUpgrade` |
| `@UserId` / `@UserName` | 有工号就传；空则跳过规程上的用户检查 |
| `@ResourceId` / `@ResourceName` | 有资源就传；空则跳过资源检查 |
| `@WorkcenterId` | OUTPUT，过程可能回写线体 |

---

## 调用块（Orbit 客户端，消息前缀 ServerMessage:）

```sql
DECLARE @return_value INT = -1;

EXEC @return_value = dbo.SysCheckSpecification
    @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
    @WorkcenterId = @WorkcenterId OUTPUT ,
    @I_OrBitUserId = @I_OrBitUserId ,
    @LotId = @LotId ,
    @I_OrBitUserName = @I_OrBitUserName ,
    @I_ResourceId = @I_ResourceId ,
    @I_ResourceName = @I_ResourceName ,
    @SpecificationId = @LotSpecificationId ,
    @MESTxnObjectName = N'BurnAgingTest';

IF @return_value = -1
BEGIN
    SELECT  '' AS ScanSN;
    SET @I_ExceptionFieldName = N'ScanSN';
    RETURN -1;
END;
```

说明：`SysCheckSpecification` 返回的 `@I_ReturnMessage` 已含 `ServerMessage:`，**不要**再写成 `'ServerMessage:' + @I_ReturnMessage`。

---

## 何时调用

批号已取到 `LotId`、`SpecificationId` 之后，写数据 / 过站之前。  
GET 与 SUBMIT 都要调（开测前防呆、回写前再防呆）。
