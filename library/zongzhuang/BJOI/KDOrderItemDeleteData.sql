

-- =============================================

-- Author:		<benson>

-- Create date: <07  5 2016  1:09PM>

-- Description:	删除KDOrderModuleItem表的数据

-- Revision: 1.00

-- Update comment:

-- Update date:

-- =============================================

CREATE PROCEDURE [dbo].[KDOrderItemDeleteData]

@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言

@I_LanguageId char(1)='1',				--客户端传入的语言ID

@I_PlugInCommand varchar(5)='',			--插件命令

@I_OrBitUserId char(12)='',				--用户ID

@I_OrBitUserName nvarchar(100)='',		--用户名

@I_ResourceId	char(12)='',			--资源ID(如果资源不在资源清单中，那么它将是空的)

@I_ResourceName nvarchar(100)='',		--资源名

@I_FiltCondition	nvarchar(max)='',	--过滤条件表达式

@I_PKId char(12)='',					--主键

@I_ParentPKId char(12)='',				--用于过滤的上级主键

@I_Parameter nvarchar(100)=''			--插件参数

--以上变量为系统服务固定接口参数，必须在每一个TreeView过程中实现.

AS

BEGIN

	-- This Stored Procedure is created by OrBit-MetaObject engine	

	SET NOCOUNT ON;

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	--执行Delete

	--如果您不了解Delete过程如何编写，请参考我们提供的示例_SampleProjectDeleteData

	--获取删除前的记录	



	if not exists(select 1 from KDOrderItem where KDOrderItemId=@I_PKId and IsAdd=1)

	begin

		set @I_ReturnMessage='ServerMessage:次行项非人工添加，不允许删除!'

		return -1

	end



  	declare @FieldsChanged nvarchar(max)

	EXEC	SysGetTableFieldsCombine 'KDOrderItem',@I_PKId,@FieldsChanged output



	delete KDOrderItem where KDOrderItemId = @I_PKId 



	--将所做的删除写入修改历史中

	EXEC	[dbo].[SysWriteInModifyHistory]

			@ObjectName = 'KDOrderItem',

			@TablePKId = @I_PKId ,

			@ModifyType = 'Delete',

			@UserName = @I_OrBitUserName,

			@ModifyHistory =  @FieldsChanged



END