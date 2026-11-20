-- =============================================
-- Author:		<LZH>
-- Create date: <2024.08.28>
-- Description:	CKD栈板解绑
-- =============================================
CREATE PROCEDURE  [dbo].[PDA_CKDPalletRelieve]
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
@I_Parameter nvarchar(100)='',      --插件参数

--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
@PalletSN nvarchar(50)='',
@ScanSN nvarchar(50) = ''
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	DECLARE @ScanBoxQty INT;

	--扫描栈板号
	IF EXISTS (
		SELECT 1 FROM ShipPallet where PalletSN = @ScanSN AND IsCancel = 0
	)
	BEGIN
		SELECT @ScanBoxQty = COUNT(1) FROM dbo.ShipPallet WHERE PalletSN = @ScanSN AND IsCancel = 0;
		
		--返回界面数据
		SELECT '' AS ScanSN, @ScanSN as PalletSN, @ScanBoxQty AS ScanBoxQty;
		SET @I_ExceptionFieldName = 'ScanSN';
		SET @I_ReturnMessage='ServerMessage:获取栈板成功,请扫描箱号解绑!';
		RETURN 0;
	END
	
	IF ISNULL(@PalletSN, '') = ''
	BEGIN
		SELECT '' AS ScanSN;
		SET @I_ExceptionFieldName = 'ScanSN';
		SET @I_ReturnMessage='ServerMessage:栈板号无效，请先扫描有效的栈板号!';
		RETURN -1;
	END 

	IF NOT EXISTS (
		SELECT 1 FROM ShipPallet WHERE BoxSN = @ScanSN AND IsCancel = 0
	)
	BEGIN
		SELECT '' AS ScanSN;
		SET @I_ExceptionFieldName = 'ScanSN';
		SET @I_ReturnMessage='ServerMessage: 扫描的箱号不属于该栈板，请检查!' + @ScanSN;
		RETURN -1;
	END

	--更新栈板信息为失效
	UPDATE ShipPallet SET IsCancel=1, BoxSN = BoxSN + '_BK' 
	WHERE PalletSN = @PalletSN AND BoxSN = @ScanSN AND IsCancel = 0;

	UPDATE OrigShipPallet SET IsCancel=1, BoxSN = BoxSN + '_BK' 
	WHERE PalletSN = @PalletSN AND BoxSN = @ScanSN AND IsCancel = 0;

	SELECT @ScanBoxQty = COUNT(1) FROM dbo.ShipPallet WHERE PalletSN = @PalletSN AND IsCancel = 0;

	SELECT '' as ScanSN, @ScanBoxQty AS ScanBoxQty;
	SET @I_ExceptionFieldName = 'ScanSN';
	SET @I_ReturnMessage = 'ServerMessage: 解绑成功!';

	return 0

END
