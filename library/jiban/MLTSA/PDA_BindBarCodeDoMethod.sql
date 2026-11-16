-- MLTSA / ZTEWXBarcodeBind: make one-to-many binding idempotent.
-- Deploy only after review. Historical duplicate rows must be cleaned separately.
ALTER PROCEDURE [dbo].[PDA_BindBarCodeDoMethod]
    @I_Sender NVARCHAR(200) = '',
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT,
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT,
    @I_LanguageId CHAR(1) = '1',
    @I_PlugInCommand VARCHAR(5) = '',
    @I_OrBitUserId CHAR(12) = '',
    @I_OrBitUserName NVARCHAR(100) = '',
    @I_ResourceId CHAR(12) = '',
    @I_ResourceName NVARCHAR(100) = '',
    @I_PKId CHAR(12) = '',
    @I_ParentPKId CHAR(12) = '',
    @I_Parameter NVARCHAR(100) = '',
    @Operator NVARCHAR(20) = '',
    @LotSN NVARCHAR(200) = '',
    @HideSn NVARCHAR(50) = '',
    @IsAgainBind BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF ISNULL(@LotSN, '') = '000'
    BEGIN
        SELECT '' AS operator, '' AS lotsn, '' AS hidesn;
        RETURN 0;
    END

    IF ISNULL(@LotSN, '') = '111'
    BEGIN
        SELECT '' AS lotsn, '解绑模式' AS hidesn;
        RETURN 0;
    END

    IF ISNULL(@Operator, '') = ''
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.PersonInfo WHERE PersonNumber = @LotSN AND IsActivity = 1)
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 请先输入有效的工号555';
            RETURN -1;
        END
        SELECT @LotSN AS Operator, '' AS lotsn;
        RETURN 0;
    END

    IF ISNULL(@HideSn, '') = '解绑模式'
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.WW_RMInventory(NOLOCK) WHERE lotsn = @LotSN)
        BEGIN
            UPDATE dbo.ProductTask SET RelateSN = '' WHERE RelateSN = @LotSN;
            SET @I_ReturnMessage = 'ServerMessage: 解绑成功';
            SELECT '' AS lotsn;
            RETURN 0;
        END

        IF EXISTS (SELECT 1 FROM dbo.ProductTask WHERE reelId = @LotSN)
        BEGIN
            UPDATE dbo.ProductTask SET RelateSN = '' WHERE reelId = @LotSN;
            SET @I_ReturnMessage = 'ServerMessage: 解绑成功';
            SELECT '' AS lotsn;
            RETURN 0;
        END

        SET @I_ReturnMessage = 'ServerMessage: 解绑失败';
        SELECT '' AS lotsn;
        RETURN -1;
    END

    IF ISNULL(@HideSn, '') = ''
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.VendorDeliveryItemLot WHERE LotSN = @LotSN AND IsCancel = 0)
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 请先扫描兆驰小包条码:' + @LotSN;
            RETURN -1;
        END

        IF EXISTS (SELECT 1 FROM dbo.ProductTask WHERE RelateSN = @LotSN)
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 兆驰小包条码[' + @LotSN + ']重复绑定';
            RETURN -1;
        END

        SELECT @LotSN AS HideSN, '' AS lotsn;
        RETURN 0;
    END

    IF LEFT(@LotSN, 3) = 'ZTE' AND CHARINDEX('&', @LotSN) > 0
    BEGIN
        SET @LotSN = SUBSTRING(@LotSN, 1, CHARINDEX('&', @LotSN) - 1);
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.ProductTask WHERE reelId = @LotSN)
    BEGIN
        EXEC dbo.usp_SyncProductTaskByReelidDoMethod
            @I_Sender = N'',
            @I_ReturnMessage = @I_ReturnMessage OUTPUT,
            @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
            @I_LanguageId = '',
            @I_PlugInCommand = '',
            @I_OrBitUserId = '',
            @I_OrBitUserName = N'',
            @I_ResourceId = '',
            @I_ResourceName = N'',
            @I_PKid = '',
            @I_ParentPKId = '',
            @I_Parameter = N'',
            @reelId = @LotSN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.ProductTask WHERE reelId = @LotSN)
    BEGIN
        SET @LotSN = SUBSTRING(@LotSN, CHARINDEX('&', @LotSN) + 1, LEN(@LotSN) - CHARINDEX('&', @LotSN));

        EXEC dbo.usp_SyncProductTaskByReelidDoMethod
            @I_Sender = N'',
            @I_ReturnMessage = @I_ReturnMessage OUTPUT,
            @I_ExceptionFieldName = @I_ExceptionFieldName OUTPUT,
            @I_LanguageId = '',
            @I_PlugInCommand = '',
            @I_OrBitUserId = '',
            @I_OrBitUserName = N'',
            @I_ResourceId = '',
            @I_ResourceName = N'',
            @I_PKid = '',
            @I_ParentPKId = '',
            @I_Parameter = N'',
            @reelId = @LotSN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.ProductTask WHERE reelId = @LotSN)
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage: 扫描的条码非reelid码[' + @LotSN + ']';
        RETURN -1;
    END

    IF EXISTS (SELECT 1 FROM dbo.ProductTask WHERE reelId = @LotSN AND ISNULL(RelateSN, '') <> '')
       AND @IsAgainBind = 0
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage: 外协条码[' + @LotSN + ']重复绑定11';
        RETURN -1;
    END

    DECLARE @prdname NVARCHAR(50) = '';
    DECLARE @productid CHAR(12) = '';
    DECLARE @itemno NVARCHAR(50) = '';
    DECLARE @zteDesc NVARCHAR(50) = '';
    DECLARE @zcDesc NVARCHAR(200) = '';

    SELECT @zcDesc = b.ProductDescription,
           @prdname = b.prdname,
           @productid = a.ProductId
    FROM dbo.WW_RMInventory a
    INNER JOIN product b ON b.ProductId = a.ProductId
    WHERE LotSN = @HideSn;

    DECLARE @str VARCHAR(200) = @LotSN;

    IF CHARINDEX('&', @LotSN) > 0
    BEGIN
        DECLARE @third_amp INT = CHARINDEX('&', @str, CHARINDEX('&', @str, CHARINDEX('&', @str) + 1) + 1);
        DECLARE @fourth_amp INT = CHARINDEX('&', @str, @third_amp + 1);
        SELECT @zteDesc = SUBSTRING(@str, @third_amp + 1, @fourth_amp - @third_amp - 1);

        IF CHARINDEX(@zteDesc, @zcDesc) = 0
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage: 中兴规格【' + @zteDesc + '】和兆驰规格[' + @zcDesc + ']不一致';
            RETURN -1;
        END
    END

    IF CHARINDEX('&', @LotSN) > 0
        SET @LotSN = SUBSTRING(@LotSN, 1, CHARINDEX(@LotSN, '&') - 1);

    SELECT @itemno = itemNo FROM dbo.ProductTask WHERE reelId = @LotSN;

    IF NOT EXISTS (SELECT 1 FROM dbo.Vendor_Product WHERE ProductId = @productid AND Vendor_ProductKey = @itemno)
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage: 中兴料号【' + @itemno + '】和兆驰料号[' + @prdname + ']不匹配';
        RETURN -1;
    END

    IF @IsAgainBind = 0
        UPDATE dbo.ProductTask
        SET relatesn = @HideSn, Operator = @Operator, createdate = GETDATE()
        WHERE reelId = @LotSN;

    IF @IsAgainBind = 1
    BEGIN
        SET XACT_ABORT ON;
        BEGIN TRY
            BEGIN TRANSACTION;

            -- Same request retried after a timeout must not create more rows.
            IF EXISTS
            (
                SELECT 1
                FROM dbo.ProductTask WITH (UPDLOCK, HOLDLOCK)
                WHERE reelId = @LotSN AND RelateSN = @HideSn
            )
            BEGIN
                COMMIT TRANSACTION;
                SET @I_ReturnMessage = 'ServerMessage: 条码【' + @HideSn + '】已绑定' + @LotSN + '，无需重复操作';
                SELECT '' AS LOTSN, '' AS HIDESN, 0 AS IsAgainBind;
                RETURN 0;
            END

            -- Copy one stable template row only, never every existing binding.
            INSERT INTO dbo.ProductTask
            (
                transactionId,
                requestId,
                externalorderkey,
                externalorderkey2,
                lpn,
                qty,
                itemNo,
                itemBarcode,
                whseId,
                reelId,
                LotSN,
                RelateSN,
                Operator,
                createdate
            )
            SELECT TOP (1)
                transactionId,
                requestId,
                externalorderkey,
                externalorderkey2,
                lpn,
                qty,
                itemNo,
                itemBarcode,
                whseId,
                reelId,
                LotSN,
                @HideSn,
                Operator,
                GETDATE()
            FROM dbo.ProductTask WITH (UPDLOCK, HOLDLOCK)
            WHERE reelId = @LotSN
            ORDER BY id;

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            THROW;
        END CATCH
    END

    SET @I_ReturnMessage = 'ServerMessage: 条码【' + @HideSn + '】绑定完成' + @LotSN;
    SELECT '' AS LOTSN, '' AS HIDESN, 0 AS IsAgainBind;
    RETURN 0;
END;
