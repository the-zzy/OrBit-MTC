

-- =============================================

-- Author:		<benson>

-- Create date: <07  5 2016 12:03PM>

-- Description:	为KDOrderInfo创建保存过程

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDOrderInfoSaveData]

    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言

    @I_IsNewRow BIT = 0 OUTPUT ,				--向客户端报告是否是新行

    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段

    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID

    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令

    @I_OrBitUserId CHAR(12) = '' ,			--用户ID

    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名

    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)

    @I_ResourceName NVARCHAR(100) = '' ,	--资源名

    @I_PKId CHAR(12) = '' ,				--主键

    @I_SourcePKId CHAR(12) = '' ,			--执行拷贝时传入的源主键  

    @I_ParentPKId CHAR(12) = '' ,			--父级主键

    @I_Parameter NVARCHAR(100) = '' ,		--插件参数

--以上变量为服务固定接口参数，必须在每一个Save过程中实现。



--以下参与必须与该元对象数据在MetadataField表中提供的字段一一对应。



--警告:	以下变量请一定要赋以默认值，否则前台程序会报错

--提示：元数据在MetadataField表中提供的所有字段必须全部包含在Save过程中

--      否则会导致因在更新时为参数不找到出前台程序报错。>

--提示：以下是用户变量定义段，如有用户变量定义段，请将上面@I_Parameter nvarchar(100)=''后面加上,号！

    @OrderName NVARCHAR(50) = '' ,

    @SOName NVARCHAR(50) = '' ,

    @IsSplitBatch BIT = 0 ,

    @OrderDescription NVARCHAR(100) = '' ,

    @CustomerName NVARCHAR(50) = '' ,

    @CustomerModel NVARCHAR(50) = '' ,

    @OrderQty INT = 0 ,

    @ProductName NVARCHAR(50) = '' ,

    @OrderDate DATETIME = NULL ,

    @RollingPlan NVARCHAR(100) = '' ,

    @CreateUserName NVARCHAR(50) = '' ,

    @CreateDate DATETIME = NULL ,

    @Brand NVARCHAR(50) = '' ,

    @Panel NVARCHAR(50) = '' ,

    @SupplierCode NVARCHAR(100) = '' ,

    @ProjectNo NVARCHAR(100) = '' ,

    @PoNo NVARCHAR(50) = '' ,

    @LotNo NVARCHAR(50) = '' ,

    @MadeCountry NVARCHAR(50) = '' ,

    @SKD NVARCHAR(50) = '' ,

    @LabelTypeId CHAR(12) = '' ,

    @LabelType NVARCHAR(50) = '' ,

    @WorkflowId CHAR(12) = '' ,

    @WorkflowName NVARCHAR(50) = '' ,

    @Country NVARCHAR(50) = '' ,

    @CustomerAddress NVARCHAR(200) = '' ,

    @PINO NVARCHAR(50) = '' ,

    @LMNYPCustomerModel NVARCHAR(50) = '' ,

    @LMNYPPINO NVARCHAR(50) = '' ,

    @LMNYSCustomerModel NVARCHAR(50) = '' ,

    @LMNYSPINO NVARCHAR(50) = '' ,

    @HSCode NVARCHAR(50) = '' ,

    @ModuleBinningQty INT = 0

