# 企业微信推送函数

## 函数1：API_SendWXGroupImage（表格形式推送）

### 功能
通过企业微信机器人发送群消息，以图片表格形式展示数据

### SQL代码

```sql
-- 企业微信表格推送
DECLARE @JsonData NVARCHAR(MAX) = '';
DECLARE @title NVARCHAR(50) = '标题';
DECLARE @Key NVARCHAR(50) = '机器人Key';
DECLARE @I_ReturnMessage NVARCHAR(MAX) = '';

-- 构造消息内容（JSON格式）
SELECT @JsonData = (
    SELECT 字段1, 字段2, 字段3
    FROM 表名
    FOR JSON PATH
);

-- 发送
EXEC dbo.API_SendWXGroupImage
    @Key = @Key,
    @title = @title,
    @JsonData = @JsonData,
    @I_ReturnMessage = @I_ReturnMessage OUTPUT;
```

### 参数说明

| 参数 | 类型 | 说明 | 必填 |
|------|------|------|------|
| @Key | NVARCHAR(50) | 企业微信机器人Key | 是 |
| @title | NVARCHAR(50) | 消息标题 | 是 |
| @JsonData | NVARCHAR(MAX) | 消息内容（JSON格式） | 是 |
| @I_ReturnMessage | NVARCHAR(MAX) | 返回消息（OUTPUT） | 是 |

### 使用场景

- 数据报表推送（以表格形式展示）
- 统计数据汇总
- 需要展示多列数据的场景

---

## 函数2：API_SendWXGroupMsg（文本消息推送+@用户）

### 功能
通过企业微信机器人发送文本消息，支持@指定用户

### SQL代码

```sql
-- 企业微信文本消息推送
DECLARE @Key NVARCHAR(50) = '机器人Key';
DECLARE @Msg NVARCHAR(MAX) = '消息内容';
DECLARE @Workcode VARCHAR(500) = '1003153,1003154'; -- 需要@的用户工号，逗号分隔
DECLARE @Type VARCHAR(10) = 'text';
DECLARE @ReturnMessage NVARCHAR(100) = '';

-- 发送
EXEC dbo.API_SendWXGroupMsg
    @Key = @Key,
    @Msg = @Msg,
    @Workcode = @Workcode,
    @Type = @Type,
    @ReturnMessage = @ReturnMessage OUTPUT;

SELECT @ReturnMessage AS 返回结果;
```

### 参数说明

| 参数 | 类型 | 说明 | 必填 |
|------|------|------|------|
| @Key | VARCHAR(100) | 企业微信机器人Key | 是 |
| @Msg | NVARCHAR(MAX) | 消息内容（文本） | 是 |
| @Workcode | VARCHAR(500) | 需要@的用户工号，多个用逗号分隔 | 否 |
| @Type | VARCHAR(10) | 消息类型（通常为'text'） | 是 |
| @ReturnMessage | NVARCHAR(100) | 返回消息（OUTPUT） | 是 |

### 使用场景

- 需要@特定用户的提醒通知
- 任务分配通知
- 异常报警（需要@责任人）
- 日常工作提醒

---

---

## 函数3：API_SendWXGroupImageWithMerge（支持合并单元格的表格图片推送）

### 功能
通过企业微信机器人发送群消息，以**支持合并单元格**的图片表格形式展示数据，支持分组合并、二级合并、单元格着色

### SQL代码

```sql
-- 企业微信表格推送（支持合并单元格）
DECLARE @JsonData NVARCHAR(MAX) = '';
DECLARE @title NVARCHAR(50) = '标题';
DECLARE @Key NVARCHAR(50) = '机器人Key';
DECLARE @I_ReturnMessage NVARCHAR(MAX) = '';

-- 构造消息内容（JSON格式，可包含颜色配置）
SELECT @JsonData = (
    SELECT 
        字段1, 字段2, 字段3,
        -- 可选：设置单元格背景色
        CASE WHEN 条件 THEN '{"字段1":"red"}' ELSE '{}' END AS cellColor,
        -- 可选：设置字体颜色
        CASE WHEN 条件 THEN '{"字段2":"blue"}' ELSE '{}' END AS cellFontColor
    FROM 表名
    FOR JSON PATH
);

-- 发送（带合并配置）
EXEC dbo.API_SendWXGroupImageWithMerge
    @Key = @Key,
    @title = @title,
    @JsonData = @JsonData,
    @autoMergeColumns = N'字段1,字段2',  -- 一级分组合并列
    @secondaryMergeColumns = N'字段3',   -- 二级合并列（可选）
    @color = N'blue',                    -- 表头颜色（可选）
    @subtitle = N'',                     -- 副标题（可选）
    @mergeCells = N'',                   -- 手动合并配置（可选）
    @I_ReturnMessage = @I_ReturnMessage OUTPUT;
```

