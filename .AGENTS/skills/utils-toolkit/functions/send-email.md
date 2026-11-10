# 发送邮件函数 (SendEmail)

## 功能
直接调用库内 `API_ExportExcelAndSendMail`（`API_ExportExcel` + `API_SendMail`）。与 `CheckIGI/MexicoHTSEmails` 相同。

```sql
DECLARE @Json NVARCHAR(MAX);
DECLARE @Msg NVARCHAR(MAX);
DECLARE @FileName NVARCHAR(200) = N'报表名称';
DECLARE @Template NVARCHAR(200) = N'欧洲外销海尔订单数据模板.xlsx';

;WITH SheetDataCTE AS (
    SELECT 0 AS SheetNO,
           (SELECT * FROM ##YourExportTable FOR JSON PATH) AS SheetData
)
SELECT @Json = (
    SELECT 2 AS ExportType, @FileName AS FileName, @Template AS Template,
           (SELECT SheetNO, JSON_QUERY(SheetData) AS SheetData FROM SheetDataCTE FOR JSON PATH) AS JsonData
    FOR JSON PATH, INCLUDE_NULL_VALUES, WITHOUT_ARRAY_WRAPPER
);

EXEC dbo.API_ExportExcelAndSendMail
    @ExcelJson = @Json,
    @Subject = N'邮件主题',
    @Content = N'<html><body>正文</body></html>',
    @IsHtml = N'true',
    @Receiver = N'a@x.com;b@x.com',
    @I_ReturnMessage = @Msg OUTPUT;
```

## 参数

| 参数 | 说明 |
|------|------|
| @ExcelJson | ExportType=2 + Template + SheetData |
| @Subject / @Content | 邮件主题、正文 |
| @IsHtml | `true` / `false` |
| @Receiver | 收件人，分号分隔 |

## 仅发邮件（已有附件路径）

```sql
EXEC dbo.API_SendMail
    @Subject  = N'主题',
    @Content  = N'正文',
    @IsHtml   = N'true',
    @FilePath = N'\\share\file.xlsx',
    @Receiver = N'user@example.com',
    @I_ReturnMessage = @Msg OUTPUT;
```

## 联调

- DataExport 联调示例：`{事业部}/开发/数据导出/DataExportEngine_MailTest.sql`（见 output-path-convention.md）
- 示例：`Example_ExportExcelAndSendMail`

模板文件放：`\\mtcs9222\信息中心\04 MES组\10 Excel模板\`
