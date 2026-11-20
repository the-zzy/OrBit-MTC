# 主键生成函数 (GeneratePK)

## 功能
生成标准主键值（CHAR(12)，带表前缀 + 36进制序列号）

---

## 方法1：使用函数直接生成（推荐，最简洁）

### 使用 `Fn_GetObjectPKId` 函数 + SEQUENCE

```sql
-- 在 INSERT 语句中直接生成主键
INSERT INTO Bill (BillId, BillNo, CreateDate)
VALUES (
    dbo.Fn_GetObjectPKId(12, 'Bill', NEXT VALUE FOR dbo.Bill_PK),
    'BILL-001',
    GETDATE()
);
```

```sql
-- 在 INSERT...SELECT 中批量生成主键
INSERT INTO Bill (BillId, BillNo, CreateDate)
SELECT 
    dbo.Fn_GetObjectPKId(12, 'Bill', NEXT VALUE FOR dbo.Bill_PK),
    'BILL-' + CAST(OrderId AS VARCHAR),
    GETDATE()
FROM Orders WITH(NOLOCK)
WHERE OrderDate = CAST(GETDATE() AS DATE);
```

```sql
-- 先声明变量
DECLARE @BillId CHAR(12);
SET @BillId = dbo.Fn_GetObjectPKId(12, 'Bill', NEXT VALUE FOR dbo.Bill_PK);

INSERT INTO Bill (BillId, BillNo, CreateDate)
VALUES (@BillId, 'BILL-001', GETDATE());
```

**说明**：
- `12` - 主键长度（固定12位）
- `'Bill'` - 表名（自动从 SysObject 查找前缀）
- `NEXT VALUE FOR dbo.Bill_PK` - 获取下一个序列值
- 函数返回：`前缀(4位) + 36进制序列号(8位)` = 12位
- 示例：`BILL00000001`、`BILL0000000A`

**优点**：
- ✅ 最简洁，一行代码搞定
- ✅ 支持 INSERT...SELECT 批量生成
- ✅ 性能优秀，直接调用序列
- ✅ 适用于所有场景

---

## 方法2：使用存储过程生成单个主键

### 使用 `SysGetObjectPKId` 存储过程

```sql
-- 声明主键变量
DECLARE @ProcessDocumentMSId CHAR(12);

-- 调用存储过程生成主键
EXEC dbo.SysGetObjectPKId
    @ObjectId = '',                      -- 对象ID（留空则通过表名查找）
    @ObjectName = 'ProcessDocumentMSHis', -- 表名
    @PKID = @ProcessDocumentMSId OUTPUT; -- 输出参数

-- 使用生成的主键
INSERT INTO ProcessDocumentMSHis (ProcessDocumentMSId, ...)
VALUES (@ProcessDocumentMSId, ...);
```

**说明**：
- 从 `SysObject` 表读取表的标准前缀（ObjectPKHeader）
- 自动调用 `{表名}_PK` 序列获取下一个序列值
- 序列值转换为36进制（0-9, A-Z），自动补0到8位
- 生成格式：`前缀(4位) + 序列号(8位)` = 12位
- 示例：`PDMS00000001`、`BILL0000000A`

**适用场景**：
- 需要先生成主键，后续多次使用
- 逻辑较复杂，需要先验证再插入

---

## 方法3：批量主键生成（大量数据）

### 使用 `SysGetBatchObjectPKId` 存储过程

```sql
-- 创建临时表存储生成的主键
CREATE TABLE #TempPKId (
    Seq INT DEFAULT 0,        -- 序号
    PKId CHAR(12) DEFAULT ''  -- 主键ID
);

-- 批量生成主键（例如生成6个）
DECLARE @Seq INT = 6;
INSERT INTO #TempPKId (Seq, PKId)
EXEC dbo.SysGetBatchObjectPKId
    @ObjectId = '',                -- 对象ID（留空则通过表名查找）
    @ObjectName = N'MacTypeSetting', -- 表名
    @RowCount = @Seq;              -- 生成数量

-- 使用生成的主键批量插入
INSERT INTO MacTypeSetting (MacTypeSettingId, CustomerId, MacType, IsCancel, CreateDate)
SELECT  PKId, a.CustomerId, 'MTC MAC', 0, GETDATE()
FROM (
    SELECT ROW_NUMBER() OVER (ORDER BY CustomerId) AS rowno, CustomerId
    FROM dbo.Customer WITH(NOLOCK)
    WHERE CustomerName IN ('ELN01', 'RKU01', 'ESI01', 'CUR01', 'LTC01', 'DSG01')
) a
INNER JOIN #TempPKId ON Seq = a.rowno;

-- 清理临时表
DROP TABLE #TempPKId;
```

