
-- =============================================
-- Author:		<benson>
-- Create date: <07  5 2016 12:03PM>
-- Description:	删除KDOrderInfo表的数据
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDOrderInfoDeleteData]
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,			--插件命令
    @I_OrBitUserId CHAR(12) = '' ,				--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,		--用户名
    @I_ResourceId CHAR(12) = '' ,			--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,		--资源名
    @I_FiltCondition NVARCHAR(MAX) = '' ,	--过滤条件表达式
    @I_PKId CHAR(12) = '' ,					--主键
    @I_ParentPKId CHAR(12) = '' ,				--用于过滤的上级主键
    @I_Parameter NVARCHAR(100) = ''			--插件参数
--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.
AS
BEGIN
	-- This Stored Procedure is created by OrBit-MetaObject engine	
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @SOName NVARCHAR(50) = '';
    DECLARE @OrderName NVARCHAR(50) = '';
    
    DECLARE @return_value INT = -1;

    IF EXISTS ( SELECT  1
                FROM    KDBoxInfo
                WHERE   KDOrderInfoId = @I_PKId )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:该订单已产生外箱，不允许删除!';
        RETURN -1;
    END;

    SELECT  @OrderName = OrderName, @SOName = SOName
    FROM    dbo.KDOrderInfo
    WHERE   KDOrderInfoId = @I_PKId;

    EXEC @return_value = [dbo].[KDOrderLockDoMethod]
        @I_Sender = N'CheckIsLock' , -- nvarchar(200)
        @I_ReturnMessage = @I_ReturnMessage OUTPUT , -- nvarchar(max)
        @SOName = @SOName , -- nvarchar(50)
        @OrderName = @OrderName; -- nvarchar(50)

    IF @return_value = -1
        RETURN -1;

    IF EXISTS ( SELECT  1
                FROM    [172.16.8.31].OrBitXIZC.dbo.ContainerItem
                WHERE   KDOrderInfoId = 'JD' + RIGHT(@I_PKId, 10) AND IsCancel = 0 )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:总装已配载，不允许删除！!';
        RETURN -1;
    END;

	    DECLARE @OrderType CHAR(1);
    DECLARE @OrderCount INT;

	IF @I_PlugInCommand = 'KDOI'  --总装订单
    SET @OrderType = '1';

	IF @I_PlugInCommand = 'KDOIB' --基板订单
    SET @OrderType = '2';

	SELECT  @OrderCount = ISNULL(COUNT(KDOrderInfoId), 0)
    FROM    KDOrderInfo
    WHERE   SOName = @SOName AND OrderType = @OrderType;

	IF  @OrderCount >  1 AND  RIGHT(@OrderName,1)<>CONVERT(CHAR,@OrderCount)
	BEGIN
		 SET @I_ReturnMessage = 'ServerMessage:存在多笔订单，必须先删除最新创建的订单，无法直接删除该笔订单！!';
        RETURN -1;


	END


    DECLARE @FieldsChanged NVARCHAR(MAX);
    EXEC SysGetTableFieldsCombine
        'KDOrderInfo' ,
        @I_PKId ,
        @FieldsChanged OUTPUT;

    DELETE  KDOrderInfo
    WHERE   KDOrderInfoId = @I_PKId; 

	--将所做的删除写入修改历史中
    EXEC [dbo].[SysWriteInModifyHistory]
        @ObjectName = 'KDOrderInfo' ,
        @TablePKId = @I_PKId ,
        @ModifyType = 'Delete' ,
        @UserName = @I_OrBitUserName ,
        @ModifyHistory = @FieldsChanged;
END;





