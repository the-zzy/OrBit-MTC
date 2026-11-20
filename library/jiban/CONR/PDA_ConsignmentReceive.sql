-- =============================================
-- Author:		<Wang RT>
-- Create date: <2024-01-01>
-- Description:	工单发料撤销扫描
-- =============================================
CREATE PROCEDURE [dbo].[PDA_ConsignmentReceive]
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKId CHAR(12) = '' ,				--主键
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = '' , 		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
    @VendorDeliveryName NVARCHAR(50) = '' ,
    @CellName NVARCHAR(50) = '' ,
    @QRCode NVARCHAR(50) = '' ,
    @BoxOrLotSN NVARCHAR(50) = ''
AS
BEGIN

    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	SET @I_ReturnMessage = 'ServerMessage:功能已停用！'
	RETURN -1;

    DECLARE @ProductId CHAR(12) = '';
    DECLARE @DeliveryUOMId CHAR(12) = '';
    DECLARE @VendorDeliveryId CHAR(12) = '';
    DECLARE @VendorDeliveryItemId CHAR(12) = '';
    DECLARE @FactoryId CHAR(12) = 'FAC1000000U3';
    DECLARE @VendorId CHAR(12) = 'VEN100001CQ2';
    DECLARE @CellId CHAR(12) = '';
    DECLARE @VendorDeliveryResId CHAR(12) = '';
	DECLARE @WorkcenterId CHAR(12) = 'WKC1000001VB';

    DECLARE @ProductName NVARCHAR(50) = '';
    DECLARE @LGORT NVARCHAR(50) = '8057';
    DECLARE @LineSequence NVARCHAR(50) = '';
    DECLARE @VendorName NVARCHAR(50) = 'KJB08';
    DECLARE @VendorDescription NVARCHAR(100) = '华为技术有限公司';
    DECLARE @DeliveryOrderName NVARCHAR(50) = '';

    DECLARE @LotQty DECIMAL(18, 4) = 0;
    DECLARE @ItemQtyReceived DECIMAL(18, 4) = 0;

    DECLARE @TempVendorDeliveryItem TABLE
        (
          VendorDeliveryItemId CHAR(12) DEFAULT '' ,
          LineSequence NVARCHAR(50) DEFAULT '' ,
          ProductName NVARCHAR(50) DEFAULT '' ,
          ItemQtyReceived FLOAT DEFAULT 0
        );

    SET @QRCode = REPLACE(REPLACE(REPLACE(@QRCode, CHAR(0x1E), ''), CHAR(0x1D), ''), CHAR(0x04), '');

    IF @I_Sender = 'DeliveryReceive'
    BEGIN

        IF ISNULL(@VendorDeliveryName, '') <> ''
        BEGIN
            INSERT  INTO @TempVendorDeliveryItem ( VendorDeliveryItemId, LineSequence, ProductName, ItemQtyReceived )
                    SELECT  b.VendorDeliveryItemId, b.LineSequence, c.prdname, b.ItemQtyReceived
                    FROM    dbo.VendorDelivery a
                    INNER JOIN dbo.VendorDeliveryItem b ON b.VendorDeliveryId = a.VendorDeliveryId
                    INNER JOIN dbo.Product c ON c.ProductId = b.ProductId
                    WHERE   a.VendorDeliveryName = @VendorDeliveryName;
        END;

        IF LEFT(@QRCode, 3) <> '[)>'
        BEGIN
            SELECT  *
            FROM    @TempVendorDeliveryItem;

            SELECT  '' AS QRCode, '' AS BoxOrLotSN;
            SET @I_ExceptionFieldName = 'QRCode';
            SET @I_ReturnMessage = 'ServerMessage:二维码起始位不符合要求【[)>】，请检查！';
            RETURN -1;
        END;

        IF LEN(@BoxOrLotSN) < 19
        BEGIN
            SELECT  *
            FROM    @TempVendorDeliveryItem;

            SELECT  '' AS QRCode, '' AS BoxOrLotSN;
            SET @I_ExceptionFieldName = 'QRCode';
            SET @I_ReturnMessage = 'ServerMessage:条形码长度低于19位，请检查！';
            RETURN -1;
        END;

        IF LEFT(@BoxOrLotSN, 1) <> 'P'
        BEGIN
            SELECT  *
            FROM    @TempVendorDeliveryItem;

            SELECT  '' AS QRCode, '' AS BoxOrLotSN;
            SET @I_ExceptionFieldName = 'QRCode';
            SET @I_ReturnMessage = 'ServerMessage:二维码起始位不符合要求【P】，请检查！';
            RETURN -1;
        END;
		
        SET @ProductName = SUBSTRING(@QRCode, CHARINDEX('H', @QRCode) + 1,
                                     LEN(@QRCode) - CHARINDEX('H', @QRCode) - CHARINDEX('Q', REVERSE(@QRCode)));

        SET @LotQty = TRY_CAST(RIGHT(@QRCode, CHARINDEX('Q', REVERSE(@QRCode)) - 1) AS DECIMAL(18, 4));

        IF ISNULL(@ProductName, '') = ''
        BEGIN
            SELECT  *
            FROM    @TempVendorDeliveryItem;

            SELECT  '' AS QRCode, '' AS BoxOrLotSN;
            SET @I_ExceptionFieldName = 'QRCode';
            SET @I_ReturnMessage = 'ServerMessage:二维码未解析到对应的料号，请检查！';
            RETURN -1;
        END;

        IF ISNULL(@LotQty, 0) = 0
        BEGIN
            SELECT  *
            FROM    @TempVendorDeliveryItem;

            SELECT  '' AS QRCode, '' AS BoxOrLotSN;
            SET @I_ExceptionFieldName = 'QRCode';
            SET @I_ReturnMessage = 'ServerMessage:二维码未解析到对应的数量，请检查！';
            RETURN -1;
        END;

        SET @ProductName = 'K7JB' + @ProductName;

        SELECT  @ProductId = ProductId, @DeliveryUOMId = PurchaseUOMId
        FROM    dbo.Product
        WHERE   prdname = @ProductName;

        IF ISNULL(@ProductId, '') = ''
        BEGIN
            SELECT  *
            FROM    @TempVendorDeliveryItem;

            SELECT  '' AS QRCode, '' AS BoxOrLotSN;
            SET @I_ExceptionFieldName = 'QRCode';
            SET @I_ReturnMessage = 'ServerMessage:料号[' + @ProductName + ']在系统中不存在，请检查！';
            RETURN -1;
        END;

        IF ISNULL(@CellName, '') <> ''
        BEGIN
            SELECT  @CellId = CellId
            FROM    dbo.Cell
            WHERE   CellName = @CellName;
        END;

        IF EXISTS ( SELECT  1
                    FROM    dbo.VendorDeliveryItemLot
                    WHERE   LotSN = @BoxOrLotSN )
        BEGIN
            IF ISNULL(@VendorDeliveryName, '') = ''
            BEGIN
                SELECT  @VendorDeliveryName = c.VendorDeliveryName
                FROM    dbo.VendorDeliveryItemLot a
                INNER JOIN dbo.VendorDeliveryItem b ON b.VendorDeliveryItemId = a.VendorDeliveryItemId
                INNER JOIN dbo.VendorDelivery c ON c.VendorDeliveryId = b.VendorDeliveryId
                WHERE   a.LotSN = @BoxOrLotSN AND c.VendorDeliveryStatus = '00';

                INSERT  INTO @TempVendorDeliveryItem ( VendorDeliveryItemId, LineSequence, ProductName, ItemQtyReceived )
                        SELECT  b.VendorDeliveryItemId, b.LineSequence, c.prdname, b.ItemQtyReceived
                        FROM    dbo.VendorDelivery a
                        INNER JOIN dbo.VendorDeliveryItem b ON b.VendorDeliveryId = a.VendorDeliveryId
                        INNER JOIN dbo.Product c ON c.ProductId = b.ProductId
                        WHERE   a.VendorDeliveryName = @VendorDeliveryName;
            END;
			
            SELECT  *
            FROM    @TempVendorDeliveryItem;

            SELECT  @VendorDeliveryName AS VendorDeliveryName, '' AS QRCode, '' AS BoxOrLotSN;
            SET @I_ExceptionFieldName = 'QRCode';
            SET @I_ReturnMessage = 'ServerMessage:条码已录入系统，请勿重复扫描！';
            RETURN -1;
        END;

        IF ISNULL(@VendorDeliveryName, '') = ''
        BEGIN
            EXEC [dbo].[Txn_BillNewSN]
                @BillName = N'MiscDelivery' ,
                @NewSN = @VendorDeliveryName OUTPUT;

            SET @VendorDeliveryId = dbo.Fn_GetObjectPKId(12, 'VendorDelivery',NEXT VALUE FOR dbo.VendorDelivery_PK);

            INSERT  INTO dbo.VendorDelivery ( VendorDeliveryId, VendorDeliveryName, VendorDeliveryDescription,
                                              VendorDeliveryType, VendorDeliveryStatus, FactoryId, VendorId,
                                              DeliveryTrueDate, Driver, Truck, IsSRM, CreateDate, CreateUserId,
                                              CreateUser, ApproveDate, ApproveUserId, ApproveUser, remarks )
            VALUES  ( @VendorDeliveryId, @VendorDeliveryName, '来料点收(捷豹)', 'MISC', '00', @FactoryId, @VendorId, GETDATE(),
                      '', '', 1, GETDATE(), @I_OrBitUserId, @I_OrBitUserName, GETDATE(), @I_OrBitUserId,
                      @I_OrBitUserName, '来料点收(捷豹)' );
        END;
        ELSE
        BEGIN
            SELECT  @VendorDeliveryId = VendorDeliveryId
            FROM    dbo.VendorDelivery
            WHERE   VendorDeliveryName = @VendorDeliveryName;
        END;

        IF NOT EXISTS ( SELECT  1
                        FROM    dbo.VendorDeliveryItem
                        WHERE   VendorDeliveryId = @VendorDeliveryId AND ProductId = @ProductId )
        BEGIN
            SELECT  @LineSequence = MAX(LineSequence)
            FROM    dbo.VendorDeliveryItem
            WHERE   VendorDeliveryId = @VendorDeliveryId;

            IF ISNULL(@LineSequence, '') = ''
                SET @LineSequence = '00010';
            ELSE
                SET @LineSequence = RIGHT('000' + CAST(CAST(@LineSequence AS INT) + 10 AS NVARCHAR(10)), 5);

            SET @VendorDeliveryItemId = dbo.Fn_GetObjectPKId(12, 'VendorDeliveryItem', NEXT VALUE FOR
                                                             dbo.VendorDeliveryItem_PK);

            INSERT  INTO dbo.VendorDeliveryItem ( VendorDeliveryItemId, VendorDeliveryId, LineSequence,
                                                  VendorDeliveryItemStatus, POId, POItemId, VendorId, ProductId,
                                                  ItemQtyDelivery, ItemQtyReceived, ItemQtyRejected, DeliveryUOMId,
                                                  CreateDate, Lgort, remarks )
            VALUES  ( @VendorDeliveryItemId, @VendorDeliveryId, @LineSequence, '00', '', '', @VendorId, @ProductId, 0, 0,
                      0, @DeliveryUOMId, GETDATE(), @LGORT, '' );
        END;
        ELSE
        BEGIN
            SELECT  @VendorDeliveryItemId = VendorDeliveryItemId
            FROM    dbo.VendorDeliveryItem
            WHERE   VendorDeliveryId = @VendorDeliveryId AND ProductId = @ProductId;
        END;

        INSERT  INTO dbo.VendorDeliveryItemLot ( VendorDeliveryItemLotId, VendorDeliveryItemId, LotSN, BoxSN, LotQty,
                                                 ReceivedQty, Productid, ProductionDateCode, ProductionLotNO,
                                                 CreateUserId, VendorId, IsReceiveScan, ReceiveUserId, ReceiveResourceId,
                                                 ReceiveDate, CellId, ResourceId, ApplyUser, ProcessProc, WorkcenterId,
                                                 POId, POItemId, DeliveryBatch )
        VALUES  ( dbo.Fn_GetObjectPKId(12, 'VendorDeliveryItemLot', NEXT VALUE FOR dbo.VendorDeliveryItemLot_PK),
                  @VendorDeliveryItemId, @BoxOrLotSN, '', @LotQty, @LotQty, @ProductId,
                  CONVERT(NVARCHAR(10), GETDATE(), 120), CONVERT(NVARCHAR(10), GETDATE(), 120), @I_OrBitUserId,
                  @VendorId, 1, @I_OrBitUserId, @I_ResourceId, GETDATE(), @CellId, @I_ResourceId, @I_OrBitUserName,
                  'PDA_ConsignmentReceive', @WorkcenterId, '', '', '' );

        UPDATE  dbo.VendorDeliveryItem
        SET     ItemQtyDelivery = ItemQtyDelivery + @LotQty, ItemQtyReceived = ItemQtyReceived + @LotQty
        WHERE   VendorDeliveryItemId = @VendorDeliveryItemId;
		
        DELETE  FROM @TempVendorDeliveryItem;

        INSERT  INTO @TempVendorDeliveryItem ( VendorDeliveryItemId, LineSequence, ProductName, ItemQtyReceived )
                SELECT  a.VendorDeliveryItemId, a.LineSequence, b.prdname, a.ItemQtyReceived
                FROM    dbo.VendorDeliveryItem a
                INNER JOIN dbo.Product b ON b.ProductId = a.ProductId
                WHERE   a.VendorDeliveryId = @VendorDeliveryId;

        SELECT  *
        FROM    @TempVendorDeliveryItem
        ORDER BY LineSequence;

        SELECT  @VendorDeliveryName AS VendorDeliveryName, '' AS QRCode, '' AS BoxOrLotSN;
        SET @I_ExceptionFieldName = 'QRCode';
        SET @I_ReturnMessage = 'ServerMessage:条码[' + @BoxOrLotSN + ']接收成功，请继续扫描！';
        RETURN 0;
    END;

    IF @I_Sender = 'ReceiveConfirm'
    BEGIN
		
        IF ISNULL(@VendorDeliveryName, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:送货单号不能为空！';
            RETURN -1;
        END;

        SELECT  @VendorDeliveryId = VendorDeliveryId
        FROM    dbo.VendorDelivery
        WHERE   VendorDeliveryName = @VendorDeliveryName;

        IF ISNULL(@VendorDeliveryId, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:送货单号无效，请检查！';
            RETURN -1;
        END;

        IF EXISTS ( SELECT  1
                    FROM    dbo.VendorDelivery
                    WHERE   VendorDeliveryName = @VendorDeliveryName AND VendorDeliveryStatus <> '00' )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:送货单号状态不是【00 正在送货】，请检查！';
            RETURN -1;
        END;

        IF NOT EXISTS ( SELECT  1
                        FROM    dbo.VendorDeliveryItem
                        WHERE   VendorDeliveryId = @VendorDeliveryId )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:送货单【' + @VendorDeliveryName + '】明细中没有数据,不允许收货确认！';
            RETURN -1; 
        END;

        SELECT  @ItemQtyReceived = SUM(ItemQtyReceived)
        FROM    dbo.VendorDeliveryItem
        WHERE   VendorDeliveryId = @VendorDeliveryId;

        EXEC [dbo].[Txn_ApplyVendorResLotSN]
            @SNCounterName = N'扫描入库号' ,
            @CounterType = N'VERES' ,
            @VendorId = @VendorId ,
            @vendordeliveryname = @DeliveryOrderName OUTPUT; 

        EXEC dbo.SysGetObjectPKId
            '' ,
            'VendorDeliveryRes' ,
            @VendorDeliveryResId OUTPUT;

        INSERT  INTO dbo.VendorDeliveryRes ( VendorDeliveryResID, Deliveryordername, Vendorid, DeliveryQty, Vendorname,
                                             ReceivedQty, IsIqc, IQCUserid, PersonId, CreateDate, Remark, rejectqty,
                                             IQCMove, Status, QcCheckqty, Divisionid, IQCPostDate, SapReceivedqty,
                                             SrmPostQty, Createuserid, IQCResult, DeliveryType, OldVendordeliveryresid,
                                             Siteid, SrmPostflag )
        VALUES  ( @VendorDeliveryResId, @DeliveryOrderName, @VendorId, ISNULL(@ItemQtyReceived, 0), @VendorDescription,
                  ISNULL(@ItemQtyReceived, 0), 1, NULL, @I_OrBitUserId, GETDATE(), '', 0, 1, NULL,
                  NULL, NULL, GETDATE(), NULL, 0, @I_OrBitUserId, '', '', '', '', 0 );
		
        INSERT  INTO dbo.Vendordeliveryresitem ( Vendordeliveryresitemid, Vendordeliveryresid, Productid, poitemid,
                                                 DeliveryQty, ReceivedQty, RejectQty, IQCQTY, IQCUSRID, Createdate,
                                                 Createuserid, iqcorderid, oldordername, VendorScanQty, Status, Lgort,
                                                 OldVendorDeliveryResid, IsQMS, MoveDate, Qmspost )
                SELECT  dbo.Fn_GetObjectPKId(12, 'VendorDeliveryResItem', NEXT VALUE FOR dbo.Vendordeliveryresitem_PK),
                        @VendorDeliveryResId, ProductId, '', ItemQtyDelivery, ItemQtyDelivery, 0, 0, '', GETDATE(),
                        @I_OrBitUserId, '', '', 0, '已报检', Lgort, VendorDeliveryItemId, 1, GETDATE(), ''
                FROM    dbo.VendorDeliveryItem
                WHERE   VendorDeliveryId = @VendorDeliveryId;

        UPDATE  dbo.VendorDelivery
        SET     VendorDeliveryStatus = '30', DeliveryTrueDate = GETDATE()
        WHERE   VendorDeliveryId = @VendorDeliveryId;

        UPDATE  a
        SET     a.VendordeliveryResitemid = b.Vendordeliveryresitemid, a.vendordeliveryresid = b.Vendordeliveryresid
        FROM    dbo.VendorDeliveryItem a
        INNER JOIN dbo.Vendordeliveryresitem b ON b.OldVendorDeliveryResid = a.VendorDeliveryItemId
        WHERE   a.VendorDeliveryId = @VendorDeliveryId;

        UPDATE  b
        SET     b.VendorDeliveryResItemid = a.VendordeliveryResitemid, b.VendorDeliveryResid = a.VendorDeliveryResid
        FROM    dbo.VendorDeliveryItem a
        INNER JOIN dbo.VendorDeliveryItemLot b ON b.VendorDeliveryItemId = a.VendorDeliveryItemId
        WHERE   a.VendorDeliveryId = @VendorDeliveryId;

        UPDATE  dbo.VendorDeliveryRes
        SET     IsIqc = 1, IQCMove = 1, Status = '5'
        WHERE   VendorDeliveryResID = @VendorDeliveryResId;

        INSERT  INTO WW_RMInventory ( WWId, LotId, LotSN, LotQty, OriginalQty, ProductId, BoxSN, POId, VendorId,
                                      ProductionDateCode, CellId, ProductionLotNO, DeliveryBatch, Lgort, locationid,
                                      WorkcenterId, IsIssueToPickingList, POItemId, VendorDeliveryResitemid )
                SELECT  dbo.Fn_GetObjectPKId(12, 'WW_RMInventory',NEXT VALUE FOR dbo.WW_RMInventory_PK), '', b.LotSN,
                        b.LotQty, b.LotQty, a.ProductId, b.BoxSN, b.POId, b.VendorId, b.ProductionDateCode, b.CellId,
                        b.ProductionLotNO, b.DeliveryBatch, a.Lgort, b.WorkcenterId, b.WorkcenterId, 0, b.POItemId,
                        b.VendorDeliveryResItemid
                FROM    dbo.VendorDeliveryItem a
                INNER JOIN dbo.VendorDeliveryItemLot b ON b.VendorDeliveryItemId = a.VendorDeliveryItemId
                WHERE   a.VendorDeliveryId = @VendorDeliveryId;

        SELECT  *
        FROM    @TempVendorDeliveryItem;

        SELECT  '' AS VendorDeliveryName, '' AS StagArea, '' AS QRCode, '' AS BoxOrLotSN, '' AS VendorDeliveryItemId;
        SET @I_ExceptionFieldName = 'StagArea';
        SET @I_ReturnMessage = 'ServerMessage:收货确认完成！';
        RETURN 0;
    END;

    RETURN 0;

END;