**说明**：
- 一次性生成多个主键，性能更好
- 返回临时表包含 `Seq`（序号）和 `PKId`（主键）
- 通过 `JOIN` 将生成的主键与业务数据关联
- 适用于批量插入场景

**适用场景**：
- 需要预先知道生成的数量
- 需要通过序号关联业务数据
- 数据量非常大（1000+条）

---

## 使用场景对比

| 场景 | 推荐方法 | 说明 |
|------|---------|------|
| **单条插入** | `Fn_GetObjectPKId` 函数 | 最简洁，一行代码 |
| **INSERT...SELECT 批量** | `Fn_GetObjectPKId` 函数 | 直接在 SELECT 中调用 |
| **需要先生成后使用** | `SysGetObjectPKId` 存储过程 | 适合复杂逻辑 |
| **超大量批量插入** | `SysGetBatchObjectPKId` 存储过程 | 一次生成多个，性能最佳 |
| **需要序号关联** | `SysGetBatchObjectPKId` 存储过程 | 返回 Seq 用于 JOIN |

---

## 完整示例

### 示例1：函数方式 - 单条插入（推荐）
```sql
INSERT INTO Bill (BillId, BillNo, CreateDate)
VALUES (
    dbo.Fn_GetObjectPKId(12, 'Bill', NEXT VALUE FOR dbo.Bill_PK),
    'BILL-001',
    GETDATE()
);
```

### 示例2：函数方式 - 批量插入（推荐）
```sql
INSERT INTO Bill (BillId, BillNo, CreateDate)
SELECT 
    dbo.Fn_GetObjectPKId(12, 'Bill', NEXT VALUE FOR dbo.Bill_PK),
    'BILL-' + CAST(OrderId AS VARCHAR),
    GETDATE()
FROM Orders WITH(NOLOCK)
WHERE OrderDate = CAST(GETDATE() AS DATE);
```

### 示例3：存储过程方式 - 单个主键
```sql
-- 申请单个主键
DECLARE @BillId CHAR(12);
EXEC dbo.SysGetObjectPKId '', 'Bill', @BillId OUTPUT;

-- 插入数据
INSERT INTO Bill (BillId, BillNo, CreateDate)
VALUES (@BillId, 'BILL-001', GETDATE());
```

### 示例4：存储过程方式 - 批量主键
```sql
-- 创建临时表
CREATE TABLE #TempBills (
    Seq INT,
    PKId CHAR(12),
    BillNo VARCHAR(50)
);

-- 准备业务数据
INSERT INTO #TempBills (Seq, BillNo)
SELECT ROW_NUMBER() OVER (ORDER BY OrderId), 'BILL-' + CAST(OrderId AS VARCHAR)
FROM Orders WITH(NOLOCK)
WHERE OrderDate = CAST(GETDATE() AS DATE);

-- 批量生成主键
DECLARE @BillCount INT;
SELECT @BillCount = COUNT(1) FROM #TempBills;

CREATE TABLE #TempPKId (Seq INT, PKId CHAR(12));
INSERT INTO #TempPKId (Seq, PKId)
EXEC dbo.SysGetBatchObjectPKId '', 'Bill', @BillCount;

-- 更新临时表中的主键
UPDATE t
SET t.PKId = p.PKId
FROM #TempBills t
INNER JOIN #TempPKId p ON t.Seq = p.Seq;

-- 批量插入
INSERT INTO Bill (BillId, BillNo, CreateDate)
SELECT PKId, BillNo, GETDATE()
FROM #TempBills;

-- 清理
DROP TABLE #TempBills;
DROP TABLE #TempPKId;
```

