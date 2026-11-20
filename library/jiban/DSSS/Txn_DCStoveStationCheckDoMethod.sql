

-- =============================================
-- Author:		<mes Zheng wb>
-- Create date: <2023.02.08>
-- Description:	<炉后交接报表查询>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[Txn_DCStoveStationCheckDoMethod] 
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
    @I_Parameter NVARCHAR(100) = '' , 		--插件参数
		
    @MOName NVARCHAR(15) = ''          --订单号
    
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	IF ISNULL(@MOName, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'Servermessage:请输入工单号！';
        RETURN -1;
    END;

	IF NOT EXISTS (SELECT TOP 1 1 FROM DCStoveStationHistory WHERE RIGHT(MOName, 10) = RIGHT(@Moname, 10))
	BEGIN
        SET @I_ReturnMessage = 'Servermessage:请输入有效的生产的工单！';
        SET @I_ExceptionFieldName = 'Moname';
        RETURN -1;
    END;

	SELECT CreateDate,WorkCenterName,ShiftName,Moname,Soname,ProductName,Side,MOqty,CurrRsultQty,
			MOdonqty,RemainQty,TransPlates 转板数量,MovetoDipQty,MoveOperator,RECOperator,CreateUserid
	FROM DCStoveStationHistory
	WHERE Moname = RIGHT('0000' + @Moname, 12)
	ORDER BY CreateDate DESC
	
	IF ISNULL(@I_Sender, '') = 'OutputAll'
    BEGIN   
        SELECT CreateDate,WorkCenterName,ShiftName,Moname,Soname,ProductName,Side,MOqty,CurrRsultQty,
				MOdonqty,RemainQty,TransPlates 转板数量,MovetoDipQty,MoveOperator,RECOperator,CreateUserid
		FROM DCStoveStationHistory
		WHERE Moname = RIGHT('0000' + @Moname, 12)
		ORDER BY CreateDate DESC
        RETURN 0;

    END; 

END








