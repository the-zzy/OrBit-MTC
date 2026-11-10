







-- =============================================

-- Author:		<OrBit Team >

-- Create date: <2008.8.8>

-- Description:	删除UserCode表的数据

-- =============================================

CREATE PROCEDURE [dbo].[UserCodeDeleteData]

@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言

@I_LanguageId char(1)='1',				--客户端传入的语言ID

@I_PlugInCommand varchar(5)='',		--插件命令

@I_OrBitUserId char(12)='',			--用户ID

@I_OrBitUserName nvarchar(100)='',	--用户名

@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)

@I_ResourceName nvarchar(100)='',	--资源名

@I_PKid char(12) ='',				--主键

@I_ParentPKId char(12)='',			--父级主键

@I_Parameter nvarchar(100)=''			--插件参数

--以上变量为系统服务固定接口参数，必须在每一个Delete过程中实现.>

AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED



	IF @I_OrBitUserName NOT IN ('1003076','1003214')

	BEGIN

		set @I_ReturnMessage='ServerMessage:不允许删除!'

	return -1

	    

	END







	--检查记录是否受到保护

	--declare @Protected bit	

	--select @Protected=Protected from UserCode where UserCodeId = @I_PKId 

	--if @Protected=1

	--begin

	--	set @I_ReturnMessage='Data has been protected'			

	--	return -1

	--end



	--获取删除前的记录	

  	declare @FieldsChanged nvarchar(max)

	EXEC	SysGetTableFieldsCombine 'UserCode',@I_PKId,@FieldsChanged output



	--执行Delete

	begin tran

		delete UserCode where UserCodeId = @I_PKId 



	Commit Tran





	--将所做的删除写入修改历史中

	EXEC	[dbo].[SysWriteInModifyHistory]

			@ObjectName = 'UserCode',

			@TablePKId = @I_PKId ,

			@ModifyType = 'Delete',

			@UserName = @I_OrBitUserName,

			@ModifyHistory =  @FieldsChanged



END









