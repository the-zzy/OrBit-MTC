# 生成唯一 ObjectPKHeader

## 用途

为 SysObject 表生成唯一的 4 位 ObjectPKHeader，自动避免冲突。

## 存储过程定义

```sql
-- =============================================
-- 存储过程: SysGetUniquePKHeader
-- 说明: 生成唯一的4位ObjectPKHeader，自动检测并避免冲突
-- 参数:
--   @BasePKHeader - 基础PKHeader（4位），如 'VISN'
--   @UniquePKHeader - 输出的唯一PKHeader
-- 返回值:
--   0 - 成功生成唯一PKHeader
--   -1 - 冲突超过9次，需要手动指定
-- 日期: 2026-06-08
-- =============================================

IF EXISTS (SELECT * FROM dbo.sysobjects 
           WHERE id = OBJECT_ID(N'[dbo].[SysGetUniquePKHeader]') 
           AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
BEGIN
    DROP PROCEDURE [dbo].[SysGetUniquePKHeader];
END
GO

CREATE PROCEDURE [dbo].[SysGetUniquePKHeader]
    @BasePKHeader NVARCHAR(4),
    @UniquePKHeader NVARCHAR(4) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    
    -- 初始化
    DECLARE @Counter INT = 1
    SET @UniquePKHeader = @BasePKHeader
    
    -- 检查是否已存在，如果存在则递增最后一位数字
    WHILE EXISTS(SELECT 1 FROM SysObject WITH(NOLOCK) WHERE ObjectPKHeader = @UniquePKHeader)
    BEGIN
        SET @UniquePKHeader = LEFT(@BasePKHeader, 3) + CAST(@Counter AS NVARCHAR(1))
        SET @Counter = @Counter + 1
        
        -- 如果超过9，返回失败
        IF @Counter > 9
        BEGIN
            SET @UniquePKHeader = NULL
            PRINT '错误: ObjectPKHeader [' + @BasePKHeader + '] 冲突，已尝试到 ' + LEFT(@BasePKHeader, 3) + '9，请手动指定唯一的4位标识'
            RETURN -1
        END
    END
    
    PRINT 'ObjectPKHeader 已设置为: ' + @UniquePKHeader
    RETURN 0
END
GO
```

## 调用示例

### 示例 1: 成功生成（无冲突）

```sql
DECLARE @PKHeader NVARCHAR(4)
DECLARE @Result INT

EXEC @Result = SysGetUniquePKHeader 
    @BasePKHeader = 'VISN', 
    @UniquePKHeader = @PKHeader OUTPUT

IF @Result = 0
BEGIN
    PRINT '成功: 使用 PKHeader = ' + @PKHeader
    -- 插入到 SysObject
    INSERT INTO SysObject(ObjectId, ObjectName, ObjectDescription, ObjectRev, ObjectType, ObjectPKHeader)
    VALUES(@ObjectId, 'VisionTestResult', '视觉检测结果表', '10.00', 'O', @PKHeader)
END
ELSE
BEGIN
    PRINT '失败: 请手动指定唯一的 PKHeader'
    RETURN
END
```

### 示例 2: 自动递增（有冲突）

```sql
-- 假设 VISN 和 VIS1 已存在
DECLARE @PKHeader NVARCHAR(4)
EXEC SysGetUniquePKHeader @BasePKHeader = 'VISN', @UniquePKHeader = @PKHeader OUTPUT

-- 输出: ObjectPKHeader 已设置为: VIS2
-- @PKHeader 的值为 'VIS2'
```

### 示例 3: 超限处理（冲突过多）

```sql
-- 假设 VISN, VIS1, VIS2, ..., VIS9 都已存在
DECLARE @PKHeader NVARCHAR(4)
DECLARE @Result INT

EXEC @Result = SysGetUniquePKHeader @BasePKHeader = 'VISN', @UniquePKHeader = @PKHeader OUTPUT

IF @Result = -1
BEGIN
    PRINT '错误: ObjectPKHeader 冲突严重，建议使用其他前缀'
    PRINT '例如: VISR, VISI, VSNR 等'
    RETURN
END
```

## 标准模板代码块

### 在元对象配置脚本中使用

