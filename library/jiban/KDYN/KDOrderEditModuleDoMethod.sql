
-- =============================================
-- Author:		<OrBit Team benson>
-- Create date: <2016.08.23>
-- Description:	<散件订单明细编辑组件信息>
-- Rev: 10.00
--=============================================
CREATE PROCEDURE [dbo].[KDOrderEditModuleDoMethod]
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
    @I_SourcePKId CHAR(12) = '' ,			--执行拷贝时传入的源主键  
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = '' ,		--插件参数	
    @CustomerNumber NVARCHAR(50) = '' ,       --客户编号
    @ModuleName NVARCHAR(50) = '' ,           --组件名称
    @EnglishDescription NVARCHAR(500) = '' ,  --英文描述
    @QtyPack DECIMAL(18, 2) = 0 ,              --包装用量
    @FieldsA NVARCHAR(500) = '' ,			  --附件字段A
    @FieldsB NVARCHAR(500) = '' ,			  --附件字段B
    @SingleWeight DECIMAL(18, 4) = 0          --单机重量
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON; 
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
			
    DECLARE @return_value INT;
    SET @return_value = -1;

	--检查元对象方法用户授权
    EXEC @return_value= [dbo].[MetadataPermissionCheckDoMethod]
        @I_ReturnMessage = @I_ReturnMessage OUTPUT ,
        @I_OrBitUserId = @I_OrBitUserId ,
        @I_OrBitUserName = @I_OrBitUserName ,
        @I_Sender = @I_Sender;

    IF @return_value = -1
    BEGIN
        SET @I_ReturnMessage = @I_ReturnMessage;
        RETURN -1;
    END;

---把中文的标点'转化为英文
    IF CHARINDEX('’', @EnglishDescription, 1) > 0
        SET @EnglishDescription = REPLACE(@EnglishDescription, '’', '''');
    IF CHARINDEX('‘', @EnglishDescription, 1) > 0
        SET @EnglishDescription = REPLACE(@EnglishDescription, '‘', '''');
    IF CHARINDEX('＇', @EnglishDescription, 1) > 0
        SET @EnglishDescription = REPLACE(@EnglishDescription, '＇', '''');

    IF CHARINDEX('’', @FieldsA, 1) > 0
        SET @FieldsA = REPLACE(@FieldsA, '’', '''');
    IF CHARINDEX('‘', @FieldsA, 1) > 0
        SET @FieldsA = REPLACE(@FieldsA, '‘', '''');
    IF CHARINDEX('＇', @FieldsA, 1) > 0
        SET @FieldsA = REPLACE(@FieldsA, '＇', '''');

    IF CHARINDEX('’', @FieldsB, 1) > 0
        SET @FieldsB = REPLACE(@FieldsB, '’', '''');
    IF CHARINDEX('‘', @FieldsB, 1) > 0
        SET @FieldsB = REPLACE(@FieldsB, '‘', '''');
    IF CHARINDEX('＇', @FieldsB, 1) > 0
        SET @FieldsB = REPLACE(@FieldsB, '＇', '''');

    DECLARE @ItemQtyRequired DECIMAL(18, 2);
    DECLARE @KDOrderInfoId CHAR(12);
    DECLARE @ProductId CHAR(12);
    DECLARE @MOPackQty DECIMAL(18, 2);	
    DECLARE @OldModuleName NVARCHAR(50)= '';

    SET @ItemQtyRequired = 0;
    SET @KDOrderInfoId = '';
    SET @ProductId = '';
    SET @MOPackQty = 0;

    DECLARE @SOName NVARCHAR(50) = '';
    DECLARE @OrderName NVARCHAR(50) = '';

    DECLARE @temp TABLE
        (
          MOId CHAR(12) ,
          ProductId CHAR(12)
        );

    IF ISNULL(@I_PKId, '') = '' OR ISNULL(@I_ParentPKId, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:请选择有效行项!';
        RETURN -1;
    END;

    SELECT  @KDOrderInfoId = KDOrderInfoId, @OldModuleName = ModuleName, @ProductId = ProductId
    FROM    KDOrderItem
    WHERE   KDOrderItemId = @I_PKId;

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

	---------已经生产箱号，不允许修改--
    IF @OldModuleName <> @ModuleName
    BEGIN
        IF EXISTS ( SELECT  1
                    FROM    KDBoxItem
                    WHERE   KDOrderInfoId = @KDOrderInfoId AND ProductId = @ProductId AND ModuleName = @OldModuleName AND IsCancel = 0 )
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:已经生成箱号,不允许修改,要修改先取消箱号!';
            RETURN -1;
        END;
    END;

	--获取BOM行信息
    UPDATE  KDOrderItem
    SET     CustomerNumber = @CustomerNumber, ModuleName = @ModuleName, EnglishDescription = @EnglishDescription,
            FieldsA = @FieldsA, FieldsB = @FieldsB, SingleWeight = @SingleWeight, QtyPack = @QtyPack
    WHERE   KDOrderItemId = @I_PKId;

    SELECT  @MOPackQty = ISNULL(SUM(KDMO.MOPackQty), 0)
    FROM    KDMO
    INNER JOIN MOItem ON MOItem.MOId = KDMO.MOId
    WHERE   KDMO.KDOrderInfoId = @KDOrderInfoId AND MOItem.ProductId = @ProductId;

    SET @ItemQtyRequired = @MOPackQty * @QtyPack;

	--更新需求数量
    UPDATE  KDOrderItem
    SET     ItemQtyRequired = @ItemQtyRequired
    WHERE   KDOrderItemId = @I_PKId;

    SET @I_ReturnMessage = 'ServerMessage:编辑散件组件信息成功!';

    RETURN 0;
END;



















