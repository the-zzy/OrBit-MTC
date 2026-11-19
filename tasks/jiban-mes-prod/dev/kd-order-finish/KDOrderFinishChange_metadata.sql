-- 基板正式。给国外 CKD 订单（KDYN）加上「变更完成状态」按钮。
-- 按钮挂在现有按钮组 MFG1000000XJ。过程 KDOrderFinishChangeDoMethod 需要先建好。

DECLARE @MethodId CHAR(12) = '';
DECLARE @TextId CHAR(12) = '';

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SysMetadataMethod
    WHERE MetadataFieldGroupId = 'MFG1000000XJ'
      AND MethodName = N'KDOrderFinishChange'
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
        @MethodId, 'MFG1000000XJ', '11', N'KDOrderFinishChange', N'KDOrderFinishChangeDoMethod',
        1, N'确认变更该散件订单的完成状态？', 0, 1,
        N'', N'', N'', N'',
        0, N'', N'', N'',
        0, 0, N'', N'', N'',
        0, 0, 0, 0, N'', N'',
        0, 0, N'', 0, N'', GETDATE()
    );
END;

UPDATE dbo.SysMetadataMethod
SET IsAcceptMainViewAsParameter = 0,
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
  AND MethodName = N'KDOrderFinishChange';

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SysText
    WHERE TextOwner = N'[Public Text]'
      AND TextModule = N'KDOrderFinishChange'
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
        @TextId, N'[Public Text]', N'KDOrderFinishChange', N'',
        N'KDOrderFinishChange', N'变更完成状态', GETDATE(), 0
    );
END;
GO