```sql
-- ====== 判断并创建存储过程 ======
IF NOT EXISTS (SELECT * FROM dbo.sysobjects 
               WHERE id = OBJECT_ID(N'[dbo].[SysGetUniquePKHeader]') 
               AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
BEGIN
    PRINT '存储过程 SysGetUniquePKHeader 不存在，正在创建...'
    
    EXEC('
    CREATE PROCEDURE [dbo].[SysGetUniquePKHeader]
        @BasePKHeader NVARCHAR(4),
        @UniquePKHeader NVARCHAR(4) OUTPUT
    AS
    BEGIN
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        
        DECLARE @Counter INT = 1
        SET @UniquePKHeader = @BasePKHeader
        
        WHILE EXISTS(SELECT 1 FROM SysObject WITH(NOLOCK) WHERE ObjectPKHeader = @UniquePKHeader)
        BEGIN
            SET @UniquePKHeader = LEFT(@BasePKHeader, 3) + CAST(@Counter AS NVARCHAR(1))
            SET @Counter = @Counter + 1
            
            IF @Counter > 9
            BEGIN
                SET @UniquePKHeader = NULL
                PRINT ''错误: ObjectPKHeader ['' + @BasePKHeader + ''] 冲突，已尝试到 '' + LEFT(@BasePKHeader, 3) + ''9，请手动指定唯一的4位标识''
                RETURN -1
            END
        END
        
        PRINT ''ObjectPKHeader 已设置为: '' + @UniquePKHeader
        RETURN 0
    END
    ')
    
    PRINT '存储过程 SysGetUniquePKHeader 创建成功'
END

-- ====== 判断ObjectId是否存在 ======
IF NOT EXISTS(SELECT ObjectId FROM SysObject WHERE ObjectName = '{ObjectName}')
BEGIN
    -- 创建SysObject对象
    EXEC [dbo].[SysGetObjectPKId]
        @ObjectName = 'SysObject',
        @PKID = @ObjectId OUTPUT

    -- 生成唯一的 ObjectPKHeader
    DECLARE @PKHeader NVARCHAR(4)
    DECLARE @PKHeaderResult INT
    
    EXEC @PKHeaderResult = [dbo].[SysGetUniquePKHeader]
        @BasePKHeader = '{PKHeader}',
        @UniquePKHeader = @PKHeader OUTPUT
    
    -- 检查是否成功生成
    IF @PKHeaderResult = -1 OR @PKHeader IS NULL
    BEGIN
        PRINT '错误: 无法生成唯一的 ObjectPKHeader，脚本终止'
        RETURN
    END

    INSERT INTO SysObject(ObjectId, ObjectName, ObjectDescription, ObjectRev, ObjectType, ObjectPKHeader)
    VALUES(@ObjectId, '{ObjectName}', '{对象描述}', '10.00', 'O', @PKHeader)
    
    PRINT 'SysObject 创建成功，ObjectPKHeader = ' + @PKHeader
END
ELSE
BEGIN
    SELECT @ObjectId = ObjectId FROM SysObject WHERE ObjectName = '{ObjectName}'
    PRINT 'SysObject 已存在，使用现有记录'
END
```

## 工作机制

1. **初始尝试**：使用用户提供的 `BasePKHeader`（如 `VISN`）
2. **冲突检测**：查询 `SysObject` 表检查是否已存在
3. **自动递增**：
   - 如果 `VISN` 已存在 → 尝试 `VIS1`
   - 如果 `VIS1` 已存在 → 尝试 `VIS2`
   - 依次递增到 `VIS9`
4. **超限保护**：如果递增到 9 仍冲突，返回 -1 并提示用户
5. **日志输出**：显示最终使用的 PKHeader

## 命名建议

| 表类型 | 建议前缀 | 示例 |
|--------|---------|------|
| 产品相关 | PROD | PROD, PRO1, PRO2 |
| 工单相关 | WKOR | WKOR, WKO1, WKO2 |
| 物料相关 | MATL | MATL, MAT1, MAT2 |
| 视觉检测 | VISN | VISN, VIS1, VIS2 |
| 质量相关 | QUAL | QUAL, QUA1, QUA2 |
| 仓储相关 | WHSE | WHSE, WHS1, WHS2 |

**原则**：
- 前 3 位有业务含义
- 最后 1 位用于冲突递增
- 避免使用已有的系统前缀

## 应用范围

- ✅ `query_metadata` - 查询元对象创建
- ✅ `standard_metadata_create` - 标准元对象创建（新建功能）
- ✅ `standard_metadata_update` - 标准元对象更新（如需新建 SysObject）

## 注意事项

1. **PKHeader 必须是 4 位**：不足或超过都会导致问题
2. **建议前缀有业务含义**：便于识别和管理
3. **数据库权限**：确保有创建存储过程的权限
4. **性能考虑**：使用 `WITH(NOLOCK)` 避免锁等待
5. **并发安全**：虽然有 WHILE 循环检查，但在高并发下仍可能冲突，建议在事务中使用

## 错误处理

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| 返回 -1 | 冲突超过9次 | 更换 BasePKHeader 前3位 |
| @UniquePKHeader 为 NULL | 存储过程执行失败 | 检查数据库连接和权限 |
| 权限错误 | 没有创建存储过程权限 | 联系 DBA 授权 |

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2026-06-08 | 初始版本，支持自动递增和冲突检测 |