### 参数说明

| 参数 | 类型 | 说明 | 必填 |
|------|------|------|------|
| @Key | NVARCHAR(50) | 企业微信机器人Key | 是 |
| @title | NVARCHAR(50) | 消息标题 | 是 |
| @JsonData | NVARCHAR(MAX) | 消息内容（JSON格式） | 是 |
| @autoMergeColumns | NVARCHAR(200) | 一级分组合并列名（逗号分隔） | 否 |
| @secondaryMergeColumns | NVARCHAR(200) | 二级合并列名（逗号分隔） | 否 |
| @color | NVARCHAR(20) | 表头背景色（red/blue/green等） | 否 |
| @subtitle | NVARCHAR(200) | 副标题（支持彩色文本） | 否 |
| @mergeCells | NVARCHAR(500) | 手动合并配置 | 否 |
| @I_ReturnMessage | NVARCHAR(MAX) | 返回消息（OUTPUT） | 是 |

### 合并逻辑说明

#### 一级合并（autoMergeColumns）
按指定列的组合值分组，组内的这些列会被合并。

**示例**：
```sql
@autoMergeColumns = N'拉别,标准人力配置'

-- 数据：
-- 行1: 拉别=Z301, 标准人力=54
-- 行2: 拉别=Z301, 标准人力=54  ← 与行1组合键相同
-- 行3: 拉别=Z302, 标准人力=60  ← 组合键不同

-- 结果：
-- 行1和行2的"拉别"和"标准人力配置"列都会合并
-- 行3独立显示
```

#### 二级合并（secondaryMergeColumns）
在分组内部，对指定列按连续相同值进行合并。

**示例**：
```sql
@autoMergeColumns = N'拉别,标准人力配置'
@secondaryMergeColumns = N'国家'

-- 数据：
-- 行1: 拉别=Z301, 国家="",   标准人力=0
-- 行2: 拉别=Z301, 国家="",   标准人力=0
-- 行3: 拉别=Z301, 国家="美国", 标准人力=0

-- 结果：
-- "拉别"和"标准人力配置"列：3行全部合并（一级）
-- "国家"列：行1、2合并，行3独立（二级）
```

### 颜色配置

#### 支持的颜色
**中文**：红色、绿色、蓝色、黄色、黑色、白色、灰色、橙色、粉色、青色、紫色、棕色  
**英文**：red, green, blue, yellow, black, white, gray, orange, pink, cyan, purple

#### cellColor 和 cellFontColor
在JSON数据中添加特殊字段控制单元格样式：

```sql
SELECT 
    列1, 列2,
    -- 设置单元格背景色
    CASE 
        WHEN 列1 > 50 THEN '{"列1":"red"}'
        ELSE '{"列1":"green"}'
    END AS cellColor,
    -- 设置字体颜色
    CASE 
        WHEN 列2 = '美国' THEN '{"列2":"blue"}'
        ELSE '{}'
    END AS cellFontColor
FROM 表名
FOR JSON PATH
```

### 完整示例

#### 示例1：每日排产数据推送（带分组合并）

```sql
DECLARE @ReturnMsg NVARCHAR(MAX);
DECLARE @JsonData NVARCHAR(MAX);
DECLARE @WXKey NVARCHAR(50) = '你的机器人Key';
DECLARE @ScheduleDate DATE = CAST(GETDATE() AS DATE);

-- 构造数据
SELECT @JsonData = (
    SELECT 
        序号, 拉别, 尺寸, 结构, 国家,
        [客户+国家+机型+方案+背光] AS 客户机型方案背光,
        模组, 装配, 测试, 包装, 专机辅助, 合计, 标准人力配置,
        -- 设置美国订单为红色字体
        CASE 
            WHEN 国家 = '美国' THEN '{"国家":"red"}' 
            ELSE '{}' 
        END AS cellFontColor
    FROM #排产数据
    FOR JSON PATH
);

-- 推送
EXEC dbo.API_SendWXGroupImageWithMerge
    @Key = @WXKey,
    @title = N'Z线体排产人力配置-' + CAST(@ScheduleDate AS NVARCHAR(10)),
    @JsonData = @JsonData,
    @autoMergeColumns = N'拉别,标准人力配置',
    @secondaryMergeColumns = N'国家',
    @color = N'blue',
    @I_ReturnMessage = @ReturnMsg OUTPUT;

SELECT @ReturnMsg AS 推送结果;
```

#### 示例2：异常数据报警（带颜色）

