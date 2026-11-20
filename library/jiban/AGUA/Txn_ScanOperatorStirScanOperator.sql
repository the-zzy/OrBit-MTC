
-- =============================================
-- Author:		<Wang RT>
-- Create date: <2020.6.1>
-- Description:	<获取用户信息>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_ScanOperatorStirScanOperator]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12) = '',				--主键
@I_SourcePKId char(12)='',			--执行拷贝时传入的源主键  
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(100)='',		--插件参数	
----------------------------------------------------------
@StirScanOperator nvarchar(50)=''       --工号

AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

      select PersonInfoId ,PersonNumber,PersonNumber as ScanOperator ,PersonName StirPersonName,PersonDescription,Position 
	  from PersonInfo where PersonInfo.PersonNumber=@StirScanOperator


	  set @I_ExceptionFieldName='AccessoryBarcodeScan'

	return 0

END




























