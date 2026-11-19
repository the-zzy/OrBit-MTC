
-- =============================================
-- Author:		<benson>
-- Create date: <07  5 2016  1:09PM>
-- Description:	删除KDOrderModuleItem表的数据
-- Revision: 1.00
-- Update comment:
-- Update date:
-- =============================================
CREATE PROCEDURE [dbo].[KDOrderItemDeleteData]
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
	--执行Delete
	--如果您不了解Delete过程如何编写，请参考我们提供的示例_SampleProjectDeleteData
	--获取删除前的记录	

    DECLARE @SOName NVARCHAR(50) = '';
    DECLARE @OrderName NVARCHAR(50) = '';

	DECLARE @return_value INT = -1;

    IF NOT EXISTS ( SELECT  1
                    FROM    KDOrderItem
                    WHERE   KDOrderItemId = @I_PKId AND IsAdd = 1 )
    BEGIN
        SET @I_ReturnMessage = 'ServerMessage:次行项非人工添加，不允许删除!';
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

    DECLARE @FieldsChanged NVARCHAR(MAX);
    EXEC SysGetTableFieldsCombine
        'KDOrderItem' ,
        @I_PKId ,
        @FieldsChanged OUTPUT;

    DELETE  KDOrderItem
    WHERE   KDOrderItemId = @I_PKId; 

	--将所做的删除写入修改历史中
    EXEC [dbo].[SysWriteInModifyHistory]
        @ObjectName = 'KDOrderItem' ,
        @TablePKId = @I_PKId ,
        @ModifyType = 'Delete' ,
        @UserName = @I_OrBitUserName ,
        @ModifyHistory = @FieldsChanged;

END;