--用户变量结束

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine

    SET NOCOUNT ON;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--执行SaveData,注意：以下过程必须根据业务的需求进行调整

	--如果您不了解SaveData过程如何编写，请参考我们提供的示例_SampleProjectSaveData



    DECLARE @ModifyObject NVARCHAR(50);

    DECLARE @ModifyType NVARCHAR(20);

    DECLARE @return_value INT;

    DECLARE @S_ReturnMessage NVARCHAR(100);

    DECLARE @KDOrderItemId CHAR(12);

    DECLARE @SOItemId CHAR(12);

    DECLARE @SOId CHAR(12);

    DECLARE @KDOrderInfoId CHAR(12);

    DECLARE @FieldsValueOld NVARCHAR(MAX);

    DECLARE @FieldsValueNew NVARCHAR(MAX);

    DECLARE @FieldsChanged NVARCHAR(MAX);

    DECLARE @MOProductId CHAR(12);

    SET @I_ReturnMessage = '';

    SET @I_IsNewRow = 0;

    SET @I_ExceptionFieldName = '';

    SET @ModifyObject = 'KDOrderInfo';   --这里必须要是当前操作的表名

    SET @ModifyType = '';



    DECLARE @OrderType CHAR(1);

    DECLARE @OrderCount INT;

    DECLARE @ProductId CHAR(12);

    DECLARE @ModuleName NVARCHAR(50);

    DECLARE @CustomerNumber NVARCHAR(50);

    DECLARE @EnglishDescription NVARCHAR(500);

	DECLARE @LineSequence NVARCHAR(50) = '';

    

    DECLARE @IsIgnore BIT;

    DECLARE @IsAdd BIT= 0;

    DECLARE @IsExpand BIT;

    DECLARE @BOMQtyRequired DECIMAL(18, 2);

    DECLARE @QtyPack DECIMAL(18, 2);

    DECLARE @UOMId CHAR(12);

    DECLARE @MOPackQty DECIMAL(18, 2);

    DECLARE @ItemQtyRequired DECIMAL(18, 2);

    DECLARE @IsBom BIT= 0;				--1是BOM里面的品号,0工单里面的品号

    DECLARE @FieldsA NVARCHAR(500)= '';		  --附件字段A

    DECLARE @FieldsB NVARCHAR(500)= '';			  --附件字段B

    DECLARE @SingleWeight DECIMAL(18, 4)= 0;         --单机重量

    SET @OrderType = '';

    SET @OrderCount = 0;

    SET @ProductId = '';

    DECLARE @ServiceUrl NVARCHAR(MAX) = '';

    DECLARE @ResponseText NVARCHAR(MAX) = '';

    DECLARE @SparePartBinningQty INT = 0;







    SET @ServiceUrl = 'http://192.168.70.21/westvalley/qw/query/0301.jsp?dh=' + @SOName;



    DECLARE @TempKDModuleOrder TABLE

        (

          Seq INT ,

          OrderName NVARCHAR(50) ,

          OrderQty INT

        );



    DECLARE @TempPKId TABLE ( Seq INT, PKId CHAR(12) );



    DECLARE @Seq INT = 0;

	

	--没有申请到主键就退出

    IF LTRIM(@I_PKId) = ''

    BEGIN

        SET @I_ReturnMessage = 'No PKId applied';

        RETURN -1;

    END;



    EXEC @ResponseText = dbo.MESCallHelperHttp_ExecRequest

        @url = @ServiceUrl , -- nvarchar(500)

        @reqData = N'' , -- nvarchar(max)

        @headers = N'' , -- nvarchar(max)

        @reqMethod = N'POST'; -- nvarchar(50)

	

    SELECT  @CustomerModel = StringValue

    FROM    dbo.ParseJSON(@ResponseText)

    WHERE   parent_ID = 1 AND sequenceNo = 2;     



    --SELECT  @ModuleBinningQty = IIF(ISNUMERIC(StringValue) = 0, 0, StringValue)

    --FROM    dbo.ParseJSON(@ResponseText)

    --WHERE   parent_ID = 1 AND sequenceNo = 7;



    SELECT  @SparePartBinningQty = IIF(ISNUMERIC(StringValue) = 0, 0, StringValue)

    FROM    dbo.ParseJSON(@ResponseText)

    WHERE   parent_ID = 1 AND sequenceNo = 10;



    IF @ModuleBinningQty = 0

        SET @ModuleBinningQty = 1;



    IF @SparePartBinningQty = 0

        SET @SparePartBinningQty = 1;



    UPDATE  dbo.SO

    SET     ModuleBinningQty = @ModuleBinningQty, @SparePartBinningQty = SparePartBinningQty,

            KHXH = IIF(ISNULL(KHXH, '') = '', @CustomerModel, KHXH)

    WHERE   SOName = @SOName;



    IF @ModuleBinningQty < 1 AND (

                                   @ProductName LIKE '745%' OR @ProductName LIKE '537Q%'

                                 )

    BEGIN

        SET @I_ReturnMessage = 'ServerMessage:模组装箱数量不能小于1！';

        RETURN -1;

    END;



	--------------raoym 20240607 --------------
	IF NOT EXISTS ( SELECT  1

                    FROM    SO

                    WHERE   SOName = @SOName )

    BEGIN

				EXEC dbo.Sync_CopyBasicData
			@SyncType = N'SO' , -- nvarchar(20)
			@SyncValues = @SOName , -- nvarchar(50)
			@I_ReturnMessage = N'' -- nvarchar(max)

    END;

	--------------raoym 20240607 --------------





    IF NOT EXISTS ( SELECT  1

                    FROM    SO

                    WHERE   SOName = @SOName )

    BEGIN

        SET @I_ReturnMessage = 'ServerMessage:销售订单号 [' + @SOName + '] 不存在，请检查!';

        RETURN -1;

    END;



    IF NOT EXISTS ( SELECT  1

                    FROM    ProductRoot

                    WHERE   ProductName = @ProductName ) AND @I_PlugInCommand <> 'BJOI'

    BEGIN

        SET @I_ReturnMessage = 'ServerMessage:成品编码 [' + @ProductName + '] 不存在，请检查!';

        RETURN -1;

    END;



    SELECT  @ProductId = ProductId

    FROM    Product

    INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId

    WHERE   ProductRoot.ProductName = @ProductName;



    IF NOT EXISTS ( SELECT  KDOrderInfoId

                    FROM    dbo.KDOrderInfo

                    WHERE   KDOrderInfoId = @I_PKId )

    BEGIN

        IF @I_PlugInCommand = 'KDOI'  --总装订单

            SET @OrderType = '1';



        IF @I_PlugInCommand = 'KDOIB' --基板订单

            SET @OrderType = '2';

			

        IF @I_PlugInCommand = 'BJOI'  --备件订单

        BEGIN

            SET @OrderType = '7';



            SELECT  @CustomerName = b.CustomerName

            FROM    dbo.SO a

            INNER JOIN dbo.Customer b ON b.CustomerId = a.CustomerId

            WHERE   a.SOName = @SOName;



            EXEC [dbo].[Sync_CopyBasicData]

                @SyncType = N'SO' , -- nvarchar(20)

                @SyncValues = @SOName; -- nvarchar(50)



            IF EXISTS ( SELECT  1

                        FROM    dbo.KDOrderInfo

                        WHERE   SOName = @SOName AND OrderType = '7' )

            BEGIN

                SET @I_ReturnMessage = 'ServerMessage:订单已存在，不允许重复新建！';

                RETURN -1;

            END;

        END;



        SELECT  @OrderCount = ISNULL(COUNT(KDOrderInfoId), 0)

        FROM    KDOrderInfo

        WHERE   SOName = @SOName AND OrderType = @OrderType;



        IF @OrderType = '1'

            SET @OrderName = 'ZZ' + @SOName + '-' + CAST(( @OrderCount + 1 ) AS VARCHAR);



        IF @OrderType = '2'

            SET @OrderName = 'JB' + @SOName + '-' + CAST(( @OrderCount + 1 ) AS VARCHAR);



        IF @OrderType = '7'

            SET @OrderName = 'BJ' + @SOName + '-' + CAST(( @OrderCount + 1 ) AS VARCHAR);

	

        IF ISNULL(@OrderName, '') = ''

        BEGIN

            SET @I_ReturnMessage = 'ServerMessage:订单号生成失败!';

            RETURN -1;

        END;



        IF EXISTS ( SELECT  1

                    FROM    KDOrderInfo

                    WHERE   OrderName = @OrderName )

        BEGIN

            SET @I_ReturnMessage = 'ServerMessage:订单号 [' + @OrderName + '] 重复，新建订单失败!';

            RETURN -1;

        END;



        INSERT  INTO dbo.KDOrderInfo ( KDOrderInfoId, OrderName, SOName, IsSplitBatch, ProductId, OrderType,

                                   OrderDescription, CustomerName, CustomerModel, OrderQty, ProductCode, ProductsCode,

                                   OrderDate, RollingPlan, Brand, Panel, SKD, SupplierCode, ProjectNo, PONO, LotNo,

                                   MadeCountry, Country, KDLabelTypeId, WorkflowId, CreateUserId, CustomerAddress, PINO,

                                   LMNYPCustomerModel, LMNYPPINO, LMNYSCustomerModel, LMNYSPINO, HSCode,

                                   ModuleBinningQty )

        VALUES  ( @I_PKId, @OrderName, @SOName, @IsSplitBatch, @ProductId, @OrderType, @OrderDescription, @CustomerName,

                  @CustomerModel, @OrderQty, @ProductName, @ProductName, @OrderDate, @RollingPlan, @Brand, @Panel, @SKD,

                  @SupplierCode, @ProjectNo, @PoNo, @LotNo, @MadeCountry, @Country, @LabelTypeId, @WorkflowId,

                  @I_OrBitUserId, @CustomerAddress, @PINO, @LMNYPCustomerModel, @LMNYPPINO, @LMNYSCustomerModel,

                  @LMNYSPINO, @HSCode, @ModuleBinningQty );



		--自动创建模组订单 add wangrt 2022-09-09

        IF EXISTS ( SELECT  1

                    FROM    dbo.OrderFieldSetting a

                    LEFT JOIN dbo.KDModuleOrder b ON b.OrderName = a.OrderName AND b.KDOrderInfoId = @I_PKId

                    WHERE   SOName = @SOName AND a.ProductName = @ProductName AND b.KDModuleOrderId IS NULL AND a.OrderType = 'TV' ) AND @OrderType = '1'

        BEGIN



            INSERT  INTO @TempKDModuleOrder ( OrderName, OrderQty )

                    SELECT  a.OrderName, a.Quantity

                    FROM    dbo.OrderFieldSetting a

                    LEFT JOIN dbo.KDModuleOrder b ON b.OrderName = a.OrderName AND b.KDOrderInfoId = @I_PKId

                    WHERE   a.SOName = @SOName AND a.ProductName = @ProductName AND b.KDModuleOrderId IS NULL AND a.OrderType = 'TV';



            UPDATE  @TempKDModuleOrder

            SET     Seq = @Seq, @Seq = @Seq + 1;



            INSERT  INTO @TempPKId ( Seq, PKId )

                    EXEC dbo.SysGetBatchObjectPKId

                        @ObjectId = '' ,

                        @ObjectName = N'KDModuleOrder' ,

                        @RowCount = @Seq;



            INSERT  INTO dbo.KDModuleOrder ( KDModuleOrderId, KDOrderInfoId, OrderName, BoxLevel, BoxType,

                                             CurrentBatchQty, CreateDate )

                    SELECT  b.PKId, @I_PKId, a.OrderName, 'A0', 'A', a.OrderQty, GETDATE()

                    FROM    @TempKDModuleOrder a

                    INNER JOIN @TempPKId b ON b.Seq = a.Seq;

        END;



        SET @I_IsNewRow = 1;		

        SET @ModifyType = 'Insert';

		--获取刚刚插入的记录

        EXEC SysGetTableFieldsCombine

            @ModifyObject ,

            @I_PKId ,

            @FieldsChanged OUTPUT;

		--备件订单插入备件明细



        IF @I_PlugInCommand = 'BJOI' AND @OrderName LIKE 'BJ20[456789]%' --备件订单

        BEGIN

		  --写入

		  --获取散件订单信息

            SELECT  @SOId = SO.SOId

            FROM    dbo.SO

            WHERE   SO.SOName = @SOName;



            IF ISNULL(@SOId, '') = ''

            BEGIN

                SET @I_ReturnMessage = 'ServerMessage:获取' + @SOName + 'SO订单信息失败！';

                RETURN -1;

            END;

            DECLARE cursor2 CURSOR

            FOR

            SELECT  LineSequence, SOItemId, ProductId, SaleQty

            FROM    dbo.SOItem

            WHERE   SOId = @SOId;

            OPEN cursor2;

            FETCH NEXT FROM cursor2

			INTO @LineSequence, @SOItemId, @ProductId, @ItemQtyRequired;

            WHILE @@FETCH_STATUS = 0

            BEGIN



                SELECT  @UOMId = UsageUOMId, @ProductName = dbo.RemoveZero(prdname)

                FROM    dbo.Product

                WHERE   ProductId = @ProductId;



                EXEC SysGetObjectPKId

                    '' ,

                    'KDOrderItem' ,

                    @KDOrderItemId OUTPUT;



                INSERT  INTO dbo.KDOrderItem ( KDOrderItemId, KDOrderInfoId, ProductId, CustomerNumber, ModuleName,

                                           EnglishDescription, FieldsA, FieldsB, SingleWeight, BOMQtyRequired,

                                           ItemQtyRequired, QtyPack, UOMId, IsIgnore, IsValidity, CreateUserId, LineSequence )

                VALUES  ( @KDOrderItemId, @I_PKId, @ProductId, [dbo].[RemoveZero](@ProductName),

                          [dbo].[RemoveZero](@ProductName), NULL, NULL, NULL, 0, 1, @ItemQtyRequired, NULL, @UOMId, 0, 1,

                          @I_OrBitUserId, @LineSequence );



                FETCH NEXT FROM cursor2

			INTO @LineSequence, @SOItemId, @ProductId, @ItemQtyRequired;

            END;

            CLOSE cursor2;

            DEALLOCATE cursor2;  

        END;

    END;

    ELSE

    BEGIN

		--获更新前的记录

        EXEC SysGetTableFieldsCombine

            @ModifyObject ,

            @I_PKId ,

            @FieldsValueOld OUTPUT;



        UPDATE  dbo.KDOrderInfo

        SET     SOName = @SOName, ProductId = @ProductId, OrderDescription = @OrderDescription,

                CustomerName = @CustomerName, CustomerModel = @CustomerModel, OrderQty = @OrderQty,

                ProductCode = @ProductName, ProductsCode = @ProductName, OrderDate = @OrderDate,

                RollingPlan = @RollingPlan, Brand = @Brand, Panel = @Panel, SupplierCode = @SupplierCode,

                ProjectNo = @ProjectNo, PONO = @PoNo, LotNo = @LotNo, MadeCountry = @MadeCountry, SKD = @SKD,

                Country = @Country, KDLabelTypeId = @LabelTypeId, WorkflowId = @WorkflowId,

                CustomerAddress = @CustomerAddress, PINO = @PINO, LMNYPCustomerModel = @LMNYPCustomerModel,

                LMNYPPINO = @LMNYPPINO, LMNYSCustomerModel = @LMNYSCustomerModel, LMNYSPINO = @LMNYSPINO,

                HSCode = @HSCode, ModuleBinningQty = @ModuleBinningQty

        WHERE   KDOrderInfoId = @I_PKId;



		--自动创建模组订单 add wangrt 2022-09-09

        IF EXISTS ( SELECT  1

                    FROM    dbo.OrderFieldSetting a

                    LEFT JOIN dbo.KDModuleOrder b ON b.OrderName = a.OrderName AND b.KDOrderInfoId = @I_PKId

                    WHERE   SOName = @SOName AND a.ProductName = @ProductName AND b.KDModuleOrderId IS NULL AND a.OrderType = 'TV' ) AND @OrderType = '1'

        BEGIN



            INSERT  INTO @TempKDModuleOrder ( OrderName, OrderQty )

                    SELECT  a.OrderName, a.Quantity

                    FROM    dbo.OrderFieldSetting a

                    LEFT JOIN dbo.KDModuleOrder b ON b.OrderName = a.OrderName AND b.KDOrderInfoId = @I_PKId

                    WHERE   a.SOName = @SOName AND a.ProductName = @ProductName AND b.KDModuleOrderId IS NULL AND a.OrderType = 'TV';



            UPDATE  @TempKDModuleOrder

            SET     Seq = @Seq, @Seq = @Seq + 1;



            INSERT  INTO @TempPKId ( Seq, PKId )

                    EXEC dbo.SysGetBatchObjectPKId

                        @ObjectId = '' ,

                        @ObjectName = N'KDModuleOrder' ,

                        @RowCount = @Seq;



            INSERT  INTO dbo.KDModuleOrder ( KDModuleOrderId, KDOrderInfoId, OrderName, BoxLevel, BoxType,

                                             CurrentBatchQty, CreateDate )

                    SELECT  b.PKId, @I_PKId, a.OrderName, 'A0', 'A', a.OrderQty, GETDATE()

                    FROM    @TempKDModuleOrder a

                    INNER JOIN @TempPKId b ON b.Seq = a.Seq;

        END;



        SET @ModifyType = 'Update';

		--获更新后的记录,并进行比较

        EXEC SysGetTableFieldsCombine

            @ModifyObject ,

            @I_PKId ,

            @FieldsValueNew OUTPUT;

        EXEC SysGetTableFieldsCompare

            @FieldsValueOld ,

            @FieldsValueNew ,

            @FieldsChanged OUTPUT;



    END;



    --最后将所做的修改入修改历史中

    IF @FieldsChanged <> ''

        EXEC [dbo].[SysWriteInModifyHistory]

            @ObjectName = @ModifyObject ,

            @TablePKId = @I_PKId ,

            @ModifyType = @ModifyType ,

            @UserName = @I_OrBitUserName ,

            @ModifyHistory = @FieldsChanged;



    RETURN 0;



END;































































