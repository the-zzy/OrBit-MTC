
-- =============================================
-- Author:		<benson>
-- Create date: <07  5 2016  1:09PM>
-- Description:	为KDOrderModuleItem创建保存过程
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDOrderItemSaveData]
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
    @ProductId CHAR(12) = '' ,
    @UOMId CHAR(12) = '' ,
    @ProductName NVARCHAR(50) = '' ,
    @ModuleName NVARCHAR(50) = '' ,
    @EnglishDescription NVARCHAR(500) = '' ,
    @CustomerNumber NVARCHAR(50) = '' ,
    @FieldsA NVARCHAR(500) = '' ,			  --附件字段A
    @ProductWeight NUMERIC(18, 6) = 0 ,			  --物料单重
    @SingleWeight DECIMAL(18, 4) = 0 ,         --单机重量
    @QtyPack DECIMAL(18, 2) = 0 ,
    @ItemQtyRequired DECIMAL(18, 2) = 0 ,
    @BOMQtyRequired DECIMAL(18, 2) = 0
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
    DECLARE @return_value INT = -1;
    DECLARE @S_ReturnMessage NVARCHAR(100);
    DECLARE @OldProductId CHAR(12)= '';	
    DECLARE @OldModuleName NVARCHAR(50)= '';

    DECLARE @FieldsValueOld NVARCHAR(MAX);
    DECLARE @FieldsValueNew NVARCHAR(MAX);
    DECLARE @FieldsChanged NVARCHAR(MAX);

    DECLARE @MOPackQty FLOAT;

    SET @I_ReturnMessage = '';
    SET @I_IsNewRow = 0;
    SET @I_ExceptionFieldName = '';
    SET @ModifyObject = 'KDOrderItem';   --这里必须要是当前操作的表名
    SET @ModifyType = '';

    SET @MOPackQty = 0;

    DECLARE @SOName NVARCHAR(50) = '';
    DECLARE @OrderName NVARCHAR(50) = '';
	
	--没有申请到主键就退出
    IF LTRIM(@I_PKId) = ''
    BEGIN
        SET @I_ReturnMessage = 'No PKId applied';
        RETURN -1;
    END;

    IF LTRIM(@ModuleName) = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:组件不能为空!';
        RETURN -1;
    END;

    SELECT  @OrderName = OrderName, @SOName = SOName
    FROM    dbo.KDOrderInfo
    WHERE   KDOrderInfoId = @I_ParentPKId;

    EXEC @return_value = [dbo].[KDOrderLockDoMethod]
        @I_Sender = N'CheckIsLock' , -- nvarchar(200)
        @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
        @SOName = @SOName , -- nvarchar(50)
        @OrderName = @OrderName; -- nvarchar(50)

    IF @return_value = -1
        RETURN -1;

	--检查物料是否重复
    IF EXISTS ( SELECT  1
                FROM    KDOrderItem
                WHERE   KDOrderInfoId = @I_ParentPKId AND KDOrderItemId != @I_PKId AND ProductId = @ProductId AND ModuleName = @ModuleName )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:物料 [' + @ProductName + '] 已存在，不允许重复!';
        RETURN -1;
    END;
	
    IF NOT EXISTS ( SELECT  1
                    FROM    KDOrderInfo s
                    INNER JOIN MO a ON s.SOName = a.SOName
                    INNER JOIN MOItem b ON a.MOId = b.MOId
                    INNER JOIN Product c ON b.ProductId = c.ProductId
                    WHERE   s.KDOrderInfoId = @I_ParentPKId AND c.prdname = @ModuleName )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:组件无效，请检查!';
        RETURN -1;
    END;
	
    SELECT  @ProductId = ProductId, @ProductName = prdname, @UOMId = UsageUOMId
    FROM    Product
    WHERE   prdname = @ModuleName;

    IF ISNULL(@EnglishDescription, '') = ''
    BEGIN
        SELECT  @EnglishDescription = EngDesc
        FROM    dbo.Product
        WHERE   ProductId = @ProductId;
    END;
	
    IF NOT EXISTS ( SELECT  KDOrderItemId
                    FROM    KDOrderItem
                    WHERE   KDOrderItemId = @I_PKId )
    BEGIN

        INSERT  INTO KDOrderItem ( KDOrderItemId, KDOrderInfoId, ProductId, CustomerNumber, ModuleName,
                                   EnglishDescription, FieldsA,
				--FieldsB,
                                   SingleWeight, BOMQtyRequired, QtyPack, ItemQtyRequired, UOMId, IsAdd, CreateUserId,
                                   IsValidity )
        VALUES  ( @I_PKId, @I_ParentPKId, @ProductId, @CustomerNumber, @ModuleName, @EnglishDescription, @FieldsA,
				--@FieldsB,
                  @SingleWeight, @BOMQtyRequired, @QtyPack, @ItemQtyRequired, @UOMId, 1, @I_OrBitUserId, 1 );
    END;
    ELSE
    BEGIN
		--if not exists(select 1 from KDOrderItem where KDOrderItemId=@I_PKId and IsAdd=1)
		--begin
		--	set @I_ReturnMessage='ServerMessage:非手工增加物料，不允许修改!'
		--	return -1
		--end

		-----已经生产箱号，不允许修改--
        SELECT  @OldProductId = ProductId, @OldModuleName = ModuleName
        FROM    KDOrderItem
        WHERE   KDOrderItemId = @I_PKId;
        IF @OldModuleName <> @ModuleName OR @OldProductId <> @ProductId
        BEGIN
            IF EXISTS ( SELECT  1
                        FROM    KDBoxItem
                        WHERE   KDOrderInfoId = @I_ParentPKId AND ProductId = @OldProductId AND ModuleName = @OldModuleName AND IsCancel = 0 )
            BEGIN
                SET @I_ReturnMessage = 'ServerMessage:已经生成箱号，不允许修改,要修改先取消箱号!';
                RETURN -1;
            END;
        END;
        IF ISNULL(@ModuleName, '') = ''
            SET @ModuleName = @ProductName;

		--获更新前的记录
        EXEC SysGetTableFieldsCombine
            @ModifyObject ,
            @I_PKId ,
            @FieldsValueOld OUTPUT;

        UPDATE  KDOrderItem
        SET     ProductId = @ProductId, CustomerNumber = @CustomerNumber, ModuleName = @ModuleName,
                EnglishDescription = @EnglishDescription, FieldsA = @FieldsA,
			--FieldsB=@FieldsB,
                SingleWeight = @SingleWeight, BOMQtyRequired = @BOMQtyRequired, ItemQtyRequired = @ItemQtyRequired,
                QtyPack = @QtyPack
        WHERE   KDOrderItemId = @I_PKId;

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




