# 调用外部API函数 (CallAPI)

## 功能
调用外部HTTP API接口

## SQL代码

### 方法1：使用CLR（推荐）
```sql
-- 需要先创建CLR程序集和函数
-- 调用示例
DECLARE @url NVARCHAR(500) = 'http://api.example.com/data';
DECLARE @method NVARCHAR(10) = 'POST';
DECLARE @body NVARCHAR(MAX) = '{"key":"value"}';
DECLARE @response NVARCHAR(MAX);

EXEC dbo.CLR_HttpRequest
    @url = @url,
    @method = @method,
    @body = @body,
    @response = @response OUTPUT;

SELECT @response;
```

### 方法2：使用Ole Automation（兼容方案）
```sql
DECLARE @url NVARCHAR(500) = 'http://api.example.com/data';
DECLARE @obj INT;
DECLARE @response NVARCHAR(MAX);

-- 创建对象
EXEC sp_OACreate 'MSXML2.ServerXMLHTTP', @obj OUT;

-- 打开连接
EXEC sp_OAMethod @obj, 'open', NULL, 'GET', @url, false;

-- 发送请求
EXEC sp_OAMethod @obj, 'send';

-- 获取响应
EXEC sp_OAGetProperty @obj, 'responseText', @response OUT;

-- 销毁对象
EXEC sp_OADestroy @obj;

SELECT @response;
```

## 参数说明

| 参数 | 类型 | 说明 | 必填 |
|------|------|------|------|
| @url | NVARCHAR(500) | API地址 | 是 |
| @method | NVARCHAR(10) | HTTP方法（GET/POST/PUT/DELETE） | 是 |
| @body | NVARCHAR(MAX) | 请求体（JSON格式） | 否 |
| @headers | NVARCHAR(MAX) | 请求头 | 否 |
| @response | NVARCHAR(MAX) | 响应结果（OUTPUT） | 是 |

## 使用示例

### GET请求
```sql
DECLARE @url NVARCHAR(500) = 'http://api.example.com/users/123';
DECLARE @response NVARCHAR(MAX);

EXEC dbo.CallAPI
    @url = @url,
    @method = 'GET',
    @response = @response OUTPUT;

SELECT @response;
```

### POST请求
```sql
DECLARE @url NVARCHAR(500) = 'http://api.example.com/orders';
DECLARE @body NVARCHAR(MAX) = '{"orderId":"ORD001","quantity":10}';
DECLARE @response NVARCHAR(MAX);

EXEC dbo.CallAPI
    @url = @url,
    @method = 'POST',
    @body = @body,
    @response = @response OUTPUT;

SELECT @response;
```

### 带认证头的请求
```sql
DECLARE @url NVARCHAR(500) = 'http://api.example.com/data';
DECLARE @headers NVARCHAR(MAX) = '{"Authorization":"Bearer token123"}';
DECLARE @response NVARCHAR(MAX);

EXEC dbo.CallAPI
    @url = @url,
    @method = 'GET',
    @headers = @headers,
    @response = @response OUTPUT;

SELECT @response;
```

## 使用场景

- 数据同步到外部系统
- 调用第三方接口获取数据
- 与其他业务系统集成
- 推送数据到消息队列

## 注意事项

- Ole Automation 方式需要启用 `Ole Automation Procedures` 配置
- CLR 方式性能更好，但需要部署CLR程序集
- 注意API调用超时设置
- 做好异常处理和重试机制
- 敏感信息（如token）不要硬编码

## 启用Ole Automation（如需要）
```sql
sp_configure 'show advanced options', 1;
RECONFIGURE;
sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
```
