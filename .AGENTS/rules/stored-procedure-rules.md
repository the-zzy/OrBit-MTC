---
description: 存储过程强制规则。所有存储过程必须遵守：禁止显式事务、必须TRY/CATCH、统一返回值规范。
alwaysApply: false
paths:
  - "**/*.sql"
---

# 存储过程强制规则

> **适用范围**：创建或修改存储过程时必须遵守本规则。

---

## 1. 事务控制（禁止）

❌ **禁止使用**：`BEGIN TRANSACTION`、`COMMIT`、`ROLLBACK`、`SAVE TRANSACTION`

**原因**：由外层调用方控制事务一致性，存储过程内部不应管理事务。

---

## 2. 错误处理（必须）

**所有存储过程必须使用 TRY/CATCH 结构**：

```sql
BEGIN TRY
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    
    -- 主体逻辑
    
    RETURN 0;
END TRY
BEGIN CATCH
    -- 记录异常信息
    DECLARE @ErrNum INT = ERROR_NUMBER();
    DECLARE @ErrLine INT = ERROR_LINE();
    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    
    INSERT INTO dbo.SqlProcedureIssueLog (
        ProcName, 
        IssueType, 
        StepCode, 
        Message, 
        ErrNumber, 
        ErrLine, 
        ErrMessage, 
        OrBitUserId
    )
    VALUES (
        '{存储过程名}', 
        N'SQL_EXCEPTION', 
        N'CATCH', 
        N'{业务描述}异常', 
        @ErrNum, 
        @ErrLine, 
        @ErrMsg, 
        @I_OrBitUserId
    );
    
    SET @I_ReturnMessage = N'ServerMessage:' + ERROR_MESSAGE();
    RETURN -1;
END CATCH
```

---

## 3. 返回值规范（强制）

| 结果 | 返回值 | 消息格式 |
|-----|--------|---------|
| 成功 | `RETURN 0` | `SET @I_ReturnMessage = N'ServerMessage:操作成功'` |
| 失败 | `RETURN -1` | `SET @I_ReturnMessage = N'ServerMessage:具体错误信息'` |

**注意**：
- 返回消息必须带 `ServerMessage:` 前缀
- 错误消息应具体描述问题，便于定位

---

## 4. 临时表规范

### 4.1 创建临时表
```sql
IF OBJECT_ID(N'tempdb..#TempTable') IS NOT NULL DROP TABLE #TempTable;

CREATE TABLE #TempTable (
    Col1 INT,
    Col2 NVARCHAR(50)
);
```

### 4.2 清理临时表
```sql
-- 使用完毕后清理
DROP TABLE #TempTable;
```

---

## 5. 性能优化要点 

### 5.1 查询优化

1. **使用WITH(NOLOCK)提示**
   ```sql
   FROM dbo.TableName a WITH(NOLOCK)
   ```

2. **避免SELECT ***
   ```sql
   -- 不推荐
   SELECT * FROM TableName;
   
   -- 推荐
   SELECT Column1, Column2, Column3 FROM TableName;
   ```

3. **使用EXISTS代替COUNT**
   ```sql
   -- 不推荐
   IF (SELECT COUNT(*) FROM TableName WHERE Condition) > 0
   
   -- 推荐
   IF EXISTS(SELECT 1 FROM TableName WHERE Condition)
   ```

4. **避免在WHERE中使用函数**
   ```sql
   -- 不推荐
   WHERE YEAR(CreateDate) = 2026
   
   -- 推荐
   WHERE CreateDate >= '2026-01-01' AND CreateDate < '2027-01-01'
   ```


### 5.2 索引使用
- 大表关联时使用索引列
- WHERE 条件优先使用索引列
- 避免在索引列上使用函数或计算

### 5.3 批量处理优先

**优先使用批量操作，避免循环遍历**

❌ **避免循环更新**（性能差）：
```sql
-- 不推荐：逐行更新
DECLARE @Id CHAR(12);
DECLARE cur CURSOR FOR SELECT ProductId FROM #TempData;
OPEN cur;
FETCH NEXT FROM cur INTO @Id;
WHILE @@FETCH_STATUS = 0
BEGIN
    UPDATE Product SET Status = 'Active' WHERE ProductId = @Id;
    FETCH NEXT FROM cur INTO @Id;
END;
CLOSE cur;
DEALLOCATE cur;
```

✅ **推荐批量处理**（性能好）：
```sql
-- 推荐：批量更新
UPDATE p SET p.Status = 'Active'
FROM Product p WITH(NOLOCK)
INNER JOIN #TempData t ON p.ProductId = t.ProductId;
```

