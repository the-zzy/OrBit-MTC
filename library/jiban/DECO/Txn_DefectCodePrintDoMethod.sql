


-- =============================================
-- Author:		<OBit Team Phoenix >
-- Create date: <2016.5.31>
-- Description:	<打印不良代码>
-- Rev: 10.00
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_DefectCodePrintDoMethod]
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
@UserComment nvarchar(100)='',

@DefectCodeType char(12)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	select DefectCodeName,DefectCodeDescription,b.UserCodeName as DefectTypeName from DefectCode a 
	left join UserCode b on a.DefectTypeId=b.UserCodeId where DefectTypeId=@DefectCodeType and IsActivity=1 order by DefectCodeName
	return 0
END

















