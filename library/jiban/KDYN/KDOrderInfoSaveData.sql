
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
    @LMNYPCustomerModel NVARCHAR(50) = '' ,
    @LMNYPPINO NVARCHAR(50) = '' ,
    @LMNYSCustomerModel NVARCHAR(50) = '' ,
    @LMNYSPINO NVARCHAR(50) = '' ,
    @BoxLabelName NVARCHAR(100) = '' ,
    @CustomerField1 VARCHAR(500) = '' ,
    @CustomerField2 VARCHAR(500) = '' ,
    @CustomerField3 VARCHAR(500) = '' ,
    @CustomerField4 VARCHAR(500) = ''
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

    DECLARE @FieldsValueOld NVARCHAR(MAX);
    DECLARE @FieldsValueNew NVARCHAR(MAX);
    DECLARE @FieldsChanged NVARCHAR(MAX);
   
    SET @I_ReturnMessage = '';
    SET @I_IsNewRow = 0;
    SET @I_ExceptionFieldName = '';
    SET @ModifyObject = 'KDOrderInfo';   --这里必须要是当前操作的表名
    SET @ModifyType = '';

    DECLARE @OrderType CHAR(1);
    DECLARE @OrderCount INT;
    DECLARE @ProductId CHAR(12);

    SET @OrderType = '';
    SET @OrderCount = 0;
    SET @ProductId = '';
    DECLARE @SOMOId CHAR(12) = '';
	
	--没有申请到主键就退出
    IF LTRIM(@I_PKId) = ''
    BEGIN
        SET @I_ReturnMessage = 'No PKId applied';
        RETURN -1;
    END;

	--各种规则检查段开始
	--判断是否有命名冲突
	-- if exists(select XXXXId from XXXX 
	--	where XXXXName=@XXXXName and XXXId  != @I_PKId)		
	--	begin
	--		set @I_ReturnMessage='NamingConflicts'
	--		set @I_ExceptionFieldName='XXXName'
	--		return -1
	--	end
   
    IF @I_PlugInCommand = 'KDYN'
    BEGIN
        UPDATE  KDOrderInfo
        SET     CustomerName = @CustomerName
        WHERE   KDOrderInfoId = @I_PKId;
       
        RETURN 0;
    END;
    
    IF NOT EXISTS ( SELECT  1
                    FROM    SO
                    WHERE   SOName = @SOName ) AND LEFT(@SOName, 3) <> '484'
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:销售订单号 [' + @SOName + '] 不存在，请检查!';
        RETURN -1;
    END;

    IF NOT EXISTS ( SELECT  1
                    FROM    ProductRoot
                    WHERE   ProductName = @ProductName )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:成品编码 [' + @ProductName + '] 不存在，请检查!';
        RETURN -1;
    END;

    SELECT  @ProductId = ProductId
    FROM    Product
    INNER JOIN ProductRoot ON ProductRoot.ProductRootId = Product.ProductRootId
    WHERE   ProductRoot.ProductName = @ProductName;

    IF @I_PlugInCommand = 'KDOI'  --总装订单
        SET @OrderType = '1';

    IF @I_PlugInCommand = 'KDOIB' --基板订单
        SET @OrderType = '2';

    DECLARE @ServiceUrl NVARCHAR(MAX) = '';
    DECLARE @ResponseText NVARCHAR(MAX) = '';

    SET @ServiceUrl = 'http://192.168.70.21/westvalley/qw/query/0301.jsp?dh=' + @SOName;

    EXEC @ResponseText = dbo.MESCallHelperHttp_ExecRequest
        @url = @ServiceUrl , -- nvarchar(500)
        @reqData = N'' , -- nvarchar(max)
        @headers = N'' , -- nvarchar(max)
        @reqMethod = N'POST'; -- nvarchar(50)
	
    SELECT  @CustomerModel = StringValue
    FROM    dbo.ParseJSON(@ResponseText)
    WHERE   parent_ID = 1 AND sequenceNo = 2;
   
    SELECT  @CustomerName = StringValue
    FROM    dbo.ParseJSON(@ResponseText)
    WHERE   parent_ID = 1 AND sequenceNo = 1;
   
    SELECT  @CustomerField1 = Col_3
    FROM    ImportExcelCommon
    WHERE   FuncName = 'SKD数据预置(料号-机型)' AND Col_1 = @ProductName AND Col_2 = @CustomerModel
    ORDER BY CreateDate;
    
    SELECT  @CustomerField3 = Col_2
    FROM    ImportExcelCommon
    WHERE   FuncName = 'SKD数据预置(料号)' AND Col_1 = @ProductName
    ORDER BY CreateDate;
   
    IF @BoxLabelName LIKE '%马来西亚%'
    BEGIN
        SELECT  @CustomerField4 = Col_3
        FROM    ImportExcelCommon
        WHERE   FuncName = 'SKD数据预置(标签-料号)' AND Col_1 = @BoxLabelName AND Col_2 = @ProductName
        ORDER BY CreateDate;
    END;

    SELECT  @OrderName = OrderName
    FROM    dbo.KDOrderInfo
    WHERE   KDOrderInfoId = @I_PKId;

    EXEC @return_value = [dbo].[KDOrderLockDoMethod]
        @I_Sender = N'CheckIsLock' , -- nvarchar(200)
        @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
        @SOName = @SOName , -- nvarchar(50)
        @OrderName = @OrderName; -- nvarchar(50)

    IF @return_value = -1
        RETURN -1;

    IF NOT EXISTS ( SELECT  KDOrderInfoId
                    FROM    KDOrderInfo
                    WHERE   KDOrderInfoId = @I_PKId )
    BEGIN
        SELECT  @OrderCount = ISNULL(COUNT(KDOrderInfoId), 0)
        FROM    KDOrderInfo
        WHERE   SOName = @SOName AND OrderType = @OrderType;

        IF @OrderType = '1'
            SET @OrderName = 'ZZ' + @SOName + '-' + CAST(( @OrderCount + 1 ) AS VARCHAR);

        IF @OrderType = '2'
            SET @OrderName = 'JB' + @SOName + '-' + CAST(( @OrderCount + 1 ) AS VARCHAR);
	
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

		--建立备件工单
        IF @SOName LIKE '20[5^6]%' AND NOT EXISTS ( SELECT  1
                                                    FROM    dbo.MO
                                                    WHERE   MOName = @SOName )
        BEGIN
            EXEC [dbo].[SysGetObjectPKId]
                '' ,
                'MO' ,
                @SOMOId OUTPUT;
            INSERT  INTO dbo.MO ( MOId, MOName, MODescription, MOStatus, MOERPStatus, MOTypeId, PlannedDateFrom,
                                  PlannedDateTo, ExecuteDateFrom, ExecuteDateTo, ProductId, MOQtyRequired, MOQtyDone,
                                  PriorityLevel, SOName, CustomerId, ParentMOId, FactoryId, WorkflowId, LGORT, OrganID,
                                  ERPDate, ModifyDate, ApproveUserId, ApproveDate, CreateUserId, CreateResourceId,
                                  CreateDate, SoItemSeq, FEVOR, IsOnLine, BatchNum, DivisionId, SapPost )
            VALUES  ( @SOMOId, @SOName, N'', '10', N'已释放', 'URC1000002EY', GETDATE(), GETDATE(), GETDATE(), GETDATE(),
                      @ProductId, @OrderQty, 0, '', @SOName, '', '', 'FAC10000000L', '', N'', N'', GETDATE(), GETDATE(),
                      '', GETDATE(), '', '', GETDATE(), '', N'', 0, '', '', NULL );
        END;

        INSERT  INTO KDOrderInfo ( KDOrderInfoId, OrderName, SOName, IsSplitBatch, ProductId, OrderType,
                                   OrderDescription, CustomerName, CustomerModel, OrderQty, ProductCode, OrderDate,
                                   RollingPlan, Brand, Panel, SKD, SupplierCode, ProjectNo, PONO, LotNo, MadeCountry,
                                   Country, KDLabelTypeId, WorkflowId, CreateUserId, CustomerAddress, LMNYPCustomerModel,
                                   LMNYPPINO, LMNYSCustomerModel, LMNYSPINO, BoxLabelName, CustomerField1,
                                   CustomerField2, CustomerField3, CustomerField4 )
        VALUES  ( @I_PKId, @OrderName, @SOName, @IsSplitBatch, @ProductId, @OrderType, @OrderDescription, @CustomerName,
                  @CustomerModel, @OrderQty, @ProductName, @OrderDate, @RollingPlan, @Brand, @Panel, @SKD, @SupplierCode,
                  @ProjectNo, @PoNo, @LotNo, @MadeCountry, @Country, @LabelTypeId, @WorkflowId, @I_OrBitUserId,
                  @CustomerAddress, @LMNYPCustomerModel, @LMNYPPINO, @LMNYSCustomerModel, @LMNYSPINO, @BoxLabelName,
                  @CustomerField1, @CustomerField2, @CustomerField3, @CustomerField4 );

        SET @I_IsNewRow = 1;		
        SET @ModifyType = 'Insert';
		--获取刚刚插入的记录
        EXEC SysGetTableFieldsCombine
            @ModifyObject ,
            @I_PKId ,
            @FieldsChanged OUTPUT;

    END;
    ELSE
    BEGIN
		
        IF CHARINDEX(@SOName, @OrderName) = 0
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:订单号不一致，请检查[' + @SOName + '/' + @OrderName + ']！';
            RETURN -1;
        END;
		
		--获更新前的记录
        EXEC SysGetTableFieldsCombine
            @ModifyObject ,
            @I_PKId ,
            @FieldsValueOld OUTPUT;

        UPDATE  KDOrderInfo
        SET     --OrderName=@OrderName,
				SOName = @SOName, ProductId = @ProductId, OrderDescription = @OrderDescription,
                CustomerName = @CustomerName, CustomerModel = @CustomerModel, OrderQty = @OrderQty,
                ProductCode = @ProductName, OrderDate = @OrderDate, RollingPlan = @RollingPlan, Brand = @Brand,
                Panel = @Panel, SupplierCode = @SupplierCode, ProjectNo = @ProjectNo, PONO = @PoNo, LotNo = @LotNo,
                MadeCountry = @MadeCountry, SKD = @SKD, Country = @Country, KDLabelTypeId = @LabelTypeId,
                WorkflowId = @WorkflowId, CustomerAddress = @CustomerAddress, LMNYPCustomerModel = @LMNYPCustomerModel,
                LMNYPPINO = @LMNYPPINO, LMNYSCustomerModel = @LMNYSCustomerModel, LMNYSPINO = @LMNYSPINO,
                BoxLabelName = @BoxLabelName, CustomerField1 = @CustomerField1, CustomerField2 = @CustomerField2,
                CustomerField3 = @CustomerField3, CustomerField4 = @CustomerField4
        WHERE   KDOrderInfoId = @I_PKId;

		--建立备件工单
        IF @SOName LIKE '20[5^6]%' AND NOT EXISTS ( SELECT  1
                                                    FROM    dbo.MO
                                                    WHERE   MOName = @SOName )
        BEGIN
			
            EXEC [dbo].[SysGetObjectPKId]
                '' ,
                'MO' ,
                @SOMOId OUTPUT;
            INSERT  INTO dbo.MO ( MOId, MOName, MODescription, MOStatus, MOERPStatus, MOTypeId, PlannedDateFrom,
                                  PlannedDateTo, ExecuteDateFrom, ExecuteDateTo, ProductId, MOQtyRequired, MOQtyDone,
                                  PriorityLevel, SOName, CustomerId, ParentMOId, FactoryId, WorkflowId, LGORT, OrganID,
                                  ERPDate, ModifyDate, ApproveUserId, ApproveDate, CreateUserId, CreateResourceId,
                                  CreateDate, SoItemSeq, FEVOR, IsOnLine, BatchNum, DivisionId, SapPost )
            VALUES  ( @SOMOId, @SOName, N'', '10', N'已释放', 'URC1000002EY', GETDATE(), GETDATE(), GETDATE(), GETDATE(),
                      @ProductId, @OrderQty, 0, '', @SOName, '', '', 'FAC10000000L', '', N'', N'', GETDATE(), GETDATE(),
                      '', GETDATE(), @I_OrBitUserId, @I_ResourceId, GETDATE(), '', N'', 0, '', '', NULL );
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









