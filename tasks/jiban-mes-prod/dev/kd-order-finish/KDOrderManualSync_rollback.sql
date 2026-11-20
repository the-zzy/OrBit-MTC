-- 基板正式。撤销「手动同步数据」按钮。
-- 先删元对象按钮和文本，再删过程。

DELETE FROM dbo.SysMetadataMethod
WHERE MetadataFieldGroupId = 'MFG1000000XJ'
  AND MethodName = N'KDOrderManualSync';

DELETE FROM dbo.SysText
WHERE TextOwner = N'[Public Text]'
  AND TextModule = N'KDOrderManualSync';

IF OBJECT_ID(N'dbo.KDOrderManualSyncDoMethod', N'P') IS NOT NULL
    DROP PROCEDURE dbo.KDOrderManualSyncDoMethod;
GO
