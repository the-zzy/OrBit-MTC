-- 基板正式。给国外 CKD 订单（KDYN）加上「手动同步数据」按钮。
-- 按钮挂在 KDOrderInfo 按钮组 MFG1000000XJ，排在「变更完成状态」(11) 之后。
-- 过程 KDOrderManualSyncDoMethod 需要先建好。

DECLARE @MethodId CHAR(12) = '';
DECLARE @TextId CHAR(12) = '';

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SysMetadataMethod
    WHERE MetadataFieldGroupId = 'MFG1000000XJ'
      AND MethodName = N'KDOrderManualSync'
)
BEGIN
    EXEC dbo.SysGetObjectPKId
        @ObjectId = '',
        @ObjectName = N'SysMetadataMethod',
        @PKID = @MethodId OUTPUT;

    INSERT INTO dbo.SysMetadataMethod
    (
        MetadataMethodId, MetadataFieldGroupId, MethodSequence, MethodName, SQLDoMethod,
        IsBeforeRunningConfirm, PromptMessage, IsAcceptMainViewAsParameter, IsRefreshTreeView,
        DefaultChart, MainViewParameter, AccessCode, DialogParameter,
        IsAutoRunQuery, QueryMargedField, QuerySummaryField, QueryColorControl,
        IsShowRowIndex, IsRunSubQuery, SubQuerySQLMethod, SubQueryParameter, SubQueryColorControl,
        IsPrintMethod, IsPreview, LabelLeftMargin, LabelTopMargin, LabelFileSP, LabelFileName,
        IsWriteToPort, IsShowDataSetWindow, PortNumber, IsRunWithSub, UDialogParameter, CreateDate
    )
    VALUES
    (
        @MethodId, 'MFG1000000XJ', '12', N'KDOrderManualSync', N'KDOrderManualSyncDoMethod',
        1, N'将增量同步总装数据到全部未完成订单，是否继续？', 0, 1,
        N'', N'', N'', N'',
        0, N'', N'', N'',
        0, 0, N'', N'', N'',
        0, 0, 0, 0, N'', N'',
        0, 0, N'', 0, N'', GETDATE()
    );
END;

UPDATE dbo.SysMetadataMethod
SET IsBeforeRunningConfirm = 1,
    PromptMessage = N'将增量同步总装数据到全部未完成订单，是否继续？',
    IsRefreshTreeView = 1,
    IsAcceptMainViewAsParameter = 0,
    DefaultChart = N'',
    MainViewParameter = N'',
    AccessCode = N'',
    DialogParameter = N'',
    IsAutoRunQuery = 0,
    QueryMargedField = N'',
    QuerySummaryField = N'',
    QueryColorControl = N'',
    IsShowRowIndex = 0,
    IsRunSubQuery = 0,
    SubQuerySQLMethod = N'',
    SubQueryParameter = N'',
    SubQueryColorControl = N'',
    IsPrintMethod = 0,
    IsPreview = 0,
    LabelLeftMargin = 0,
    LabelTopMargin = 0,
    LabelFileSP = N'',
    LabelFileName = N'',
    IsWriteToPort = 0,
    IsShowDataSetWindow = 0,
    PortNumber = N'',
    IsRunWithSub = 0,
    UDialogParameter = N''
WHERE MetadataFieldGroupId = 'MFG1000000XJ'
  AND MethodName = N'KDOrderManualSync';

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SysText
    WHERE TextOwner = N'[Public Text]'
      AND TextModule = N'KDOrderManualSync'
)
BEGIN
    EXEC dbo.SysGetObjectPKId
        @ObjectId = '',
        @ObjectName = N'SysText',
        @PKID = @TextId OUTPUT;

    INSERT INTO dbo.SysText
    (
        SysTextId, TextOwner, TextModule, TextControl, Text1, Text2, CreateDate, Protected
    )
    VALUES
    (
        @TextId, N'[Public Text]', N'KDOrderManualSync', N'',
        N'KDOrderManualSync', N'手动同步数据', GETDATE(), 0
    );
END;

UPDATE dbo.SysText
SET Text2 = N'手动同步数据'
WHERE TextOwner = N'[Public Text]'
  AND TextModule = N'KDOrderManualSync';
GO
