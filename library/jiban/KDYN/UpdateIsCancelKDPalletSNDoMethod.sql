
-- =============================================
-- Author:		<OrBit Wang RT>
-- Create date: <2020.12.21>
-- Description:	撤销栈板
-- =============================================
CREATE PROCEDURE  [dbo].[UpdateIsCancelKDPalletSNDoMethod]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKid char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)='',		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
@StartPalletSN NVARCHAR(50) = '',
@EndPalletSN NVARCHAR(50) = ''
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @Count INT = 0
	DECLARE @return_value INT = -1;

	--检查元对象方法用户授权
	exec @return_value=[dbo].[MetadataPermissionCheckDoMethod]
		@I_ReturnMessage=@I_ReturnMessage output,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_Sender=@I_Sender

	if @return_value=-1
	begin
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	END
    
	IF ISNULL(@StartPalletSN,'') = '' OR ISNULL(@EndPalletSN,'') = ''
	BEGIN
		SET @I_ReturnMessage = 'ServerMessage: 起始结束栈板号不能为空！'
		RETURN -1;
	END

	IF EXISTS ( SELECT 1 FROM dbo.KDPalletInfo WHERE KDOrderInfoId = @I_ParentPKId AND PalletSN > @EndPalletSN AND IsCancel = 0 )
	BEGIN
		SET @I_ReturnMessage = 'ServerMessage: 栈板号只能从末尾开始撤销！'
		RETURN -1;
	END

	DECLARE @TempPalletSN TABLE
	(
		PalletSN NVARCHAR(50)
	)

	INSERT INTO @TempPalletSN ( PalletSN )
	SELECT PalletSN FROM dbo.KDPalletInfo 
	WHERE KDOrderInfoId = @I_ParentPKId --AND PalletSN LIKE 'PZZ%'
	AND PalletSN >= @StartPalletSN AND PalletSN <= @EndPalletSN

	/*IF EXISTS ( SELECT 1 FROM dbo.ShipPallet a
				INNER JOIN @TempPalletSN b ON b.PalletSN = a.PalletSN AND a.IsCancel = 0)
	BEGIN
		SET @I_ReturnMessage = 'ServerMessage: 已装栈，不允许撤销！'
		RETURN -1;
	END*/

	UPDATE a 
	SET a.PalletSN = a.PalletSN + '_BAK', a.IsCancel = 1, a.ModifyDate = GETDATE()
	FROM dbo.KDPalletInfo a
	INNER JOIN @TempPalletSN b ON b.PalletSN = a.PalletSN
	WHERE a.KDOrderInfoId = @I_ParentPKId --AND a.PalletSN LIKE 'PZZ%'
	
	UPDATE a 
	SET a.PalletSN = a.PalletSN + '_BAK', a.IsCancel = 1, a.ModifyDate = GETDATE()
	FROM dbo.ShipPallet a
	INNER JOIN @TempPalletSN b ON b.PalletSN = a.PalletSN

	SELECT @Count = COUNT(1) FROM @TempPalletSN

	UPDATE dbo.KDOrderInfo
	SET PalletCounter = PalletCounter - @Count
	WHERE KDOrderInfoId = @I_ParentPKId

	SET @I_ReturnMessage = 'ServerMessage: 栈板撤销成功！'
	RETURN 0

END