**例外情况**：
- 只有在复杂业务逻辑必须逐行判断时才使用循环
- 如需循环，优先使用 `WHILE` 循环而不是游标

### 5.4 避免游标
```sql
-- ❌ 避免使用游标（性能差）
DECLARE cursor1 CURSOR FOR SELECT ...
OPEN cursor1;
FETCH NEXT FROM cursor1 INTO ...
WHILE @@FETCH_STATUS = 0
BEGIN
    -- 逐行处理
    FETCH NEXT FROM cursor1 INTO ...
END;
CLOSE cursor1;
DEALLOCATE cursor1;

-- ✅ 优先使用集合操作（性能好）
INSERT INTO TargetTable (...)
SELECT ... FROM SourceTable WHERE ...;
```

---

## 6. 存储过程创建模式

### 6.1 禁止使用的模式

❌ **禁止使用 DROP + CREATE 模式**：
```sql
-- 禁止！会丢失权限和依赖关系
IF EXISTS (SELECT * FROM sys.objects WHERE ...)
DROP PROCEDURE [dbo].[ProcName]
GO

CREATE PROCEDURE [dbo].[ProcName] ...
```

❌ **禁止使用 IF NOT EXISTS + CREATE 模式**：
```sql
-- 禁止！可能覆盖正在使用的存储过程
IF NOT EXISTS (SELECT * FROM sys.objects WHERE ...)
BEGIN
    CREATE PROCEDURE [dbo].[ProcName] ...
END
```

### 6.2 推荐使用的模式

✅ **直接使用 create  PROCEDURE**：
```sql
-- 推荐！保留权限，安全修改
create PROCEDURE [dbo].[ProcName]
    @Param1 INT,
    @Param2 NVARCHAR(50)
AS
BEGIN
    -- 逻辑
END
GO
```

**说明**：
- 如果存储过程不存在，手动创建一次后再使用 create  
- 避免自动创建，防止覆盖正在使用的存储过程

---

## 7. 标准存储过程模板

### 7.1 SaveData 存储过程
```sql
ALTER PROCEDURE [dbo].[{表名}SaveData]
    -- 系统固定接口参数
    @I_ReturnMessage      NVARCHAR(MAX) = '' OUTPUT,
    @I_IsNewRow           BIT = 0 OUTPUT,
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT,
    @I_LanguageId         CHAR(1) = '1',
    @I_PlugInCommand      VARCHAR(5) = '',
    @I_OrBitUserId        CHAR(12) = '',
    @I_OrBitUserName      NVARCHAR(100) = '',
    @I_ResourceId         CHAR(12) = '',
    @I_ResourceName       NVARCHAR(100) = '',
    @I_PKId               CHAR(12) = '',
    @I_SourcePKId         CHAR(12) = '',
    @I_ParentPKId         CHAR(12) = '',
    @I_Parameter          NVARCHAR(100) = '',
    
    -- 业务字段参数
    @Field1 NVARCHAR(50) = '',
    @Field2 NVARCHAR(100) = ''
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        
        -- 初始化
        SET @I_ReturnMessage = '';
        SET @I_IsNewRow = 0;
        SET @I_ExceptionFieldName = '';
        
        -- 检查主键
        IF LTRIM(@I_PKId) = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:No PKId applied';
            RETURN -1;
        END;
        
        -- 判断新增还是更新
        IF NOT EXISTS (SELECT 1 FROM {表名} WHERE {表名}Id = @I_PKId)
        BEGIN
            -- 新增
            INSERT INTO {表名} ({表名}Id, Field1, Field2, CreateDate, ModifyDate)
            VALUES (@I_PKId, @Field1, @Field2, GETDATE(), GETDATE());
            
            SET @I_IsNewRow = 1;
        END
        ELSE
        BEGIN
            -- 更新
            UPDATE {表名} SET
                Field1 = @Field1,
                Field2 = @Field2,
                ModifyDate = GETDATE()
            WHERE {表名}Id = @I_PKId;
        END;
        
        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        
        INSERT INTO dbo.SqlProcedureIssueLog (
            ProcName, IssueType, StepCode, Message, 
            ErrNumber, ErrLine, ErrMessage, OrBitUserId
        )
        VALUES (
            '{表名}SaveData', N'SQL_EXCEPTION', N'CATCH', 
            N'{表名}保存异常', @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId
        );
        
        SET @I_ReturnMessage = 'ServerMessage:' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO
```

---

---

> **重要提示**：违反本规则可能导致存储过程运行失败、性能低下或覆盖正在使用的代码。 