---

## 注意事项

### ✅ 必须遵守
1. **表必须在 SysObject 中注册**：确保表名和前缀已配置
2. **必须创建序列对象**：`CREATE SEQUENCE dbo.{表名}_PK START WITH 1 INCREMENT BY 1;`
3. **主键格式固定**：CHAR(12) = 前缀(4位) + 序列号(8位)
4. **函数方式优先**：大部分场景使用 `Fn_GetObjectPKId` 函数即可

### ⚠️ 常见错误
1. ❌ **直接在 INSERT...SELECT 中调用存储过程**
   ```sql
   -- 错误示例
   INSERT INTO Bill (BillId, BillNo)
   SELECT (EXEC dbo.SysGetObjectPKId '', 'Bill', @BillId OUTPUT), 'BILL-001';
   ```
   **正确做法**：使用函数方式
   ```sql
   INSERT INTO Bill (BillId, BillNo)
   SELECT dbo.Fn_GetObjectPKId(12, 'Bill', NEXT VALUE FOR dbo.Bill_PK), 'BILL-001';
   ```
   
2. ❌ **循环中调用单个主键存储过程**
   ```sql
   -- 错误示例（性能差）
   WHILE @i < @count
   BEGIN
       EXEC dbo.SysGetObjectPKId '', 'Bill', @BillId OUTPUT;
       INSERT INTO Bill VALUES (@BillId, ...);
       SET @i = @i + 1;
   END;
   ```
   **正确做法**：使用函数方式或批量存储过程
   ```sql
   -- 方式1：函数（推荐）
   INSERT INTO Bill (BillId, ...)
   SELECT dbo.Fn_GetObjectPKId(12, 'Bill', NEXT VALUE FOR dbo.Bill_PK), ...
   FROM SourceTable;
   
   -- 方式2：批量存储过程
   EXEC dbo.SysGetBatchObjectPKId '', 'Bill', @count;
   ```

3. ❌ **忘记创建序列对象**
   - 如果序列不存在，存储过程会回退到老方案（更新 SysObject.ObjectPKCounter）
   - 性能会下降，并发会有锁竞争

---

## 底层原理

### 主键生成规则
1. 查询 `SysObject` 表获取 `ObjectPKHeader`（表前缀）
2. 调用序列 `{表名}_PK` 获取下一个序列值
3. 将序列值转换为36进制（0-9, A-Z）
4. 补0到8位，拼接前缀形成12位主键

### 序列对象
```sql
-- 创建序列（如果不存在）
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'Bill_PK')
BEGIN
    CREATE SEQUENCE dbo.Bill_PK
    START WITH 1
    INCREMENT BY 1
    MINVALUE 1
    MAXVALUE 2821109904055  -- 36^8 = 2.8万亿
    NO CYCLE;
END;
```

### 36进制转换
- 序列值 1 → `00000001`
- 序列值 10 → `0000000A`
- 序列值 36 → `00000010`
- 序列值 1296 → `00000100` (36²)

---

## 性能对比

| 方法 | 单次调用 | 1000次调用 | 并发性能 | 推荐场景 |
|------|---------|-----------|---------|---------|
| Fn_GetObjectPKId 函数 | 极快 | 快 | 优秀 | ⭐ 首选 |
| SysGetObjectPKId 存储过程 | 快 | 慢 | 一般 | 复杂逻辑 |
| SysGetBatchObjectPKId 存储过程 | 一般 | 极快 | 优秀 | 超大批量 |
| 老方案（更新计数器） | 快 | 慢 | 差（锁表） | ❌ 废弃 |

**结论**：
- 🥇 **首选**：`Fn_GetObjectPKId` 函数 - 简洁高效，适用99%场景
- 🥈 **备选**：`SysGetBatchObjectPKId` 存储过程 - 超大批量（1000+）且需要序号关联
- 🥉 **特殊场景**：`SysGetObjectPKId` 存储过程 - 复杂业务逻辑需要先生成后使用