```sql
DECLARE @ReturnMsg NVARCHAR(MAX);
DECLARE @JsonData NVARCHAR(MAX);

-- 构造异常数据（根据异常等级设置颜色）
SELECT @JsonData = (
    SELECT 
        工单号, 产品名称, 异常类型, 异常数量,
        -- 根据异常等级设置颜色
        CASE 
            WHEN 异常数量 >= 100 THEN '{"异常数量":"red"}'
            WHEN 异常数量 >= 50 THEN '{"异常数量":"yellow"}'
            ELSE '{"异常数量":"green"}'
        END AS cellColor,
        -- 高异常数量白色字体
        CASE 
            WHEN 异常数量 >= 100 THEN '{"异常数量":"white"}'
            ELSE '{}'
        END AS cellFontColor
    FROM #异常数据
    FOR JSON PATH
);

-- 推送报警
EXEC dbo.API_SendWXGroupImageWithMerge
    @Key = '报警机器人Key',
    @title = N'生产异常报警',
    @JsonData = @JsonData,
    @color = N'red',
    @subtitle = N'红色:严重 黄色:警告 绿色:一般',
    @I_ReturnMessage = @ReturnMsg OUTPUT;
```

#### 示例3：完成率汇总（带分组和颜色）

```sql
DECLARE @ReturnMsg NVARCHAR(MAX);
DECLARE @JsonData NVARCHAR(MAX);

-- 构造汇总数据
SELECT @JsonData = (
    SELECT 
        部门, 产品类型, 目标产量, 实际产量, 完成率,
        -- 根据完成率设置颜色
        CASE 
            WHEN 完成率 >= 100 THEN '{"完成率":"green"}'
            WHEN 完成率 >= 80 THEN '{"完成率":"yellow"}'
            ELSE '{"完成率":"red"}'
        END AS cellColor
    FROM (
        SELECT 
            部门, 产品类型,
            SUM(目标产量) AS 目标产量,
            SUM(实际产量) AS 实际产量,
            CAST(SUM(实际产量) * 100.0 / NULLIF(SUM(目标产量), 0) AS INT) AS 完成率
        FROM #生产数据
        GROUP BY 部门, 产品类型
    ) t
    ORDER BY 部门, 产品类型
    FOR JSON PATH
);

-- 推送（按部门分组合并）
EXEC dbo.API_SendWXGroupImageWithMerge
    @Key = @WXKey,
    @title = N'每日产量汇总-' + CONVERT(VARCHAR(10), GETDATE(), 120),
    @JsonData = @JsonData,
    @autoMergeColumns = N'部门',
    @color = N'blue',
    @I_ReturnMessage = @ReturnMsg OUTPUT;
```

### 使用场景

- ✅ 需要合并相同数据的报表（如按线体、部门分组）
- ✅ 需要根据数据值动态设置颜色（异常高亮、完成率标识）
- ✅ 复杂的多层级数据展示
- ✅ 每日排产、生产汇总等定期推送

### 与函数1的区别

| 功能 | API_SendWXGroupImage | API_SendWXGroupImageWithMerge |
|------|---------------------|-------------------------------|
| 基础表格 | ✅ | ✅ |
| 单元格合并 | ❌ | ✅ |
| 分组合并 | ❌ | ✅ |
| 二级合并 | ❌ | ✅ |
| 单元格着色 | ❌ | ✅ |
| 字体颜色 | ❌ | ✅ |
| 推荐场景 | 简单表格 | 复杂报表 |

---

## 使用建议

### 选择哪个函数？

- **使用 API_SendWXGroupImage**：简单表格数据展示，无需合并和特殊样式
- **使用 API_SendWXGroupImageWithMerge**：需要合并单元格、颜色标识的复杂报表
- **使用 API_SendWXGroupMsg**：需要@用户、发送文本通知、个性化消息

### 完整示例：每日设备点检通知

```sql
-- 构建消息内容
DECLARE @MessageContent NVARCHAR(MAX) = '';
SET @MessageContent = N'【设备日常点检通知】' + CHAR(10) +
    N'日期：2026-06-05' + CHAR(10) + CHAR(10) +
    N'您负责的设备点检情况：' + CHAR(10) +
    N'✅ 已点检：2台' + CHAR(10) +
    N'❌ 未点检：3台' + CHAR(10) + CHAR(10) +
    N'未点检设备清单：' + CHAR(10) +
    N'1. EQ001 - 设备描述1' + CHAR(10) +
    N'2. EQ002 - 设备描述2';

-- 发送并@负责人
DECLARE @ReturnMsg NVARCHAR(100);
EXEC dbo.API_SendWXGroupMsg
    @Key = '99c9e820-e454-483c-a75c-4ed3f22de496',
    @Msg = @MessageContent,
    @Workcode = '1003153', -- 负责人工号
    @Type = 'text',
    @ReturnMessage = @ReturnMsg OUTPUT;
```

## 注意事项

- 企业微信机器人Key需要从企业微信后台获取
- 消息发送频率有限制，避免短时间大量推送
- @Workcode 必须是有效的员工工号
- JSON格式数据必须符合JSON规范
- 推送失败时检查返回消息排查原因
